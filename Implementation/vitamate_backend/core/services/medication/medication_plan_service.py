from __future__ import annotations

from datetime import timedelta

from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from core.models import ConditionMedication, ConditionMedicationLog, UserCondition
from core.repositories.condition_repository import ConditionRepository
from core.repositories.medication_repository import MedicationRepository
from core.services.medication_legacy_mirror_service import MedicationLegacyMirrorService
from core.services.medication_schedule_service import MedicationScheduleService
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers


class MedicationPlanService:
    @staticmethod
    def _validate_dates(payload: dict) -> None:
        start_date = payload.get("start_date")
        end_date = payload.get("end_date")
        if start_date and end_date and start_date > end_date:
            raise ValidationError({"end_date": "End date must be after start date."})

    @staticmethod
    def _resolve_condition(*, user, source_type: str, user_condition_id):
        if source_type == ConditionMedication.SOURCE_CONDITION:
            if not user_condition_id:
                raise ValidationError({"user_condition_id": "Condition source requires user_condition_id."})
            condition = ConditionRepository.get_by_id_for_user(user=user, condition_id=user_condition_id)
            if condition is None:
                raise ValidationError({"user_condition_id": "Condition not found for this user."})
            return condition
        if user_condition_id:
            raise ValidationError({"user_condition_id": "Manual medications cannot be linked to a condition."})
        return None

    @staticmethod
    def _dosage_label(payload: dict) -> str:
        dosage = str(payload.get("dosage") or "").strip()
        if dosage:
            return dosage
        amount = payload.get("dose_amount") or payload.get("dosage_amount") or ""
        unit = payload.get("dose_unit") or payload.get("dosage_unit") or ""
        return f"{amount} {unit}".strip()

    @classmethod
    def _attrs(cls, *, user, payload: dict, existing: ConditionMedication | None = None) -> dict:
        source_type = payload.get("source_type") or getattr(existing, "source_type", ConditionMedication.SOURCE_MANUAL)
        if source_type not in {ConditionMedication.SOURCE_MANUAL, ConditionMedication.SOURCE_CONDITION}:
            raise ValidationError({"source_type": "source_type must be manual or condition."})
        condition_id = payload.get("user_condition_id", payload.get("user_condition", None))
        if condition_id is None and existing is not None:
            condition_id = existing.user_condition_id
        condition = cls._resolve_condition(
            user=user,
            source_type=source_type,
            user_condition_id=condition_id,
        )
        display_name = str(payload.get("display_name") or payload.get("name") or "").strip()
        if not display_name and existing is None:
            raise ValidationError({"display_name": "This field is required."})
        cls._validate_dates(payload)
        dosage = cls._dosage_label(payload)
        return {
            "user": user,
            "user_condition": condition,
            "source_type": source_type,
            "medicine_id": payload.get(
                "medicine_id",
                payload.get("medicine", getattr(existing, "medicine_id", None)),
            ),
            "display_name": display_name or existing.display_name,
            "name": display_name or existing.name,
            "scientific_name": payload.get("scientific_name", getattr(existing, "scientific_name", "")),
            "dosage": dosage or getattr(existing, "dosage", ""),
            "dosage_amount": str(payload.get("dose_amount", payload.get("dosage_amount", getattr(existing, "dosage_amount", ""))) or ""),
            "dosage_unit": str(payload.get("dose_unit", payload.get("dosage_unit", getattr(existing, "dosage_unit", ""))) or ""),
            "form": payload.get("form", getattr(existing, "form", "")),
            "instructions": payload.get("instructions", getattr(existing, "instructions", "")),
            "relation_to_meal": payload.get("relation_to_meal", getattr(existing, "relation_to_meal", ConditionMedication.RELATION_ANYTIME)),
            "recurrence_pattern": payload.get("recurrence_pattern", getattr(existing, "recurrence_pattern", [])),
            "start_date": payload.get("start_date", getattr(existing, "start_date", timezone.localdate())),
            "end_date": payload.get("end_date", getattr(existing, "end_date", None)),
            "is_active": payload.get("is_active", getattr(existing, "is_active", True)),
            "is_prn": payload.get("is_prn", getattr(existing, "is_prn", False)),
            "timezone": payload.get("timezone", getattr(existing, "timezone", "UTC")),
            "adherence_mode": payload.get("adherence_mode", getattr(existing, "adherence_mode", ConditionMedication.ADHERENCE_STRICT)),
            "reminder_enabled": payload.get("reminder_enabled", getattr(existing, "reminder_enabled", True)),
            "reminder_lead_minutes": payload.get("reminder_lead_minutes", getattr(existing, "reminder_lead_minutes", 15)),
            "supplement_nutrient_id": payload.get(
                "supplement_nutrient_id",
                getattr(existing, "supplement_nutrient_id", None),
            ),
            "supplement_nutrient_amount": payload.get(
                "supplement_nutrient_amount",
                getattr(existing, "supplement_nutrient_amount", None),
            ),
            "supplement_nutrient_unit": payload.get(
                "supplement_nutrient_unit",
                getattr(existing, "supplement_nutrient_unit", ""),
            ),
        }

    @classmethod
    @transaction.atomic
    def create_medication_plan(cls, *, user, payload: dict, publish_event: bool = True) -> ConditionMedication:
        schedules_payload = payload.pop("schedules", [])
        attrs = cls._attrs(user=user, payload=payload)
        medication = MedicationRepository.create_medication(**attrs)
        MedicationScheduleService.replace_schedules(
            medication=medication,
            schedules_payload=schedules_payload,
        )
        MedicationLegacyMirrorService.sync_from_condition_medication(medication)
        if publish_event:
            cls._publish_plan_event(
                medication=medication,
                trigger_reference=str(medication.id),
            )
        return medication

    @classmethod
    @transaction.atomic
    def update_medication_plan(
        cls,
        *,
        user,
        medication_id: int,
        payload: dict,
        publish_event: bool = True,
    ) -> ConditionMedication:
        medication = MedicationRepository.get_by_id_for_user(user=user, medication_id=medication_id)
        if medication is None:
            raise ValidationError({"detail": "Medication not found."})
        schedules_payload = payload.pop("schedules", None)
        attrs = cls._attrs(user=user, payload={**payload, "source_type": payload.get("source_type", medication.source_type)}, existing=medication)
        for key, value in attrs.items():
            setattr(medication, key, value)
        MedicationRepository.save_medication(medication)
        if schedules_payload is not None:
            MedicationScheduleService.replace_schedules(
                medication=medication,
                schedules_payload=schedules_payload,
            )
        else:
            MedicationScheduleService.generate_pending_doses(
                medication=medication,
                from_dt=timezone.now(),
                to_dt=timezone.now() + timedelta(hours=MedicationScheduleService.DEFAULT_GENERATION_HOURS),
            )
        MedicationLegacyMirrorService.sync_from_condition_medication(medication)
        if publish_event:
            cls._publish_plan_event(
                medication=medication,
                trigger_reference=str(medication.id),
            )
        return medication

    @classmethod
    @transaction.atomic
    def deactivate_medication_plan(
        cls,
        *,
        user,
        medication_id: int,
        publish_event: bool = True,
    ) -> ConditionMedication:
        medication = MedicationRepository.get_by_id_for_user(user=user, medication_id=medication_id)
        if medication is None:
            raise ValidationError({"detail": "Medication not found."})
        medication.is_active = False
        MedicationRepository.save_medication(medication, update_fields=["is_active", "updated_at"])
        MedicationRepository.deactivate_schedules(medication=medication)
        MedicationRepository.delete_future_non_final_logs(medication=medication)
        MedicationLegacyMirrorService.deactivate_mirror(medication)
        if publish_event:
            cls._publish_plan_event(
                medication=medication,
                trigger_reference=str(medication.id),
            )
        return medication

    @staticmethod
    def attach_to_condition(*, user, medication_id: int, user_condition_id: int) -> ConditionMedication:
        medication = MedicationRepository.get_by_id_for_user(user=user, medication_id=medication_id)
        condition = ConditionRepository.get_by_id_for_user(user=user, condition_id=user_condition_id)
        if medication is None or condition is None:
            raise ValidationError({"detail": "Medication or condition not found."})
        medication.user_condition = condition
        medication.source_type = ConditionMedication.SOURCE_CONDITION
        MedicationRepository.save_medication(
            medication,
            update_fields=["user_condition", "source_type", "updated_at"],
        )
        MedicationLegacyMirrorService.sync_from_condition_medication(medication)
        MedicationPlanService._publish_plan_event(
            medication=medication,
            trigger_reference=str(medication.id),
        )
        return medication

    @staticmethod
    def detach_from_condition(*, user, medication_id: int) -> ConditionMedication:
        medication = MedicationRepository.get_by_id_for_user(user=user, medication_id=medication_id)
        if medication is None:
            raise ValidationError({"detail": "Medication not found."})
        medication.user_condition = None
        medication.source_type = ConditionMedication.SOURCE_MANUAL
        MedicationRepository.save_medication(
            medication,
            update_fields=["user_condition", "source_type", "updated_at"],
        )
        MedicationLegacyMirrorService.sync_from_condition_medication(medication)
        MedicationPlanService._publish_plan_event(
            medication=medication,
            trigger_reference=str(medication.id),
        )
        return medication

    @staticmethod
    def _publish_plan_event(*, medication: ConditionMedication, trigger_reference: str) -> None:
        HealthStateEventPublisher.publish_on_commit(
            user=medication.user,
            trigger_type=HealthStateTriggers.MEDICATION_PLAN_CHANGED,
            payload={
                "trigger_reference": trigger_reference,
                "source_id": medication.id,
                "event_dates": [timezone.localdate()],
                "user_condition_id": medication.user_condition_id,
            },
        )
