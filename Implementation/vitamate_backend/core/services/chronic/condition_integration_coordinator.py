from __future__ import annotations

from datetime import date

from django.utils import timezone

from core.models import UserCondition
from core.services.chronic.condition_constraint_engine import EffectiveConditionConstraints
from core.services.chronic.condition_runtime_summary_service import (
    ConditionRuntimeSummaryService,
)
from core.services.constraints import EffectiveConstraintReader


class ConditionIntegrationCoordinator:
    """Coordinates chronic-condition side effects across trackers and summaries."""

    def __init__(self, *, constraint_engine=None):
        # Kept only for constructor compatibility during the legacy-engine
        # deprecation window. Runtime target reads are materialized below.
        del constraint_engine

    @staticmethod
    def _chronic_service():
        from core.services.chronic_condition_service import ChronicConditionService

        return ChronicConditionService

    def sync_after_condition_change(
        self,
        *,
        user_condition: UserCondition,
        trigger_type: str | None = None,
        trigger_reference: str | None = None,
    ) -> None:
        del trigger_type, trigger_reference
        chronic_service = self._chronic_service()
        chronic_service.rebuild_targets_for_condition(user_condition)
        chronic_service.evaluate_condition(user_condition=user_condition)

    def sync_all_for_user(self, *, user, on_date: date | None = None) -> None:
        chronic_service = self._chronic_service()
        for condition in UserCondition.objects.filter(user=user, is_active=True).select_related("condition_type"):
            if not condition.targets.exists():
                chronic_service.rebuild_targets_for_condition(condition)
            chronic_service.evaluate_condition(user_condition=condition, on_date=on_date)

    def effective_constraints(self, *, user, profile, on_date: date | None = None):
        on_date = on_date or timezone.localdate()
        targets = EffectiveConstraintReader.get_effective_constraints(
            user=user,
            requests=[
                {
                    "tracker_type": "nutrition",
                    "constraint_key": "calories_kcal",
                    "default_value": profile.daily_calorie_target,
                    "default_unit": "kcal",
                },
                {
                    "tracker_type": "hydration",
                    "constraint_key": "daily_water_liters",
                    "default_value": profile.daily_water_target,
                    "default_unit": "liters",
                },
                {
                    "tracker_type": "steps",
                    "constraint_key": "steps_count",
                    "default_value": profile.daily_step_goal,
                    "default_unit": "steps",
                },
                {
                    "tracker_type": "activity",
                    "constraint_key": "calories_burned",
                    "default_value": profile.daily_burn_goal,
                    "default_unit": "kcal",
                },
            ],
        )
        runtime = ConditionRuntimeSummaryService.build(user=user, on_date=on_date)
        rows = {
            tracker: EffectiveConstraintReader.get_effective_tracker_constraints(
                user=user,
                tracker_type=tracker,
            )
            for tracker in ("nutrition", "monitoring")
        }

        def boundary(tracker, metric_key, field, reducer):
            values = [
                float(row[field])
                for row in rows[tracker]
                if row.get("metric_key") == metric_key and row.get(field) is not None
            ]
            return reducer(values) if values else None

        return EffectiveConditionConstraints(
            calories_target=int(targets[("nutrition", "calories_kcal")].value or 0),
            water_target_liters=float(
                targets[("hydration", "daily_water_liters")].value or 0
            ),
            step_target=int(targets[("steps", "steps_count")].value or 0),
            burn_target=int(targets[("activity", "calories_burned")].value or 0),
            exercise_intensity_mode=runtime.exercise_intensity_mode,
            applied_summaries=runtime.applied_summaries,
            active_condition_labels=runtime.active_condition_labels,
            medication_count_today=runtime.medication_count_today,
            pending_doses_today=runtime.pending_doses_today,
            adherence_percent=runtime.adherence_percent,
            sodium_limit_mg=boundary("nutrition", "sodium_mg", "max_value", min),
            fasting_glucose_min=boundary(
                "monitoring", "fasting_glucose", "min_value", max
            ),
            fasting_glucose_max=boundary(
                "monitoring", "fasting_glucose", "max_value", min
            ),
            systolic_target=boundary(
                "monitoring", "systolic_bp", "max_value", min
            ),
            diastolic_target=boundary(
                "monitoring", "diastolic_bp", "max_value", min
            ),
            ldl_target=boundary("monitoring", "ldl", "max_value", min),
        )
