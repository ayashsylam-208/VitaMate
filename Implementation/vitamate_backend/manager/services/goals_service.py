from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta

from django.db.models import Sum
from django.utils import timezone

from core.models import (
    ActivityLog,
    ConditionMedication,
    Habit,
    MealLog,
    SleepLog,
    StepLog,
    WaterLog,
)
from manager.models import HealthGoalOverride
from users.services.profile_metrics_calculator import ProfileMetricsCalculator
from users.services.user_profile_service import UserProfileService


def _percent(current: float, target: float) -> int:
    if target <= 0:
        return 0
    return round(max(0, min(current / target, 1.0)) * 100)


def _float(value) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


@dataclass(frozen=True)
class GoalSpec:
    key: str
    label: str
    unit: str
    icon: str
    category: str
    route: str
    min_value: float
    max_value: float


class ManagerGoalsService:
    SOURCE_RECOMMENDED = "calculated_default"
    SOURCE_CUSTOM = "user_override"

    SPECS = [
        GoalSpec("nutrition", "Nutrition", "kcal", "restaurant", "routine", "/meals", 800, 6000),
        GoalSpec("hydration", "Hydration", "ml", "water_drop", "routine", "/water", 500, 6000),
        GoalSpec("steps", "Steps", "steps", "directions_walk", "activity", "/activities", 1000, 40000),
        GoalSpec("active_time", "Active time", "min", "timer", "activity", "/activities", 5, 300),
        GoalSpec("sleep", "Sleep", "h", "bedtime", "recovery", "/sleep", 3, 14),
        GoalSpec("weight", "Weight", "kg", "monitor_weight", "body", "/my-vitamate/health-profile", 30, 250),
        GoalSpec("habits", "Habits", "tasks", "check_circle", "habits", "/habits", 1, 12),
    ]

    @classmethod
    def list_goals(cls, *, user) -> list[dict]:
        profile = UserProfileService.ensure_profile(user)
        overrides = {
            row.key: row
            for row in HealthGoalOverride.objects.filter(user=user)
        }
        today = timezone.localdate()
        recommendations = cls._recommended_values(profile=profile)
        current_values = cls._current_values(user=user, target_date=today)

        return [
            cls._goal_payload(
                spec=spec,
                recommended_value=recommendations[spec.key],
                current_value=current_values[spec.key],
                override=overrides.get(spec.key),
            )
            for spec in cls.SPECS
        ]

    @classmethod
    def upsert_custom_goal(cls, *, user, key: str, custom_value) -> dict:
        spec = cls._spec_for_key(key)
        if custom_value is None:
            HealthGoalOverride.objects.filter(user=user, key=key).delete()
            return cls._single_goal(user=user, key=key)

        value = _float(custom_value)
        if value < spec.min_value or value > spec.max_value:
            raise ValueError(
                f"{spec.label} must be between {spec.min_value:g} and {spec.max_value:g} {spec.unit}."
            )
        HealthGoalOverride.objects.update_or_create(
            user=user,
            key=key,
            defaults={"custom_value": value, "unit": spec.unit},
        )
        return cls._single_goal(user=user, key=key)

    @classmethod
    def reset_goals(cls, *, user) -> list[dict]:
        HealthGoalOverride.objects.filter(user=user).delete()
        return cls.list_goals(user=user)

    @classmethod
    def _single_goal(cls, *, user, key: str) -> dict:
        for goal in cls.list_goals(user=user):
            if goal["key"] == key:
                return goal
        raise ValueError("Unknown goal.")

    @classmethod
    def _spec_for_key(cls, key: str) -> GoalSpec:
        for spec in cls.SPECS:
            if spec.key == key:
                return spec
        raise ValueError("Unknown goal.")

    @classmethod
    def _goal_payload(
        cls,
        *,
        spec: GoalSpec,
        recommended_value: float,
        current_value: float,
        override: HealthGoalOverride | None,
    ) -> dict:
        custom_value = override.custom_value if override else None
        effective_value = custom_value if custom_value is not None else recommended_value
        source = cls.SOURCE_CUSTOM if override else cls.SOURCE_RECOMMENDED
        progress = _percent(current=current_value, target=effective_value)
        return {
            "key": spec.key,
            "label": spec.label,
            "icon": spec.icon,
            "category": spec.category,
            "route": spec.route,
            "unit": spec.unit,
            "current_value": round(current_value, 2),
            "recommended_value": round(recommended_value, 2),
            "custom_value": None if custom_value is None else round(float(custom_value), 2),
            "effective_value": round(float(effective_value or 0), 2),
            "source": source,
            "source_label": "Custom" if override else "Recommended by VitaMate",
            "progress_percent": progress,
            "is_complete": progress >= 100,
            "updated_at": override.updated_at.isoformat() if override else None,
        }

    @classmethod
    def _recommended_values(cls, *, profile) -> dict:
        metrics = ProfileMetricsCalculator.calculate(profile)
        target_weight = cls._recommended_target_weight(profile=profile)
        active_minutes = round(float(profile.weekly_activity_goal_hours or 2.5) * 60 / 7)
        return {
            "nutrition": float(metrics.daily_calorie_target),
            "hydration": round(float(metrics.daily_water_target) * 1000),
            "steps": float(metrics.daily_step_goal),
            "active_time": float(max(active_minutes, 20)),
            "sleep": float(profile.recommended_sleep_hours or 8),
            "weight": target_weight,
            "habits": float(max(Habit.objects.filter(user=profile.user).count(), 1)),
        }

    @staticmethod
    def _recommended_target_weight(*, profile) -> float:
        current = float(profile.weight or 0)
        if profile.goal == "lose":
            return max(current - 5, 30)
        if profile.goal in {"gain", "muscle"}:
            return min(current + 5, 250)
        return current

    @classmethod
    def _current_values(cls, *, user, target_date) -> dict:
        meals = MealLog.objects.filter(user=user, date=target_date)
        calories = sum(int(meal.total_calories or 0) for meal in meals)
        water_l = (
            WaterLog.objects.filter(user=user, date=target_date)
            .aggregate(total=Sum("amount_liter"))
            .get("total")
            or 0
        )
        step_log = StepLog.objects.filter(user=user, date=target_date).first()
        steps = float(getattr(step_log, "steps_count", 0) or 0)
        active_minutes = (
            ActivityLog.objects.filter(user=user, date=target_date)
            .aggregate(total=Sum("duration_minutes"))
            .get("total")
            or 0
        )
        sleep_hours = 0.0
        for log in SleepLog.objects.filter(user=user, date=target_date):
            sleep_hours += float(getattr(log, "duration_hours", 0) or 0)
        habits_target = max(Habit.objects.filter(user=user).count(), 1)
        completed_habits = Habit.objects.filter(user=user, habitlog__date=target_date).distinct().count()
        profile = UserProfileService.ensure_profile(user)
        return {
            "nutrition": float(calories),
            "hydration": float(water_l or 0) * 1000,
            "steps": steps,
            "active_time": float(active_minutes or 0),
            "sleep": sleep_hours,
            "weight": float(profile.weight or 0),
            "habits": float(min(completed_habits, habits_target)),
        }


def active_medication_count(*, user) -> int:
    return ConditionMedication.objects.filter(user=user, is_active=True).count()
