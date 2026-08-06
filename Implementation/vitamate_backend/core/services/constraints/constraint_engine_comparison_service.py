from __future__ import annotations

from django.db import models
from django.utils import timezone

from core.models import ResolvedTrackerConstraint, UnifiedHealthState
from core.services.chronic.condition_constraint_engine import ConditionConstraintEngine
from core.services.constraints.effective_constraint_reader import EffectiveConstraintReader


class ConstraintEngineComparisonService:
    METRICS = (
        ("nutrition", "calories_kcal", "calories_target", "kcal"),
        ("nutrition", "protein_g", None, "g"),
        ("nutrition", "carbohydrates_g", None, "g"),
        ("nutrition", "fat_g", None, "g"),
        ("nutrition", "fiber_g", None, "g"),
        ("nutrition", "sugars_g", None, "g"),
        ("hydration", "daily_water_liters", "water_target_liters", "liters"),
        ("steps", "steps_count", "step_target", "steps"),
        ("activity", "activity_minutes", None, "minutes"),
        ("activity", "calories_burned", "burn_target", "kcal"),
        ("nutrition", "sodium_mg", "sodium_limit_mg", "mg"),
        ("nutrition", "saturated_fat_pct_kcal", None, "% kcal"),
        ("sleep", "sleep_hours", None, "hours"),
        ("medication", "adherence_percent", None, "percent"),
        ("monitoring", "fasting_glucose", "fasting_glucose_max", "mg/dL"),
        ("monitoring", "systolic_bp", "systolic_target", "mmHg"),
        ("monitoring", "diastolic_bp", "diastolic_target", "mmHg"),
        ("monitoring", "ldl", "ldl_target", "mg/dL"),
    )

    @classmethod
    def compare_user(cls, *, user, at_time=None) -> list[dict]:
        profile = getattr(user, "userprofile", None)
        if profile is None:
            return []
        at_time = at_time or timezone.now()
        legacy = ConditionConstraintEngine.build_effective_constraints(
            user=user,
            profile=profile,
            on_date=timezone.localdate(at_time),
        )
        state = UnifiedHealthState.objects.filter(
            user=user,
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
        ).order_by("-state_date", "-last_computed_at").first()
        rows = []
        for tracker_type, metric_key, legacy_attr, unit in cls.METRICS:
            legacy_value = getattr(legacy, legacy_attr, None) if legacy_attr else None
            materialized = EffectiveConstraintReader.get_effective_constraint(
                user=user,
                tracker_type=tracker_type,
                constraint_key=metric_key,
                at_time=at_time,
                default_value=None,
                default_unit=unit,
            )
            materialized_value = None if materialized.defaulted else materialized.value
            state_value = cls._state_value(
                state=state,
                tracker_type=tracker_type,
                metric_key=metric_key,
            )
            if legacy_value is None and materialized_value is None:
                status = "both_missing"
            elif legacy_value is None:
                status = "materialized_only"
            elif materialized_value is None:
                status = "legacy_only"
            elif abs(float(legacy_value) - float(materialized_value)) <= 0.001:
                status = "exact_match"
            elif materialized.source_type in {
                ResolvedTrackerConstraint.SOURCE_PHYSICIAN_OVERRIDE,
                ResolvedTrackerConstraint.SOURCE_SAFETY_CRITICAL_CONDITION_RULE,
                ResolvedTrackerConstraint.SOURCE_DYNAMIC_CONDITION_STATE,
                ResolvedTrackerConstraint.SOURCE_CONDITION_NUTRIENT_RULE,
                ResolvedTrackerConstraint.SOURCE_USER_CUSTOM_TARGET,
            }:
                status = "explainable_difference"
            else:
                status = "unexplained_difference"
            rows.append(
                {
                    "user_id": user.id,
                    "tracker_type": tracker_type,
                    "constraint_key": metric_key,
                    "legacy_value": legacy_value,
                    "materialized_value": materialized_value,
                    "unified_state_value": state_value,
                    "state_version": state.version if state else None,
                    "unit": materialized.unit or unit,
                    "source_type": materialized.source_type if not materialized.defaulted else "",
                    "priority": materialized.priority,
                    "effective_from": materialized.effective_from,
                    "effective_to": materialized.effective_to,
                    "status": status,
                }
            )
        fixed_keys = {(tracker, key) for tracker, key, _legacy, _unit in cls.METRICS}
        for constraint in ResolvedTrackerConstraint.objects.filter(
            user=user,
            tracker_type=ResolvedTrackerConstraint.TRACKER_MICRONUTRIENT,
            status=ResolvedTrackerConstraint.STATUS_ACTIVE,
            effective_from__lte=at_time,
        ).filter(
            models.Q(effective_to__isnull=True) | models.Q(effective_to__gt=at_time)
        ).order_by("metric_key", "-priority"):
            key = (constraint.tracker_type, constraint.metric_key)
            if key in fixed_keys:
                continue
            rows.append(
                {
                    "user_id": user.id,
                    "tracker_type": constraint.tracker_type,
                    "constraint_key": constraint.metric_key,
                    "legacy_value": None,
                    "materialized_value": (
                        constraint.target_value
                        if constraint.target_value is not None
                        else constraint.max_value
                        if constraint.max_value is not None
                        else constraint.min_value
                    ),
                    "unified_state_value": None,
                    "state_version": state.version if state else None,
                    "unit": constraint.unit,
                    "source_type": constraint.source_type,
                    "priority": constraint.priority,
                    "effective_from": constraint.effective_from,
                    "effective_to": constraint.effective_to,
                    "status": "materialized_only",
                }
            )
        return rows

    @staticmethod
    def _state_value(*, state, tracker_type: str, metric_key: str):
        if state is None:
            return None
        summary = dict(state.progress_summary or {})
        main = dict(summary.get("summary") or {})
        hydration = dict(summary.get("hydration") or {})
        activity = dict(summary.get("activity") or {})
        sleep = dict(summary.get("sleep") or {})
        state_paths = {
            ("nutrition", "calories_kcal"): main.get("calories_target"),
            ("hydration", "daily_water_liters"): hydration.get("target"),
            ("steps", "steps_count"): activity.get("steps_target"),
            ("activity", "calories_burned"): main.get("burn_target"),
            ("sleep", "sleep_hours"): sleep.get("recommended_sleep_hours"),
            ("medication", "adherence_percent"): dict(summary.get("medications") or {}).get(
                "adherence_7d"
            ),
        }
        return state_paths.get((tracker_type, metric_key))
