from __future__ import annotations

import logging
from datetime import datetime, time, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from django.db import transaction
from django.utils import timezone

from core.services.chronic.condition_alert_service import ConditionAlertService
from gamification.models import MotivationExperienceEvent
from notification_hub.models import (
    NotificationDevice,
    NotificationPlan,
    NotificationPlanEvent,
)
from notification_hub.services.compilers import (
    ActivityRuleCompiler,
    CelebrationIntentCompiler,
    CompiledPlan,
    HabitRuleCompiler,
    HealthSignalIntentCompiler,
    HydrationRuleCompiler,
    MealRuleCompiler,
    MedicationRuleCompiler,
    MotivationIntentCompiler,
    SleepRuleCompiler,
    StepsRuleCompiler,
)
from notification_hub.services.preferences_service import NotificationPreferencesService


logger = logging.getLogger(__name__)


class NotificationHubPlanner:
    CHANNELS_VERSION = 3
    HORIZON_HOURS = 72
    ROUTINE_PROXIMITY_MINUTES = 90

    TERMINAL_STATUSES = {
        NotificationPlan.STATUS_ACKNOWLEDGED,
        NotificationPlan.STATUS_EXPIRED,
        NotificationPlan.STATUS_CANCELLED,
    }
    QUOTA_EVENT_TYPES = {
        NotificationPlanEvent.EVENT_SCHEDULED_LOCAL,
        NotificationPlanEvent.EVENT_PRESENTED_IN_APP,
        NotificationPlanEvent.EVENT_DELIVERED,
        NotificationPlanEvent.EVENT_ACKNOWLEDGED,
        # Count legacy clients once while they roll forward.
        NotificationPlanEvent.EVENT_FOREGROUND_SUPPRESSED,
    }
    IN_APP_PRESENTABLE_STATUSES = {
        NotificationPlan.STATUS_PENDING,
        NotificationPlan.STATUS_PLANNED,
        NotificationPlan.STATUS_SCHEDULED_LOCAL,
        NotificationPlan.STATUS_DELIVERY_FAILED,
    }

    @classmethod
    def _envelope(cls, *, data: dict, request_id: str) -> dict:
        return {
            "data": data,
            "meta": {
                "is_stale": False,
                "computed_at": timezone.now().isoformat(),
                "snapshot_version": cls.CHANNELS_VERSION,
                "request_id": request_id,
            },
        }

    @staticmethod
    def _device_timezone(device: NotificationDevice):
        try:
            return ZoneInfo(str(device.timezone or "UTC"))
        except ZoneInfoNotFoundError:
            return timezone.get_current_timezone()

    @classmethod
    def _device_payload(cls, device: NotificationDevice) -> dict:
        return {
            "id": device.id,
            "is_primary": bool(device.is_primary),
            "is_active": bool(device.is_active and device.revoked_at is None),
            "assignment_version": int(device.assignment_version or 1),
            "permission_status": device.permission_status,
        }

    @classmethod
    def _disabled_sync(
        cls,
        *,
        device: NotificationDevice,
        reason: str,
        request_id: str,
        cancel_plan_ids: list[str],
        in_app_events: list[dict] | None = None,
    ) -> dict:
        logger.info(
            "notification_hub_sync_disabled user_id=%s device_id=%s primary=%s reason=%s",
            device.user_id,
            device.id,
            device.is_primary,
            reason,
        )
        return cls._envelope(
            data={
                "delivery_enabled": False,
                "reason": reason,
                "device": cls._device_payload(device),
                "device_assignment_version": int(device.assignment_version or 1),
                "server_now": timezone.now().isoformat(),
                "channels_version": cls.CHANNELS_VERSION,
                "horizon_hours": cls.HORIZON_HOURS,
                "plans": [],
                "cancel_plan_ids": cancel_plan_ids,
                "cancelled_plan_ids": cancel_plan_ids,
                "cancel_all_local_plans": True,
                "in_app_events": in_app_events or [],
            },
            request_id=request_id,
        )

    @classmethod
    def _quiet_allowed(
        cls,
        *,
        compiled: CompiledPlan,
        preferences,
        candidate_dt: datetime | None,
        device: NotificationDevice,
    ) -> bool:
        if not preferences.quiet_hours_enabled or candidate_dt is None:
            return True
        if (
            compiled.category == NotificationPlan.CATEGORY_HEALTH_CRITICAL
            and preferences.critical_bypass_quiet_hours
        ):
            return True
        if preferences.quiet_start is None or preferences.quiet_end is None:
            return True
        local_value = candidate_dt.astimezone(cls._device_timezone(device)).time()
        value = local_value.replace(tzinfo=None)
        start = preferences.quiet_start
        end = preferences.quiet_end
        if start <= end:
            return not (start <= value <= end)
        return not (value >= start or value <= end)

    @staticmethod
    def _action_context(row: CompiledPlan) -> str:
        domain = str(row.source_domain or "").strip().lower()
        if domain in {
            "hydration",
            "nutrition",
            "activity",
            "sleep",
            "medication",
            "steps",
            "habits",
        }:
            return domain
        mission_map = {
            "hydration_goal": "hydration",
            "nutrition_meals": "nutrition",
            "activity_minutes": "activity",
            "medication_adherence": "medication",
            "habit_goal": "habits",
            "sleep_goal": "sleep",
        }
        source_ref = str(row.source_ref or "").strip().lower()
        if source_ref in mission_map:
            return mission_map[source_ref]
        if row.type == "first_meal_missing":
            return "nutrition"
        route_map = {
            "/water": "hydration",
            "/nutrition": "nutrition",
            "/meals": "nutrition",
            "/activity": "activity",
            "/sleep": "sleep",
            "/medications": "medication",
            "/habits": "habits",
        }
        return route_map.get(str(row.route or "").strip().lower(), "")

    @classmethod
    def _routine_occurrences_near(
        cls,
        *,
        routine: CompiledPlan,
        candidate_at: datetime,
        device: NotificationDevice,
    ) -> list[datetime]:
        if routine.deliver_at is not None:
            return [routine.deliver_at]
        spec = routine.schedule_spec or {}
        kind = str(spec.get("kind") or "")
        if not kind:
            return []
        tzinfo = cls._device_timezone(device)
        local_candidate = candidate_at.astimezone(tzinfo)
        rows: list[datetime] = []
        for day_offset in (-1, 0, 1):
            target_day = (local_candidate + timedelta(days=day_offset)).date()
            if kind in {"daily_time", "weekly_time"}:
                allowed = {
                    int(value)
                    for value in spec.get("days_of_week", [])
                    if str(value).isdigit()
                }
                if kind == "weekly_time" and allowed and target_day.isoweekday() not in allowed:
                    continue
                rows.append(
                    datetime.combine(
                        target_day,
                        time(
                            int(spec.get("hour") or 0),
                            int(spec.get("minute") or 0),
                        ),
                        tzinfo=tzinfo,
                    )
                )
                continue
            if kind != "interval_window":
                continue
            start_parts = str(spec.get("start_time") or "09:00").split(":")
            end_parts = str(spec.get("end_time") or "21:00").split(":")
            interval = max(int(spec.get("interval_minutes") or 60), 1)
            cursor = datetime.combine(
                target_day,
                time(int(start_parts[0]), int(start_parts[1])),
                tzinfo=tzinfo,
            )
            end = datetime.combine(
                target_day,
                time(int(end_parts[0]), int(end_parts[1])),
                tzinfo=tzinfo,
            )
            while cursor <= end:
                rows.append(cursor)
                cursor += timedelta(minutes=interval)
        return rows

    @classmethod
    def _suppressed_by_routine_window(
        cls,
        *,
        candidate: CompiledPlan,
        routine_plans: list[CompiledPlan],
        device: NotificationDevice,
    ) -> bool:
        if candidate.category != NotificationPlan.CATEGORY_MOTIVATION:
            return False
        if candidate.deliver_at is None:
            return False
        context = cls._action_context(candidate)
        if not context:
            return False
        window = timedelta(minutes=cls.ROUTINE_PROXIMITY_MINUTES)
        for routine in routine_plans:
            if cls._action_context(routine) != context:
                continue
            for routine_at in cls._routine_occurrences_near(
                routine=routine,
                candidate_at=candidate.deliver_at,
                device=device,
            ):
                if abs(candidate.deliver_at - routine_at) <= window:
                    logger.info(
                        "notification_candidate_rejected device_id=%s category=motivation decision=proximity context=%s",
                        device.id,
                        context,
                    )
                    return True
        return False

    @classmethod
    def _compiled_plans(cls, *, user) -> list[CompiledPlan]:
        preferences = NotificationPreferencesService.get_or_create(user=user)
        rows: list[CompiledPlan] = []
        rows.extend(MedicationRuleCompiler.compile(user=user, preferences=preferences))
        rows.extend(HealthSignalIntentCompiler.compile(user=user, preferences=preferences))
        rows.extend(HydrationRuleCompiler.compile(user=user, preferences=preferences))
        rows.extend(MealRuleCompiler.compile(user=user, preferences=preferences))
        rows.extend(ActivityRuleCompiler.compile(user=user, preferences=preferences))
        rows.extend(SleepRuleCompiler.compile(user=user, preferences=preferences))
        rows.extend(StepsRuleCompiler.compile(user=user, preferences=preferences))
        rows.extend(HabitRuleCompiler.compile(user=user, preferences=preferences))
        rows.extend(MotivationIntentCompiler.compile(user=user, preferences=preferences))
        rows.extend(CelebrationIntentCompiler.compile(user=user, preferences=preferences))
        now = timezone.now()
        rows = [row for row in rows if row.expire_at is None or row.expire_at > now]
        rows.sort(
            key=lambda item: (
                -int(item.priority or 0),
                item.expire_at or datetime.max.replace(tzinfo=ZoneInfo("UTC")),
                item.dedupe_key,
            )
        )
        return rows

    @classmethod
    def _serialize_plan(cls, *, plan: NotificationPlan) -> dict:
        scheduled_at = plan.deliver_at.isoformat() if plan.deliver_at else None
        expires_at = plan.expire_at.isoformat() if plan.expire_at else None
        return {
            "plan_id": plan.plan_id,
            "revision": int(plan.revision or 1),
            "kind": plan.kind,
            "category": plan.category,
            "delivery": "in_app" if plan.kind == NotificationPlan.KIND_IN_APP else "local_scheduled",
            "type": plan.type,
            "priority": int(plan.priority or 0),
            "title": plan.title,
            "body": plan.body,
            "route": plan.route,
            "payload": plan.payload or {},
            "schedule_spec": plan.schedule_spec or {},
            "deliver_at": scheduled_at,
            "scheduled_at": scheduled_at,
            "expire_at": expires_at,
            "expires_at": expires_at,
            "sound_profile": plan.sound_profile,
            "channel_id": cls._channel_id(plan.category),
            "exact_required": bool(plan.exact_required),
            "foreground_behavior": plan.foreground_behavior,
            "dedupe_key": plan.dedupe_key,
            "cancellation_key": plan.plan_id,
            "status": plan.status,
            "source_event_type": plan.source_event_type,
            "source_event_id": plan.source_event_id,
        }

    @classmethod
    def _channel_id(cls, category: str) -> str:
        return {
            NotificationPlan.CATEGORY_HEALTH_CRITICAL: "health_critical_v3",
            NotificationPlan.CATEGORY_MOTIVATION: "motivation_v3",
            NotificationPlan.CATEGORY_CELEBRATION: "motivation_v3",
            NotificationPlan.CATEGORY_SYSTEM: "system_status_v3",
        }.get(category, "routine_v3")

    @classmethod
    def _upsert_plan(
        cls,
        *,
        user,
        device,
        compiled: CompiledPlan,
    ) -> tuple[NotificationPlan, bool, bool]:
        values = {
            "kind": compiled.kind,
            "category": compiled.category,
            "type": compiled.type,
            "priority": compiled.priority,
            "title": compiled.title,
            "body": compiled.body,
            "route": compiled.route,
            "payload": compiled.payload,
            "schedule_spec": compiled.schedule_spec,
            "deliver_at": compiled.deliver_at,
            "expire_at": compiled.expire_at,
            "sound_profile": compiled.sound_profile,
            "exact_required": compiled.exact_required,
            "foreground_behavior": compiled.foreground_behavior,
            "source_domain": compiled.source_domain,
            "source_ref": compiled.source_ref,
            "source_event_type": compiled.source_event_type,
            "source_event_id": compiled.source_event_id,
        }
        plan, created = NotificationPlan.objects.get_or_create(
            device=device,
            dedupe_key=compiled.dedupe_key,
            defaults={"user": user, "status": NotificationPlan.STATUS_PLANNED, **values},
        )
        if created:
            return plan, True, True
        comparison_values = values
        if (
            compiled.kind == NotificationPlan.KIND_INTENT
            and compiled.category == NotificationPlan.CATEGORY_HEALTH_CRITICAL
        ):
            # Immediate health intents are compiled at sync time. Their rolling
            # delivery window must not create a new revision of the same warning.
            comparison_values = {
                key: value
                for key, value in values.items()
                if key not in {"deliver_at", "expire_at"}
            }
        changed = any(
            getattr(plan, key) != value for key, value in comparison_values.items()
        )
        if changed:
            for key, value in values.items():
                setattr(plan, key, value)
            plan.revision = int(plan.revision or 1) + 1
            plan.status = NotificationPlan.STATUS_PLANNED
            plan.presented_at = None
            plan.acknowledged_at = None
            plan.save()
        elif plan.status in {NotificationPlan.STATUS_CANCELLED, NotificationPlan.STATUS_EXPIRED}:
            plan.status = NotificationPlan.STATUS_PLANNED
            plan.save(update_fields=["status", "updated_at"])
        return plan, False, changed

    @classmethod
    def _filter_motivation_quota(
        cls,
        *,
        rows: list[CompiledPlan],
        device: NotificationDevice,
        preferences,
    ) -> list[CompiledPlan]:
        tzinfo = cls._device_timezone(device)
        local_now = timezone.now().astimezone(tzinfo)
        start = datetime.combine(local_now.date(), time.min, tzinfo=tzinfo)
        end = start + timedelta(days=1)
        historical = list(
            NotificationPlanEvent.objects.filter(
                device=device,
                plan__category=NotificationPlan.CATEGORY_MOTIVATION,
                event_type__in=cls.QUOTA_EVENT_TYPES,
                event_at__gte=start,
                event_at__lt=end,
            ).select_related("plan")
        )
        counted_plan_ids = {event.plan_id for event in historical}
        active_today = list(
            NotificationPlan.objects.filter(
                device=device,
                category=NotificationPlan.CATEGORY_MOTIVATION,
                deliver_at__gte=start,
                deliver_at__lt=end,
            ).exclude(status__in=cls.TERMINAL_STATUSES)
        )
        counted_plan_ids.update(plan.id for plan in active_today)
        existing_by_dedupe = {plan.dedupe_key: plan for plan in active_today}
        limit = max(int(preferences.motivation_max_per_day or 2), 0)
        remaining = max(0, limit - len(counted_plan_ids))
        cooldown = timedelta(hours=int(preferences.motivation_type_cooldown_hours or 6))
        recent_types = {
            event.plan.type
            for event in historical
            if event.event_at >= timezone.now() - cooldown
        }
        accepted_types: set[str] = set()
        accepted: list[CompiledPlan] = []
        for row in rows:
            if row.category != NotificationPlan.CATEGORY_MOTIVATION:
                accepted.append(row)
                continue
            if row.dedupe_key in existing_by_dedupe:
                accepted.append(row)
                continue
            if remaining <= 0:
                logger.info(
                    "notification_candidate_rejected device_id=%s category=motivation decision=quota quota_remaining=0",
                    device.id,
                )
                continue
            if row.type in recent_types or row.type in accepted_types:
                logger.info(
                    "notification_candidate_rejected device_id=%s category=motivation decision=cooldown type=%s quota_remaining=%s",
                    device.id,
                    row.type,
                    remaining,
                )
                continue
            accepted.append(row)
            accepted_types.add(row.type)
            remaining -= 1
            logger.info(
                "notification_candidate_accepted device_id=%s category=motivation type=%s quota_remaining=%s",
                device.id,
                row.type,
                remaining,
            )
        return accepted

    @classmethod
    @transaction.atomic
    def sync(
        cls,
        *,
        user,
        device,
        last_known_plan_ids: list[str],
        foreground_state: str,
        request_id: str,
    ) -> dict:
        device = NotificationDevice.objects.select_for_update().get(pk=device.pk)
        known_ids = {str(value) for value in last_known_plan_ids if str(value)}
        if device.user_id != user.id:
            raise ValueError("Notification device does not belong to this user.")
        if not device.is_active or device.revoked_at is not None:
            return cls._disabled_sync(
                device=device,
                reason="device_inactive",
                request_id=request_id,
                cancel_plan_ids=sorted(known_ids),
            )
        if not device.is_primary:
            return cls._disabled_sync(
                device=device,
                reason="not_primary_device",
                request_id=request_id,
                cancel_plan_ids=sorted(known_ids),
            )

        preferences = NotificationPreferencesService.get_or_create(user=user)
        raw_rows = cls._compiled_plans(user=user)
        routine_rows = [
            row for row in raw_rows if row.category == NotificationPlan.CATEGORY_ROUTINE
        ]
        eligible: list[CompiledPlan] = []
        for row in raw_rows:
            if row.expire_at is not None and row.expire_at <= timezone.now():
                continue
            if not cls._quiet_allowed(
                compiled=row,
                preferences=preferences,
                candidate_dt=row.deliver_at,
                device=device,
            ):
                continue
            if cls._suppressed_by_routine_window(
                candidate=row,
                routine_plans=routine_rows,
                device=device,
            ):
                continue
            eligible.append(row)
        eligible.sort(
            key=lambda item: (
                -int(item.priority or 0),
                item.expire_at or datetime.max.replace(tzinfo=ZoneInfo("UTC")),
                item.dedupe_key,
            )
        )
        eligible = cls._filter_motivation_quota(
            rows=eligible,
            device=device,
            preferences=preferences,
        )

        delivery_enabled = bool(
            device.notifications_authorized
            and device.notifications_enabled_systemwide
            and device.permission_status in {"authorized", "provisional"}
        )
        active_existing = {
            row.dedupe_key: row
            for row in NotificationPlan.objects.filter(device=device).exclude(
                status__in=cls.TERMINAL_STATUSES
            )
        }
        next_dedupe_keys = {row.dedupe_key for row in eligible}
        local_plans: list[NotificationPlan] = []
        in_app_events: list[dict] = []

        for compiled in eligible:
            is_foreground_event = (
                foreground_state == "foreground"
                and compiled.kind == NotificationPlan.KIND_INTENT
                and compiled.foreground_behavior in {"in_app_only", "alert"}
            )
            if not delivery_enabled and not is_foreground_event:
                continue
            plan, _, _ = cls._upsert_plan(
                user=user,
                device=device,
                compiled=compiled,
            )
            if is_foreground_event:
                if plan.status in cls.IN_APP_PRESENTABLE_STATUSES:
                    in_app_events.append(cls._serialize_plan(plan=plan))
            else:
                if plan.status not in {
                    NotificationPlan.STATUS_PRESENTED_IN_APP,
                    NotificationPlan.STATUS_ACKNOWLEDGED,
                    NotificationPlan.STATUS_DISMISSED,
                }:
                    local_plans.append(plan)

        cancel_ids = set(known_ids - {plan.plan_id for plan in local_plans})
        for dedupe_key, row in active_existing.items():
            if dedupe_key in next_dedupe_keys:
                continue
            if row.plan_id in {event["plan_id"] for event in in_app_events}:
                cancel_ids.add(row.plan_id)
                continue
            row.status = NotificationPlan.STATUS_CANCELLED
            row.save(update_fields=["status", "updated_at"])
            cancel_ids.add(row.plan_id)

        device.last_sync_at = timezone.now()
        device.save(update_fields=["last_sync_at", "updated_at"])
        if not delivery_enabled:
            return cls._disabled_sync(
                device=device,
                reason="notifications_unavailable",
                request_id=request_id,
                cancel_plan_ids=sorted(cancel_ids | known_ids),
                in_app_events=in_app_events,
            )

        serialized_cancel = sorted(cancel_ids)
        return cls._envelope(
            data={
                "delivery_enabled": True,
                "reason": None,
                "device": cls._device_payload(device),
                "device_assignment_version": int(device.assignment_version or 1),
                "server_now": timezone.now().isoformat(),
                "channels_version": cls.CHANNELS_VERSION,
                "horizon_hours": cls.HORIZON_HOURS,
                "plans": [cls._serialize_plan(plan=plan) for plan in local_plans],
                "cancel_plan_ids": serialized_cancel,
                "cancelled_plan_ids": serialized_cancel,
                "cancel_all_local_plans": False,
                "in_app_events": in_app_events,
            },
            request_id=request_id,
        )

    @classmethod
    def _next_status(cls, *, current: str, outcome: str) -> str:
        allowed = {
            NotificationPlanEvent.EVENT_SCHEDULED_LOCAL: {
                NotificationPlan.STATUS_PLANNED,
                NotificationPlan.STATUS_DELIVERY_FAILED,
                NotificationPlan.STATUS_SCHEDULED_LOCAL,
            },
            NotificationPlanEvent.EVENT_PRESENTED_IN_APP: {
                NotificationPlan.STATUS_PLANNED,
                NotificationPlan.STATUS_SCHEDULED_LOCAL,
                NotificationPlan.STATUS_DELIVERY_FAILED,
                NotificationPlan.STATUS_DISMISSED,
                NotificationPlan.STATUS_PRESENTED_IN_APP,
            },
            NotificationPlanEvent.EVENT_DELIVERY_FAILED: {
                NotificationPlan.STATUS_PLANNED,
                NotificationPlan.STATUS_SCHEDULED_LOCAL,
                NotificationPlan.STATUS_PRESENTED_IN_APP,
                NotificationPlan.STATUS_DELIVERY_FAILED,
            },
            NotificationPlanEvent.EVENT_ACKNOWLEDGED: {
                NotificationPlan.STATUS_PRESENTED_IN_APP,
                NotificationPlan.STATUS_DELIVERED,
                NotificationPlan.STATUS_ACKNOWLEDGED,
            },
            NotificationPlanEvent.EVENT_DISMISSED: {
                NotificationPlan.STATUS_PRESENTED_IN_APP,
                NotificationPlan.STATUS_DISMISSED,
            },
            NotificationPlanEvent.EVENT_EXPIRED: set(),
            NotificationPlanEvent.EVENT_SUPPRESSED_BY_POLICY: {
                NotificationPlan.STATUS_PENDING,
                NotificationPlan.STATUS_PLANNED,
            },
            NotificationPlanEvent.EVENT_DELIVERED: {
                NotificationPlan.STATUS_SCHEDULED_LOCAL,
                NotificationPlan.STATUS_DELIVERED,
            },
            NotificationPlanEvent.EVENT_OPENED: {
                NotificationPlan.STATUS_SCHEDULED_LOCAL,
                NotificationPlan.STATUS_DELIVERED,
                NotificationPlan.STATUS_PRESENTED_IN_APP,
            },
            NotificationPlanEvent.EVENT_CANCELLED: {
                NotificationPlan.STATUS_PENDING,
                NotificationPlan.STATUS_PLANNED,
                NotificationPlan.STATUS_SCHEDULED_LOCAL,
                NotificationPlan.STATUS_DELIVERY_FAILED,
                NotificationPlan.STATUS_DISMISSED,
                NotificationPlan.STATUS_CANCELLED,
            },
        }
        if outcome == NotificationPlanEvent.EVENT_EXPIRED:
            if current == NotificationPlan.STATUS_ACKNOWLEDGED:
                raise ValueError("Acknowledged plans cannot expire.")
            return NotificationPlan.STATUS_EXPIRED
        if outcome not in allowed or current not in allowed[outcome]:
            raise ValueError(f"Unsupported notification transition: {current} -> {outcome}.")
        return {
            NotificationPlanEvent.EVENT_SCHEDULED_LOCAL: NotificationPlan.STATUS_SCHEDULED_LOCAL,
            NotificationPlanEvent.EVENT_PRESENTED_IN_APP: NotificationPlan.STATUS_PRESENTED_IN_APP,
            NotificationPlanEvent.EVENT_DELIVERY_FAILED: NotificationPlan.STATUS_DELIVERY_FAILED,
            NotificationPlanEvent.EVENT_ACKNOWLEDGED: NotificationPlan.STATUS_ACKNOWLEDGED,
            NotificationPlanEvent.EVENT_DISMISSED: NotificationPlan.STATUS_DISMISSED,
            NotificationPlanEvent.EVENT_SUPPRESSED_BY_POLICY: NotificationPlan.STATUS_SUPPRESSED_BY_POLICY,
            NotificationPlanEvent.EVENT_DELIVERED: NotificationPlan.STATUS_DELIVERED,
            NotificationPlanEvent.EVENT_OPENED: NotificationPlan.STATUS_PRESENTED_IN_APP,
            NotificationPlanEvent.EVENT_CANCELLED: NotificationPlan.STATUS_CANCELLED,
        }[outcome]

    @classmethod
    @transaction.atomic
    def report(
        cls,
        *,
        user,
        device,
        events: list[dict],
        request_id: str,
    ) -> dict:
        normalized = []
        for item in events:
            event_id = str(item.get("event_id") or "").strip()
            plan_id = str(item.get("plan_id") or "").strip()
            outcome = str(item.get("outcome") or "").strip()
            if not event_id or not plan_id or not outcome:
                continue
            existing_event = NotificationPlanEvent.objects.filter(event_id=event_id).first()
            if existing_event is not None:
                normalized.append(
                    {
                        "event_id": event_id,
                        "plan_id": existing_event.plan.plan_id,
                        "outcome": existing_event.event_type,
                        "duplicate": True,
                    }
                )
                continue
            plan = (
                NotificationPlan.objects.select_for_update()
                .filter(user=user, device=device, plan_id=plan_id)
                .first()
            )
            if plan is None:
                continue
            revision = int(item.get("revision") or plan.revision or 1)
            if revision != int(plan.revision or 1):
                raise ValueError("Report revision does not match the current plan revision.")
            next_status = cls._next_status(current=plan.status, outcome=outcome)
            event_at = item.get("occurred_at")
            if not isinstance(event_at, datetime):
                event_at = timezone.now()
            NotificationPlanEvent.objects.create(
                event_id=event_id,
                plan=plan,
                device=device,
                plan_revision=revision,
                event_type=outcome,
                event_at=event_at,
                failure_code=str(item.get("failure_code") or ""),
                suppression_reason=str(item.get("suppression_reason") or ""),
                payload=dict(item.get("metadata") or {}),
            )
            plan.status = next_status
            update_fields = ["status", "updated_at"]
            if outcome in {
                NotificationPlanEvent.EVENT_PRESENTED_IN_APP,
                NotificationPlanEvent.EVENT_OPENED,
            }:
                plan.presented_at = event_at
                update_fields.append("presented_at")
            if outcome == NotificationPlanEvent.EVENT_ACKNOWLEDGED:
                plan.acknowledged_at = event_at
                update_fields.append("acknowledged_at")
                if (
                    plan.source_event_type == "motivation_experience"
                    and plan.source_event_id
                ):
                    MotivationExperienceEvent.objects.filter(
                        user=user,
                        pk=plan.source_event_id,
                        is_acknowledged=False,
                    ).update(is_acknowledged=True, acknowledged_at=event_at)
                if plan.source_domain == "condition_alert" and plan.source_ref.isdigit():
                    ConditionAlertService.mark_seen(
                        user=user,
                        alert_id=int(plan.source_ref),
                    )
            plan.save(update_fields=update_fields)
            normalized.append(
                {
                    "event_id": event_id,
                    "plan_id": plan.plan_id,
                    "revision": revision,
                    "outcome": outcome,
                    "duplicate": False,
                }
            )
            logger.info(
                "notification_event_reported user_id=%s device_id=%s plan_id=%s revision=%s outcome=%s",
                user.id,
                device.id,
                plan.plan_id,
                revision,
                outcome,
            )

        return cls._envelope(
            data={"recorded_events": normalized},
            request_id=request_id,
        )
