from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, time, timedelta

from django.db.models import Q
from django.utils import timezone

from core.models import (
    ConditionAlert,
    ConditionMedication,
    ConditionMedicationLog,
    MealLog,
    UnifiedHealthState,
    UnhealthyHabitReminder,
)
from core.repositories.hydration.water_log_repository import HydrationRepository
from core.services.constraints import EffectiveConstraintReader
from gamification.models import DailyMission, MotivationExperienceEvent
from gamification.services.motivation_experience_service import MotivationExperienceService
from gamification.services.motivation_feed_service import MotivationFeedService
from gamification.services.points_service import PointsService
from notification_hub.models import NotificationPlan
from notification_hub.services.preferences_service import NotificationPreferencesService
from users.services.user_profile_service import UserProfileService


@dataclass(frozen=True)
class CompiledPlan:
    kind: str
    category: str
    type: str
    priority: int
    title: str
    body: str
    route: str
    dedupe_key: str
    source_domain: str
    source_ref: str
    source_event_type: str = ""
    source_event_id: str = ""
    payload: dict = field(default_factory=dict)
    schedule_spec: dict = field(default_factory=dict)
    deliver_at: datetime | None = None
    expire_at: datetime | None = None
    sound_profile: str = ""
    exact_required: bool = False
    foreground_behavior: str = ""

class MedicationRuleCompiler:
    @staticmethod
    def _medication_body(medication: ConditionMedication) -> str:
        condition_name = (
            medication.user_condition.condition_type.name
            if medication.user_condition_id and medication.user_condition
            else ""
        )
        dose_label = " ".join(
            str(item).strip()
            for item in [medication.dosage_amount, medication.dosage_unit, medication.form]
            if str(item or "").strip()
        )
        subtitle = condition_name or dose_label or medication.instructions or "Scheduled dose"
        return f"{medication.name} - {subtitle}"

    @classmethod
    def compile(cls, *, user, preferences) -> list[CompiledPlan]:
        if not preferences.enable_medication_reminders or not preferences.enable_routine_reminders:
            return []

        from core.services.medication.dose_materialization_service import DoseMaterializationService

        DoseMaterializationService.materialize_user(
            user=user,
            horizon_hours=72,
            mark_overdue=True,
        )

        now = timezone.now()
        horizon = now + timedelta(hours=72)
        plans: list[CompiledPlan] = []
        logs = (
            ConditionMedicationLog.objects.filter(
                medication__user=user,
                medication__is_active=True,
                medication__is_prn=False,
                medication__reminder_enabled=True,
                status__in=[
                    ConditionMedicationLog.STATUS_PENDING,
                    ConditionMedicationLog.STATUS_SNOOZED,
                ],
            )
            .filter(
                Q(scheduled_for__gte=now, scheduled_for__lte=horizon)
                | Q(snoozed_until__gte=now, snoozed_until__lte=horizon)
            )
            .select_related(
                "medication",
                "medication__user_condition",
                "medication__user_condition__condition_type",
                "schedule",
            )
            .order_by("scheduled_for", "snoozed_until", "id")
        )
        for log in logs:
            medication = log.medication
            deliver_at = log.snoozed_until if log.status == ConditionMedicationLog.STATUS_SNOOZED else log.scheduled_for
            if deliver_at is None or deliver_at <= now:
                continue
            is_snoozed = log.status == ConditionMedicationLog.STATUS_SNOOZED
            plan_type = "medication_snoozed" if is_snoozed else "medication_dose"
            payload = {
                "log_id": log.id,
                "schedule_id": log.schedule_id,
                "medication_id": medication.id,
                "scheduled_for": log.scheduled_for.isoformat() if log.scheduled_for else None,
            }
            plans.append(
                CompiledPlan(
                    kind=NotificationPlan.KIND_RULE,
                    category=NotificationPlan.CATEGORY_HEALTH_CRITICAL,
                    type=plan_type,
                    priority=99 if is_snoozed else 98,
                    title="Medication reminder",
                    body=cls._medication_body(medication),
                    route=MotivationExperienceService.ROUTE_MEDICATIONS,
                    dedupe_key=f"medication-dose-log:{log.id}:{plan_type}",
                    source_domain="medication",
                    source_ref=str(log.id),
                    payload=payload,
                    deliver_at=deliver_at,
                    expire_at=deliver_at + timedelta(hours=2),
                    sound_profile="health_critical",
                    exact_required=True,
                    foreground_behavior="alert",
                )
            )
            lead_minutes = int(medication.reminder_lead_minutes or 0)
            if lead_minutes <= 0 or is_snoozed or log.scheduled_for is None:
                continue
            lead_at = log.scheduled_for - timedelta(minutes=lead_minutes)
            if lead_at <= now:
                continue
            plans.append(
                CompiledPlan(
                    kind=NotificationPlan.KIND_RULE,
                    category=NotificationPlan.CATEGORY_HEALTH_CRITICAL,
                    type="medication_lead",
                    priority=96,
                    title="Upcoming medication",
                    body=f"{medication.name} in {lead_minutes} min",
                    route=MotivationExperienceService.ROUTE_MEDICATIONS,
                    dedupe_key=f"medication-lead-log:{log.id}:{lead_minutes}",
                    source_domain="medication",
                    source_ref=str(log.id),
                    payload={**payload, "lead_minutes": lead_minutes},
                    deliver_at=lead_at,
                    expire_at=log.scheduled_for,
                    sound_profile="health_critical",
                    exact_required=True,
                    foreground_behavior="alert",
                )
            )
        return plans


