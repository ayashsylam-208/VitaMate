from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from core.models import ConstraintResolutionRun


class HealthStateTriggers:
    READ_MODEL_REFRESH_REQUESTED = "read_model_refresh_requested"
    MEAL_LOGGED = "meal_logged"
    MEAL_UPDATED = "meal_updated"
    MEAL_DELETED = "meal_deleted"
    WATER_LOGGED = "water_logged"
    WATER_UPDATED = "water_updated"
    WATER_DELETED = "water_deleted"
    STEPS_LOGGED = "steps_logged"
    STEPS_UPDATED = "steps_updated"
    STEPS_DELETED = "steps_deleted"
    ACTIVITY_LOGGED = "activity_logged"
    ACTIVITY_UPDATED = "activity_updated"
    ACTIVITY_DELETED = "activity_deleted"
    SLEEP_LOGGED = "sleep_logged"
    SLEEP_UPDATED = "sleep_updated"
    SLEEP_DELETED = "sleep_deleted"
    CONDITION_READING_LOGGED = "condition_reading_logged"
    USER_CONDITION_UPDATED = "user_condition_updated"
    USER_PROFILE_UPDATED = "user_profile_updated"
    MEDICATION_PLAN_CHANGED = "medication_plan_changed"
    MEDICATION_ADHERENCE_CHANGED = "medication_adherence_changed"
    USER_NUTRIENT_TARGET_CHANGED = "user_nutrient_target_changed"
    UNHEALTHY_HABIT_CHANGED = "unhealthy_habit_changed"


@dataclass(frozen=True)
class HealthStateImpactPlan:
    trigger_type: str
    reason: str
    affected_trackers: tuple[str, ...]
    event_dates: tuple[date, ...]
    recompute_current: bool
    recompute_daily: bool
    sync_active_conditions: bool = False
    recompute_constraints: bool = False
    constraint_trigger_type: str | None = None
    constraint_tracker_type: str | None = None


