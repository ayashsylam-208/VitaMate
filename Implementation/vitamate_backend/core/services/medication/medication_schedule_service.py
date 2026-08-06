from __future__ import annotations

from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from core.models import ConditionMedication, ConditionMedicationLog, ConditionMedicationSchedule
from core.repositories.medication_repository import MedicationRepository


class MedicationScheduleService:
    DEFAULT_GENERATION_HOURS = 72
    LEGACY_TIMEZONE_FALLBACKS = {
        "+03": "Asia/Damascus",
        "+03:00": "Asia/Damascus",
        "UTC+3": "Asia/Damascus",
        "UTC+03:00": "Asia/Damascus",
        "GMT+3": "Asia/Damascus",
        "GMT+03:00": "Asia/Damascus",
        "EEST": "Asia/Damascus",
        "Syria Standard Time": "Asia/Damascus",
    }

    @staticmethod
    def _as_time(value) -> time:
        if isinstance(value, time):
            return value
        if isinstance(value, str):
            try:
                return time.fromisoformat(value)
            except ValueError as exc:
                raise ValidationError({"time": "Use HH:MM format."}) from exc
        raise ValidationError({"time": "This field is required."})

    @staticmethod
    def _days(value) -> list[int]:
        if value in (None, ""):
            return []
        if not isinstance(value, list):
            raise ValidationError({"days_of_week": "Expected a list of weekday indexes."})
        days = []
        for item in value:
            try:
                day = int(item)
            except (TypeError, ValueError) as exc:
                raise ValidationError({"days_of_week": "Weekdays must be integers 0-6."}) from exc
            if day < 0 or day > 6:
                raise ValidationError({"days_of_week": "Weekdays must be integers 0-6."})
            days.append(day)
        return sorted(set(days))

    @classmethod
    def validate_schedules(
        cls,
        *,
        medication: ConditionMedication | None,
        is_prn: bool,
        schedules_payload: list[dict],
    ) -> list[dict]:
        normalized = []
        seen = set()
        for raw in schedules_payload or []:
            item = dict(raw)
            schedule_type = item.get("schedule_type") or ConditionMedicationSchedule.TYPE_DAILY
            if schedule_type not in {choice[0] for choice in ConditionMedicationSchedule.SCHEDULE_TYPE_CHOICES}:
                raise ValidationError({"schedule_type": "Unsupported schedule type."})

            days = cls._days(item.get("days_of_week", item.get("recurrence_days", [])))
            if schedule_type == ConditionMedicationSchedule.TYPE_SPECIFIC_DAYS and not days:
                raise ValidationError({"days_of_week": "Select at least one day for specific-days schedules."})

            interval_hours = item.get("interval_hours")
            if interval_hours in ("", None):
                interval_hours = None
            elif int(interval_hours) <= 0:
                raise ValidationError({"interval_hours": "Interval hours must be greater than zero."})
            else:
                interval_hours = int(interval_hours)

            if schedule_type == ConditionMedicationSchedule.TYPE_INTERVAL and interval_hours is None:
                raise ValidationError({"interval_hours": "Interval schedules require interval_hours."})

            time_of_day = None
            if schedule_type != ConditionMedicationSchedule.TYPE_AS_NEEDED:
                time_of_day = cls._as_time(item.get("time") or item.get("time_of_day"))
            else:
                time_of_day = cls._as_time(item.get("time") or item.get("time_of_day") or "00:00")

            meal_relation = item.get("meal_relation") or ConditionMedicationSchedule.MEAL_NONE
            if meal_relation == "with_meal":
                meal_relation = ConditionMedicationSchedule.MEAL_WITH_FOOD
            if meal_relation not in {choice[0] for choice in ConditionMedicationSchedule.MEAL_RELATION_CHOICES}:
                raise ValidationError({"meal_relation": "Unsupported meal relation."})

            grace_period_minutes = int(item.get("grace_period_minutes") or 60)
            snooze_default_minutes = int(item.get("snooze_default_minutes") or 15)
            if grace_period_minutes < 0:
                raise ValidationError({"grace_period_minutes": "Grace period cannot be negative."})
            if snooze_default_minutes <= 0:
                raise ValidationError({"snooze_default_minutes": "Snooze default must be positive."})

            is_active = bool(item.get("is_active", True))
            signature = (schedule_type, time_of_day, tuple(days), interval_hours, is_active)
            if signature in seen:
                raise ValidationError({"schedules": "Duplicate medication schedule."})
            seen.add(signature)

            normalized.append(
                {
                    "schedule_type": schedule_type,
                    "time_of_day": time_of_day,
                    "days_of_week": days,
                    "recurrence_days": days,
                    "interval_hours": interval_hours,
                    "meal_relation": meal_relation,
                    "grace_period_minutes": grace_period_minutes,
                    "snooze_default_minutes": snooze_default_minutes,
                    "is_active": is_active,
                }
            )

        has_active_fixed = any(
            item["is_active"] and item["schedule_type"] != ConditionMedicationSchedule.TYPE_AS_NEEDED
            for item in normalized
        )
        if not is_prn and not has_active_fixed:
            raise ValidationError({"schedules": "At least one active schedule is required unless medication is PRN."})
        return normalized

    @classmethod
    @transaction.atomic
    def replace_schedules(
        cls,
        *,
        medication: ConditionMedication,
        schedules_payload: list[dict],
    ) -> list[ConditionMedicationSchedule]:
        normalized = cls.validate_schedules(
            medication=medication,
            is_prn=medication.is_prn,
            schedules_payload=schedules_payload,
        )
        MedicationRepository.delete_future_non_final_logs(medication=medication)
        MedicationRepository.delete_all_schedules(medication=medication)
        schedules = [
            MedicationRepository.create_schedule(medication=medication, **item)
            for item in normalized
        ]
        cls.generate_pending_doses(
            medication=medication,
            from_dt=timezone.now(),
            to_dt=timezone.now() + timedelta(hours=cls.DEFAULT_GENERATION_HOURS),
        )
        return schedules

    @classmethod
    def _local_dt(
        cls,
        *,
        medication: ConditionMedication,
        target_date: date,
        time_of_day: time,
    ) -> datetime:
        tzinfo = cls._timezone_for_medication(medication)
        local = datetime.combine(target_date, time_of_day).replace(tzinfo=tzinfo)
        return local.astimezone(timezone.get_current_timezone())

    @classmethod
    def _timezone_for_medication(cls, medication: ConditionMedication):
        timezone_name = str(medication.timezone or "UTC").strip() or "UTC"
        try:
            return ZoneInfo(timezone_name)
        except ZoneInfoNotFoundError:
            fallback = cls.LEGACY_TIMEZONE_FALLBACKS.get(timezone_name, "UTC")
            if fallback != timezone_name:
                medication.timezone = fallback
                MedicationRepository.save_medication(
                    medication,
                    update_fields=["timezone", "updated_at"],
                )
            return ZoneInfo(fallback)

    @staticmethod
    def _schedule_active_on_date(
        *,
        medication: ConditionMedication,
        schedule: ConditionMedicationSchedule,
        target_date: date,
    ) -> bool:
        if not medication.is_active or not schedule.is_active:
            return False
        if medication.is_prn or schedule.schedule_type == ConditionMedicationSchedule.TYPE_AS_NEEDED:
            return False
        if medication.start_date and target_date < medication.start_date:
            return False
        if medication.end_date and target_date > medication.end_date:
            return False
        days = schedule.days_of_week or schedule.recurrence_days or []
        if schedule.schedule_type == ConditionMedicationSchedule.TYPE_SPECIFIC_DAYS:
            return target_date.weekday() in days
        if days:
            return target_date.weekday() in days
        return True

    @classmethod
    @transaction.atomic
    def generate_pending_doses(
        cls,
        *,
        medication: ConditionMedication,
        from_dt: datetime,
        to_dt: datetime,
    ) -> list[ConditionMedicationLog]:
        if timezone.is_naive(from_dt):
            from_dt = timezone.make_aware(from_dt, timezone.get_current_timezone())
        if timezone.is_naive(to_dt):
            to_dt = timezone.make_aware(to_dt, timezone.get_current_timezone())

        generated = []
        start_date = from_dt.date()
        end_date = to_dt.date()
        day_count = (end_date - start_date).days
        schedules = MedicationRepository.list_active_schedules(medication=medication)
        for offset in range(day_count + 1):
            target_date = start_date + timedelta(days=offset)
            for schedule in schedules:
                if not cls._schedule_active_on_date(
                    medication=medication,
                    schedule=schedule,
                    target_date=target_date,
                ):
                    continue
                scheduled_times = [cls._local_dt(
                    medication=medication,
                    target_date=target_date,
                    time_of_day=schedule.time_of_day,
                )]
                if schedule.schedule_type == ConditionMedicationSchedule.TYPE_INTERVAL and schedule.interval_hours:
                    cursor = scheduled_times[0] + timedelta(hours=schedule.interval_hours)
                    day_end = cls._local_dt(
                        medication=medication,
                        target_date=target_date,
                        time_of_day=time(23, 59),
                    )
                    while cursor <= day_end:
                        scheduled_times.append(cursor)
                        cursor += timedelta(hours=schedule.interval_hours)

                for scheduled_for in scheduled_times:
                    if scheduled_for < from_dt or scheduled_for > to_dt:
                        continue
                    log, created = MedicationRepository.get_or_create_dose_log(
                        medication=medication,
                        scheduled_for=scheduled_for,
                        defaults={
                            "schedule": schedule,
                            "scheduled_date": scheduled_for.date(),
                            "status": ConditionMedicationLog.STATUS_PENDING,
                            "action_source": ConditionMedicationLog.ACTION_SYSTEM,
                        },
                    )
                    if created:
                        generated.append(log)
        return generated

    @classmethod
    def rebuild_pending_doses(cls, *, medication: ConditionMedication) -> list[ConditionMedicationLog]:
        return cls.generate_pending_doses(
            medication=medication,
            from_dt=timezone.now(),
            to_dt=timezone.now() + timedelta(hours=cls.DEFAULT_GENERATION_HOURS),
        )