class HydrationRuleCompiler:
    @classmethod
    def compile(cls, *, user, preferences) -> list[CompiledPlan]:
        user_profile = UserProfileService.ensure_profile(user)
        if not preferences.enable_routine_reminders or not preferences.enable_water_reminders:
            return []
        today = timezone.localdate()
        start_dt, end_dt = HydrationRepository.day_bounds(today)
        hydration_current = HydrationRepository.get_hydration_contribution_for_period(
            user=user,
            start=start_dt,
            end=end_dt,
        )
        active_target, state_version, state_generated_at = cls._active_target_liters(
            user=user,
            user_profile=user_profile,
            today=today,
        )
        if active_target > 0 and float(hydration_current or 0) >= active_target:
            return []
        interval_minutes = int(user_profile.water_reminder_interval_minutes or 60)
        latest_log = HydrationRepository.list_for_user_on_date(user, today).first()
        schedule_spec = {
            "kind": "interval_window",
            "interval_minutes": interval_minutes,
            "start_time": (
                preferences.water_reminder_start_time or NotificationPreferencesService.DEFAULT_WATER_START
            ).isoformat(),
            "end_time": (
                preferences.water_reminder_end_time or NotificationPreferencesService.DEFAULT_WATER_END
            ).isoformat(),
        }
        if latest_log is not None:
            not_before = latest_log.consumed_at + timedelta(minutes=interval_minutes)
            if not_before > timezone.now():
                schedule_spec["not_before"] = not_before.isoformat()
        return [
            CompiledPlan(
                kind=NotificationPlan.KIND_RULE,
                category=NotificationPlan.CATEGORY_ROUTINE,
                type="hydration_interval",
                priority=78,
                title="Hydration reminder",
                body="Take a drink and keep your hydration streak moving.",
                route=MotivationExperienceService.ROUTE_WATER,
                dedupe_key="routine:hydration-interval",
                source_domain="hydration",
                source_ref="profile",
                payload={
                    "active_target_ml": round(active_target * 1000),
                    "hydration_contribution_ml": round(float(hydration_current or 0) * 1000),
                    "goal_completed": False,
                    "state_version": state_version,
                    "state_generated_at": state_generated_at,
                },
                schedule_spec=schedule_spec,
                expire_at=end_dt,
                sound_profile="routine",
                foreground_behavior="banner",
            )
        ]

    @staticmethod
    def _active_target_liters(*, user, user_profile, today) -> tuple[float, int | None, str | None]:
        state = UnifiedHealthState.objects.filter(
            user=user,
            state_date=today,
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
        ).first()
        hydration = dict((state.progress_summary.get("hydration") if state else {}) or {})
        from_state = (
            hydration.get("adjusted_target")
            or hydration.get("target")
            or hydration.get("constraint_target")
            or hydration.get("base_target")
        )
        try:
            if from_state is not None and float(from_state) > 0:
                return (
                    float(from_state),
                    int(state.version),
                    state.last_computed_at.isoformat() if state.last_computed_at else None,
                )
        except (TypeError, ValueError):
            pass
        effective = EffectiveConstraintReader.get_effective_constraint(
            user=user,
            tracker_type="hydration",
            constraint_key="daily_water_liters",
            default_value=float(user_profile.daily_water_target or 0),
            default_unit="liters",
        )
        return float(effective.value or 0), None, None


