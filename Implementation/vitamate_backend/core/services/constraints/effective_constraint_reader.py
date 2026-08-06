from __future__ import annotations

from collections import defaultdict
from dataclasses import asdict, dataclass
from typing import Iterable

from core.models import ResolvedTrackerConstraint
from core.services.constraints.constraint_read_service import ConstraintReadService


@dataclass(frozen=True, slots=True)
class EffectiveConstraint:
    tracker_type: str
    constraint_key: str
    value: float | int | None
    unit: str
    rule_type: str
    source_type: str
    reason: str
    priority: int
    effective_from: str | None
    effective_to: str | None
    constraint_id: int | None
    defaulted: bool = False

    def as_dict(self) -> dict:
        return asdict(self)


class EffectiveConstraintReader:
    """Authoritative read facade for materialized tracker constraints."""

    @classmethod
    def get_effective_constraint(
        cls,
        *,
        user,
        tracker_type: str,
        constraint_key: str,
        at_time=None,
        default_value=None,
        default_unit: str = "",
        default_source: str = "documented_profile_default",
    ) -> EffectiveConstraint:
        constraints = list(
            ConstraintReadService.active_for_user(
                user=user,
                tracker_type=tracker_type,
                metric_keys=[constraint_key],
                at_time=at_time,
            )
        )
        return cls._resolve_constraints(
            constraints=constraints,
            tracker_type=tracker_type,
            constraint_key=constraint_key,
            default_value=default_value,
            default_unit=default_unit,
            default_source=default_source,
        )

    @classmethod
    def get_effective_constraints(
        cls,
        *,
        user,
        requests: Iterable[dict],
        at_time=None,
    ) -> dict[tuple[str, str], EffectiveConstraint]:
        """Resolve many targets from one active-constraint query."""
        normalized_requests = [dict(item) for item in requests]
        if not normalized_requests:
            return {}
        metric_keys = sorted(
            {str(item["constraint_key"]) for item in normalized_requests}
        )
        grouped = defaultdict(list)
        for constraint in ConstraintReadService.active_for_user(
            user=user,
            metric_keys=metric_keys,
            at_time=at_time,
        ):
            grouped[(constraint.tracker_type, constraint.metric_key)].append(constraint)
        return {
            (str(item["tracker_type"]), str(item["constraint_key"])): cls._resolve_constraints(
                constraints=grouped[
                    (str(item["tracker_type"]), str(item["constraint_key"]))
                ],
                tracker_type=str(item["tracker_type"]),
                constraint_key=str(item["constraint_key"]),
                default_value=item.get("default_value"),
                default_unit=str(item.get("default_unit") or ""),
                default_source=str(
                    item.get("default_source") or "documented_profile_default"
                ),
            )
            for item in normalized_requests
        }

    @classmethod
    def _resolve_constraints(
        cls,
        *,
        constraints,
        tracker_type: str,
        constraint_key: str,
        default_value,
        default_unit: str,
        default_source: str,
    ) -> EffectiveConstraint:
        value = ConstraintReadService.effective_numeric_value_from_constraints(
            constraints=list(constraints),
            fallback=default_value,
        )
        selected = cls._selected_constraint(constraints=constraints, value=value)
        if selected is None:
            return EffectiveConstraint(
                tracker_type=tracker_type,
                constraint_key=constraint_key,
                value=value,
                unit=default_unit,
                rule_type=ResolvedTrackerConstraint.RULE_TARGET,
                source_type=default_source,
                reason="No active materialized constraint; explicit documented default used.",
                priority=0,
                effective_from=None,
                effective_to=None,
                constraint_id=None,
                defaulted=True,
            )
        return EffectiveConstraint(
            tracker_type=tracker_type,
            constraint_key=constraint_key,
            value=value,
            unit=selected.unit,
            rule_type=selected.rule_type,
            source_type=selected.source_type,
            reason=selected.reason_summary,
            priority=selected.priority,
            effective_from=selected.effective_from.isoformat() if selected.effective_from else None,
            effective_to=selected.effective_to.isoformat() if selected.effective_to else None,
            constraint_id=selected.id,
        )

    @staticmethod
    def get_effective_tracker_constraints(*, user, tracker_type: str, at_time=None) -> list[dict]:
        return [
            ConstraintReadService.serialize_constraint(constraint)
            for constraint in ConstraintReadService.active_for_user(
                user=user,
                tracker_type=tracker_type,
                at_time=at_time,
            )
        ]

    @staticmethod
    def _selected_constraint(*, constraints, value):
        if not constraints:
            return None
        exact_targets = [
            item
            for item in constraints
            if item.rule_type == ResolvedTrackerConstraint.RULE_TARGET
            and item.target_value is not None
            and value is not None
            and float(item.target_value) == float(value)
        ]
        candidates = exact_targets or list(constraints)
        return sorted(candidates, key=lambda item: (item.priority, item.computed_at, item.id), reverse=True)[0]
