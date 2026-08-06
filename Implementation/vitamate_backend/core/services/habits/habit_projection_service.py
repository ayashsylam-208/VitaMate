from __future__ import annotations

from datetime import datetime, time, timedelta
from uuid import uuid4

from django.db import transaction
from django.utils import timezone

from core.models import MealLog, UnhealthyHabit, UnhealthyHabitLog, WaterLog
from core.services.habits.habit_evaluation_service import HabitEvaluationService
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers


class TrackerToHabitProjectionService:
    """Creates idempotent HabitLog projections from nutrition/hydration writes."""

    FAST_FOOD_MARKERS = {
        "fast food",
        "fast_food",
        "burger",
        "fries",
        "fried chicken",
        "pizza",
    }

    @classmethod
    @transaction.atomic
    def sync_from_meal(
        cls,
        *,
        meal_log: MealLog,
        clear_stale_projections: bool = True,
    ) -> dict | None:
        if cls._is_habit_origin_record(meal_log):
            return None
        if meal_log.origin_domain == MealLog.ORIGIN_HYDRATION:
            return None

        projections = []
        if cls._is_fast_food_meal(meal_log):
            projections.append(
                cls._upsert_projection_from_meal(
                    meal_log=meal_log,
                    habit_type=UnhealthyHabit.TYPE_FAST_FOOD,
                    quantity=1,
                    unit="meals",
                    caffeine_mg=0,
                    calories_kcal=float(meal_log.snapshot_calories_kcal or 0),
                    food_name=meal_log.food.name if meal_log.food_id else "",
                )
            )
        elif clear_stale_projections:
            cls.delete_for_meal(meal_log=meal_log, habit_type=UnhealthyHabit.TYPE_FAST_FOOD)

        caffeine_mg = float(meal_log.snapshot_caffeine_mg or 0)
        if caffeine_mg > 0 or getattr(meal_log.food, "contains_caffeine", False):
            projections.append(
                cls._upsert_projection_from_meal(
                    meal_log=meal_log,
                    habit_type=UnhealthyHabit.TYPE_CAFFEINE,
                    quantity=1,
                    unit="mg" if caffeine_mg > 0 else "servings",
                    caffeine_mg=caffeine_mg,
                    calories_kcal=float(meal_log.snapshot_calories_kcal or 0),
                    food_name=meal_log.food.name if meal_log.food_id else "",
                )
            )
        elif clear_stale_projections:
            cls.delete_for_meal(meal_log=meal_log, habit_type=UnhealthyHabit.TYPE_CAFFEINE)

        projections = [projection for projection in projections if projection is not None]
        if not projections:
            return None
        if len(projections) == 1:
            return projections[0]
        return {
            "status": "linked_multiple",
            "source_domain": "nutrition",
            "source_id": meal_log.id,
            "projections": projections,
        }

    @classmethod
    @transaction.atomic
    def sync_from_water(cls, *, water_log: WaterLog) -> dict | None:
        if cls._is_habit_origin_record(water_log):
            return None
        caffeine_mg = cls._caffeine_mg_for_water(water_log)
        contains_caffeine = bool(
            caffeine_mg > 0
            or getattr(water_log.drink_item, "contains_caffeine", False)
            or getattr(water_log.food_item, "contains_caffeine", False)
        )
        if not contains_caffeine:
            cls.delete_for_water(water_log=water_log, habit_type=UnhealthyHabit.TYPE_CAFFEINE)
            return None
        return cls._upsert_projection_from_water(
            water_log=water_log,
            habit_type=UnhealthyHabit.TYPE_CAFFEINE,
            quantity=1,
            unit="mg" if caffeine_mg > 0 else "servings",
            caffeine_mg=caffeine_mg,
            food_name=water_log.beverage_name or getattr(water_log.drink_item, "name", ""),
        )

    @classmethod
    @transaction.atomic
    def delete_for_meal(cls, *, meal_log: MealLog, habit_type: str | None = None) -> None:
        query = UnhealthyHabitLog.objects.filter(
            linked_meal_log=meal_log,
            source_type=UnhealthyHabitLog.SOURCE_TYPE_TRACKER_PROJECTION,
            origin_domain=UnhealthyHabitLog.ORIGIN_NUTRITION,
        )
        if habit_type:
            query = query.filter(habit__habit_type=habit_type)
        affected = {(row.habit.user_id, row.log_date) for row in query.select_related("habit")}
        query.delete()
        cls._publish_for_user_dates(user=meal_log.user, dates={date for _, date in affected}, source=f"meal:{meal_log.id}:projection-delete")

    @classmethod
    @transaction.atomic
    def delete_for_water(cls, *, water_log: WaterLog, habit_type: str | None = None) -> None:
        query = UnhealthyHabitLog.objects.filter(
            linked_water_log=water_log,
            source_type=UnhealthyHabitLog.SOURCE_TYPE_TRACKER_PROJECTION,
            origin_domain=UnhealthyHabitLog.ORIGIN_HYDRATION,
        )
        if habit_type:
            query = query.filter(habit__habit_type=habit_type)
        affected = {(row.habit.user_id, row.log_date) for row in query.select_related("habit")}
        query.delete()
        cls._publish_for_user_dates(user=water_log.user, dates={date for _, date in affected}, source=f"water:{water_log.id}:projection-delete")

    @classmethod
    def _upsert_projection_from_meal(
        cls,
        *,
        meal_log: MealLog,
        habit_type: str,
        quantity: float,
        unit: str,
        caffeine_mg: float,
        calories_kcal: float,
        food_name: str,
    ) -> dict | None:
        habit = cls._active_habit(user=meal_log.user, habit_type=habit_type)
        if habit is None:
            return {
                "status": "suggest_setup",
                "habit_type": habit_type,
                "source_domain": "nutrition",
                "source_id": meal_log.id,
            }
        logged_at = meal_log.consumed_at or timezone.now()
        log_date = timezone.localdate(logged_at)
        source_ref = f"meal_log:{meal_log.id}"
        correlation_id = meal_log.correlation_id or uuid4().hex
        is_within_limit = cls._is_within_limit(habit=habit, target_date=log_date, source_ref=source_ref, metric=cls._metric(habit_type, quantity, caffeine_mg))
        log, _ = UnhealthyHabitLog.objects.update_or_create(
            habit=habit,
            source_type=UnhealthyHabitLog.SOURCE_TYPE_TRACKER_PROJECTION,
            source_ref=source_ref,
            defaults={
                "logged_at": logged_at,
                "log_date": log_date,
                "quantity": quantity,
                "unit": unit,
                "trigger": "",
                "mood": "",
                "notes": "Linked from nutrition tracker.",
                "is_relapse": not is_within_limit,
                "is_within_limit": is_within_limit,
                "source": UnhealthyHabitLog.SOURCE_NUTRITION,
                "sync_to_tracker": False,
                "origin_domain": UnhealthyHabitLog.ORIGIN_NUTRITION,
                "origin_record_id": str(meal_log.id),
                "correlation_id": correlation_id,
                "reward_owner_domain": "nutrition",
                "meal_type": meal_log.meal_type or "unknown",
                "linked_meal_log": meal_log,
                "linked_water_log": meal_log.water_logs.first(),
                "caffeine_mg": caffeine_mg,
                "calories_kcal": calories_kcal,
                "food_name": food_name,
                "healthy_replacement": False,
            },
        )
        cls._publish_changed(user=meal_log.user, event_date=log_date, source=f"meal:{meal_log.id}:projection")
        return cls._projection_payload(log=log, source_domain="nutrition", source_id=meal_log.id)

    @classmethod
    def _upsert_projection_from_water(
        cls,
        *,
        water_log: WaterLog,
        habit_type: str,
        quantity: float,
        unit: str,
        caffeine_mg: float,
        food_name: str,
    ) -> dict | None:
        habit = cls._active_habit(user=water_log.user, habit_type=habit_type)
        if habit is None:
            return {
                "status": "suggest_setup",
                "habit_type": habit_type,
                "source_domain": "hydration",
                "source_id": water_log.id,
            }
        source_ref = f"water_log:{water_log.id}"
        correlation_id = water_log.correlation_id or uuid4().hex
        is_within_limit = cls._is_within_limit(habit=habit, target_date=water_log.date, source_ref=source_ref, metric=cls._metric(habit_type, quantity, caffeine_mg))
        log, _ = UnhealthyHabitLog.objects.update_or_create(
            habit=habit,
            source_type=UnhealthyHabitLog.SOURCE_TYPE_TRACKER_PROJECTION,
            source_ref=source_ref,
            defaults={
                "logged_at": timezone.make_aware(
                    datetime.combine(water_log.date, time.min),
                    timezone.get_current_timezone(),
                ),
                "log_date": water_log.date,
                "quantity": quantity,
                "unit": unit,
                "trigger": "",
                "mood": "",
                "notes": "Linked from hydration tracker.",
                "is_relapse": not is_within_limit,
                "is_within_limit": is_within_limit,
                "source": UnhealthyHabitLog.SOURCE_HYDRATION,
                "sync_to_tracker": False,
                "origin_domain": UnhealthyHabitLog.ORIGIN_HYDRATION,
                "origin_record_id": str(water_log.id),
                "correlation_id": correlation_id,
                "reward_owner_domain": "hydration",
                "meal_type": "drink",
                "linked_meal_log": water_log.linked_meal_log,
                "linked_water_log": water_log,
                "caffeine_mg": caffeine_mg,
                "calories_kcal": float(getattr(water_log.linked_meal_log, "snapshot_calories_kcal", 0) or 0),
                "food_name": food_name,
                "healthy_replacement": False,
            },
        )
        cls._publish_changed(user=water_log.user, event_date=water_log.date, source=f"water:{water_log.id}:projection")
        return cls._projection_payload(log=log, source_domain="hydration", source_id=water_log.id)

    @staticmethod
    def _is_habit_origin_record(record) -> bool:
        return (
            getattr(record, "origin_domain", "") == "habits"
            or getattr(record, "source_type", "") == "habit_projection"
        )

    @classmethod
    def _is_fast_food_meal(cls, meal_log: MealLog) -> bool:
        if meal_log.is_fast_food:
            return True
        tags = {str(item).strip().lower() for item in (meal_log.quality_tags or [])}
        if "fast_food" in tags or "fast food" in tags:
            return True
        text = " ".join(
            part
            for part in [
                getattr(meal_log.food, "name", ""),
                getattr(meal_log.food, "category", ""),
                getattr(getattr(meal_log.food, "primary_category", None), "code", ""),
                getattr(getattr(meal_log.food, "primary_category", None), "name", ""),
            ]
            if part
        ).lower()
        return any(marker in text for marker in cls.FAST_FOOD_MARKERS)

    @staticmethod
    def _caffeine_mg_for_water(water_log: WaterLog) -> float:
        if float(water_log.caffeine_mg or 0) > 0:
            return float(water_log.caffeine_mg or 0)
        meal = water_log.linked_meal_log
        if meal is not None and float(meal.snapshot_caffeine_mg or 0) > 0:
            return float(meal.snapshot_caffeine_mg or 0)
        return 0.0

    @staticmethod
    def _active_habit(*, user, habit_type: str) -> UnhealthyHabit | None:
        return (
            UnhealthyHabit.objects.filter(
                user=user,
                habit_type=habit_type,
                status=UnhealthyHabit.STATUS_ACTIVE,
            )
            .select_related("plan", "baseline")
            .order_by("-created_at", "-id")
            .first()
        )

    @staticmethod
    def _metric(habit_type: str, quantity: float, caffeine_mg: float) -> float:
        if habit_type == UnhealthyHabit.TYPE_CAFFEINE and caffeine_mg > 0:
            return caffeine_mg
        return quantity

    @staticmethod
    def _is_within_limit(*, habit: UnhealthyHabit, target_date, source_ref: str, metric: float) -> bool:
        plan = getattr(habit, "plan", None)
        if plan is None:
            return True
        if habit.habit_type == UnhealthyHabit.TYPE_FAST_FOOD and plan.weekly_limit is not None:
            week_start = target_date - timedelta(days=target_date.weekday())
            current = sum(
                float(log.quantity or 0)
                for log in habit.logs.filter(log_date__gte=week_start, log_date__lte=target_date)
                .exclude(source_ref=source_ref)
            )
            return current + metric <= float(plan.weekly_limit)
        target = plan.daily_limit if plan.daily_limit is not None else plan.target_quantity
        if target is None:
            return True
        current = sum(
            float(log.caffeine_mg or log.quantity or 0)
            for log in habit.logs.filter(log_date=target_date).exclude(source_ref=source_ref)
        )
        return current + metric <= float(target)

    @staticmethod
    def _projection_payload(*, log: UnhealthyHabitLog, source_domain: str, source_id: int) -> dict:
        return {
            "status": "linked",
            "source_domain": source_domain,
            "source_id": source_id,
            "habit_log_id": log.id,
            "habit_id": log.habit_id,
            "habit_type": log.habit.habit_type,
            "evaluation": HabitEvaluationService.evaluate_habit(habit=log.habit, target_date=log.log_date),
        }

    @staticmethod
    def _publish_changed(*, user, event_date, source: str) -> None:
        from gamification.services.motivation_service import MotivationService

        MotivationService.refresh_daily(user=user, target_date=event_date)
        HealthStateEventPublisher.publish_on_commit(
            user=user,
            trigger_type=HealthStateTriggers.UNHEALTHY_HABIT_CHANGED,
            payload={
                "trigger_reference": source,
                "event_dates": [event_date],
            },
        )

    @classmethod
    def _publish_for_user_dates(cls, *, user, dates: set, source: str) -> None:
        for event_date in dates:
            cls._publish_changed(user=user, event_date=event_date, source=source)