class MealRuleCompiler:
    @classmethod
    def compile(cls, *, user, preferences) -> list[CompiledPlan]:
        del user
        if not preferences.enable_routine_reminders or not preferences.enable_meal_reminders:
            return []
        slots = [
            ("breakfast", preferences.breakfast_reminder_time or NotificationPreferencesService.DEFAULT_BREAKFAST),
            ("lunch", preferences.lunch_reminder_time or NotificationPreferencesService.DEFAULT_LUNCH),
            ("dinner", preferences.dinner_reminder_time or NotificationPreferencesService.DEFAULT_DINNER),
        ]
        return [
            CompiledPlan(
                kind=NotificationPlan.KIND_RULE,
                category=NotificationPlan.CATEGORY_ROUTINE,
                type="meal_time",
                priority=80,
                title=f"{slot.title()} reminder",
                body=f"Log your {slot} to keep today on track.",
                route=MotivationExperienceService.ROUTE_MEALS,
                dedupe_key=f"routine:meal:{slot}",
                source_domain="nutrition",
                source_ref=slot,
                schedule_spec={"kind": "daily_time", "hour": value.hour, "minute": value.minute},
                payload={"meal_type": slot},
                sound_profile="routine",
                foreground_behavior="banner",
            )
            for slot, value in slots
        ]


class ActivityRuleCompiler:
    @classmethod
    def compile(cls, *, user, preferences) -> list[CompiledPlan]:
        user_profile = UserProfileService.ensure_profile(user)
        if not preferences.enable_routine_reminders:
            return []
        plans: list[CompiledPlan] = []
        if preferences.enable_activity_reminders:
            reminder_time = user_profile.activity_reminder_time or time(10, 0)
            reminder_days = list(user_profile.activity_reminder_days or [])
            plans.append(
                CompiledPlan(
                    kind=NotificationPlan.KIND_RULE,
                    category=NotificationPlan.CATEGORY_ROUTINE,
                    type="activity_time",
                    priority=74,
                    title="Activity reminder",
                    body="Plan a workout or short walk today.",
                    route=MotivationExperienceService.ROUTE_ACTIVITY,
                    dedupe_key="routine:activity-time",
                    source_domain="activity",
                    source_ref="profile",
                    schedule_spec={
                        "kind": "weekly_time" if reminder_days else "daily_time",
                        "hour": reminder_time.hour,
                        "minute": reminder_time.minute,
                        "days_of_week": reminder_days,
                    },
                    sound_profile="routine",
                    foreground_behavior="banner",
                )
            )
        if user_profile.inactive_reminder_enabled:
            plans.append(
                CompiledPlan(
                    kind=NotificationPlan.KIND_RULE,
                    category=NotificationPlan.CATEGORY_ROUTINE,
                    type="inactive_gap",
                    priority=72,
                    title="Move a little",
                    body="A short movement break keeps your day balanced.",
                    route=MotivationExperienceService.ROUTE_ACTIVITY,
                    dedupe_key="routine:inactive-gap",
                    source_domain="activity",
                    source_ref="profile",
                    schedule_spec={
                        "kind": "interval_window",
                        "interval_minutes": int(user_profile.inactive_reminder_hours or 3) * 60,
                        "start_time": "09:00:00",
                        "end_time": "21:00:00",
                    },
                    sound_profile="routine",
                    foreground_behavior="banner",
                )
            )
        return plans


