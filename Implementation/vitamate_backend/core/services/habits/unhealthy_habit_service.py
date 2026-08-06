from __future__ import annotations

from collections import Counter
from datetime import date, datetime, time, timedelta
from uuid import uuid4

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone
from rest_framework.exceptions import NotFound, ValidationError

from core.models import (
    FoodItem,
    MealLog,
    NutritionFacts,
    UnhealthyHabit,
    UnhealthyHabitBaseline,
    UnhealthyHabitLog,
    UnhealthyHabitPlan,
    UnhealthyHabitPointEvent,
    UnhealthyHabitReminder,
    WaterLog,
)
from core.services.nutrition_service import NutritionLoggingService as NutritionService
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers
from core.services.habits.habit_evaluation_service import HabitEvaluationService
from gamification.services.points_service import PointsService


class UnhealthyHabitService:
    HABIT_LABELS = {
        UnhealthyHabit.TYPE_SMOKING: "Smoking",
        UnhealthyHabit.TYPE_CAFFEINE: "Caffeine",
        UnhealthyHabit.TYPE_FAST_FOOD: "Fast food",
    }
    DEFAULT_UNITS = {
        UnhealthyHabit.TYPE_SMOKING: "cigarettes",
        UnhealthyHabit.TYPE_CAFFEINE: "mg",
        UnhealthyHabit.TYPE_FAST_FOOD: "meals",
    }

    @classmethod
    def overview(cls, *, user, request_id: str) -> dict:
        today = timezone.localdate()
        habits = list(
            UnhealthyHabit.objects.filter(user=user)
            .select_related("baseline", "plan")
            .prefetch_related("reminders")
            .order_by("habit_type", "-created_at")
        )
        latest_by_type = {}
        for habit in habits:
            latest_by_type.setdefault(habit.habit_type, habit)

        payload = []
        for habit_type in (
            UnhealthyHabit.TYPE_SMOKING,
            UnhealthyHabit.TYPE_CAFFEINE,
            UnhealthyHabit.TYPE_FAST_FOOD,
        ):
            habit = latest_by_type.get(habit_type)
            if habit is None:
                payload.append(cls._empty_card(habit_type))
                continue
            payload.append(cls._habit_payload(habit=habit, today=today))

        return cls._envelope(
            data={
                "habits": payload,
                "summary": cls.summary_for_user(user=user, target_date=today),
                "support_message": "Progress is measured by consistency, not perfection.",
            },
            request_id=request_id,
        )

    @classmethod
    @transaction.atomic
    def create_habit(cls, *, user, payload: dict, request_id: str) -> dict:
        habit_type = payload["habit_type"]
        idempotency_key = str(payload.get("idempotency_key") or "").strip()
        if idempotency_key:
            existing = UnhealthyHabit.objects.filter(
                user=user,
                setup_idempotency_key=idempotency_key,
            ).first()
            if existing is not None:
                return cls._envelope(
                    data={"habit": cls._habit_payload(habit=existing, today=timezone.localdate())},
                    request_id=request_id,
                )
        habit = (
            UnhealthyHabit.objects.filter(
                user=user,
                habit_type=habit_type,
                status__in=(UnhealthyHabit.STATUS_ACTIVE, UnhealthyHabit.STATUS_PAUSED),
            )
            .order_by("-created_at", "-id")
            .first()
        )
        if habit is None:
            habit = UnhealthyHabit.objects.create(
                user=user,
                habit_type=habit_type,
                title=payload.get("title") or cls.HABIT_LABELS[habit_type],
                goal_type=payload.get("goal_type") or UnhealthyHabit.GOAL_REDUCE,
                start_date=payload.get("start_date") or timezone.localdate(),
                target_date=payload.get("target_date"),
                setup_idempotency_key=idempotency_key,
            )
        else:
            habit.title = payload.get("title") or habit.title or cls.HABIT_LABELS[habit_type]
            habit.goal_type = payload.get("goal_type") or habit.goal_type
            habit.status = UnhealthyHabit.STATUS_ACTIVE
            if payload.get("start_date") is not None:
                habit.start_date = payload.get("start_date")
            if "target_date" in payload:
                habit.target_date = payload.get("target_date")
            if idempotency_key and not habit.setup_idempotency_key:
                habit.setup_idempotency_key = idempotency_key
            habit.save(
                update_fields=[
                    "title",
                    "goal_type",
                    "status",
                    "start_date",
                    "target_date",
                    "setup_idempotency_key",
                    "updated_at",
                ]
            )
        cls._publish_changed(user=user, event_date=habit.start_date, reference=f"habit:{habit.id}")
        return cls._envelope(
            data={"habit": cls._habit_payload(habit=habit, today=timezone.localdate())},
            request_id=request_id,
        )

    @classmethod
    @transaction.atomic
    def setup_habit(cls, *, user, payload: dict, request_id: str) -> dict:
        idempotency_key = str(payload.get("idempotency_key") or "").strip()
        if idempotency_key:
            existing = UnhealthyHabit.objects.filter(
                user=user,
                setup_idempotency_key=idempotency_key,
            ).select_related("baseline", "plan").prefetch_related("reminders").first()
            if existing is not None:
                return cls._envelope(
                    data={"habit": cls._habit_payload(habit=existing, today=timezone.localdate())},
                    request_id=request_id,
                )

        habit_payload = dict(payload.get("habit") or {})
        if idempotency_key:
            habit_payload["idempotency_key"] = idempotency_key
        habit_result = cls.create_habit(
            user=user,
            payload=habit_payload,
            request_id=request_id,
        )
        habit_id = dict(dict(habit_result.get("data") or {}).get("habit") or {}).get("id")
        habit = cls.get_habit_for_user(user=user, habit_id=habit_id)

        cls.upsert_baseline(
            habit=habit,
            payload=dict(payload.get("baseline") or {}),
            request_id=request_id,
        )
        plan_payload = {
            **dict(payload.get("plan") or {}),
            "goal_type": habit_payload.get("goal_type") or habit.goal_type,
        }
        cls.upsert_plan(habit=habit, payload=plan_payload, request_id=request_id)
        reminders = list(payload.get("reminders") or [])
        if reminders:
            cls.replace_reminders(habit=habit, reminders=reminders, request_id=request_id)
        habit = cls.get_habit_for_user(user=user, habit_id=habit.id)
        return cls._envelope(
            data={"habit": cls._habit_payload(habit=habit, today=timezone.localdate())},
            request_id=request_id,
        )

    @classmethod
    @transaction.atomic
    def upsert_baseline(cls, *, habit, payload: dict, request_id: str) -> dict:
        baseline, _ = UnhealthyHabitBaseline.objects.update_or_create(
            habit=habit,
            defaults={
                "initial_frequency": payload.get("initial_frequency") or 0,
                "initial_quantity": payload.get("initial_quantity") or 0,
                "unit": payload.get("unit") or cls.DEFAULT_UNITS.get(habit.habit_type, ""),
                "common_trigger": payload.get("common_trigger") or "",
                "common_time": payload.get("common_time"),
                "notes": payload.get("notes") or "",
                "extra": payload.get("extra") or {},
            },
        )
        cls._ensure_default_plan(habit=habit, baseline=baseline)
        cls._publish_changed(user=habit.user, event_date=timezone.localdate(), reference=f"baseline:{habit.id}")
        return cls._envelope(
            data={"habit": cls._habit_payload(habit=habit, today=timezone.localdate())},
            request_id=request_id,
        )

    @classmethod
    @transaction.atomic
    def upsert_plan(cls, *, habit, payload: dict, request_id: str) -> dict:
        requested_goal_type = payload.get("goal_type")
        if requested_goal_type:
            habit.goal_type = requested_goal_type
        baseline = getattr(habit, "baseline", None)
        defaults = cls._default_plan_values(habit=habit, baseline=baseline)
        defaults.update(
            {
                "daily_limit": payload.get("daily_limit", defaults.get("daily_limit")),
                "weekly_limit": payload.get("weekly_limit", defaults.get("weekly_limit")),
                "target_quantity": payload.get("target_quantity", defaults.get("target_quantity")),
                "reduction_percentage": payload.get(
                    "reduction_percentage",
                    defaults.get("reduction_percentage", 0),
                ),
                "cutoff_time": payload.get("cutoff_time", defaults.get("cutoff_time")),
                "plan_stage": payload.get("plan_stage") or defaults.get("plan_stage", ""),
                "healthy_replacement_required": bool(
                    payload.get(
                        "healthy_replacement_required",
                        defaults.get("healthy_replacement_required", False),
                    )
                ),
                "reminder_time": payload.get("reminder_time", defaults.get("reminder_time")),
                "notes": payload.get("notes") or "",
            }
        )
        UnhealthyHabitPlan.objects.update_or_create(habit=habit, defaults=defaults)
        if payload.get("target_date") is not None:
            habit.target_date = payload.get("target_date")
        habit.save(update_fields=["goal_type", "target_date", "updated_at"])
        cls._publish_changed(user=habit.user, event_date=timezone.localdate(), reference=f"plan:{habit.id}")
        return cls._envelope(
            data={"habit": cls._habit_payload(habit=habit, today=timezone.localdate())},
            request_id=request_id,
        )

    @classmethod
    @transaction.atomic
    def log_habit(cls, *, habit, payload: dict, request_id: str) -> dict:
        logged_at = payload.get("logged_at") or timezone.now()
        log_date = timezone.localtime(logged_at).date()
        quantity = float(payload.get("quantity") or 1)
        caffeine_mg = float(payload.get("caffeine_mg") or 0)
        calories_kcal = float(payload.get("calories_kcal") or 0)

        idempotency_key = str(payload.get("idempotency_key") or "").strip()
        source_ref = f"direct:{idempotency_key}" if idempotency_key else ""
        if source_ref:
            existing = UnhealthyHabitLog.objects.filter(
                habit=habit,
                source_type=UnhealthyHabitLog.SOURCE_TYPE_DIRECT,
                source_ref=source_ref,
            ).first()
            if existing is not None:
                evaluation = HabitEvaluationService.evaluate_habit(
                    habit=habit,
                    target_date=existing.log_date,
                )
                return cls._envelope(
                    data=cls._write_payload(
                        log=existing,
                        habit=habit,
                        evaluation=evaluation,
                        tracker_projection=cls._tracker_projection_payload(existing),
                    ),
                    request_id=request_id,
                )

        metric_quantity = cls._metric_quantity(
            habit_type=habit.habit_type,
            quantity=quantity,
            caffeine_mg=caffeine_mg,
        )
        is_within_limit = cls._is_within_limit_after_log(
            habit=habit,
            log_date=log_date,
            new_metric_quantity=metric_quantity,
        )
        is_relapse = bool(payload.get("is_relapse")) or not is_within_limit

        log = UnhealthyHabitLog.objects.create(
            habit=habit,
            logged_at=logged_at,
            log_date=log_date,
            quantity=quantity,
            unit=payload.get("unit") or cls.DEFAULT_UNITS.get(habit.habit_type, ""),
            trigger=payload.get("trigger") or "",
            mood=payload.get("mood") or "",
            notes=payload.get("notes") or "",
            is_relapse=is_relapse,
            is_within_limit=is_within_limit,
            sync_to_tracker=bool(payload.get("sync_to_tracker")),
            origin_domain=UnhealthyHabitLog.ORIGIN_HABITS,
            origin_record_id="",
            correlation_id=idempotency_key or uuid4().hex,
            source_type=UnhealthyHabitLog.SOURCE_TYPE_DIRECT,
            source_ref=source_ref,
            reward_owner_domain="habits",
            meal_type=payload.get("meal_type") or "unknown",
            caffeine_mg=caffeine_mg,
            calories_kcal=calories_kcal,
            food_name=payload.get("food_name") or "",
            healthy_replacement=bool(payload.get("healthy_replacement")),
        )

        if log.sync_to_tracker:
            cls._sync_tracker_log(log=log, payload=payload)
            log.refresh_from_db()
        cls._award_points(log)
        cls._publish_changed(user=habit.user, event_date=log_date, reference=f"unhealthy-log:{log.id}")
        evaluation = HabitEvaluationService.evaluate_habit(habit=habit, target_date=log_date)

        return cls._envelope(
            data=cls._write_payload(
                log=log,
                habit=habit,
                evaluation=evaluation,
                tracker_projection=cls._tracker_projection_payload(log),
            ),
            request_id=request_id,
        )

    @classmethod
    @transaction.atomic
    def update_habit_log(cls, *, habit, log_id: int, payload: dict, request_id: str) -> dict:
        log = habit.logs.filter(id=log_id).first()
        if log is None:
            raise NotFound("Habit log not found.")
        if log.source_type == UnhealthyHabitLog.SOURCE_TYPE_TRACKER_PROJECTION:
            raise ValidationError(
                {"log": "Edit this record from its source tracker."},
            )

        logged_at = payload.get("logged_at") or log.logged_at
        log.logged_at = logged_at
        log.log_date = timezone.localtime(logged_at).date()
        log.quantity = float(payload.get("quantity", log.quantity) or 0)
        log.unit = payload.get("unit", log.unit) or cls.DEFAULT_UNITS.get(habit.habit_type, "")
        log.trigger = payload.get("trigger", log.trigger) or ""
        log.mood = payload.get("mood", log.mood) or ""
        log.notes = payload.get("notes", log.notes) or ""
        log.sync_to_tracker = bool(payload.get("sync_to_tracker", log.sync_to_tracker))
        log.caffeine_mg = float(payload.get("caffeine_mg", log.caffeine_mg) or 0)
        log.calories_kcal = float(payload.get("calories_kcal", log.calories_kcal) or 0)
        log.food_name = payload.get("food_name", log.food_name) or ""
        log.healthy_replacement = bool(payload.get("healthy_replacement", log.healthy_replacement))
        log.meal_type = payload.get("meal_type", log.meal_type) or "unknown"
        metric_quantity = cls._metric_quantity(
            habit_type=habit.habit_type,
            quantity=log.quantity,
            caffeine_mg=log.caffeine_mg,
        )
        log.is_within_limit = cls._is_within_limit_after_log_excluding(
            habit=habit,
            log_date=log.log_date,
            new_metric_quantity=metric_quantity,
            exclude_log_id=log.id,
        )
        log.is_relapse = bool(payload.get("is_relapse", log.is_relapse)) or not log.is_within_limit
        log.save(
            update_fields=[
                "logged_at",
                "log_date",
                "quantity",
                "unit",
                "trigger",
                "mood",
                "notes",
                "sync_to_tracker",
                "caffeine_mg",
                "calories_kcal",
                "food_name",
                "healthy_replacement",
                "meal_type",
                "is_within_limit",
                "is_relapse",
            ]
        )
        if log.sync_to_tracker:
            cls._sync_tracker_log(log=log, payload=payload)
            log.refresh_from_db()
        else:
            cls._delete_tracker_projection_for_log(log=log)
            log.linked_meal_log = None
            log.linked_water_log = None
            log.save(update_fields=["linked_meal_log", "linked_water_log"])
        cls._publish_changed(user=habit.user, event_date=log.log_date, reference=f"unhealthy-log-update:{log.id}")
        evaluation = HabitEvaluationService.evaluate_habit(habit=habit, target_date=log.log_date)
        return cls._envelope(
            data=cls._write_payload(
                log=log,
                habit=habit,
                evaluation=evaluation,
                tracker_projection=cls._tracker_projection_payload(log),
            ),
            request_id=request_id,
        )

    @classmethod
    @transaction.atomic
    def delete_habit_log(cls, *, habit, log_id: int, request_id: str) -> dict:
        log = habit.logs.filter(id=log_id).first()
        if log is None:
            raise NotFound("Habit log not found.")
        target_date = log.log_date
        if log.source_type != UnhealthyHabitLog.SOURCE_TYPE_TRACKER_PROJECTION:
            cls._delete_tracker_projection_for_log(log=log)
        log.delete()
        cls._publish_changed(user=habit.user, event_date=target_date, reference=f"unhealthy-log-delete:{log_id}")
        return cls._envelope(
            data={
                "deleted": True,
                "log_id": log_id,
                "summary": cls.summary_for_user(user=habit.user, target_date=target_date),
            },
            request_id=request_id,
        )

    @classmethod
    @transaction.atomic
    def daily_check_in(cls, *, habit, payload: dict, request_id: str) -> dict:
        if habit.status != UnhealthyHabit.STATUS_ACTIVE:
            evaluation = HabitEvaluationService.evaluate_habit(
                habit=habit,
                target_date=payload.get("date") or timezone.localdate(),
            )
            return cls._envelope(
                data={
                    "log": None,
                    "habit": cls._habit_payload(
                        habit=habit,
                        today=payload.get("date") or timezone.localdate(),
                    ),
                    "evaluation": evaluation,
                    "confirmed_points": [],
                    "in_app_events": [],
                    "tracker_projection": {},
                },
                request_id=request_id,
            )
        target_date = payload.get("date") or timezone.localdate()
        used = bool(payload.get("used"))
        idempotency_key = str(payload.get("idempotency_key") or "").strip()
        source_ref = f"checkin:{target_date.isoformat()}:{idempotency_key}" if idempotency_key else f"checkin:{target_date.isoformat()}"

        logged_at = timezone.make_aware(datetime.combine(target_date, time(12, 0)), timezone.get_current_timezone())
        log, created = UnhealthyHabitLog.objects.get_or_create(
            habit=habit,
            source_type=UnhealthyHabitLog.SOURCE_TYPE_DIRECT,
            source_ref=source_ref,
            defaults={
                "logged_at": logged_at,
                "log_date": target_date,
                "quantity": 1 if used else 0,
                "unit": cls.DEFAULT_UNITS.get(habit.habit_type, ""),
                "is_relapse": used and habit.goal_type == UnhealthyHabit.GOAL_QUIT,
                "is_within_limit": not used,
                "source": UnhealthyHabitLog.SOURCE_MANUAL,
                "origin_domain": UnhealthyHabitLog.ORIGIN_HABITS,
                "correlation_id": idempotency_key or uuid4().hex,
                "reward_owner_domain": "habits",
                "is_abstinence_checkin": not used,
            },
        )
        if not created:
            log.quantity = 1 if used else 0
            log.is_abstinence_checkin = not used
            log.is_relapse = used and habit.goal_type == UnhealthyHabit.GOAL_QUIT
            log.is_within_limit = not log.is_relapse
            log.save(update_fields=["quantity", "is_abstinence_checkin", "is_relapse", "is_within_limit"])
        if used:
            cls._award_points(log)
        else:
            cls._apply_point_event(
                log=log,
                event_type=UnhealthyHabitPointEvent.EVENT_IMPROVEMENT,
                points=5,
                award=lambda: PointsService.award_unhealthy_habit_improvement(
                    habit.user,
                    source_id=f"{habit.id}:abstinence:{target_date.isoformat()}",
                    event_date=target_date,
                ),
                per_log=False,
            )
        cls._publish_changed(user=habit.user, event_date=target_date, reference=f"checkin:{habit.id}:{target_date}")
        evaluation = HabitEvaluationService.evaluate_habit(habit=habit, target_date=target_date)
        return cls._envelope(
            data=cls._write_payload(
                log=log,
                habit=habit,
                evaluation=evaluation,
                tracker_projection={},
            ),
            request_id=request_id,
        )

    @classmethod
    @transaction.atomic
    def replace_reminders(cls, *, habit, reminders: list[dict], request_id: str) -> dict:
        habit.reminders.all().delete()
        for item in reminders:
            if item.get("time_of_day") is None:
                continue
            UnhealthyHabitReminder.objects.create(
                habit=habit,
                time_of_day=item["time_of_day"],
                message=item.get("message") or cls._default_reminder_message(habit.habit_type),
                is_active=item.get("is_active", True),
            )
        cls._publish_changed(user=habit.user, event_date=timezone.localdate(), reference=f"reminders:{habit.id}")
        return cls._envelope(
            data={"habit": cls._habit_payload(habit=habit, today=timezone.localdate())},
            request_id=request_id,
        )

    @classmethod
    @transaction.atomic
    def pause_habit(cls, *, habit, request_id: str) -> dict:
        habit.status = UnhealthyHabit.STATUS_PAUSED
        habit.save(update_fields=["status", "updated_at"])
        cls._publish_changed(user=habit.user, event_date=timezone.localdate(), reference=f"pause:{habit.id}")
        return cls._envelope(
            data={"habit": cls._habit_payload(habit=habit, today=timezone.localdate())},
            request_id=request_id,
        )

    @classmethod
    @transaction.atomic
    def resume_habit(cls, *, habit, request_id: str) -> dict:
        habit.status = UnhealthyHabit.STATUS_ACTIVE
        habit.save(update_fields=["status", "updated_at"])
        cls._publish_changed(user=habit.user, event_date=timezone.localdate(), reference=f"resume:{habit.id}")
        return cls._envelope(
            data={"habit": cls._habit_payload(habit=habit, today=timezone.localdate())},
            request_id=request_id,
        )

    @staticmethod
    def get_habit_for_user(*, user, habit_id: int) -> UnhealthyHabit:
        habit = (
            UnhealthyHabit.objects.filter(user=user, id=habit_id)
            .select_related("baseline", "plan")
            .prefetch_related("reminders")
            .first()
        )
        if habit is None:
            raise NotFound("Habit not found.")
        return habit

    @classmethod
    def summary_for_user(cls, *, user, target_date: date | None = None) -> dict:
        target_date = target_date or timezone.localdate()
        evaluation_summary = HabitEvaluationService.evaluate_user(
            user=user,
            target_date=target_date,
        )
        active_habits = [
            item
            for item in evaluation_summary["evaluations"]
            if item.get("is_applicable")
        ]
        confirmed = [item for item in active_habits if item.get("confirmed")]
        relapse_count = int(evaluation_summary.get("relapses_today") or 0)
        points_today = (
            UnhealthyHabitPointEvent.objects.filter(habit__user=user, event_date=target_date)
            .aggregate(total=Sum("points"))
            .get("total")
            or 0
        )
        return {
            "active_count": len(active_habits),
            "logs_today": len(confirmed),
            "confirmed_today": len(confirmed),
            "completed_today": int(evaluation_summary.get("completed_count") or 0),
            "relapses_today": relapse_count,
            "points_today": int(points_today),
            "score": int(evaluation_summary.get("score") or 0),
            "habit_types": [item.get("habit_type") for item in active_habits],
            "evaluations": evaluation_summary["evaluations"],
        }

    @classmethod
    def late_caffeine_logs(cls, *, user, planned_bed_time: datetime) -> list[dict]:
        day_start = planned_bed_time - timedelta(hours=18)
        logs = UnhealthyHabitLog.objects.filter(
            habit__user=user,
            habit__habit_type=UnhealthyHabit.TYPE_CAFFEINE,
            logged_at__gte=day_start,
            logged_at__lte=planned_bed_time,
            caffeine_mg__gt=0,
        )
        result = []
        for log in logs:
            local_time = timezone.localtime(log.logged_at)
            hours_before_bed = (planned_bed_time - log.logged_at).total_seconds() / 3600
            if local_time.hour >= 14 or hours_before_bed <= 8:
                result.append(
                    {
                        "source": "unhealthy_habits",
                        "logged_at": log.logged_at.isoformat(),
                        "caffeine_mg": round(log.caffeine_mg, 1),
                    }
                )
        return result

    @classmethod
    def late_smoking_logs(cls, *, user, planned_bed_time: datetime) -> list[dict]:
        window_start = planned_bed_time - timedelta(hours=3)
        return [
            {
                "source": "unhealthy_habits",
                "logged_at": log.logged_at.isoformat(),
                "quantity": round(log.quantity, 2),
            }
            for log in UnhealthyHabitLog.objects.filter(
                habit__user=user,
                habit__habit_type=UnhealthyHabit.TYPE_SMOKING,
                logged_at__gte=window_start,
                logged_at__lte=planned_bed_time,
            )
        ]

    @classmethod
    def _habit_payload(cls, *, habit: UnhealthyHabit, today: date) -> dict:
        progress = cls._progress_for_habit(habit=habit, target_date=today)
        baseline = getattr(habit, "baseline", None)
        plan = getattr(habit, "plan", None)
        return {
            "id": habit.id,
            "habit_type": habit.habit_type,
            "label": cls.HABIT_LABELS.get(habit.habit_type, habit.habit_type),
            "title": habit.title or cls.HABIT_LABELS.get(habit.habit_type, habit.habit_type),
            "goal_type": habit.goal_type,
            "status": habit.status,
            "start_date": str(habit.start_date),
            "target_date": str(habit.target_date) if habit.target_date else None,
            "is_setup": baseline is not None and plan is not None,
            "baseline": cls._baseline_payload(baseline),
            "plan": cls._plan_payload(plan),
            "progress": progress,
            "evaluation": HabitEvaluationService.evaluate_habit(habit=habit, target_date=today),
            "reminders": [cls._reminder_payload(item) for item in habit.reminders.all()],
        }

    @classmethod
    def _empty_card(cls, habit_type: str) -> dict:
        return {
            "id": None,
            "habit_type": habit_type,
            "label": cls.HABIT_LABELS[habit_type],
            "title": cls.HABIT_LABELS[habit_type],
            "goal_type": UnhealthyHabit.GOAL_REDUCE,
            "status": "not_started",
            "start_date": None,
            "target_date": None,
            "is_setup": False,
            "baseline": None,
            "plan": None,
            "progress": cls._empty_progress(habit_type),
            "evaluation": {
                "habit_id": None,
                "date": timezone.localdate().isoformat(),
                "habit_type": habit_type,
                "status": "not_logged",
                "is_applicable": False,
                "is_complete": False,
                "confirmed": False,
            },
            "reminders": [],
        }

    @staticmethod
    def _baseline_payload(baseline) -> dict | None:
        if baseline is None:
            return None
        return {
            "initial_frequency": baseline.initial_frequency,
            "initial_quantity": baseline.initial_quantity,
            "unit": baseline.unit,
            "common_trigger": baseline.common_trigger,
            "common_time": baseline.common_time.strftime("%H:%M") if baseline.common_time else None,
            "notes": baseline.notes,
            "extra": baseline.extra,
        }

    @staticmethod
    def _plan_payload(plan) -> dict | None:
        if plan is None:
            return None
        return {
            "daily_limit": plan.daily_limit,
            "weekly_limit": plan.weekly_limit,
            "target_quantity": plan.target_quantity,
            "reduction_percentage": plan.reduction_percentage,
            "cutoff_time": plan.cutoff_time.strftime("%H:%M") if plan.cutoff_time else None,
            "plan_stage": plan.plan_stage,
            "healthy_replacement_required": plan.healthy_replacement_required,
            "reminder_time": plan.reminder_time.strftime("%H:%M") if plan.reminder_time else None,
            "notes": plan.notes,
        }

    @staticmethod
    def _reminder_payload(reminder) -> dict:
        return {
            "id": reminder.id,
            "time_of_day": reminder.time_of_day.strftime("%H:%M"),
            "message": reminder.message,
            "is_active": reminder.is_active,
        }

    @classmethod
    def _progress_for_habit(cls, *, habit: UnhealthyHabit, target_date: date) -> dict:
        today_logs = list(habit.logs.filter(log_date=target_date))
        week_start = target_date - timedelta(days=target_date.weekday())
        week_logs = list(habit.logs.filter(log_date__gte=week_start, log_date__lte=target_date))
        plan = getattr(habit, "plan", None)
        baseline = getattr(habit, "baseline", None)

        today_value = sum(cls._metric_from_log(log) for log in today_logs)
        week_value = sum(cls._metric_from_log(log) for log in week_logs)
        daily_limit = plan.daily_limit if plan and plan.daily_limit is not None else None
        weekly_limit = plan.weekly_limit if plan and plan.weekly_limit is not None else None
        limit = weekly_limit if habit.habit_type == UnhealthyHabit.TYPE_FAST_FOOD else daily_limit
        current = week_value if habit.habit_type == UnhealthyHabit.TYPE_FAST_FOOD else today_value
        adherence = 100
        if limit and limit > 0:
            adherence = max(0, min(100, round((1 - max(current - limit, 0) / limit) * 100)))

        baseline_quantity = baseline.initial_quantity if baseline else 0
        improvement = 0
        if baseline_quantity:
            improvement = max(0, round(((baseline_quantity - today_value) / baseline_quantity) * 100))

        triggers = [log.trigger for log in week_logs if log.trigger]
        hours = [timezone.localtime(log.logged_at).hour for log in week_logs]
        risky_hour = Counter(hours).most_common(1)[0][0] if hours else None
        return {
            "today_value": round(today_value, 2),
            "week_value": round(week_value, 2),
            "daily_limit": daily_limit,
            "weekly_limit": weekly_limit,
            "adherence_percent": adherence,
            "improvement_percent": improvement,
            "relapse_count": sum(1 for log in week_logs if log.is_relapse),
            "top_trigger": Counter(triggers).most_common(1)[0][0] if triggers else "",
            "risky_hour": risky_hour,
            "support_message": cls._support_message(
                habit_type=habit.habit_type,
                is_over_limit=bool(limit and current > limit),
                has_logs=bool(today_logs),
            ),
            "logs_today": [cls._log_payload(log) for log in today_logs],
        }

    @classmethod
    def _empty_progress(cls, habit_type: str) -> dict:
        return {
            "today_value": 0,
            "week_value": 0,
            "daily_limit": None,
            "weekly_limit": None,
            "adherence_percent": 0,
            "improvement_percent": 0,
            "relapse_count": 0,
            "top_trigger": "",
            "risky_hour": None,
            "support_message": cls._support_message(
                habit_type=habit_type,
                is_over_limit=False,
                has_logs=False,
            ),
            "logs_today": [],
        }

    @staticmethod
    def _log_payload(log: UnhealthyHabitLog) -> dict:
        return {
            "id": log.id,
            "logged_at": log.logged_at.isoformat(),
            "log_date": str(log.log_date),
            "quantity": log.quantity,
            "unit": log.unit,
            "trigger": log.trigger,
            "mood": log.mood,
            "notes": log.notes,
            "is_relapse": log.is_relapse,
            "is_within_limit": log.is_within_limit,
            "sync_to_tracker": log.sync_to_tracker,
            "caffeine_mg": log.caffeine_mg,
            "calories_kcal": log.calories_kcal,
            "food_name": log.food_name,
            "healthy_replacement": log.healthy_replacement,
            "linked_meal_log": log.linked_meal_log_id,
            "linked_water_log": log.linked_water_log_id,
            "origin_domain": log.origin_domain,
            "origin_record_id": log.origin_record_id,
            "correlation_id": log.correlation_id,
            "source_type": log.source_type,
            "source_ref": log.source_ref,
            "reward_owner_domain": log.reward_owner_domain,
            "meal_type": log.meal_type,
            "is_abstinence_checkin": log.is_abstinence_checkin,
        }

    @classmethod
    def _write_payload(
        cls,
        *,
        log: UnhealthyHabitLog,
        habit: UnhealthyHabit,
        evaluation: dict,
        tracker_projection: dict,
    ) -> dict:
        return {
            "log": cls._log_payload(log),
            "habit": cls._habit_payload(habit=habit, today=log.log_date),
            "evaluation": evaluation,
            "confirmed_points": cls._points_for_log(log),
            "in_app_events": list(evaluation.get("in_app_events") or []),
            "tracker_projection": tracker_projection,
        }

    @staticmethod
    def _points_for_log(log: UnhealthyHabitLog) -> list[dict]:
        return [
            {
                "event_type": item.event_type,
                "points": int(item.points or 0),
                "event_date": item.event_date.isoformat(),
            }
            for item in log.point_events.order_by("created_at", "id")
        ]

    @staticmethod
    def _tracker_projection_payload(log: UnhealthyHabitLog) -> dict:
        meal = log.linked_meal_log
        water = log.linked_water_log
        return {
            "meal_log_id": meal.id if meal is not None else None,
            "water_log_id": water.id if water is not None else None,
            "source_ref": f"habit_log:{log.id}",
            "status": "linked" if meal is not None or water is not None else "none",
        }

    @classmethod
    def _ensure_default_plan(cls, *, habit: UnhealthyHabit, baseline: UnhealthyHabitBaseline) -> None:
        if hasattr(habit, "plan"):
            return
        UnhealthyHabitPlan.objects.create(
            habit=habit,
            **cls._default_plan_values(habit=habit, baseline=baseline),
        )

    @classmethod
    def _default_plan_values(cls, *, habit: UnhealthyHabit, baseline) -> dict:
        initial = float(getattr(baseline, "initial_quantity", 0) or 0)
        target_quantity = 0 if habit.goal_type == UnhealthyHabit.GOAL_QUIT else None
        if habit.habit_type == UnhealthyHabit.TYPE_FAST_FOOD:
            weekly = max(0, round(initial * 0.8, 2)) if initial else 2
            return {
                "daily_limit": None,
                "weekly_limit": weekly,
                "target_quantity": target_quantity if target_quantity is not None else max(0, round(weekly * 0.5, 2)),
                "reduction_percentage": 20 if initial else 0,
                "cutoff_time": None,
                "plan_stage": cls._generated_plan_stage(
                    habit_type=habit.habit_type,
                    goal_type=habit.goal_type,
                    first_limit=weekly,
                    unit="meals/week",
                ),
                "healthy_replacement_required": True,
                "reminder_time": time(12, 0),
            }
        if habit.habit_type == UnhealthyHabit.TYPE_CAFFEINE:
            daily = max(0, round(initial * 0.8, 2)) if initial else 300
            return {
                "daily_limit": daily,
                "weekly_limit": None,
                "target_quantity": target_quantity if target_quantity is not None else max(0, round(daily * 0.5, 2)),
                "reduction_percentage": 20 if initial else 0,
                "cutoff_time": time(18, 0),
                "plan_stage": cls._generated_plan_stage(
                    habit_type=habit.habit_type,
                    goal_type=habit.goal_type,
                    first_limit=daily,
                    unit="mg/day",
                ),
                "healthy_replacement_required": False,
                "reminder_time": time(14, 0),
            }
        daily = max(0, round(initial * 0.8, 2)) if initial else 5
        return {
            "daily_limit": daily,
            "weekly_limit": None,
            "target_quantity": target_quantity if target_quantity is not None else max(0, round(daily * 0.5, 2)),
            "reduction_percentage": 20 if initial else 0,
            "cutoff_time": None,
            "plan_stage": cls._generated_plan_stage(
                habit_type=habit.habit_type,
                goal_type=habit.goal_type,
                first_limit=daily,
                unit="per day",
            ),
            "healthy_replacement_required": False,
            "reminder_time": time(18, 0),
        }

    @staticmethod
    def _generated_plan_stage(*, habit_type: str, goal_type: str, first_limit: float, unit: str) -> str:
        goal_label = "Quit plan" if goal_type == UnhealthyHabit.GOAL_QUIT else "Reduction plan"
        if habit_type == UnhealthyHabit.TYPE_CAFFEINE:
            return f"{goal_label}: start with up to {first_limit:g} {unit}, then reduce step by step."
        if habit_type == UnhealthyHabit.TYPE_FAST_FOOD:
            return f"{goal_label}: start with up to {first_limit:g} {unit}, then replace gradually."
        return f"{goal_label}: start with up to {first_limit:g} {unit}, then reduce step by step."

    @classmethod
    def _is_within_limit_after_log(
        cls,
        *,
        habit: UnhealthyHabit,
        log_date: date,
        new_metric_quantity: float,
    ) -> bool:
        plan = getattr(habit, "plan", None)
        if plan is None:
            return True
        if habit.habit_type == UnhealthyHabit.TYPE_FAST_FOOD:
            if not plan.weekly_limit:
                return True
            week_start = log_date - timedelta(days=log_date.weekday())
            current = sum(
                cls._metric_from_log(log)
                for log in habit.logs.filter(log_date__gte=week_start, log_date__lte=log_date)
            )
            return current + new_metric_quantity <= plan.weekly_limit
        if not plan.daily_limit:
            return True
        current = sum(cls._metric_from_log(log) for log in habit.logs.filter(log_date=log_date))
        return current + new_metric_quantity <= plan.daily_limit

    @classmethod
    def _is_within_limit_after_log_excluding(
        cls,
        *,
        habit: UnhealthyHabit,
        log_date: date,
        new_metric_quantity: float,
        exclude_log_id: int,
    ) -> bool:
        plan = getattr(habit, "plan", None)
        if plan is None:
            return True
        if habit.habit_type == UnhealthyHabit.TYPE_FAST_FOOD:
            if not plan.weekly_limit:
                return True
            week_start = log_date - timedelta(days=log_date.weekday())
            current = sum(
                cls._metric_from_log(log)
                for log in habit.logs.filter(log_date__gte=week_start, log_date__lte=log_date)
                .exclude(id=exclude_log_id)
            )
            return current + new_metric_quantity <= plan.weekly_limit
        if not plan.daily_limit:
            return True
        current = sum(
            cls._metric_from_log(log)
            for log in habit.logs.filter(log_date=log_date).exclude(id=exclude_log_id)
        )
        return current + new_metric_quantity <= plan.daily_limit

    @classmethod
    def _metric_from_log(cls, log: UnhealthyHabitLog) -> float:
        return cls._metric_quantity(
            habit_type=log.habit.habit_type,
            quantity=log.quantity,
            caffeine_mg=log.caffeine_mg,
        )

    @staticmethod
    def _metric_quantity(*, habit_type: str, quantity: float, caffeine_mg: float) -> float:
        if habit_type == UnhealthyHabit.TYPE_CAFFEINE:
            return caffeine_mg if caffeine_mg > 0 else quantity
        return quantity

    @classmethod
    def _sync_tracker_log(cls, *, log: UnhealthyHabitLog, payload: dict) -> None:
        if log.habit.habit_type not in {
            UnhealthyHabit.TYPE_CAFFEINE,
            UnhealthyHabit.TYPE_FAST_FOOD,
        }:
            return
        if log.source_type == UnhealthyHabitLog.SOURCE_TYPE_TRACKER_PROJECTION:
            return
        food = cls._resolve_or_create_food(log=log, payload=payload)
        if food is None:
            return
        source_ref = f"habit_log:{log.id}"
        meal_type = cls._projected_meal_type(log=log)
        existing_meal = MealLog.objects.filter(
            user=log.habit.user,
            source_type=MealLog.SOURCE_TYPE_HABIT_PROJECTION,
            source_ref=source_ref,
        ).first()
        meal_kwargs = {
            "user": log.habit.user,
            "food": food,
            "meal_type": meal_type,
            "quantity": payload.get("tracker_quantity") or 1,
            "unit": payload.get("tracker_unit") or "serving",
            "consumed_at": log.logged_at,
            "notes": f"Synced from unhealthy habit: {log.habit.get_habit_type_display()}",
            "source": MealLog.SOURCE_HABIT_SYNC,
            "sync_hydration": log.habit.habit_type == UnhealthyHabit.TYPE_CAFFEINE,
            "publish_event": True,
            "origin_domain": MealLog.ORIGIN_HABITS,
            "origin_record_id": str(log.id),
            "correlation_id": log.correlation_id or f"habit-log:{log.id}",
            "source_type": MealLog.SOURCE_TYPE_HABIT_PROJECTION,
            "source_ref": source_ref,
            "reward_owner_domain": "habits",
            "is_fast_food": log.habit.habit_type == UnhealthyHabit.TYPE_FAST_FOOD,
            "quality_tags": ["fast_food"] if log.habit.habit_type == UnhealthyHabit.TYPE_FAST_FOOD else [],
        }
        if existing_meal is None:
            meal = NutritionService.log_meal(**meal_kwargs)
        else:
            meal = NutritionService.update_meal_log(
                existing_meal,
                food=food,
                meal_type=meal_type,
                quantity=meal_kwargs["quantity"],
                unit=meal_kwargs["unit"],
                consumed_at=log.logged_at,
                notes=meal_kwargs["notes"],
                source=MealLog.SOURCE_HABIT_SYNC,
                sync_hydration=meal_kwargs["sync_hydration"],
                publish_event=True,
                origin_domain=MealLog.ORIGIN_HABITS,
                origin_record_id=str(log.id),
                correlation_id=meal_kwargs["correlation_id"],
                source_type=MealLog.SOURCE_TYPE_HABIT_PROJECTION,
                source_ref=source_ref,
                reward_owner_domain="habits",
                is_fast_food=meal_kwargs["is_fast_food"],
                quality_tags=meal_kwargs["quality_tags"],
            )
        log.linked_meal_log = meal
        if getattr(meal, "water_logs", None):
            linked_water = meal.water_logs.first()
            if linked_water is not None:
                log.linked_water_log = linked_water
                linked_water.source_type = WaterLog.SOURCE_TYPE_HABIT_PROJECTION
                linked_water.source_ref = source_ref
                linked_water.origin_domain = WaterLog.ORIGIN_HABITS
                linked_water.origin_record_id = str(log.id)
                linked_water.correlation_id = log.correlation_id or f"habit-log:{log.id}"
                linked_water.reward_owner_domain = "habits"
                linked_water.caffeine_mg = float(log.caffeine_mg or 0)
                linked_water.save(
                    update_fields=[
                        "source_type",
                        "source_ref",
                        "origin_domain",
                        "origin_record_id",
                        "correlation_id",
                        "reward_owner_domain",
                        "caffeine_mg",
                    ]
                )
        log.source = UnhealthyHabitLog.SOURCE_NUTRITION
        log.save(update_fields=["linked_meal_log", "linked_water_log", "source"])

    @staticmethod
    def _delete_tracker_projection_for_log(*, log: UnhealthyHabitLog) -> None:
        meal = log.linked_meal_log
        water = log.linked_water_log
        if meal is not None and meal.source_type == MealLog.SOURCE_TYPE_HABIT_PROJECTION:
            NutritionService.delete_meal_log(meal, publish_event=False)
            return
        if water is not None and water.source_type == WaterLog.SOURCE_TYPE_HABIT_PROJECTION:
            from core.services.hydration.water_service import WaterService

            WaterService.delete_water_log(water)

    @staticmethod
    def _projected_meal_type(*, log: UnhealthyHabitLog) -> str:
        value = str(log.meal_type or "").strip()
        allowed = {"breakfast", "lunch", "dinner", "snack", "drink", "unknown"}
        if value in allowed:
            return value
        if log.habit.habit_type == UnhealthyHabit.TYPE_CAFFEINE:
            return "drink"
        return "unknown"

    @classmethod
    def _resolve_or_create_food(cls, *, log: UnhealthyHabitLog, payload: dict):
        food_id = payload.get("food_id")
        if food_id:
            food = FoodItem.objects.filter(id=food_id).first()
            if food is None:
                raise ValidationError({"food_id": "Food item not found."})
            return food
        if not log.food_name and not log.calories_kcal and not log.caffeine_mg:
            return None

        name = log.food_name or cls.HABIT_LABELS.get(log.habit.habit_type, "Habit item")
        existing_items = FoodItem.objects.filter(
            created_by=log.habit.user,
            name__iexact=name,
            source=FoodItem.SOURCE_CUSTOM,
        )
        for existing in existing_items:
            facts = getattr(existing, "nutrition_facts", None)
            if facts is None:
                continue
            if (
                abs(float(facts.caffeine_mg or 0) - log.caffeine_mg) < 0.01
                and abs(float(facts.calories_kcal or 0) - log.calories_kcal) < 0.01
            ):
                return existing

        is_caffeine = log.habit.habit_type == UnhealthyHabit.TYPE_CAFFEINE
        return NutritionService.create_food_item(
            {
                "created_by": log.habit.user,
                "name": name,
                "item_type": FoodItem.TYPE_BEVERAGE if is_caffeine else FoodItem.TYPE_FOOD,
                "category": "Caffeine" if is_caffeine else "Fast food",
                "source": FoodItem.SOURCE_CUSTOM,
                "default_serving_size": 1,
                "default_serving_unit": "serving",
                "is_hydration_trackable": is_caffeine,
                "contains_caffeine": is_caffeine and log.caffeine_mg > 0,
                "nutrition_facts": {
                    "basis_type": NutritionFacts.BASIS_PER_SERVING,
                    "basis_value": 1,
                    "basis_amount": 1,
                    "basis_unit": "serving",
                    "serving_size": 1,
                    "serving_unit": "serving",
                    "calories_kcal": log.calories_kcal,
                    "caffeine_mg": log.caffeine_mg,
                    "water_g": 240 if is_caffeine else 0,
                },
                "serving_options": [
                    {
                        "name": "1 serving",
                        "amount": 1,
                        "unit": "serving",
                        "is_default": True,
                    }
                ],
            }
        )

    @classmethod
    def _award_points(cls, log: UnhealthyHabitLog) -> None:
        if (
            log.reward_owner_domain != "habits"
            or log.source_type == UnhealthyHabitLog.SOURCE_TYPE_TRACKER_PROJECTION
        ):
            return
        cls._apply_point_event(
            log=log,
            event_type=UnhealthyHabitPointEvent.EVENT_LOGGED,
            points=2,
            award=lambda: PointsService.award_unhealthy_habit_log(
                log.habit.user,
                source_id=log.id,
                event_date=log.log_date,
            ),
            per_log=True,
        )
        if log.is_within_limit:
            cls._apply_point_event(
                log=log,
                event_type=UnhealthyHabitPointEvent.EVENT_WITHIN_LIMIT,
                points=5,
                award=lambda: PointsService.award_unhealthy_habit_within_limit(
                    log.habit.user,
                    source_id=f"{log.habit_id}:within_limit",
                    event_date=log.log_date,
                ),
                per_log=False,
            )
        if log.healthy_replacement:
            cls._apply_point_event(
                log=log,
                event_type=UnhealthyHabitPointEvent.EVENT_HEALTHY_REPLACEMENT,
                points=5,
                award=lambda: PointsService.award_unhealthy_habit_replacement(
                    log.habit.user,
                    source_id=log.id,
                    event_date=log.log_date,
                ),
                per_log=True,
            )
        baseline = getattr(log.habit, "baseline", None)
        if baseline and baseline.initial_quantity:
            total_today = sum(
                cls._metric_from_log(item)
                for item in log.habit.logs.filter(log_date=log.log_date)
            )
            if total_today < baseline.initial_quantity:
                cls._apply_point_event(
                    log=log,
                    event_type=UnhealthyHabitPointEvent.EVENT_IMPROVEMENT,
                    points=5,
                    award=lambda: PointsService.award_unhealthy_habit_improvement(
                        log.habit.user,
                        source_id=f"{log.habit_id}:improvement",
                        event_date=log.log_date,
                    ),
                    per_log=False,
                )

    @staticmethod
    def _apply_point_event(*, log, event_type: str, points: int, award, per_log: bool) -> None:
        exists_query = {
            "habit": log.habit,
            "event_type": event_type,
            "event_date": log.log_date,
        }
        if per_log:
            exists_query["log"] = log
        if UnhealthyHabitPointEvent.objects.filter(**exists_query).exists():
            return
        UnhealthyHabitPointEvent.objects.create(
            habit=log.habit,
            log=log if per_log else None,
            event_type=event_type,
            event_date=log.log_date,
            points=points,
        )
        award()

    @staticmethod
    def _support_message(*, habit_type: str, is_over_limit: bool, has_logs: bool) -> str:
        if is_over_limit:
            return "This is a signal to adjust the plan, not a failure. Log the trigger and continue."
        if not has_logs:
            if habit_type == UnhealthyHabit.TYPE_FAST_FOOD:
                return "Plan one simple alternative before the usual fast-food time."
            if habit_type == UnhealthyHabit.TYPE_CAFFEINE:
                return "Track caffeine timing so sleep recommendations can stay accurate."
            return "Keep your reasons visible before the usual craving window."
        return "You logged it. The next useful step is noticing the trigger."

    @staticmethod
    def _default_reminder_message(habit_type: str) -> str:
        if habit_type == UnhealthyHabit.TYPE_CAFFEINE:
            return "Check your caffeine limit before another drink."
        if habit_type == UnhealthyHabit.TYPE_FAST_FOOD:
            return "Pause and choose the option that matches your plan."
        return "A craving is temporary. Try a short replacement action first."

    @staticmethod
    def _publish_changed(*, user, event_date: date, reference: str) -> None:
        from gamification.services.motivation_service import MotivationService

        MotivationService.refresh_daily(
            user=user,
            target_date=event_date,
        )
        HealthStateEventPublisher.publish_on_commit(
            user=user,
            trigger_type=HealthStateTriggers.UNHEALTHY_HABIT_CHANGED,
            payload={
                "trigger_reference": reference,
                "event_dates": [event_date],
            },
        )

    @staticmethod
    def _envelope(*, data: dict, request_id: str) -> dict:
        return {
            "data": data,
            "meta": {
                "is_stale": False,
                "computed_at": timezone.now().isoformat(),
                "snapshot_version": None,
                "request_id": request_id,
            },
        }
