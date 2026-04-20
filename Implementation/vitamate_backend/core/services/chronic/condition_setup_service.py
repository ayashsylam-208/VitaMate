from __future__ import annotations

from django.db import transaction
from django.utils import timezone

from core.models import (
    ConditionDailyEvaluation,
    ConditionMedication,
    HealthTarget,
    UserCondition,
)
from core.repositories.condition_repository import ConditionRepository
from core.services.condition_catalog_service import ConditionCatalogService
from core.services.condition_evaluators import evaluator_for_condition
from core.services.condition_integration_coordinator import ConditionIntegrationCoordinator
from core.services.chronic_condition_service import ChronicConditionService
from core.services.medication_legacy_mirror_service import MedicationLegacyMirrorService
from core.services.medication_plan_service import MedicationPlanService
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers


class ConditionSetupService:
    def __init__(self, *, integration_coordinator: ConditionIntegrationCoordinator | None = None):
        self._integration = integration_coordinator or ConditionIntegrationCoordinator()

    @transaction.atomic
    def create_condition(
        self,
        *,
        user,
        condition_type_id: int,
        diagnosis_date=None,
        condition_status: str | None = None,
        status: str | None = None,
        severity: str | None = None,
        severity_code: str | None = None,
        notes: str = "",
        is_active: bool = True,
        profile_data: dict | None = None,
        target_overrides: list[dict] | None = None,
        medications_data: list[dict] | None = None,
    ) -> UserCondition:
        condition_type = ConditionCatalogService.resolve_supported_condition_type(
            condition_type_id=condition_type_id
        )
        self._validate_supported(condition_type=condition_type)
        normalized_status = self._validate_status(condition_status or status)
        normalized_severity = self._validate_severity(
            condition_type=condition_type,
            severity=severity or severity_code,
        )
        duplicate = ConditionRepository.find_active_duplicate(
            user=user,
            condition_type=condition_type,
        )
        if is_active and duplicate is not None:
            raise ValueError("This condition is already active for the current user.")

        normalized_profile = ConditionCatalogService.normalize_profile_data(
            condition_type=condition_type,
            profile_data=profile_data,
        )
        ConditionCatalogService.validate_profile_data(
            condition_type=condition_type,
            profile_data=normalized_profile,
        )

        user_condition = ConditionRepository.create_condition(
            user=user,
            condition_type=condition_type,
            diagnosis_date=diagnosis_date,
            status=normalized_status,
            severity_code=normalized_severity,
            notes=notes,
            is_active=is_active,
            profile_data=normalized_profile,
        )
        self._replace_medications(user_condition=user_condition, medications_data=medications_data or [])
        self._rebuild_condition_state(user_condition=user_condition, target_overrides=target_overrides or [])
        return user_condition

    @transaction.atomic
    def update_condition(
        self,
        *,
        user_condition: UserCondition,
        diagnosis_date=None,
        condition_status: str | None = None,
        status: str | None = None,
        severity: str | None = None,
        severity_code: str | None = None,
        notes: str | None = None,
        is_active: bool | None = None,
        profile_data: dict | None = None,
        target_overrides: list[dict] | None = None,
        medications_data: list[dict] | None = None,
    ) -> UserCondition:
        self._validate_supported(condition_type=user_condition.condition_type)
        if condition_status or status:
            user_condition.status = self._validate_status(condition_status or status)
        if severity or severity_code:
            user_condition.severity_code = self._validate_severity(
                condition_type=user_condition.condition_type,
                severity=severity or severity_code,
            )
        if diagnosis_date is not None:
            user_condition.diagnosis_date = diagnosis_date
        if notes is not None:
            user_condition.notes = notes
        if is_active is not None:
            user_condition.is_active = is_active
        if profile_data is not None:
            normalized_profile = ConditionCatalogService.normalize_profile_data(
                condition_type=user_condition.condition_type,
                profile_data=profile_data,
            )
            ConditionCatalogService.validate_profile_data(
                condition_type=user_condition.condition_type,
                profile_data=normalized_profile,
            )
            user_condition.profile_data = normalized_profile
        ConditionRepository.save_condition(user_condition)

        if medications_data is not None:
            self._replace_medications(user_condition=user_condition, medications_data=medications_data)
        self._rebuild_condition_state(user_condition=user_condition, target_overrides=target_overrides)
        return user_condition

    def _rebuild_condition_state(self, *, user_condition: UserCondition, target_overrides: list[dict] | None) -> None:
        ChronicConditionService.rebuild_targets_for_condition(user_condition)
        self._sync_condition_targets(user_condition=user_condition)
        if target_overrides is not None:
            ChronicConditionService.apply_target_overrides(
                user_condition=user_condition,
                overrides=target_overrides,
            )
        ConditionRepository.get_or_create_daily_evaluation(
            user_condition=user_condition,
            evaluation_date=timezone.localdate(),
            defaults={
                "status": ConditionDailyEvaluation.STATUS_STABLE,
                "medication_adherence_percent": 0,
                "restriction_adherence_percent": 0,
                "points_delta": 0,
            },
        )
        HealthStateEventPublisher.publish_on_commit(
            user=user_condition.user,
            trigger_type=HealthStateTriggers.USER_CONDITION_UPDATED,
            payload={
                "trigger_reference": str(user_condition.id),
                "source_id": user_condition.id,
                "event_dates": [timezone.localdate()],
                "user_condition_id": user_condition.id,
            },
        )

    def _sync_condition_targets(self, *, user_condition: UserCondition) -> None:
        evaluator = evaluator_for_condition(user_condition)
        new_targets = evaluator.get_target_ranges(user_condition)
        target_keys = {item["target_key"] for item in new_targets}
        ConditionRepository.delete_dynamic_targets_except(
            user_condition=user_condition,
            target_keys=target_keys,
        )

        for item in new_targets:
            ConditionRepository.upsert_dynamic_target(
                user_condition=user_condition,
                target_key=item["target_key"],
                defaults={
                    "target_name": item["target_name"],
                    "category": item["category"],
                    "metric_key": item["metric_key"],
                    "evaluation_mode": item["evaluation_mode"],
                    "unit": item["unit"],
                    "min_value": item.get("min_value"),
                    "max_value": item.get("max_value"),
                    "priority": item.get("priority", 2),
                    "is_scored": item.get("is_scored", False),
                    "guidance": item.get("guidance", ""),
                    "evidence_source": item.get("evidence_source", "VitaMate rules-based chronic profile"),
                    "is_inference": True,
                },
            )

    @staticmethod
    def _replace_medications(*, user_condition: UserCondition, medications_data: list[dict]) -> None:
        for medication in user_condition.medications.all():
            MedicationLegacyMirrorService.deactivate_mirror(medication)
        user_condition.medications.all().delete()
        for medication_data in medications_data:
            payload = dict(medication_data)
            payload["schedules"] = list(payload.pop("schedules", []))
            payload["source_type"] = ConditionMedication.SOURCE_CONDITION
            payload["user_condition_id"] = user_condition.id
            MedicationPlanService.create_medication_plan(
                user=user_condition.user,
                payload=payload,
                publish_event=False,
            )

    @staticmethod
    def _validate_supported(*, condition_type) -> None:
        if not ConditionCatalogService.is_supported(condition_type):
            raise ValueError("This chronic condition is not supported in v1.")

    @staticmethod
    def _validate_status(status: str | None) -> str:
        normalized = str(status or "").strip() or UserCondition.STATUS_ACTIVE
        valid = {choice[0] for choice in UserCondition.STATUS_CHOICES}
        if normalized not in valid:
            raise ValueError("condition_status must be a supported status value.")
        return normalized

    @staticmethod
    def _validate_severity(*, condition_type, severity: str | None) -> str:
        normalized = str(severity or "").strip()
        if not normalized:
            raise ValueError("severity is required.")
        valid_codes = {option.get("code") for option in condition_type.severity_options}
        if valid_codes and normalized not in valid_codes:
            raise ValueError("severity must match one of the supported severity options.")
        return normalized
