from __future__ import annotations

from django.db import transaction
from django.utils import timezone

from core.models import ConditionDailyEvaluation, HealthTarget, UserCondition
from core.repositories.condition_repository import ConditionRepository
from core.services.chronic_condition_service import ChronicConditionService
from core.services.condition_alert_service import ConditionAlertService
from core.services.condition_evaluators import evaluator_for_condition
from core.services.condition_indicator_service import ConditionIndicatorService
from core.services.condition_integration_coordinator import ConditionIntegrationCoordinator
from core.services.condition_points_evaluator import ConditionPointsEvaluator
from core.services.condition_recommendation_service import ConditionRecommendationService
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers


class ConditionMeasurementWorkflowService:
    def __init__(self, *, integration_coordinator: ConditionIntegrationCoordinator | None = None):
        self._integration = integration_coordinator or ConditionIntegrationCoordinator()

    @transaction.atomic
    def log_reading(self, *, user, user_condition: UserCondition, payload: dict) -> dict:
        self._validate_ownership(user=user, user_condition=user_condition)
        evaluator = evaluator_for_condition(user_condition)
        record_payload = ConditionIndicatorService.build_record_payload(
            user_condition=user_condition,
            payload=payload,
        )
        record = user_condition.indicator_records.create(**record_payload)
        record.classification = evaluator.classify_reading(user_condition, record)
        evaluation = evaluator.evaluate_risk(user_condition, latest_record=record)
        record.risk_level = evaluation.get("risk_level", "")
        record.save(update_fields=["classification", "risk_level"])

        effective_restrictions = evaluator.get_restrictions(user_condition, latest_record=record)
        recommendations = ConditionRecommendationService.normalize(
            evaluator.build_recommendations(user_condition, evaluation, latest_record=record)
        )
        alerts = ConditionAlertService.sync_alerts(
            user_condition=user_condition,
            alerts=self._alert_specs(
                evaluation=evaluation,
                effective_restrictions=effective_restrictions,
                record=record,
            ),
            on_date=timezone.localdate(record.recorded_at),
        )
        self._reset_dynamic_targets(user_condition=user_condition, evaluator=evaluator)
        adjusted_targets = self._apply_tracker_impacts(
            user_condition=user_condition,
            tracker_impacts=evaluation.get("tracker_impacts") or [],
        )

        daily_evaluation, _ = ConditionRepository.get_or_create_daily_evaluation(
            user_condition=user_condition,
            evaluation_date=timezone.localdate(record.recorded_at),
        )
        daily_evaluation.status = self._evaluation_status(evaluation)
        daily_evaluation.risk_flags = list(evaluation.get("risk_flags") or [])
        daily_evaluation.recommendations_payload = recommendations
        daily_evaluation.tracker_impacts_payload = list(evaluation.get("tracker_impacts") or [])
        daily_evaluation.latest_recorded_at = record.recorded_at
        daily_evaluation.save(
            update_fields=[
                "status",
                "risk_flags",
                "recommendations_payload",
                "tracker_impacts_payload",
                "latest_recorded_at",
                "updated_at",
            ]
        )

        points_delta = ConditionPointsEvaluator.apply_reading_points(
            user_condition=user_condition,
            record=record,
            evaluation=evaluation,
        )
        HealthStateEventPublisher.publish_on_commit(
            user=user_condition.user,
            trigger_type=HealthStateTriggers.CONDITION_READING_LOGGED,
            payload={
                "trigger_reference": str(record.id),
                "source_id": record.id,
                "event_dates": [timezone.localdate(record.recorded_at)],
                "user_condition_id": user_condition.id,
            },
        )

        return {
            "reading": {
                "id": record.id,
                "indicator_type": record.indicator_type,
                "classification": record.classification,
                "risk_level": record.risk_level,
            },
            "evaluation": {
                "status": daily_evaluation.status,
                "risk_flags": daily_evaluation.risk_flags,
            },
            "effective_restrictions": [
                {
                    "code": item.get("code"),
                    "severity": item.get("severity"),
                }
                for item in effective_restrictions
            ],
            "adjusted_targets": adjusted_targets,
            "alerts": [
                {
                    "code": alert.code,
                    "level": alert.level,
                }
                for alert in alerts
            ],
            "recommendations": recommendations,
            "points_delta": points_delta,
        }

    @transaction.atomic
    def log_legacy_indicator(self, *, user, user_condition: UserCondition, payload: dict):
        self._validate_ownership(user=user, user_condition=user_condition)
        record_payload = ConditionIndicatorService.build_legacy_record_payload(
            user_condition=user_condition,
            payload=payload,
        )
        record = user_condition.indicator_records.create(**record_payload)
        HealthStateEventPublisher.publish_on_commit(
            user=user_condition.user,
            trigger_type=HealthStateTriggers.CONDITION_READING_LOGGED,
            payload={
                "trigger_reference": str(record.id),
                "source_id": record.id,
                "event_dates": [timezone.localdate(record.recorded_at)],
                "user_condition_id": user_condition.id,
            },
        )
        return record

    @staticmethod
    def _validate_ownership(*, user, user_condition: UserCondition) -> None:
        if user_condition.user_id != user.id:
            raise PermissionError("You can only log readings for your own conditions.")

    @staticmethod
    def _evaluation_status(evaluation: dict) -> str:
        status = str(evaluation.get("status") or ConditionDailyEvaluation.STATUS_STABLE)
        valid = {choice[0] for choice in ConditionDailyEvaluation.STATUS_CHOICES}
        return status if status in valid else ConditionDailyEvaluation.STATUS_STABLE

    @staticmethod
    def _alert_specs(*, evaluation: dict, effective_restrictions: list[dict], record) -> list[dict]:
        alerts = []
        for flag in evaluation.get("risk_flags") or []:
            alerts.append(
                {
                    "code": flag,
                    "level": evaluation.get("risk_level", ""),
                    "message": f"Risk flag detected: {flag.replace('_', ' ')}",
                    "alert_type": "monitoring",
                    "metadata": {
                        "record_id": record.id,
                        "indicator_type": record.indicator_type,
                    },
                }
            )
        for item in effective_restrictions:
            alerts.append(
                {
                    "code": item.get("code"),
                    "level": item.get("severity", ""),
                    "message": item.get("message") or item.get("code", "").replace("_", " ").title(),
                    "alert_type": "restriction",
                    "metadata": {
                        "record_id": record.id,
                        "indicator_type": record.indicator_type,
                    },
                }
            )
        return alerts

    @staticmethod
    def _apply_tracker_impacts(*, user_condition: UserCondition, tracker_impacts: list[dict]) -> list[dict]:
        adjusted_targets = []
        dynamic_keys = {
            item.get("key")
            for item in tracker_impacts
            if item.get("metric_key") and item.get("evaluation_mode")
        }
        if dynamic_keys:
            ConditionRepository.delete_dynamic_targets_by_keys(
                user_condition=user_condition,
                target_keys=dynamic_keys,
            )

        for item in tracker_impacts:
            if not item.get("metric_key") or not item.get("evaluation_mode"):
                continue
            value = item.get("value")
            target = ConditionRepository.create_dynamic_target(
                user_condition=user_condition,
                source_restriction=None,
                target_key=item["key"],
                target_name=item.get("label") or item["key"].replace("_", " ").title(),
                category=item.get("category") or item.get("tracker") or "monitoring",
                metric_key=item["metric_key"],
                evaluation_mode=item["evaluation_mode"],
                unit=item.get("unit") or "",
                min_value=value if item["key"].endswith("_min") else None,
                max_value=value if not item["key"].endswith("_min") else None,
                priority=2,
                is_scored=True,
                guidance=item.get("guidance") or "",
                evidence_source="VitaMate rules-based chronic adjustment",
                is_inference=True,
            )
            adjusted_targets.append(
                {
                    "tracker": item.get("tracker"),
                    "key": target.target_key,
                    "value": value,
                }
            )
        return adjusted_targets

    @staticmethod
    def _reset_dynamic_targets(*, user_condition: UserCondition, evaluator) -> None:
        baseline_targets = evaluator.get_target_ranges(user_condition)
        baseline_keys = {item["target_key"] for item in baseline_targets}
        ConditionRepository.delete_dynamic_targets_except(
            user_condition=user_condition,
            target_keys=baseline_keys,
        )

        for item in baseline_targets:
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
