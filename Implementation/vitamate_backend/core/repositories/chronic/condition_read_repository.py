from __future__ import annotations

from django.utils import timezone

from core.models import (
    ConditionMedication,
    ConditionMedicationLog,
    ConditionMedicationSchedule,
    ConditionType,
    HealthIndicatorRecord,
    UserCondition,
)


class ConditionReadRepository:
    @staticmethod
    def condition_types_queryset():
        return ConditionType.objects.prefetch_related("restrictions", "rule_profiles").all()

    @staticmethod
    def user_conditions_queryset(*, user):
        return (
            UserCondition.objects.filter(user=user)
            .select_related("condition_type")
            .prefetch_related(
                "condition_type__restrictions",
                "condition_type__rule_profiles",
                "targets",
                "medications__schedules__logs",
                "indicator_records",
                "alerts",
            )
        )

    @staticmethod
    def condition_medications_queryset(*, user, user_condition_id=None):
        queryset = (
            ConditionMedication.objects.filter(user_condition__user=user)
            .select_related("user_condition", "user_condition__condition_type")
            .prefetch_related("schedules__logs")
        )
        if user_condition_id:
            queryset = queryset.filter(user_condition_id=user_condition_id)
        return queryset

    @staticmethod
    def medication_plans_queryset(*, user):
        return (
            ConditionMedication.objects.filter(user=user)
            .select_related("user_condition", "user_condition__condition_type", "medicine")
            .prefetch_related("schedules", "dose_logs")
            .order_by("-is_active", "display_name", "name", "id")
        )

    @staticmethod
    def condition_medication_schedules_queryset(*, user):
        return ConditionMedicationSchedule.objects.filter(
            medication__user_condition__user=user
        ).select_related("medication__user_condition")

    @staticmethod
    def health_indicator_records_queryset(*, user, user_condition_id=None):
        queryset = HealthIndicatorRecord.objects.filter(user_condition__user=user).select_related(
            "user_condition",
            "user_condition__condition_type",
        )
        if user_condition_id:
            queryset = queryset.filter(user_condition_id=user_condition_id)
        return queryset

    @staticmethod
    def today_dose_logs_queryset(*, user, target_date=None):
        target_date = target_date or timezone.localdate()
        return (
            ConditionMedicationLog.objects.filter(
                medication__user=user,
                medication__is_active=True,
                scheduled_date=target_date,
            )
            .select_related("medication", "medication__user_condition", "medication__user_condition__condition_type")
            .order_by("scheduled_for", "id")
        )