class SleepRuleCompiler:
    @classmethod
    def compile(cls, *, user, preferences) -> list[CompiledPlan]:
        user_profile = UserProfileService.ensure_profile(user)
        if not preferences.enable_routine_reminders or not preferences.enable_sleep_reminders:
            return []
        plans = []
        if user_profile.target_bed_time is not None:
            plans.append(
                CompiledPlan(
                    kind=NotificationPlan.KIND_RULE,
                    category=NotificationPlan.CATEGORY_ROUTINE,
                    type="sleep_bedtime",
                    priority=70,
                    title="Bedtime reminder",
                    body="Start winding down for better recovery.",
                    route=MotivationExperienceService.ROUTE_SLEEP,
                    dedupe_key="routine:sleep-bedtime",
                    source_domain="sleep",
                    source_ref="bedtime",
                    schedule_spec={
                        "kind": "daily_time",
                        "hour": user_profile.target_bed_time.hour,
                        "minute": user_profile.target_bed_time.minute,
                    },
                    sound_profile="routine",
                    foreground_behavior="banner",
                )
            )
        plans.append(
            CompiledPlan(
                kind=NotificationPlan.KIND_RULE,
                category=NotificationPlan.CATEGORY_ROUTINE,
                type="sleep_wake",
                priority=69,
                title="Wake reminder",
                body="Stay consistent with your sleep routine.",
                route=MotivationExperienceService.ROUTE_SLEEP,
                dedupe_key="routine:sleep-wake",
                source_domain="sleep",
                source_ref="wake",
                schedule_spec={
                    "kind": "daily_time",
                    "hour": user_profile.target_wake_time.hour,
                    "minute": user_profile.target_wake_time.minute,
                },
                sound_profile="routine",
                foreground_behavior="banner",
            )
        )
        return plans


class StepsRuleCompiler:
    @classmethod
    def compile(cls, *, user, preferences) -> list[CompiledPlan]:
        del user
        if not preferences.enable_routine_reminders or not preferences.enable_step_reminders:
            return []
        when = preferences.steps_reminder_time or NotificationPreferencesService.DEFAULT_STEPS
        return [
            CompiledPlan(
                kind=NotificationPlan.KIND_RULE,
                category=NotificationPlan.CATEGORY_ROUTINE,
                type="steps_time",
                priority=68,
                title="Steps reminder",
                body="Take a short walk to keep your step goal moving.",
                route=MotivationExperienceService.ROUTE_STEPS,
                dedupe_key="routine:steps-time",
                source_domain="steps",
                source_ref="profile",
                schedule_spec={"kind": "daily_time", "hour": when.hour, "minute": when.minute},
                sound_profile="routine",
                foreground_behavior="banner",
            )
        ]


class HabitRuleCompiler:
    @classmethod
    def compile(cls, *, user, preferences) -> list[CompiledPlan]:
        if not preferences.enable_routine_reminders or not preferences.enable_habit_reminders:
            return []
        rows = (
            UnhealthyHabitReminder.objects.filter(
                habit__user=user,
                habit__status="active",
                is_active=True,
            )
            .select_related("habit")
            .order_by("habit_id", "id")
        )
        plans: list[CompiledPlan] = []
        for reminder in rows:
            plans.append(
                CompiledPlan(
                    kind=NotificationPlan.KIND_RULE,
                    category=NotificationPlan.CATEGORY_ROUTINE,
                    type="habit_time",
                    priority=66,
                    title="Habit support reminder",
                    body=reminder.message,
                    route=MotivationExperienceService.ROUTE_HABITS,
                    dedupe_key=f"routine:habit:{reminder.id}",
                    source_domain="habits",
                    source_ref=str(reminder.id),
                    schedule_spec={
                        "kind": "daily_time",
                        "hour": reminder.time_of_day.hour,
                        "minute": reminder.time_of_day.minute,
                    },
                    payload={"habit_id": reminder.habit_id},
                    sound_profile="routine",
                    foreground_behavior="banner",
                )
            )
        return plans


