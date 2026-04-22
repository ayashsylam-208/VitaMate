from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta

from core.models import ConditionMedication, ConditionMedicationLog, UserCondition
from core.repositories.medication_repository import MedicationRepository


@dataclass(frozen=True)
class MedicationAdherenceSummary:
    medication_id: int | None
    expected_doses: int
    taken_doses: int
    missed_doses: int
    skipped_doses: int
    pending_doses: int
    overdue_doses: int
    adherence_percent: float
    streak_days: int
    on_time_percent: float


class MedicationAdherenceService:
    TAKEN_STATUSES = {
        ConditionMedicationLog.STATUS_TAKEN,
        ConditionMedicationLog.STATUS_TAKEN_ON_TIME,
        ConditionMedicationLog.STATUS_TAKEN_LATE,
    }
    ON_TIME_STATUSES = {
        ConditionMedicationLog.STATUS_TAKEN,
        ConditionMedicationLog.STATUS_TAKEN_ON_TIME,
    }

    @classmethod
    def _logs_for_period(cls, *, medication_ids: list[int], start_date: date, end_date: date):
        return MedicationRepository.logs_for_medication_ids(
            medication_ids=medication_ids,
            start_date=start_date,
            end_date=end_date,
        )

    @classmethod
    def _summary_from_logs(
        cls,
        *,
        logs,
        medication_id: int | None,
        start_date: date,
        end_date: date,
    ) -> MedicationAdherenceSummary:
        logs = list(logs)
        expected = len(logs)
        taken = sum(1 for log in logs if log.status in cls.TAKEN_STATUSES)
        missed = sum(1 for log in logs if log.status == ConditionMedicationLog.STATUS_MISSED)
        skipped = sum(1 for log in logs if log.status == ConditionMedicationLog.STATUS_SKIPPED)
        pending = sum(
            1
            for log in logs
            if log.status in {ConditionMedicationLog.STATUS_PENDING, ConditionMedicationLog.STATUS_SNOOZED}
        )
        overdue = sum(1 for log in logs if log.status == ConditionMedicationLog.STATUS_OVERDUE)
        on_time = sum(1 for log in logs if log.status in cls.ON_TIME_STATUSES)
        adherence = round((taken / expected) * 100, 2) if expected else 0.0
        on_time_percent = round((on_time / expected) * 100, 2) if expected else 0.0

        by_date: dict[date, list[ConditionMedicationLog]] = {}
        for log in logs:
            by_date.setdefault(log.scheduled_date, []).append(log)
        streak = 0
        cursor = end_date
        while cursor >= start_date:
            day_logs = by_date.get(cursor, [])
            if not day_logs:
                cursor -= timedelta(days=1)
                continue
            if all(log.status in cls.TAKEN_STATUSES for log in day_logs):
                streak += 1
                cursor -= timedelta(days=1)
                continue
            break

        return MedicationAdherenceSummary(
            medication_id=medication_id,
            expected_doses=expected,
            taken_doses=taken,
            missed_doses=missed,
            skipped_doses=skipped,
            pending_doses=pending,
            overdue_doses=overdue,
            adherence_percent=adherence,
            streak_days=streak,
            on_time_percent=on_time_percent,
        )

    @classmethod
    def get_medication_adherence(
        cls,
        *,
        medication: ConditionMedication,
        start_date: date,
        end_date: date,
    ) -> MedicationAdherenceSummary:
        logs = cls._logs_for_period(
            medication_ids=[medication.id],
            start_date=start_date,
            end_date=end_date,
        )
        return cls._summary_from_logs(
            logs=logs,
            medication_id=medication.id,
            start_date=start_date,
            end_date=end_date,
        )

    @classmethod
    def get_user_adherence(
        cls,
        *,
        user,
        start_date: date,
        end_date: date,
    ) -> MedicationAdherenceSummary:
        medication_ids = MedicationRepository.medication_ids_for_user(user=user)
        logs = cls._logs_for_period(
            medication_ids=medication_ids,
            start_date=start_date,
            end_date=end_date,
        )
        return cls._summary_from_logs(
            logs=logs,
            medication_id=None,
            start_date=start_date,
            end_date=end_date,
        )

    @classmethod
    def get_condition_adherence(
        cls,
        *,
        user_condition: UserCondition,
        start_date: date,
        end_date: date,
    ) -> MedicationAdherenceSummary:
        medication_ids = MedicationRepository.medication_ids_for_condition(
            user_condition=user_condition,
        )
        logs = cls._logs_for_period(
            medication_ids=medication_ids,
            start_date=start_date,
            end_date=end_date,
        )
        return cls._summary_from_logs(
            logs=logs,
            medication_id=None,
            start_date=start_date,
            end_date=end_date,
        )

    @classmethod
    def counts_for_day(cls, *, user, target_date: date) -> dict:
        logs = list(
            MedicationRepository.logs_for_user_on_date(
                user=user,
                target_date=target_date,
            ).only("status")
        )
        total = len(logs)
        taken = 0
        pending = 0
        missed = 0
        overdue = 0
        skipped = 0
        for log in logs:
            if log.status in cls.TAKEN_STATUSES:
                taken += 1
            elif log.status in {
                ConditionMedicationLog.STATUS_PENDING,
                ConditionMedicationLog.STATUS_SNOOZED,
            }:
                pending += 1
            elif log.status == ConditionMedicationLog.STATUS_MISSED:
                missed += 1
            elif log.status == ConditionMedicationLog.STATUS_OVERDUE:
                overdue += 1
            elif log.status == ConditionMedicationLog.STATUS_SKIPPED:
                skipped += 1
        return {
            "today_total_doses": total,
            "taken_today": taken,
            "pending_today": pending,
            "missed_today": missed,
            "overdue_today": overdue,
            "skipped_today": skipped,
        }

    @classmethod
    def next_due(cls, *, user):
        return MedicationRepository.next_due_for_user(user=user)
