from __future__ import annotations

from collections import defaultdict

from django.db.models import Q
from django.utils import timezone

from core.models import ResolvedTrackerConstraint


class ConstraintReadService:
    """Optimized read facade for active materialized constraints."""

    @staticmethod
    def has_active_constraints(*, user) -> bool:
        return ResolvedTrackerConstraint.objects.filter(
            user=user,
            status=ResolvedTrackerConstraint.STATUS_ACTIVE,
        ).exists()

    @staticmethod
    def active_for_user(
        *,
        user,
        tracker_type: str | None = None,
        metric_keys: list[str] | tuple[str, ...] | None = None,
        at_time=None,
    ):
        at_time = at_time or timezone.now()
        query = ResolvedTrackerConstraint.objects.filter(
            user=user,
            status=ResolvedTrackerConstraint.STATUS_ACTIVE,
            effective_from__lte=at_time,
        ).filter(
            Q(effective_to__isnull=True) | Q(effective_to__gt=at_time),
        ).select_related(
            "source_condition",
            "source_condition__condition_type",
            "source_restriction",
            "source_target",
            "source_nutrient_rule",
            "source_user_nutrient_target",
        )
        if tracker_type:
            query = query.filter(tracker_type=tracker_type)
        if metric_keys:
            query = query.filter(metric_key__in=metric_keys)
        return query.order_by("tracker_type", "metric_key", "-priority", "-computed_at")

    @classmethod
    def active_summary_for_user(cls, *, user, tracker_type: str | None = None) -> dict[str, list[dict]]:
        grouped: dict[str, list[dict]] = defaultdict(list)
        for constraint in cls.active_for_user(user=user, tracker_type=tracker_type):
            grouped[constraint.tracker_type].append(cls.serialize_constraint(constraint))
        return dict(grouped)

    @classmethod
    def serialize_constraint(cls, constraint: ResolvedTrackerConstraint) -> dict:
        return {
            "id": constraint.id,
            "tracker_type": constraint.tracker_type,
            "category": constraint.category,
            "metric_key": constraint.metric_key,
            "rule_type": constraint.rule_type,
            "evaluation_mode": constraint.evaluation_mode,
            "unit": constraint.unit,
            "min_value": constraint.min_value,
            "max_value": constraint.max_value,
            "target_value": constraint.target_value,
            "warning_value": constraint.warning_value,
            "priority": constraint.priority,
            "is_blocking": constraint.is_blocking,
            "is_scored": constraint.is_scored,
            "source_type": constraint.source_type,
            "reason_summary": constraint.reason_summary,
            "confidence_score": constraint.confidence_score,
            "effective_from": constraint.effective_from.isoformat() if constraint.effective_from else None,
            "effective_to": constraint.effective_to.isoformat() if constraint.effective_to else None,
            "computed_at": constraint.computed_at.isoformat() if constraint.computed_at else None,
            "status": constraint.status,
            "version_hash": constraint.version_hash,
        }

    @classmethod
    def effective_numeric_value(
        cls,
        *,
        user,
        tracker_type: str,
        metric_key: str,
        fallback: float | int | None = None,
        at_time=None,
    ) -> float | int | None:
        constraints = list(
            cls.active_for_user(
                user=user,
                tracker_type=tracker_type,
                metric_keys=[metric_key],
                at_time=at_time,
            )
        )
        return cls.effective_numeric_value_from_constraints(
            constraints=constraints,
            fallback=fallback,
        )

    @classmethod
    def effective_numeric_value_from_constraints(
        cls,
        *,
        constraints: list[ResolvedTrackerConstraint],
        fallback: float | int | None = None,
    ) -> float | int | None:
        if not constraints:
            return fallback

        target_constraint = cls._highest_priority_constraint(
            constraints=constraints,
            rule_type=ResolvedTrackerConstraint.RULE_TARGET,
            value_attr="target_value",
        )
        target = float(target_constraint.target_value) if target_constraint is not None else None
        minimum_priority = target_constraint.priority if target_constraint is not None else 0
        max_value = cls._most_restrictive_value(
            constraints=constraints,
            rule_types={
                ResolvedTrackerConstraint.RULE_MAX,
                ResolvedTrackerConstraint.RULE_AVOID,
                ResolvedTrackerConstraint.RULE_RANGE,
            },
            value_attr="max_value",
            choose_min=True,
            minimum_priority=minimum_priority,
        )
        min_value = cls._most_restrictive_value(
            constraints=constraints,
            rule_types={
                ResolvedTrackerConstraint.RULE_MIN,
                ResolvedTrackerConstraint.RULE_RANGE,
            },
            value_attr="min_value",
            choose_min=False,
            minimum_priority=minimum_priority,
        )

        value = target if target is not None else fallback
        if value is None and max_value is not None:
            value = max_value
        if value is None and min_value is not None:
            value = min_value
        if value is not None and max_value is not None and float(value) > float(max_value):
            value = max_value
        if value is not None and min_value is not None and float(value) < float(min_value):
            value = min_value
        return value

    @staticmethod
    def _highest_priority_constraint(
        *,
        constraints: list[ResolvedTrackerConstraint],
        rule_type: str,
        value_attr: str,
    ) -> ResolvedTrackerConstraint | None:
        values = [
            constraint
            for constraint in constraints
            if constraint.rule_type == rule_type and getattr(constraint, value_attr) is not None
        ]
        if not values:
            return None
        return sorted(values, key=lambda item: (item.priority, item.computed_at), reverse=True)[0]

    @staticmethod
    def _most_restrictive_value(
        *,
        constraints: list[ResolvedTrackerConstraint],
        rule_types: set[str],
        value_attr: str,
        choose_min: bool,
        minimum_priority: int = 0,
    ) -> float | None:
        values = [
            float(getattr(constraint, value_attr))
            for constraint in constraints
            if constraint.rule_type in rule_types
            and getattr(constraint, value_attr) is not None
            and constraint.priority >= minimum_priority
        ]
        if not values:
            return None
        return min(values) if choose_min else max(values)
