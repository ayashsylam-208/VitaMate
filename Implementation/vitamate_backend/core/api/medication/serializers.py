from __future__ import annotations

from datetime import timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from django.utils import timezone
from rest_framework import serializers

from core.models import ConditionMedication, ConditionMedicationLog, ConditionMedicationSchedule
from core.services.medication_adherence_service import MedicationAdherenceService, MedicationAdherenceSummary


class MedicationSchedulePayloadSerializer(serializers.Serializer):
    id = serializers.IntegerField(read_only=True)
    schedule_type = serializers.ChoiceField(
        choices=ConditionMedicationSchedule.SCHEDULE_TYPE_CHOICES,
        default=ConditionMedicationSchedule.TYPE_DAILY,
    )
    time = serializers.TimeField(required=False)
    time_of_day = serializers.TimeField(required=False)
    days_of_week = serializers.ListField(
        child=serializers.IntegerField(min_value=0, max_value=6),
        required=False,
        default=list,
    )
    recurrence_days = serializers.ListField(
        child=serializers.IntegerField(min_value=0, max_value=6),
        required=False,
        default=list,
    )
    interval_hours = serializers.IntegerField(required=False, min_value=1, allow_null=True)
    meal_relation = serializers.ChoiceField(
        choices=ConditionMedicationSchedule.MEAL_RELATION_CHOICES,
        default=ConditionMedicationSchedule.MEAL_NONE,
    )
    grace_period_minutes = serializers.IntegerField(required=False, min_value=0, default=60)
    snooze_default_minutes = serializers.IntegerField(required=False, min_value=1, default=15)
    is_active = serializers.BooleanField(default=True)


class MedicationPlanWriteSerializer(serializers.Serializer):
    display_name = serializers.CharField(max_length=100, required=False, allow_blank=True)
    name = serializers.CharField(max_length=100, required=False, allow_blank=True)
    medicine_id = serializers.IntegerField(required=False, allow_null=True)
    source_type = serializers.ChoiceField(
        choices=ConditionMedication.SOURCE_TYPE_CHOICES,
        default=ConditionMedication.SOURCE_MANUAL,
    )
    user_condition_id = serializers.IntegerField(required=False, allow_null=True)
    dose_amount = serializers.DecimalField(max_digits=8, decimal_places=2, required=False, allow_null=True)
    dose_unit = serializers.CharField(max_length=40, required=False, allow_blank=True)
    dosage = serializers.CharField(max_length=80, required=False, allow_blank=True)
    form = serializers.CharField(max_length=40, required=False, allow_blank=True)
    instructions = serializers.CharField(max_length=200, required=False, allow_blank=True)
    start_date = serializers.DateField(required=False)
    end_date = serializers.DateField(required=False, allow_null=True)
    is_active = serializers.BooleanField(required=False, default=True)
    is_prn = serializers.BooleanField(required=False, default=False)
    timezone = serializers.CharField(max_length=64, required=False, default="UTC")
    adherence_mode = serializers.ChoiceField(
        choices=ConditionMedication.ADHERENCE_MODE_CHOICES,
        required=False,
        default=ConditionMedication.ADHERENCE_STRICT,
    )
    supplement_nutrient_id = serializers.IntegerField(required=False, allow_null=True)
    supplement_nutrient_amount = serializers.FloatField(required=False, allow_null=True)
    supplement_nutrient_unit = serializers.CharField(max_length=30, required=False, allow_blank=True)
    reminder_enabled = serializers.BooleanField(required=False, default=True)
    reminder_lead_minutes = serializers.IntegerField(required=False, min_value=0, default=15)
    schedules = MedicationSchedulePayloadSerializer(many=True, required=False, default=list)

    def validate(self, attrs):
        display_name = (attrs.get("display_name") or attrs.get("name") or "").strip()
        if not display_name and self.instance is None:
            raise serializers.ValidationError({"display_name": "This field is required."})
        if attrs.get("end_date") and attrs.get("start_date") and attrs["start_date"] > attrs["end_date"]:
            raise serializers.ValidationError({"end_date": "End date must be after start date."})
        if attrs.get("source_type") == ConditionMedication.SOURCE_CONDITION and not attrs.get("user_condition_id"):
            raise serializers.ValidationError({"user_condition_id": "Condition source requires user_condition_id."})
        timezone_name = str(attrs.get("timezone") or getattr(self.instance, "timezone", "") or "UTC").strip()
        try:
            ZoneInfo(timezone_name)
        except ZoneInfoNotFoundError as exc:
            raise serializers.ValidationError(
                {"timezone": "Use a valid IANA timezone, for example Asia/Damascus."}
            ) from exc
        return attrs


