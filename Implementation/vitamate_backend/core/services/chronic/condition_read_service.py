from __future__ import annotations

from core.repositories.condition_read_repository import ConditionReadRepository
from core.repositories.medication_repository import MedicationRepository


class ConditionReadService:
    @staticmethod
    def get_condition_types():
        return ConditionReadRepository.condition_types_queryset()

    @staticmethod
    def get_user_conditions(*, user, compact: bool = False):
        if compact:
            return ConditionReadRepository.user_conditions_compact_queryset(user=user)
        return ConditionReadRepository.user_conditions_queryset(user=user)

    @staticmethod
    def get_user_conditions_home(*, user):
        return ConditionReadRepository.user_conditions_home_queryset(user=user)

    @staticmethod
    def get_user_conditions_guidance(*, user):
        return ConditionReadRepository.user_conditions_guidance_queryset(user=user)

    @staticmethod
    def get_condition_medications(*, user, user_condition_id=None):
        return MedicationRepository.condition_medications_queryset(
            user=user,
            user_condition_id=user_condition_id,
        )

    @staticmethod
    def get_condition_medication_schedules(*, user):
        return MedicationRepository.schedules_for_user(user=user)

    @staticmethod
    def get_health_indicator_records(*, user, user_condition_id=None):
        return ConditionReadRepository.health_indicator_records_queryset(
            user=user,
            user_condition_id=user_condition_id,
        )
