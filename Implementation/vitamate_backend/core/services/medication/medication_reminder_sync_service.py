from __future__ import annotations

from core.models import ConditionMedication, ConditionMedicationSchedule
from core.repositories.medication_repository import MedicationRepository


class MedicationReminderSyncService:
    @staticmethod
    def build_reminder_sync_payload(*, user) -> dict:
        items = []
        medications = MedicationRepository.reminder_sync_medications(user=user)
        for medication in medications:
            for schedule in medication.schedules.filter(is_active=True):
                if medication.is_prn or schedule.schedule_type == ConditionMedicationSchedule.TYPE_AS_NEEDED:
                    continue
                items.append(
                    {
                        "medication_id": medication.id,
                        "schedule_id": schedule.id,
                        "display_name": medication.display_name or medication.name,
                        "start_date": str(medication.start_date) if medication.start_date else None,
                        "end_date": str(medication.end_date) if medication.end_date else None,
                        "timezone": medication.timezone,
                        "scheduled_times": [schedule.time_of_day.strftime("%H:%M")],
                        "days_of_week": schedule.days_of_week or schedule.recurrence_days or [],
                        "meal_relation": schedule.meal_relation,
                        "snooze_default_minutes": schedule.snooze_default_minutes,
                        "reminder_lead_minutes": medication.reminder_lead_minutes,
                        "linked_condition": (
                            {
                                "id": medication.user_condition_id,
                                "name": medication.user_condition.condition_type.name,
                            }
                            if medication.user_condition_id
                            else None
                        ),
                    }
                )
        return {"items": items}
