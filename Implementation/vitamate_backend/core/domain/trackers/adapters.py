from __future__ import annotations

from dataclasses import dataclass

from core.domain.trackers.base import BaseTracker, TrackerGoal, TrackerSnapshot, TrackerStatus


def _constraint_metadata(constraints: tuple[dict, ...]) -> dict:
    if not constraints:
        return {}
    return {"active_constraints": list(constraints)}


@dataclass(slots=True)
class ActivityTrackerAdapter(BaseTracker):
    calories_burned: int
    burn_target: int
    exercise_minutes: int
    sessions_count: int
    constraints: tuple[dict, ...] = ()

    def snapshot(self) -> TrackerSnapshot:
        return TrackerSnapshot(
            tracker_id="activity",
            status=TrackerStatus.ACTIVE,
            current_value=float(self.calories_burned),
            goal=TrackerGoal("daily_burn_goal", float(self.burn_target), "kcal"),
            metadata={
                "exercise_minutes": self.exercise_minutes,
                "sessions_count": self.sessions_count,
                **_constraint_metadata(self.constraints),
            },
        )


@dataclass(slots=True)
class StepsTrackerAdapter(BaseTracker):
    steps: int
    steps_target: int
    distance_km: float
    calories_burned: int
    burn_rate_kcal_per_km: float
    constraints: tuple[dict, ...] = ()

    def snapshot(self) -> TrackerSnapshot:
        return TrackerSnapshot(
            tracker_id="steps",
            status=TrackerStatus.ACTIVE,
            current_value=float(self.steps),
            goal=TrackerGoal("daily_step_goal", float(self.steps_target), "steps"),
            metadata={
                "distance_km": self.distance_km,
                "calories_burned": self.calories_burned,
                "burn_rate_kcal_per_km": self.burn_rate_kcal_per_km,
                **_constraint_metadata(self.constraints),
            },
        )


@dataclass(slots=True)
class SleepTrackerAdapter(BaseTracker):
    logged_hours_today: float
    recommended_sleep_hours: float
    progress_percent: int
    constraints: tuple[dict, ...] = ()

    def snapshot(self) -> TrackerSnapshot:
        return TrackerSnapshot(
            tracker_id="sleep",
            status=TrackerStatus.ACTIVE,
            current_value=float(self.logged_hours_today),
            goal=TrackerGoal(
                "recommended_sleep_hours",
                float(self.recommended_sleep_hours),
                "hours",
            ),
            metadata={
                "progress_percent": self.progress_percent,
                **_constraint_metadata(self.constraints),
            },
        )


@dataclass(slots=True)
class HydrationTrackerAdapter(BaseTracker):
    water_current_liters: float
    water_target_liters: float
    adjusted_target_liters: float
    constraints: tuple[dict, ...] = ()

    def snapshot(self) -> TrackerSnapshot:
        return TrackerSnapshot(
            tracker_id="hydration",
            status=TrackerStatus.ACTIVE,
            current_value=float(self.water_current_liters),
            goal=TrackerGoal("daily_water_target", float(self.water_target_liters), "liters"),
            metadata={
                "adjusted_target_liters": self.adjusted_target_liters,
                **_constraint_metadata(self.constraints),
            },
        )


@dataclass(slots=True)
class NutritionTrackerAdapter(BaseTracker):
    calories_consumed: int
    calories_target: int
    calories_remaining: int
    protein_g: float = 0
    carbs_g: float = 0
    fat_g: float = 0
    sugars_g: float = 0
    fiber_g: float = 0
    caffeine_mg: float = 0
    constraints: tuple[dict, ...] = ()

    def snapshot(self) -> TrackerSnapshot:
        return TrackerSnapshot(
            tracker_id="nutrition",
            status=TrackerStatus.ACTIVE,
            current_value=float(self.calories_consumed),
            goal=TrackerGoal("daily_calorie_target", float(self.calories_target), "kcal"),
            metadata={
                "calories_remaining": self.calories_remaining,
                "protein_g": round(self.protein_g, 2),
                "carbs_g": round(self.carbs_g, 2),
                "fat_g": round(self.fat_g, 2),
                "sugars_g": round(self.sugars_g, 2),
                "fiber_g": round(self.fiber_g, 2),
                "caffeine_mg": round(self.caffeine_mg, 2),
                **_constraint_metadata(self.constraints),
            },
        )


@dataclass(slots=True)
class MedicationTrackerAdapter(BaseTracker):
    active_medications: int
    today_total_doses: int = 0
    taken_today: int = 0
    pending_today: int = 0
    missed_today: int = 0
    overdue_today: int = 0
    next_due: str | None = None
    adherence_7d: float = 0
    constraints: tuple[dict, ...] = ()

    def snapshot(self) -> TrackerSnapshot:
        return TrackerSnapshot(
            tracker_id="medication",
            status=TrackerStatus.ACTIVE,
            current_value=float(self.active_medications),
            goal=None,
            metadata={
                "today_total_doses": self.today_total_doses,
                "taken_today": self.taken_today,
                "pending_today": self.pending_today,
                "missed_today": self.missed_today,
                "overdue_today": self.overdue_today,
                "next_due": self.next_due,
                "adherence_7d": self.adherence_7d,
                **_constraint_metadata(self.constraints),
            },
        )


@dataclass(slots=True)
class HabitTrackerAdapter(BaseTracker):
    total_habits: int
    completed_today: int
    constraints: tuple[dict, ...] = ()

    def snapshot(self) -> TrackerSnapshot:
        status = TrackerStatus.ACTIVE if self.total_habits > 0 else TrackerStatus.INACTIVE
        return TrackerSnapshot(
            tracker_id="habit",
            status=status,
            current_value=float(self.completed_today),
            goal=TrackerGoal("daily_habit_completions", float(self.total_habits), "count"),
            metadata={
                "total_habits": self.total_habits,
                **_constraint_metadata(self.constraints),
            },
        )


@dataclass(slots=True)
class ChronicConditionTrackerAdapter(BaseTracker):
    active_conditions: int
    adherence_percent: float
    open_alerts: int
    constraints: tuple[dict, ...] = ()

    def snapshot(self) -> TrackerSnapshot:
        status = TrackerStatus.ACTIVE if self.active_conditions > 0 else TrackerStatus.INACTIVE
        return TrackerSnapshot(
            tracker_id="chronic_conditions",
            status=status,
            current_value=float(self.adherence_percent),
            goal=TrackerGoal("daily_condition_adherence", 100.0, "percent"),
            metadata={
                "active_conditions": self.active_conditions,
                "open_alerts": self.open_alerts,
                **_constraint_metadata(self.constraints),
            },
        )
