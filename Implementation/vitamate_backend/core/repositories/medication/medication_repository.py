from __future__ import annotations

from datetime import date, datetime

from django.db.models import Prefetch, Q
from django.utils import timezone

from core.models import ConditionMedication, ConditionMedicationLog, ConditionMedicationSchedule


class MedicationRepository:
    NON_FINAL_LOG_STATUSES = [
        ConditionMedicationLog.STATUS_PENDING,
        ConditionMedicationLog.STATUS_SNOOZED,
        ConditionMedicationLog.STATUS_OVERDUE,
    ]

    @staticmethod
    def medication_plans_queryset(*, user):
        return (
            ConditionMedication.objects.filter(user=user)
            .select_related("user_condition", "user_condition__condition_type", "medicine")
            .prefetch_related("schedules", "dose_logs")
            .order_by("-is_active", "display_name", "name", "id")
        )

    @staticmethod
    def condition_medications_queryset(*, user, user_condition_id=None):
        queryset = (
            ConditionMedication.objects.filter(user_condition__user=user)
            .select_related("user_condition", "user_condition__condition_type", "medicine")
            .prefetch_related("schedules__logs")
            .order_by("-is_active", "display_name", "name", "id")
        )
        if user_condition_id:
            queryset = queryset.filter(user_condition_id=user_condition_id)
        return queryset

    @staticmethod
    def active_medication_plans_queryset(*, user):
        return MedicationRepository.medication_plans_queryset(user=user).filter(is_active=True)

    @staticmethod
    def get_by_id_for_user(*, user, medication_id: int):
        return MedicationRepository.medication_plans_queryset(user=user).filter(id=medication_id).first()

    @staticmethod
    def create_medication(**attrs):
        return ConditionMedication.objects.create(**attrs)

    @staticmethod
    def save_medication(medication, *, update_fields=None):
        if update_fields is None:
            medication.save()
        else:
            medication.save(update_fields=update_fields)
        return medication

    @staticmethod
    def list_active_schedules(*, medication):
        return medication.schedules.filter(is_active=True).order_by("time_of_day", "id")

    @staticmethod
    def schedules_for_user_condition(*, user_condition):
        return (
            ConditionMedicationSchedule.objects.filter(
                medication__user_condition=user_condition,
                medication__is_active=True,
            )
            .select_related("medication")
            .order_by("time_of_day", "id")
        )

    @staticmethod
    def schedules_for_user(*, user):
        return (
            ConditionMedicationSchedule.objects.filter(
                medication__user_condition__user=user,
                medication__user_condition__is_active=True,
                medication__is_active=True,
            )
            .select_related("medication", "medication__user_condition", "medication__user_condition__condition_type")
            .prefetch_related("logs")
            .order_by("time_of_day", "id")
        )

    @staticmethod
    def schedules_for_user_on_date(*, user, target_date: date):
        return (
            ConditionMedicationSchedule.objects.filter(
                medication__user_condition__user=user,
                medication__user_condition__is_active=True,
                medication__is_active=True,
            )
            .select_related("medication", "medication__user_condition", "medication__user_condition__condition_type")
            .prefetch_related(
                Prefetch(
                    "logs",
                    queryset=ConditionMedicationLog.objects.filter(
                        scheduled_date=target_date,
                    ).order_by("-id"),
                )
            )
            .order_by("time_of_day", "id")
        )

    @staticmethod
    def deactivate_schedules(*, medication):
        medication.schedules.update(is_active=False)

    @staticmethod
    def delete_all_schedules(*, medication):
        medication.schedules.all().delete()

    @staticmethod
    def create_schedule(*, medication, **attrs):
        return ConditionMedicationSchedule.objects.create(medication=medication, **attrs)

    @staticmethod
    def delete_future_non_final_logs(*, medication, scheduled_date_from=None):
        scheduled_date_from = scheduled_date_from or timezone.localdate()
        return ConditionMedicationLog.objects.filter(
            medication=medication,
            scheduled_date__gte=scheduled_date_from,
            status__in=MedicationRepository.NON_FINAL_LOG_STATUSES,
        ).delete()

    @staticmethod
    def get_or_create_dose_log(*, medication, scheduled_for, defaults: dict):
        return ConditionMedicationLog.objects.get_or_create(
            medication=medication,
            scheduled_for=scheduled_for,
            defaults=defaults,
        )

    @staticmethod
    def get_or_create_schedule_log(*, schedule, scheduled_date, defaults: dict):
        return ConditionMedicationLog.objects.get_or_create(
            schedule=schedule,
            scheduled_date=scheduled_date,
            defaults=defaults,
        )

    @staticmethod
    def get_schedule_log_for_day(*, schedule, scheduled_date):
        return schedule.logs.filter(scheduled_date=scheduled_date).first()

    @staticmethod
    def save_dose_log(log, *, update_fields=None):
        if update_fields is None:
            log.save()
        else:
            log.save(update_fields=update_fields)
        return log

    @staticmethod
    def get_dose_log_for_user(*, user, log_id: int):
        return (
            ConditionMedicationLog.objects.select_related(
                "medication",
                "medication__user_condition",
                "schedule",
            )
            .filter(id=log_id, medication__user=user)
            .first()
        )

    @staticmethod
    def list_pending_dose_logs_before(*, now: datetime):
        return ConditionMedicationLog.objects.select_related("schedule").filter(
            status=ConditionMedicationLog.STATUS_PENDING,
            scheduled_for__lt=now,
        )

    @staticmethod
    def logs_for_medication_ids(*, medication_ids: list[int], start_date: date, end_date: date):
        if not medication_ids:
            return ConditionMedicationLog.objects.none()
        return ConditionMedicationLog.objects.filter(
            medication_id__in=medication_ids,
            scheduled_date__gte=start_date,
            scheduled_date__lte=end_date,
        )

    @staticmethod
    def medication_ids_for_user(*, user):
        return list(ConditionMedication.objects.filter(user=user).values_list("id", flat=True))

    @staticmethod
    def medication_ids_for_condition(*, user_condition):
        return list(
            ConditionMedication.objects.filter(user_condition=user_condition).values_list("id", flat=True)
        )

    @staticmethod
    def logs_for_user_on_date(*, user, target_date: date):
        return ConditionMedicationLog.objects.filter(
            medication__user=user,
            scheduled_date=target_date,
        )

    @staticmethod
    def next_due_for_user(*, user):
        return (
            ConditionMedicationLog.objects.filter(
                medication__user=user,
                medication__is_active=True,
            )
            .filter(
                Q(status=ConditionMedicationLog.STATUS_PENDING)
                | Q(status=ConditionMedicationLog.STATUS_SNOOZED)
                | Q(status=ConditionMedicationLog.STATUS_OVERDUE)
            )
            .order_by("scheduled_for", "id")
            .first()
        )

    @staticmethod
    def reminder_sync_medications(*, user):
        return (
            ConditionMedication.objects.filter(user=user, is_active=True, reminder_enabled=True)
            .select_related("user_condition", "user_condition__condition_type")
            .prefetch_related("schedules")
            .order_by("display_name", "name", "id")
        )

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