class HealthSignalIntentCompiler:
    ALERT_LEVELS = {"critical", "high"}
    MAX_READING_ALERT_AGE = timedelta(hours=24)
    WARNING_PRIORITY = {
        "critical": 95,
        "high": 88,
        "warning": 82,
        "moderate": 76,
        "info": 64,
    }

    @classmethod
    def _is_actionable_warning(cls, *, user, warning: dict, now: datetime) -> bool:
        source = str(warning.get("source") or "")
        if source not in {"condition_alert", "condition_risk"}:
            return True

        event_at = None
        if source == "condition_alert":
            alert_id = str(warning.get("id") or "")
            alert = (
                ConditionAlert.objects.filter(
                    pk=int(alert_id),
                    user_condition__user=user,
                )
                .only("created_at", "status")
                .first()
                if alert_id.isdigit()
                else None
            )
            if alert is not None:
                if alert.status != ConditionAlert.STATUS_OPEN:
                    return False
                event_at = alert.created_at

        if event_at is None:
            raw_event_at = warning.get("created_at") or warning.get(
                "latest_recorded_at"
            )
            if raw_event_at:
                try:
                    event_at = datetime.fromisoformat(
                        str(raw_event_at).replace("Z", "+00:00")
                    )
                except ValueError:
                    event_at = None
        if event_at is None:
            return True
        if timezone.is_naive(event_at):
            event_at = timezone.make_aware(event_at, timezone.get_current_timezone())
        return event_at >= now - cls.MAX_READING_ALERT_AGE

    @classmethod
    def compile(cls, *, user, preferences) -> list[CompiledPlan]:
        if not preferences.enable_health_alerts:
            return []
        state = (
            UnifiedHealthState.objects.filter(
                user=user,
                window_kind=UnifiedHealthState.WINDOW_CURRENT,
            )
            .order_by("-last_computed_at", "-id")
            .first()
        )
        if state is None:
            return []
        now = timezone.now()
        plans: list[CompiledPlan] = []
        for warning in state.warnings or []:
            code = str(warning.get("code") or "health-warning")
            level = str(warning.get("level") or "warning").lower()
            if code == "medication_overdue" or level not in cls.ALERT_LEVELS:
                continue
            if not cls._is_actionable_warning(user=user, warning=warning, now=now):
                continue
            title = str(warning.get("title") or warning.get("message") or "Health alert")
            body = str(warning.get("message") or "Review your health alert details.")
            condition_label = str(warning.get("condition_label") or "").strip()
            alert_id = str(warning.get("id") or "").strip()
            is_condition_alert = (
                warning.get("source") == "condition_alert" and alert_id.isdigit()
            )
            plans.append(
                CompiledPlan(
                    kind=NotificationPlan.KIND_INTENT,
                    category=NotificationPlan.CATEGORY_HEALTH_CRITICAL,
                    type="health_warning",
                    priority=cls.WARNING_PRIORITY.get(level, 78),
                    title=title[:120],
                    body=body[:240],
                    route="/chronic-conditions",
                    dedupe_key=f"health-warning:{code}:{state.state_date.isoformat()}",
                    source_domain=(
                        "condition_alert" if is_condition_alert else "health_state"
                    ),
                    source_ref=alert_id if is_condition_alert else str(state.id),
                    payload={
                        "warning": warning,
                        "allow_acknowledge": True,
                        "source_label": condition_label,
                    },
                    deliver_at=now,
                    expire_at=now + timedelta(hours=4),
                    sound_profile="health_critical",
                    exact_required=True,
                    foreground_behavior="alert",
                )
            )
        return plans


