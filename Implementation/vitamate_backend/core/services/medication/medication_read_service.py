from __future__ import annotations

from django.utils import timezone

from core.repositories.medication_repository import MedicationRepository


class MedicationReadService:
    @staticmethod
    def get_medication_plans(*, user):
        return MedicationRepository.medication_plans_queryset(user=user)

    @staticmethod
    def get_active_medication_plans(*, user):
        return MedicationRepository.active_medication_plans_queryset(user=user)

    @staticmethod
    def get_today_dose_logs(*, user, target_date=None):
        return MedicationRepository.today_dose_logs_queryset(
            user=user,
            target_date=target_date,
        )

    @staticmethod
    def get_today_preview_for_medication(*, medication, target_date=None):
        target_date = target_date or timezone.localdate()
        return MedicationReadService.get_today_dose_logs(
            user=medication.user,
            target_date=target_date,
        ).filter(medication=medication)
