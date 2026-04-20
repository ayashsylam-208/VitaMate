from __future__ import annotations

from datetime import datetime, timedelta

from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from core.models import ConditionMedicationLog
from core.repositories.medication_repository import MedicationRepository
from core.services.condition_points_evaluator import ConditionPointsEvaluator
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers


class MedicationDoseWorkflowService:
    FINAL_STATUSES = {
        ConditionMedicationLog.STATUS_TAKEN,
        ConditionMedicationLog.STATUS_TAKEN_ON_TIME,
        ConditionMedicationLog.STATUS_TAKEN_LATE,
        ConditionMedicationLog.STATUS_MISSED,
        ConditionMedicationLog.STATUS_SKIPPED,
    }

    @staticmethod
    def _get_log(*, user, log_id: int) -> ConditionMedicationLog:
        log = MedicationRepository.get_dose_log_for_user(user=user, log_id=log_id)
        if log is None:
            raise ValidationError({"detail": "Dose log not found."})
        if not log.medication.is_active:
            raise ValidationError({"detail": "This medication is inactive."})
        return log

    @staticmethod
    def _aware(value: datetime | None) -> datetime:
        value = value or timezone.now()
        if timezone.is_naive(value):
            return timezone.make_aware(value, timezone.get_current_timezone())
        return value

    @staticmethod
    def _apply_condition_points(log: ConditionMedicationLog) -> None:
        condition = log.medication.user_condition
        if condition is not None:
            ConditionPointsEvaluator.apply_medication_log_points(
                log=log,
                user_condition=condition,
            )

    @classmethod
    def _ensure_not_final(cls, log: ConditionMedicationLog) -> None:
        if log.status in cls.FINAL_STATUSES:
            raise ValidationError({"detail": "This dose is already finalized."})

    @classmethod
    @transaction.atomic
    def mark_taken(
        cls,
        *,
        user,
        log_id: int,
        taken_at: datetime | None = None,
        dose_taken_amount=None,
    ) -> ConditionMedicationLog:
        log = cls._get_log(user=user, log_id=log_id)
        cls._ensure_not_final(log)
        taken_at = cls._aware(taken_at)
        grace_minutes = log.schedule.grace_period_minutes if log.schedule else 60
        scheduled_for = log.scheduled_for or taken_at
        on_time_cutoff = scheduled_for + timedelta(minutes=grace_minutes)
        log.status = (
            ConditionMedicationLog.STATUS_TAKEN_ON_TIME
            if taken_at <= on_time_cutoff
            else ConditionMedicationLog.STATUS_TAKEN_LATE
        )
        log.taken_at = taken_at
        log.dose_taken_amount = dose_taken_amount
        log.action_source = ConditionMedicationLog.ACTION_USER
        MedicationRepository.save_dose_log(
            log,
            update_fields=["status", "taken_at", "dose_taken_amount", "action_source", "updated_at"],
        )
        cls._apply_condition_points(log)
        cls._publish_adherence_event(log)
        return log

    @classmethod
    @transaction.atomic
    def mark_missed(cls, *, user, log_id: int) -> ConditionMedicationLog:
        log = cls._get_log(user=user, log_id=log_id)
        cls._ensure_not_final(log)
        log.status = ConditionMedicationLog.STATUS_MISSED
        log.taken_at = None
        log.action_source = ConditionMedicationLog.ACTION_USER
        MedicationRepository.save_dose_log(
            log,
            update_fields=["status", "taken_at", "action_source", "updated_at"],
        )
        cls._apply_condition_points(log)
        cls._publish_adherence_event(log)
        return log

    @classmethod
    @transaction.atomic
    def mark_skipped(cls, *, user, log_id: int, reason: str = "") -> ConditionMedicationLog:
        log = cls._get_log(user=user, log_id=log_id)
        cls._ensure_not_final(log)
        log.status = ConditionMedicationLog.STATUS_SKIPPED
        log.taken_at = None
        log.skip_reason = reason or ""
        log.notes = reason or ""
        log.action_source = ConditionMedicationLog.ACTION_USER
        MedicationRepository.save_dose_log(
            log,
            update_fields=["status", "taken_at", "skip_reason", "notes", "action_source", "updated_at"],
        )
        cls._apply_condition_points(log)
        cls._publish_adherence_event(log)
        return log

    @classmethod
    @transaction.atomic
    def snooze(cls, *, user, log_id: int, snoozed_until: datetime) -> ConditionMedicationLog:
        log = cls._get_log(user=user, log_id=log_id)
        if log.status in cls.FINAL_STATUSES:
            raise ValidationError({"detail": "Finalized doses cannot be snoozed."})
        snoozed_until = cls._aware(snoozed_until)
        if snoozed_until <= timezone.now():
            raise ValidationError({"snoozed_until": "Snooze time must be in the future."})
        log.status = ConditionMedicationLog.STATUS_SNOOZED
        log.snoozed_until = snoozed_until
        log.action_source = ConditionMedicationLog.ACTION_USER
        MedicationRepository.save_dose_log(
            log,
            update_fields=["status", "snoozed_until", "action_source", "updated_at"],
        )
        cls._apply_condition_points(log)
        cls._publish_adherence_event(log)
        return log

    @classmethod
    @transaction.atomic
    def mark_overdue_pending_doses(cls, *, now: datetime | None = None) -> int:
        now = cls._aware(now)
        changed = 0
        pending = MedicationRepository.list_pending_dose_logs_before(now=now)
        for log in pending:
            grace_minutes = log.schedule.grace_period_minutes if log.schedule else 60
            if log.scheduled_for and log.scheduled_for + timedelta(minutes=grace_minutes) <= now:
                log.status = ConditionMedicationLog.STATUS_OVERDUE
                log.action_source = ConditionMedicationLog.ACTION_SYSTEM
                MedicationRepository.save_dose_log(
                    log,
                    update_fields=["status", "action_source", "updated_at"],
                )
                changed += 1
        return changed

    @staticmethod
    def _publish_adherence_event(log: ConditionMedicationLog) -> None:
        HealthStateEventPublisher.publish_on_commit(
            user=log.medication.user,
            trigger_type=HealthStateTriggers.MEDICATION_ADHERENCE_CHANGED,
            payload={
                "trigger_reference": str(log.id),
                "source_id": log.id,
                "event_dates": [log.scheduled_date],
                "medication_id": log.medication_id,
                "user_condition_id": log.medication.user_condition_id,
            },
        )
