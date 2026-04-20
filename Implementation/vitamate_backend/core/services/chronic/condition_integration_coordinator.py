from __future__ import annotations

from datetime import date

from core.models import UserCondition
from core.services.condition_constraint_engine import ConditionConstraintEngine


class ConditionIntegrationCoordinator:
    """Coordinates chronic-condition side effects across trackers and summaries."""

    def __init__(self, *, constraint_engine: ConditionConstraintEngine | None = None):
        self._constraint_engine = constraint_engine or ConditionConstraintEngine()

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
        for condition in UserCondition.objects.filter(user=user, is_active=True):
            if not condition.targets.exists():
                self._chronic_service().rebuild_targets_for_condition(condition)
        return self._constraint_engine.build_effective_constraints(
            user=user,
            profile=profile,
            on_date=on_date,
        )
