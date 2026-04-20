from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta

from django.db import transaction
from django.utils import timezone

from core.models import (
    ConditionAlert,
    ConditionMedication,
    ConditionMedicationLog,
    ConditionMedicationSchedule,
    UserCondition,
)
from core.repositories.medication_repository import MedicationRepository
from core.services.condition_points_evaluator import ConditionPointsEvaluator
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers


@dataclass(frozen=True)
class DoseActionResult:
    log: ConditionMedicationLog
    reminder_at: datetime | None = None


class ConditionMedicationService:
    MISSED_MEDICATION_GRACE_MINUTES = 90
    DEFAULT_SNOOZE_MINUTES = 15

    @staticmethod
    def _system_local_now() -> datetime:
        return timezone.localtime()

    @staticmethod
    def _schedule_is_active_for_date(
        *,
        schedule: ConditionMedicationSchedule,
        target_date: date,
    ) -> bool:
        medication = schedule.medication
        if not medication.is_active:
            return False
        if medication.start_date and target_date < medication.start_date:
            return False
        if medication.end_date and target_date > medication.end_date:
            return False
        recurrence_days = schedule.recurrence_days or medication.recurrence_pattern or []
        if recurrence_days:
            return target_date.weekday() in recurrence_days
        return True

    @staticmethod
    def scheduled_datetime_for(
        *,
        schedule: ConditionMedicationSchedule,
        target_date: date,
    ) -> datetime:
        naive = datetime.combine(target_date, schedule.time_of_day)
        if timezone.is_naive(naive):
            return timezone.make_aware(naive, timezone.get_current_timezone())
        return naive

    @classmethod
    def dose_display_for_today(
        cls,
        *,
        schedule: ConditionMedicationSchedule,
        today: date,
    ) -> dict:
        is_scheduled_today = cls._schedule_is_active_for_date(
            schedule=schedule,
            target_date=today,
        )
        log = MedicationRepository.get_schedule_log_for_day(
            schedule=schedule,
            scheduled_date=today,
        )
        scheduled_for = (
            log.scheduled_for
            if log and log.scheduled_for
            else cls.scheduled_datetime_for(schedule=schedule, target_date=today)
        )
        return {
            "id": schedule.id,
            "time_of_day": schedule.time_of_day.strftime("%H:%M"),
            "scheduled_for": scheduled_for.isoformat() if scheduled_for else None,
            "today_status": log.status if log else ("pending" if is_scheduled_today else "not_scheduled"),
            "taken_at": log.taken_at.isoformat() if log and log.taken_at else None,
            "skip_reason": log.skip_reason if log else "",
            "reminder_enabled": schedule.medication.reminder_enabled,
            "reminder_lead_minutes": schedule.medication.reminder_lead_minutes,
            "recurrence_days": schedule.recurrence_days,
            "is_scheduled_today": is_scheduled_today,
        }

    @classmethod
    @transaction.atomic
    def ensure_today_medication_logs(
        cls,
        *,
        user_condition: UserCondition,
        now: datetime | None = None,
    ) -> None:
        now = now or cls._system_local_now()
        today = now.date()
        schedules = MedicationRepository.schedules_for_user_condition(user_condition=user_condition)
        for schedule in schedules:
            if not cls._schedule_is_active_for_date(schedule=schedule, target_date=today):
                continue

            scheduled_dt = cls.scheduled_datetime_for(schedule=schedule, target_date=today)
            overdue_at = scheduled_dt + timedelta(minutes=cls.MISSED_MEDICATION_GRACE_MINUTES)
            log = MedicationRepository.get_schedule_log_for_day(
                schedule=schedule,
                scheduled_date=today,
            )
            if log or now < overdue_at:
                continue

            log, created = MedicationRepository.get_or_create_schedule_log(
                schedule=schedule,
                scheduled_date=today,
                defaults={
                    "medication": schedule.medication,
                    "scheduled_for": scheduled_dt,
                    "status": ConditionMedicationLog.STATUS_MISSED,
                },
            )
            if not created:
                continue

            ConditionPointsEvaluator.apply_medication_log_points(
                log=log,
                user_condition=user_condition,
            )
            cls._ensure_alert(
                user_condition=user_condition,
                alert_type=ConditionAlert.TYPE_MEDICATION,
                message=(
                    f"Missed medication reminder: {schedule.medication.name} "
                    f"at {schedule.time_of_day.strftime('%H:%M')}"
                ),
                on_date=today,
            )

    @staticmethod
    def _ensure_alert(*, user_condition: UserCondition, alert_type: str, message: str, on_date: date) -> None:
        exists = user_condition.alerts.filter(
            alert_type=alert_type,
            message=message,
            created_at__date=on_date,
        ).exists()
        if not exists:
            ConditionAlert.objects.create(
                user_condition=user_condition,
                alert_type=alert_type,
                message=message,
            )

    @classmethod
    @transaction.atomic
    def mark_taken(
        cls,
        *,
        schedule: ConditionMedicationSchedule,
        now: datetime | None = None,
    ) -> DoseActionResult:
        now = now or cls._system_local_now()
        today = now.date()
        user_condition = schedule.medication.user_condition
        scheduled_dt = cls.scheduled_datetime_for(schedule=schedule, target_date=today)
        on_time_cutoff = scheduled_dt + timedelta(minutes=cls.MISSED_MEDICATION_GRACE_MINUTES)

        log, _ = MedicationRepository.get_or_create_schedule_log(
            schedule=schedule,
            scheduled_date=today,
            defaults={
                "medication": schedule.medication,
                "scheduled_for": scheduled_dt,
                "taken_at": now,
                "status": (
                    ConditionMedicationLog.STATUS_TAKEN_ON_TIME
                    if now <= on_time_cutoff
                    else ConditionMedicationLog.STATUS_TAKEN_LATE
                ),
            },
        )

        if log.status not in {
            ConditionMedicationLog.STATUS_TAKEN_ON_TIME,
            ConditionMedicationLog.STATUS_TAKEN_LATE,
        }:
            log.taken_at = now
            log.scheduled_for = scheduled_dt
            log.status = (
                ConditionMedicationLog.STATUS_TAKEN_ON_TIME
                if now <= on_time_cutoff
                else ConditionMedicationLog.STATUS_TAKEN_LATE
            )
            MedicationRepository.save_dose_log(
                log,
                update_fields=["taken_at", "scheduled_for", "status"],
            )

        ConditionPointsEvaluator.apply_medication_log_points(
            log=log,
            user_condition=user_condition,
        )
        cls._publish_adherence_event(log)
        return DoseActionResult(log=log)

    @classmethod
    @transaction.atomic
    def mark_missed(
        cls,
        *,
        schedule: ConditionMedicationSchedule,
        now: datetime | None = None,
    ) -> DoseActionResult:
        now = now or cls._system_local_now()
        today = now.date()
        scheduled_dt = cls.scheduled_datetime_for(schedule=schedule, target_date=today)
        log, _ = MedicationRepository.get_or_create_schedule_log(
            schedule=schedule,
            scheduled_date=today,
            defaults={
                "medication": schedule.medication,
                "scheduled_for": scheduled_dt,
                "status": ConditionMedicationLog.STATUS_MISSED,
            },
        )
        log.scheduled_for = scheduled_dt
        log.taken_at = None
        log.status = ConditionMedicationLog.STATUS_MISSED
        MedicationRepository.save_dose_log(
            log,
            update_fields=["scheduled_for", "taken_at", "status"],
        )
        ConditionPointsEvaluator.apply_medication_log_points(
            log=log,
            user_condition=schedule.medication.user_condition,
        )
        cls._publish_adherence_event(log)
        return DoseActionResult(log=log)

    @classmethod
    @transaction.atomic
    def skip_dose(
        cls,
        *,
        schedule: ConditionMedicationSchedule,
        reason: str,
        now: datetime | None = None,
    ) -> DoseActionResult:
        now = now or cls._system_local_now()
        today = now.date()
        scheduled_dt = cls.scheduled_datetime_for(schedule=schedule, target_date=today)
        log, _ = MedicationRepository.get_or_create_schedule_log(
            schedule=schedule,
            scheduled_date=today,
            defaults={
                "medication": schedule.medication,
                "scheduled_for": scheduled_dt,
                "status": ConditionMedicationLog.STATUS_SKIPPED,
                "skip_reason": reason,
            },
        )
        log.scheduled_for = scheduled_dt
        log.taken_at = None
        log.status = ConditionMedicationLog.STATUS_SKIPPED
        log.skip_reason = reason
        MedicationRepository.save_dose_log(
            log,
            update_fields=["scheduled_for", "taken_at", "status", "skip_reason"],
        )
        ConditionPointsEvaluator.apply_medication_log_points(
            log=log,
            user_condition=schedule.medication.user_condition,
        )
        cls._publish_adherence_event(log)
        return DoseActionResult(log=log)

    @classmethod
    @transaction.atomic
    def snooze_dose(
        cls,
        *,
        schedule: ConditionMedicationSchedule,
        snooze_minutes: int | None = None,
        now: datetime | None = None,
    ) -> DoseActionResult:
        now = now or cls._system_local_now()
        today = now.date()
        snooze_minutes = snooze_minutes or cls.DEFAULT_SNOOZE_MINUTES
        scheduled_dt = cls.scheduled_datetime_for(schedule=schedule, target_date=today)
        reminder_at = now + timedelta(minutes=snooze_minutes)
        log, _ = MedicationRepository.get_or_create_schedule_log(
            schedule=schedule,
            scheduled_date=today,
            defaults={
                "medication": schedule.medication,
                "scheduled_for": reminder_at,
                "status": ConditionMedicationLog.STATUS_SNOOZED,
            },
        )
        log.scheduled_for = reminder_at
        log.taken_at = None
        log.status = ConditionMedicationLog.STATUS_SNOOZED
        MedicationRepository.save_dose_log(
            log,
            update_fields=["scheduled_for", "taken_at", "status"],
        )
        if reminder_at > scheduled_dt:
            cls._ensure_alert(
                user_condition=schedule.medication.user_condition,
                alert_type=ConditionAlert.TYPE_MEDICATION,
                message=(
                    f"Medication snoozed: {schedule.medication.name} until "
                    f"{reminder_at.strftime('%H:%M')}"
                ),
                on_date=today,
            )
        ConditionPointsEvaluator.apply_medication_log_points(
            log=log,
            user_condition=schedule.medication.user_condition,
        )
        cls._publish_adherence_event(log)
        return DoseActionResult(log=log, reminder_at=reminder_at)

    @classmethod
    def today_dose_list(cls, *, user, on_date: date | None = None) -> list[dict]:
        on_date = on_date or cls._system_local_now().date()
        schedules = MedicationRepository.schedules_for_user(user=user)
        results = []
        for schedule in schedules:
            if not cls._schedule_is_active_for_date(schedule=schedule, target_date=on_date):
                continue
            schedule_payload = cls.dose_display_for_today(schedule=schedule, today=on_date)
            medication = schedule.medication
            results.append(
                {
                    "schedule": schedule_payload,
                    "medication": {
                        "id": medication.id,
                        "name": medication.name,
                        "scientific_name": medication.scientific_name,
                        "dosage": medication.dosage,
                        "dosage_amount": medication.dosage_amount,
                        "dosage_unit": medication.dosage_unit,
                        "relation_to_meal": medication.relation_to_meal,
                        "instructions": medication.instructions,
                    },
                    "condition": {
                        "id": medication.user_condition.id,
                        "type": medication.user_condition.condition_type.code,
                        "name": medication.user_condition.condition_type.name,
                    },
                }
            )
        return sorted(results, key=lambda item: item["schedule"]["time_of_day"])

    @classmethod
    def active_medication_count_for_today(cls, *, user, on_date: date | None = None) -> int:
        on_date = on_date or cls._system_local_now().date()
        return len(cls.today_dose_list(user=user, on_date=on_date))

    @classmethod
    def pending_dose_count_for_today(cls, *, user, on_date: date | None = None) -> int:
        on_date = on_date or cls._system_local_now().date()
        return sum(
            1
            for item in cls.today_dose_list(user=user, on_date=on_date)
            if item["schedule"]["today_status"] in {"pending", ConditionMedicationLog.STATUS_SNOOZED}
        )

    @staticmethod
    def _publish_adherence_event(log: ConditionMedicationLog) -> None:
        medication = log.medication or getattr(log.schedule, "medication", None)
        if medication is None:
            return
        HealthStateEventPublisher.publish_on_commit(
            user=medication.user,
            trigger_type=HealthStateTriggers.MEDICATION_ADHERENCE_CHANGED,
            payload={
                "trigger_reference": str(log.id),
                "source_id": log.id,
                "event_dates": [log.scheduled_date],
                "medication_id": medication.id,
                "user_condition_id": medication.user_condition_id,
            },
        )
