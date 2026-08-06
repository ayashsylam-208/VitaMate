from __future__ import annotations

import math

from core.models import ResolvedTrackerConstraint
from core.services.constraints.constraint_source_collector import ConstraintCandidate


class ConstraintCandidateValidationError(ValueError):
    pass


class ConstraintCandidateValidator:
    CANONICAL_UNITS = {
        ("nutrition", "calories_kcal"): "kcal",
        ("hydration", "daily_water_liters"): "liters",
        ("hydration", "total_fluid_intake_liters"): "liters",
        ("steps", "steps_count"): "steps",
        ("activity", "activity_minutes"): "minutes",
        ("activity", "calories_burned"): "kcal",
        ("sleep", "sleep_hours"): "hours",
        ("sleep", "bed_time"): "hour_of_day",
        ("sleep", "wake_time"): "hour_of_day",
        ("medication", "adherence_percent"): "percent",
        ("medication", "missed_doses_count"): "count",
        ("monitoring", "systolic_bp"): "mmHg",
        ("monitoring", "diastolic_bp"): "mmHg",
        ("monitoring", "ldl"): "mg/dL",
        ("monitoring", "hdl"): "mg/dL",
        ("monitoring", "triglycerides"): "mg/dL",
        ("monitoring", "fasting_glucose"): "mg/dL",
        ("monitoring", "postprandial_glucose"): "mg/dL",
    }

    @classmethod
    def validate_all(cls, candidates: list[ConstraintCandidate]) -> None:
        for index, candidate in enumerate(candidates):
            try:
                cls.validate(candidate)
            except ConstraintCandidateValidationError as exc:
                raise ConstraintCandidateValidationError(
                    f"candidate[{index}] {candidate.tracker_type}/{candidate.metric_key}: {exc}"
                ) from exc

    @classmethod
    def validate(cls, candidate: ConstraintCandidate) -> None:
        valid_trackers = {item[0] for item in ResolvedTrackerConstraint.TRACKER_TYPE_CHOICES}
        if candidate.tracker_type not in valid_trackers:
            raise ConstraintCandidateValidationError("unknown tracker type")
        if not candidate.metric_key:
            raise ConstraintCandidateValidationError("missing constraint key")
        if not candidate.unit:
            raise ConstraintCandidateValidationError("missing unit")

        expected_unit = cls.CANONICAL_UNITS.get(
            (candidate.tracker_type, candidate.metric_key)
        )
        if expected_unit and candidate.unit != expected_unit:
            raise ConstraintCandidateValidationError(
                f"unit must be {expected_unit!r}, got {candidate.unit!r}"
            )

        values = {
            "min_value": candidate.min_value,
            "max_value": candidate.max_value,
            "target_value": candidate.target_value,
            "warning_value": candidate.warning_value,
        }
        for name, value in values.items():
            if value is None:
                continue
            numeric = float(value)
            if not math.isfinite(numeric):
                raise ConstraintCandidateValidationError(f"{name} must be finite")
            if numeric < 0:
                raise ConstraintCandidateValidationError(f"{name} must not be negative")
        if (
            candidate.min_value is not None
            and candidate.max_value is not None
            and float(candidate.min_value) > float(candidate.max_value)
        ):
            raise ConstraintCandidateValidationError("minimum exceeds maximum")