class DoseTakenActionSerializer(serializers.Serializer):
    taken_at = serializers.DateTimeField(required=False)
    dose_taken_amount = serializers.DecimalField(max_digits=8, decimal_places=2, required=False, allow_null=True)


class DoseSkippedActionSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=255, required=False, allow_blank=True)


class DoseSnoozeActionSerializer(serializers.Serializer):
    snoozed_until = serializers.DateTimeField()


class PrnDoseActionSerializer(serializers.Serializer):
    taken_at = serializers.DateTimeField(required=False)
    dose_taken_amount = serializers.DecimalField(max_digits=8, decimal_places=2, required=False, allow_null=True)
    notes = serializers.CharField(max_length=255, required=False, allow_blank=True)


class MedicationHistoryQuerySerializer(serializers.Serializer):
    status = serializers.ChoiceField(
        choices=["all", "taken", "missed", "skipped", "snoozed", "pending", "overdue"],
        required=False,
        default="all",
    )
    page = serializers.IntegerField(required=False, min_value=1, default=1)
    page_size = serializers.IntegerField(required=False, min_value=1, max_value=100, default=30)


class MedicationAdherenceSummarySerializer(serializers.Serializer):
    medication_id = serializers.IntegerField(allow_null=True)
    expected_doses = serializers.IntegerField()
    taken_doses = serializers.IntegerField()
    missed_doses = serializers.IntegerField()
    skipped_doses = serializers.IntegerField()
    pending_doses = serializers.IntegerField()
    overdue_doses = serializers.IntegerField()
    adherence_percent = serializers.FloatField()
    streak_days = serializers.IntegerField()
    on_time_percent = serializers.FloatField()


def serialize_adherence(summary: MedicationAdherenceSummary) -> dict:
    return {
        "medication_id": summary.medication_id,
        "expected_doses": summary.expected_doses,
        "taken_doses": summary.taken_doses,
        "missed_doses": summary.missed_doses,
        "skipped_doses": summary.skipped_doses,
        "pending_doses": summary.pending_doses,
        "overdue_doses": summary.overdue_doses,
        "adherence_percent": summary.adherence_percent,
        "streak_days": summary.streak_days,
        "on_time_percent": summary.on_time_percent,
    }


def canonical_dose_status(log: ConditionMedicationLog) -> str:
    if log.status in {
        ConditionMedicationLog.STATUS_TAKEN,
        ConditionMedicationLog.STATUS_TAKEN_ON_TIME,
        ConditionMedicationLog.STATUS_TAKEN_LATE,
    }:
        return "taken"
    return log.status


def serialize_schedule(schedule: ConditionMedicationSchedule) -> dict:
    return {
        "id": schedule.id,
        "schedule_type": schedule.schedule_type,
        "time": schedule.time_of_day.strftime("%H:%M"),
        "time_of_day": schedule.time_of_day.strftime("%H:%M"),
        "days_of_week": schedule.days_of_week or schedule.recurrence_days or [],
        "recurrence_days": schedule.recurrence_days or schedule.days_of_week or [],
        "interval_hours": schedule.interval_hours,
        "meal_relation": schedule.meal_relation,
        "grace_period_minutes": schedule.grace_period_minutes,
        "snooze_default_minutes": schedule.snooze_default_minutes,
        "is_active": schedule.is_active,
    }