class MotivationIntentCompiler:
    @classmethod
    def compile(cls, *, user, preferences) -> list[CompiledPlan]:
        if not preferences.enable_motivation_reminders or not preferences.enable_routine_reminders:
            return []

        target_date = timezone.localdate()
        now = timezone.localtime()
        summary = MotivationFeedService._summary(user=user, target_date=target_date)
        missions = MotivationFeedService._missions(user=user, target_date=target_date)
        badges = MotivationFeedService._badge_candidates(user=user)
        focus = MotivationFeedService._focus(summary=summary, missions=missions, badges=badges)

        rows: list[CompiledPlan] = []
        meals_today = set(
            MealLog.objects.filter(
                user=user,
                date=target_date,
                meal_type__in=("breakfast", "lunch", "dinner"),
            ).values_list("meal_type", flat=True)
        )
        reward_points = int(
            (PointsService.RULE_DEFAULTS.get("MEAL_LOGGED") or {}).get("points") or 0
        )
        for meal_type, meal_time in (
            ("breakfast", NotificationPreferencesService.DEFAULT_BREAKFAST),
            ("lunch", NotificationPreferencesService.DEFAULT_LUNCH),
            ("dinner", NotificationPreferencesService.DEFAULT_DINNER),
        ):
            if meal_type in meals_today:
                continue
            deliver_after = timezone.make_aware(
                datetime.combine(target_date, meal_time),
                timezone.get_current_timezone(),
            )
            if now < deliver_after:
                continue
            rows.append(
                CompiledPlan(
                    kind=NotificationPlan.KIND_INTENT,
                    category=NotificationPlan.CATEGORY_MOTIVATION,
                    type="first_meal_missing",
                    priority=74,
                    title=f"Log your {meal_type}",
                    body=f"Track it now to earn +{reward_points} points.",
                    route=MotivationExperienceService.ROUTE_MEALS,
                    dedupe_key=f"motivation:first-meal:{meal_type}:{target_date.isoformat()}",
                    source_domain="motivation",
                    source_ref=meal_type,
                    payload={"reward_points": reward_points},
                    deliver_at=deliver_after,
                    expire_at=deliver_after + timedelta(hours=2),
                    sound_profile="motivation",
                    foreground_behavior="in_app_only",
                )
            )
            break

        near_missions = [
            mission
            for mission in missions
            if mission.status == DailyMission.STATUS_IN_PROGRESS
            and 60 <= mission.progress_percent < 100
            and mission.points_reward > 0
        ]
        near_missions.sort(key=lambda item: (-item.progress_percent, -item.points_reward))
        if near_missions:
            mission = near_missions[0]
            rows.append(
                CompiledPlan(
                    kind=NotificationPlan.KIND_INTENT,
                    category=NotificationPlan.CATEGORY_MOTIVATION,
                    type="mission_near_complete",
                    priority=72,
                    title=mission.title,
                    body=f"One more step closes this mission for +{mission.points_reward} points.",
                    route=MotivationExperienceService.route_for_mission(mission.mission_type),
                    dedupe_key=f"motivation:mission-near:{mission.mission_type}:{target_date.isoformat()}",
                    source_domain="motivation",
                    source_ref=mission.mission_type,
                    payload={"reward_points": int(mission.points_reward or 0)},
                    deliver_at=now,
                    expire_at=now + timedelta(hours=4),
                    sound_profile="motivation",
                    foreground_behavior="in_app_only",
                )
            )

        if int(summary.get("current_streak") or 0) > 0 and now.hour >= 18:
            actionable = next(
                (
                    mission
                    for mission in missions
                    if mission.status not in {
                        DailyMission.STATUS_COMPLETED,
                        DailyMission.STATUS_NOT_APPLICABLE,
                    }
                ),
                None,
            )
            if actionable is not None:
                rows.append(
                    CompiledPlan(
                        kind=NotificationPlan.KIND_INTENT,
                        category=NotificationPlan.CATEGORY_MOTIVATION,
                        type="streak_at_risk",
                        priority=76,
                        title="Keep your streak alive",
                        body=f"{actionable.title} can protect your streak tonight.",
                        route=MotivationExperienceService.route_for_mission(actionable.mission_type),
                        dedupe_key=f"motivation:streak-risk:{target_date.isoformat()}",
                        source_domain="motivation",
                        source_ref=str(target_date),
                        payload={"reward_points": int(actionable.points_reward or 0)},
                        deliver_at=now,
                        expire_at=now + timedelta(hours=3),
                        sound_profile="motivation",
                        foreground_behavior="in_app_only",
                    )
                )

        for badge in badges:
            remaining = max(int(badge.badge.required_value or 0) - int(badge.progress_value or 0), 0)
            if remaining != 1:
                continue
            rows.append(
                CompiledPlan(
                    kind=NotificationPlan.KIND_INTENT,
                    category=NotificationPlan.CATEGORY_MOTIVATION,
                    type="badge_near_unlock",
                    priority=70,
                    title=f"{badge.badge.name} is close",
                    body="One more action can unlock this badge.",
                    route=MotivationExperienceService.ROUTE_SCORE,
                    dedupe_key=f"motivation:badge-near:{badge.badge.code}:{target_date.isoformat()}",
                    source_domain="motivation",
                    source_ref=badge.badge.code,
                    payload={"reward_points": int(badge.badge.points_bonus or 0)},
                    deliver_at=now,
                    expire_at=now + timedelta(hours=8),
                    sound_profile="motivation",
                    foreground_behavior="in_app_only",
                )
            )
            break

        points_to_next = int(summary.get("points_to_next_level") or 0)
        if 0 < points_to_next <= 50:
            rows.append(
                CompiledPlan(
                    kind=NotificationPlan.KIND_INTENT,
                    category=NotificationPlan.CATEGORY_MOTIVATION,
                    type="level_progress_nudge",
                    priority=68,
                    title="Next level is close",
                    body=f"You only need {points_to_next} more points.",
                    route=str(focus.get("route") or MotivationExperienceService.ROUTE_SCORE),
                    dedupe_key=f"motivation:level-close:{summary.get('level')}:{target_date.isoformat()}",
                    source_domain="motivation",
                    source_ref=str(summary.get("level") or 1),
                    payload={"reward_points": int(focus.get("reward_points") or 0)},
                    deliver_at=now,
                    expire_at=now + timedelta(hours=6),
                    sound_profile="motivation",
                    foreground_behavior="in_app_only",
                )
            )
        return rows