class TrackerDependencyMap:
    ALWAYS_CURRENT_TRIGGERS = {
        HealthStateTriggers.USER_CONDITION_UPDATED,
        HealthStateTriggers.USER_PROFILE_UPDATED,
        HealthStateTriggers.MEDICATION_PLAN_CHANGED,
        HealthStateTriggers.MEDICATION_ADHERENCE_CHANGED,
        HealthStateTriggers.USER_NUTRIENT_TARGET_CHANGED,
        HealthStateTriggers.UNHEALTHY_HABIT_CHANGED,
        HealthStateTriggers.READ_MODEL_REFRESH_REQUESTED,
    }

    TRIGGER_RULES = {
        HealthStateTriggers.MEAL_LOGGED: {
            "trackers": ("nutrition", "hydration", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Meal log changed nutrition totals.",
        },
        HealthStateTriggers.MEAL_UPDATED: {
            "trackers": ("nutrition", "hydration", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Meal log was updated.",
        },
        HealthStateTriggers.MEAL_DELETED: {
            "trackers": ("nutrition", "hydration", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Meal log was deleted.",
        },
        HealthStateTriggers.WATER_LOGGED: {
            "trackers": ("hydration", "nutrition", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Hydration log changed hydration totals.",
        },
        HealthStateTriggers.WATER_UPDATED: {
            "trackers": ("hydration", "nutrition", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Hydration log was updated.",
        },
        HealthStateTriggers.WATER_DELETED: {
            "trackers": ("hydration", "nutrition", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Hydration log was deleted.",
        },
        HealthStateTriggers.STEPS_LOGGED: {
            "trackers": ("steps", "activity", "hydration", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Steps totals changed.",
        },
        HealthStateTriggers.STEPS_UPDATED: {
            "trackers": ("steps", "activity", "hydration", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Steps totals were updated.",
        },
        HealthStateTriggers.STEPS_DELETED: {
            "trackers": ("steps", "activity", "hydration", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Steps totals were deleted.",
        },
        HealthStateTriggers.ACTIVITY_LOGGED: {
            "trackers": ("activity", "hydration", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Activity log changed burn and hydration targets.",
        },
        HealthStateTriggers.ACTIVITY_UPDATED: {
            "trackers": ("activity", "hydration", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Activity log was updated.",
        },
        HealthStateTriggers.ACTIVITY_DELETED: {
            "trackers": ("activity", "hydration", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Activity log was deleted.",
        },
        HealthStateTriggers.SLEEP_LOGGED: {
            "trackers": ("sleep", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Sleep log changed sleep progress.",
        },
        HealthStateTriggers.SLEEP_UPDATED: {
            "trackers": ("sleep", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Sleep log was updated.",
        },
        HealthStateTriggers.SLEEP_DELETED: {
            "trackers": ("sleep", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Sleep log was deleted.",
        },
        HealthStateTriggers.CONDITION_READING_LOGGED: {
            "trackers": ("monitoring", "nutrition", "hydration", "activity"),
            "sync_active_conditions": True,
            "recompute_constraints": True,
            "constraint_trigger_type": ConstraintResolutionRun.TRIGGER_HEALTH_INDICATOR_RECORD,
            "constraint_tracker_type": "monitoring",
            "reason": "Condition reading changed chronic state and safety bands.",
        },
        HealthStateTriggers.USER_CONDITION_UPDATED: {
            "trackers": ("monitoring", "nutrition", "hydration", "activity", "medication"),
            "sync_active_conditions": True,
            "recompute_constraints": True,
            "constraint_trigger_type": ConstraintResolutionRun.TRIGGER_USER_CONDITION,
            "reason": "Condition setup changed active targets and constraints.",
        },
        HealthStateTriggers.USER_PROFILE_UPDATED: {
            "trackers": ("nutrition", "hydration", "activity", "steps", "sleep"),
            "sync_active_conditions": False,
            "recompute_constraints": True,
            "constraint_trigger_type": ConstraintResolutionRun.TRIGGER_USER_PROFILE,
            "reason": "User profile changed derived goals.",
        },
        HealthStateTriggers.MEDICATION_PLAN_CHANGED: {
            "trackers": ("medication", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": True,
            "constraint_trigger_type": ConstraintResolutionRun.TRIGGER_MEDICATION_PLAN,
            "constraint_tracker_type": "medication",
            "reason": "Medication plan changed adherence and reminders.",
        },
        HealthStateTriggers.MEDICATION_ADHERENCE_CHANGED: {
            "trackers": ("medication", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": True,
            "constraint_trigger_type": ConstraintResolutionRun.TRIGGER_MEDICATION_PLAN,
            "constraint_tracker_type": "medication",
            "reason": "Medication adherence changed.",
        },
        HealthStateTriggers.USER_NUTRIENT_TARGET_CHANGED: {
            "trackers": ("nutrition",),
            "sync_active_conditions": False,
            "recompute_constraints": True,
            "constraint_trigger_type": ConstraintResolutionRun.TRIGGER_USER_NUTRIENT_TARGET,
            "constraint_tracker_type": "nutrition",
            "reason": "User nutrient targets changed nutrition constraints.",
        },
        HealthStateTriggers.UNHEALTHY_HABIT_CHANGED: {
            "trackers": ("habit", "nutrition", "hydration", "sleep", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Unhealthy habit plan or log changed.",
        },
        HealthStateTriggers.READ_MODEL_REFRESH_REQUESTED: {
            "trackers": ("nutrition", "hydration", "activity", "steps", "sleep", "medication", "habit", "monitoring"),
            "sync_active_conditions": True,
            "recompute_constraints": False,
            "reason": "Read model refresh requested.",
        },
    }

    @classmethod
    def build_plan(
        cls,
        *,
        trigger_type: str,
        payload: dict | None,
        today: date,
    ) -> HealthStateImpactPlan:
        payload = dict(payload or {})
        config = cls.TRIGGER_RULES.get(trigger_type, {})
        event_dates = cls._event_dates(payload=payload, today=today)
        recompute_current = today in event_dates or trigger_type in cls.ALWAYS_CURRENT_TRIGGERS
        return HealthStateImpactPlan(
            trigger_type=trigger_type,
            reason=str(config.get("reason") or trigger_type.replace("_", " ").title()),
            affected_trackers=tuple(config.get("trackers") or ()),
            event_dates=event_dates,
            recompute_current=recompute_current,
            recompute_daily=bool(event_dates),
            sync_active_conditions=bool(config.get("sync_active_conditions")),
            recompute_constraints=bool(config.get("recompute_constraints")),
            constraint_trigger_type=config.get("constraint_trigger_type"),
            constraint_tracker_type=config.get("constraint_tracker_type"),
        )

    @staticmethod
    def _event_dates(*, payload: dict, today: date) -> tuple[date, ...]:
        raw_dates = payload.get("event_dates")
        values = []
        if isinstance(raw_dates, (list, tuple)):
            values.extend(raw_dates)
        elif raw_dates:
            values.append(raw_dates)

        normalized = []
        for value in values:
            if isinstance(value, date):
                normalized.append(value)
                continue
            text = str(value or "").strip()
            if not text:
                continue
            try:
                normalized.append(date.fromisoformat(text))
            except ValueError:
                continue

        if not normalized:
            return (today,)
        return tuple(sorted(set(normalized)))