def serialize_dose_log(log: ConditionMedicationLog) -> dict:
    medication = log.medication
    condition = medication.user_condition if medication else None
    return {
        "log_id": log.id,
        "medication_id": medication.id if medication else None,
        "display_name": medication.display_name or medication.name if medication else "",
        "linked_condition": (
            {
                "id": condition.id,
                "name": condition.condition_type.name,
            }
            if condition
            else None
        ),
        "linked_condition_name": condition.condition_type.name if condition else None,
        "scheduled_for": log.scheduled_for.isoformat() if log.scheduled_for else None,
        "status": canonical_dose_status(log),
        "raw_status": log.status,
        "snoozed_until": log.snoozed_until.isoformat() if log.snoozed_until else None,
        "taken_at": log.taken_at.isoformat() if log.taken_at else None,
        "dose_amount": medication.dosage_amount if medication else "",
        "dose_unit": medication.dosage_unit if medication else "",
        "form": medication.form if medication else "",
        "meal_relation": (
            log.schedule.meal_relation
            if getattr(log, "schedule", None)
            else ConditionMedicationSchedule.MEAL_NONE
        ),
        "notes": log.notes or log.skip_reason,
        "points_applied": log.points_applied,
        "scheduled_date": log.scheduled_date.isoformat() if log.scheduled_date else None,
        "is_prn": bool(medication.is_prn) if medication else False,
        "audit": {
            "action_source": log.action_source,
            "created_at": log.created_at.isoformat() if log.created_at else None,
            "updated_at": log.updated_at.isoformat() if log.updated_at else None,
        },
    }


def serialize_medication(medication: ConditionMedication, *, include_schedules: bool = True) -> dict:
    now = timezone.now()
    today = timezone.localdate()
    week_start = today - timedelta(days=6)
    next_due = (
        medication.dose_logs.filter(
            status__in=[
                ConditionMedicationLog.STATUS_PENDING,
                ConditionMedicationLog.STATUS_SNOOZED,
                ConditionMedicationLog.STATUS_OVERDUE,
            ],
            scheduled_for__gte=now,
        )
        .order_by("scheduled_for", "id")
        .first()
    )
    adherence = MedicationAdherenceService.get_medication_adherence(
        medication=medication,
        start_date=week_start,
        end_date=today,
    )
    condition = medication.user_condition
    return {
        "id": medication.id,
        "medicine_id": medication.medicine_id,
        "display_name": medication.display_name or medication.name,
        "name": medication.name,
        "source_type": medication.source_type,
        "linked_condition": (
            {
                "id": condition.id,
                "name": condition.condition_type.name,
            }
            if condition
            else None
        ),
        "linked_condition_id": condition.id if condition else None,
        "linked_condition_name": condition.condition_type.name if condition else None,
        "dose_amount": medication.dosage_amount,
        "dose_unit": medication.dosage_unit,
        "dosage": medication.dosage,
        "form": medication.form,
        "instructions": medication.instructions,
        "start_date": str(medication.start_date) if medication.start_date else None,
        "end_date": str(medication.end_date) if medication.end_date else None,
        "is_active": medication.is_active,
        "is_prn": medication.is_prn,
        "timezone": medication.timezone,
        "adherence_mode": medication.adherence_mode,
        "supplement_nutrient_id": medication.supplement_nutrient_id,
        "supplement_nutrient_code": medication.supplement_nutrient.code if medication.supplement_nutrient else "",
        "supplement_nutrient_amount": medication.supplement_nutrient_amount,
        "supplement_nutrient_unit": medication.supplement_nutrient_unit,
        "next_due": next_due.scheduled_for.isoformat() if next_due and next_due.scheduled_for else None,
        "adherence_summary_short": serialize_adherence(adherence),
        "schedules": [serialize_schedule(schedule) for schedule in medication.schedules.all()] if include_schedules else [],
    }