class CelebrationIntentCompiler:
    IMPORTANT_TYPES = {
        MotivationExperienceEvent.TYPE_MISSION_COMPLETED,
        MotivationExperienceEvent.TYPE_BADGE_EARNED,
        MotivationExperienceEvent.TYPE_LEVEL_UP,
        MotivationExperienceEvent.TYPE_STREAK_MILESTONE,
    }

    @classmethod
    def compile(cls, *, user, preferences) -> list[CompiledPlan]:
        del preferences
        now = timezone.now()
        rows = list(
            MotivationExperienceEvent.objects.filter(
                user=user,
                is_acknowledged=False,
                created_at__gt=now - timedelta(hours=12),
            )
            .order_by("-created_at", "-id")[:6]
        )
        plans: list[CompiledPlan] = []
        for row in rows:
            if row.event_type not in cls.IMPORTANT_TYPES:
                continue
            plans.append(
                CompiledPlan(
                    kind=NotificationPlan.KIND_INTENT,
                    category=NotificationPlan.CATEGORY_CELEBRATION,
                    type=row.event_type,
                    priority=60,
                    title=row.title,
                    body=row.subtitle,
                    route=row.route,
                    dedupe_key=f"celebration:{row.id}",
                    source_domain="gamification",
                    source_ref=str(row.id),
                    source_event_type="motivation_experience",
                    source_event_id=str(row.id),
                    payload={
                        "animation": row.animation,
                        "points_delta": int(row.points_delta or 0),
                    },
                    deliver_at=row.created_at,
                    expire_at=row.created_at + timedelta(hours=12),
                    sound_profile="motivation",
                    foreground_behavior="in_app_only",
                )
            )
        return plans
