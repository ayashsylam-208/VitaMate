from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from core.models import ConditionDailyEvaluation, UserCondition
from core.services.condition_catalog_service import ConditionCatalogService
from core.services.condition_medication_service import ConditionMedicationService
from core.services.constraints import ConstraintReadService


@dataclass(frozen=True, slots=True)
class ConditionRuntimeSummary:
    active_condition_labels: tuple[str, ...]
    medication_count_today: int
    pending_doses_today: int
    adherence_percent: float
    applied_summaries: tuple[str, ...]
    exercise_intensity_mode: str
    disclaimer: str = (
        "Chronic-condition guidance in VitaMate supports self-management and "
        "does not replace your clinician."
    )


class ConditionRuntimeSummaryService:
    """Builds non-target chronic metadata without invoking the legacy engine."""

    @classmethod
    def build(cls, *, user, on_date: date) -> ConditionRuntimeSummary:
        conditions = list(
            UserCondition.objects.filter(
                user=user,
                is_active=True,
                status__in=(
                    UserCondition.STATUS_ACTIVE,
                    UserCondition.STATUS_CONTROLLED,
                    UserCondition.STATUS_NEEDS_ATTENTION,
                ),
            ).select_related("condition_type")
        )
        condition_ids = [condition.id for condition in conditions]
        evaluations = list(
            ConditionDailyEvaluation.objects.filter(
                user_condition_id__in=condition_ids,
                evaluation_date=on_date,
            ).values_list(
                "medication_adherence_percent",
                "restriction_adherence_percent",
            )
        )
        adherence_values = [
            (float(medication or 0) + float(restriction or 0)) / 2
            for medication, restriction in evaluations
        ]
        adherence = (
            round(sum(adherence_values) / len(adherence_values), 2)
            if adherence_values
            else 0.0
        )
        medication_count, pending_doses = ConditionMedicationService.today_dose_counts(
            user=user,
            on_date=on_date,
        )
        condition_constraints = [
            constraint
            for constraint in ConstraintReadService.active_for_user(user=user)
            if constraint.source_condition_id in condition_ids
            or (
                constraint.source_restriction_id
                and constraint.source_restriction.user_condition_id in condition_ids
            )
            or (
                constraint.source_target_id
                and constraint.source_target.user_condition_id in condition_ids
            )
        ]
        summaries = tuple(
            dict.fromkeys(
                constraint.reason_summary
                for constraint in condition_constraints
                if constraint.reason_summary
            )
        )
        movement_adjusted = any(
            constraint.tracker_type in {"activity", "steps"}
            for constraint in condition_constraints
        )
        return ConditionRuntimeSummary(
            active_condition_labels=tuple(
                ConditionCatalogService.display_name(condition.condition_type)
                for condition in conditions
            ),
            medication_count_today=medication_count,
            pending_doses_today=pending_doses,
            adherence_percent=adherence,
            applied_summaries=summaries,
            exercise_intensity_mode=(
                "condition_adjusted" if movement_adjusted else "standard"
            ),
        )
