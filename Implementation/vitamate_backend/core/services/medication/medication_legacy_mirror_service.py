from __future__ import annotations

from datetime import time

from core.models import ConditionMedication, Medicine


class MedicationLegacyMirrorService:
    """Keeps legacy Medicine rows aligned with ConditionMedication plans.

    ConditionMedication remains the source of truth. Medicine is only a
    compatibility mirror for older API surfaces that still read /api/medicines/.
    """

    @classmethod
    def sync_from_condition_medication(cls, medication: ConditionMedication) -> Medicine:
        legacy = medication.medicine
        if legacy is not None and legacy.user_id != medication.user_id:
            legacy = None

        defaults = {
            "user": medication.user,
            "name": cls._display_name(medication),
            "dosage": cls._dosage(medication),
            "time_to_take": cls._first_schedule_time(medication),
            "is_active": medication.is_active,
        }

        if legacy is None:
            legacy = Medicine.objects.create(**defaults)
            medication.medicine = legacy
            medication.save(update_fields=["medicine", "updated_at"])
            return legacy

        changed_fields = []
        if legacy.user_id != medication.user_id:
            legacy.user = medication.user
            changed_fields.append("user")
        for field in ["name", "dosage", "time_to_take", "is_active"]:
            value = defaults[field]
            if getattr(legacy, field) != value:
                setattr(legacy, field, value)
                changed_fields.append(field)
        if changed_fields:
            legacy.save(update_fields=changed_fields)
        return legacy

    @staticmethod
    def deactivate_mirror(medication: ConditionMedication) -> None:
        legacy = medication.medicine
        if legacy is not None and legacy.is_active:
            legacy.is_active = False
            legacy.save(update_fields=["is_active"])

    @staticmethod
    def _display_name(medication: ConditionMedication) -> str:
        return (medication.display_name or medication.name or "").strip() or "Medication"

    @staticmethod
    def _dosage(medication: ConditionMedication) -> str:
        return (medication.dosage or medication.dosage_amount or "").strip() or "As directed"

    @staticmethod
    def _first_schedule_time(medication: ConditionMedication) -> time:
        schedule = medication.schedules.filter(is_active=True).order_by("time_of_day", "id").first()
        if schedule is not None and schedule.time_of_day is not None:
            return schedule.time_of_day
        return time(0, 0)
