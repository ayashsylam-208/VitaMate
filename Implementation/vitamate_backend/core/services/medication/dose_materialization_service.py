from __future__ import annotations

from datetime import datetime, timedelta

from django.db import transaction
from django.utils import timezone

from core.models import ConditionMedication
from core.services.medication.medication_dose_workflow_service import (
    MedicationDoseWorkflowService,
)
from core.services.medication.medication_read_service import MedicationReadService
from core.services.medication.medication_schedule_service import MedicationScheduleService


class DoseMaterializationService:
    DEFAULT_LOOKBACK_HOURS = 1
    DEFAULT_HORIZON_HOURS = 72

    @classmethod
    @transaction.atomic
    def materialize_medication(
        cls,
        *,
        medication: ConditionMedication,
        now: datetime | None = None,
        lookback_hours: int = DEFAULT_LOOKBACK_HOURS,
        horizon_hours: int = DEFAULT_HORIZON_HOURS,
        mark_overdue: bool = True,
    ) -> dict:
        now = cls._aware(now)
        generated = MedicationScheduleService.generate_pending_doses(
            medication=medication,
            from_dt=now - timedelta(hours=lookback_hours),
            to_dt=now + timedelta(hours=horizon_hours),
        )
        overdue_count = (
            MedicationDoseWorkflowService.mark_overdue_pending_doses(now=now)
            if mark_overdue
            else 0
        )
        return {
            "generated_count": len(generated),
            "overdue_count": overdue_count,
            "horizon_hours": horizon_hours,
        }

    @classmethod
    @transaction.atomic
    def materialize_user(
        cls,
        *,
        user,
        now: datetime | None = None,
        lookback_hours: int = DEFAULT_LOOKBACK_HOURS,
        horizon_hours: int = DEFAULT_HORIZON_HOURS,
        mark_overdue: bool = True,
    ) -> dict:
        now = cls._aware(now)
        generated_count = 0
        for medication in MedicationReadService.get_active_medication_plans(user=user):
            generated_count += len(
                MedicationScheduleService.generate_pending_doses(
                    medication=medication,
                    from_dt=now - timedelta(hours=lookback_hours),
                    to_dt=now + timedelta(hours=horizon_hours),
                )
            )
        overdue_count = (
            MedicationDoseWorkflowService.mark_overdue_pending_doses(now=now)
            if mark_overdue
            else 0
        )
        return {
            "generated_count": generated_count,
            "overdue_count": overdue_count,
            "horizon_hours": horizon_hours,
        }

    @staticmethod
    def _aware(value: datetime | None) -> datetime:
        value = value or timezone.now()
        if timezone.is_naive(value):
            return timezone.make_aware(value, timezone.get_current_timezone())
        return value
