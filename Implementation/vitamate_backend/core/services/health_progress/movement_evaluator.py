from __future__ import annotations

from datetime import date, timedelta
from typing import Any

from django.db.models import Sum
from django.utils import timezone

from core.models import ActivityLog, StepLog
from core.services.constraints import EffectiveConstraintReader


STATUS_NOT_STARTED = "not_started"
STATUS_IN_PROGRESS = "in_progress"
STATUS_COMPLETED = "completed"
STATUS_INSUFFICIENT_DATA = "insufficient_data"
STATUS_NOT_APPLICABLE = "not_applicable"


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(round(float(value)))
    except (TypeError, ValueError):
        return default


def _percent(current: float, target: float) -> int:
    if target <= 0:
        return 0
    return int(round(min(max(current / target, 0.0), 1.0) * 100))


class MovementEvaluator:
    """Backend-authored movement definition shared by health progress and read models."""

    SCORE_VERSION = "movement-v1"
    DEFAULT_STEP_WEIGHT = 0.4
    DEFAULT_EXERCISE_WEIGHT = 0.6

    @classmethod
    def evaluate(
        cls,
        *,
        user,
        target_date: date | None = None,
        steps_target_override: int | None = None,
        burn_target_override: int | None = None,
        exercise_target_minutes_override: int | None = None,
    ) -> dict:
        target_date = target_date or timezone.localdate()
        profile = getattr(user, "userprofile", None)
        profile_steps_target = _safe_int(getattr(profile, "daily_step_goal", 0), 6000)
        profile_burn_target = _safe_int(getattr(profile, "daily_burn_goal", 0), 300)
        effective_steps_target = EffectiveConstraintReader.get_effective_constraint(
            user=user,
            tracker_type="steps",
            constraint_key="steps_count",
            default_value=profile_steps_target,
            default_unit="steps",
            default_source="profile_fallback",
        )
        effective_burn_target = EffectiveConstraintReader.get_effective_constraint(
            user=user,
            tracker_type="activity",
            constraint_key="calories_burned",
            default_value=profile_burn_target,
            default_unit="kcal",
            default_source="profile_fallback",
        )
        steps_target = (
            _safe_int(steps_target_override)
            if steps_target_override is not None
            else _safe_int(effective_steps_target.value, profile_steps_target)
        )
        burn_target = (
            _safe_int(burn_target_override)
            if burn_target_override is not None
            else _safe_int(effective_burn_target.value, profile_burn_target)
        )
        weekly_hours = float(getattr(profile, "weekly_activity_goal_hours", 0) or 0)
        exercise_target = (
            _safe_int(exercise_target_minutes_override)
            if exercise_target_minutes_override is not None
            else max(int(round((weekly_hours * 60) / 7)), 20)
            if weekly_hours > 0
            else 0
        )

        step_log = StepLog.objects.filter(user=user, date=target_date).first()
        steps = _safe_int(getattr(step_log, "steps_count", 0))
        distance_km = float(getattr(step_log, "distance_km", 0) or 0)
        raw_step_calories = _safe_int(getattr(step_log, "calories_burned", 0))

        workout_logs = list(
            ActivityLog.objects.filter(user=user, date=target_date).select_related("exercise", "user")
        )
        workout_minutes = sum(_safe_int(log.duration_minutes) for log in workout_logs)
        workout_calories = sum(cls._activity_log_calories(log) for log in workout_logs)
        workout_count = len(workout_logs)

        step_calories = cls._non_workout_step_calories(
            raw_step_calories=raw_step_calories,
            workout_calories=workout_calories,
            workout_logs=workout_logs,
        )
        active_calories = step_calories + workout_calories

        steps_component = cls._component(
            key="steps",
            label="Steps",
            current=steps,
            target=steps_target,
            unit="steps",
            requirement="required" if steps_target > 0 else "not_applicable",
            weight=cls.DEFAULT_STEP_WEIGHT,
        )
        exercise_component = cls._component(
            key="exercise",
            label="Intentional exercise",
            current=workout_minutes,
            target=exercise_target,
            unit="min",
            requirement="required" if exercise_target > 0 else "not_applicable",
            weight=cls.DEFAULT_EXERCISE_WEIGHT,
        )
        components = {
            "steps": {
                **steps_component,
                "distance_km": round(distance_km, 3),
                "calories": step_calories,
                "raw_step_calories": raw_step_calories,
            },
            "exercise": {
                **exercise_component,
                "active_minutes": workout_minutes,
                "target_minutes": exercise_target,
                "calories": workout_calories,
                "workout_count": workout_count,
            },
        }

        applicable = [
            component
            for component in components.values()
            if component["requirement"] != "not_applicable"
        ]
        total_weight = sum(float(component["weight"]) for component in applicable)
        score = (
            int(round(sum(component["score"] * component["weight"] for component in applicable) / total_weight))
            if total_weight > 0
            else 0
        )
        required = [
            component
            for component in applicable
            if component["requirement"] == "required"
        ]
        is_complete = bool(required) and all(
            component["status"] == STATUS_COMPLETED for component in required
        )
        has_data = steps > 0 or workout_minutes > 0 or workout_calories > 0
        if not applicable:
            status = STATUS_NOT_APPLICABLE
            coverage = 100
            next_action = None
        elif is_complete:
            status = STATUS_COMPLETED
            coverage = 100
            next_action = None
        elif has_data:
            status = STATUS_IN_PROGRESS
            coverage = 100
            next_action = cls._next_action(components)
        else:
            status = STATUS_NOT_STARTED
            coverage = 0
            next_action = cls._next_action(components)

        return {
            "domain": "movement",
            "score_version": cls.SCORE_VERSION,
            "score": score,
            "status": status,
            "is_complete": is_complete,
            "coverage": coverage,
            "target_sources": {
                "steps": (
                    "explicit_override"
                    if steps_target_override is not None
                    else effective_steps_target.source_type
                ),
                "active_burn": (
                    "explicit_override"
                    if burn_target_override is not None
                    else effective_burn_target.source_type
                ),
            },
            "components": components,
            "next_action": next_action,
            "active_calories": {
                "value": active_calories,
                "target": burn_target,
                "percent": _percent(active_calories, burn_target),
                "remaining": max(burn_target - active_calories, 0),
                "breakdown": {
                    "steps": step_calories,
                    "workouts": workout_calories,
                },
                "dedupe_strategy": "conservative_workout_calorie_subtraction_v1",
            },
            "active_time": {
                "today_minutes": workout_minutes,
                "daily_target_minutes": exercise_target,
                "remaining_minutes": max(exercise_target - workout_minutes, 0),
                "percent": _percent(workout_minutes, exercise_target),
                "breakdown": {
                    "detected_active_walking": 0,
                    "recorded_workouts": workout_minutes,
                },
                "coverage_status": (
                    STATUS_INSUFFICIENT_DATA
                    if steps > 0 and workout_minutes == 0
                    else status
                ),
                "dedupe_strategy": "workout_intervals_only_until_step_intervals_available_v1",
            },
            "weekly_active_time": cls.weekly_active_time(user=user, target_date=target_date),
        }

    @classmethod
    def weekly_active_time(cls, *, user, target_date: date) -> dict:
        week_start = target_date - timedelta(days=target_date.weekday())
        week_end = week_start + timedelta(days=6)
        logs = ActivityLog.objects.filter(user=user, date__gte=week_start, date__lte=week_end)
        total_minutes = _safe_int(logs.aggregate(total=Sum("duration_minutes")).get("total"))
        active_days = logs.values("date").distinct().count()
        profile = getattr(user, "userprofile", None)
        weekly_target = int(round(float(getattr(profile, "weekly_activity_goal_hours", 0) or 0) * 60))
        return {
            "week_start": week_start.isoformat(),
            "week_end": week_end.isoformat(),
            "weekly_minutes": total_minutes,
            "weekly_target_minutes": weekly_target,
            "active_day_count": active_days,
            "percent": _percent(total_minutes, weekly_target),
        }

    @staticmethod
    def _activity_log_calories(log: ActivityLog) -> int:
        try:
            return _safe_int(log.calories_burned)
        except Exception:
            return 0

    @staticmethod
    def _non_workout_step_calories(*, raw_step_calories: int, workout_calories: int, workout_logs: list[ActivityLog]) -> int:
        if not workout_logs:
            return max(raw_step_calories, 0)
        # Until step intervals are available, keep the calories split conservative:
        # workouts own their recorded burn, and step calories are reduced so totals
        # never add the same walking/running energy twice.
        return max(raw_step_calories - max(workout_calories, 0), 0)

    @staticmethod
    def _component(*, key: str, label: str, current: int, target: int, unit: str, requirement: str, weight: float) -> dict:
        score = _percent(current, target)
        if requirement == "not_applicable":
            status = STATUS_NOT_APPLICABLE
        elif current <= 0:
            status = STATUS_NOT_STARTED
        elif score >= 100:
            status = STATUS_COMPLETED
        else:
            status = STATUS_IN_PROGRESS
        return {
            "key": key,
            "label": label,
            "current": current,
            "target": target,
            "unit": unit,
            "score": score,
            "progress_percent": score,
            "required": requirement == "required",
            "requirement": requirement,
            "status": status,
            "weight": weight,
        }

    @staticmethod
    def _next_action(components: dict[str, dict]) -> dict:
        steps = components["steps"]
        exercise = components["exercise"]
        if steps["requirement"] == "required" and steps["status"] != STATUS_COMPLETED:
            return {
                "title": "Add movement today",
                "subtitle": f"{max(steps['target'] - steps['current'], 0)} steps left for today's movement goal.",
                "route": "/activities/steps",
            }
        if exercise["requirement"] == "required" and exercise["status"] != STATUS_COMPLETED:
            return {
                "title": "Start a workout",
                "subtitle": f"{max(exercise['target'] - exercise['current'], 0)} active minutes left today.",
                "route": "/activities/workouts",
            }
        return {
            "title": "Keep movement going",
            "subtitle": "A short walk or workout keeps today's progress accurate.",
            "route": "/activities",
        }
