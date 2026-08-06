from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from core.models import (
    ActivityLog,
    ConditionAlert,
    ConditionDailyEvaluation,
    ConditionMedication,
    ConditionMedicationLog,
    ConditionMedicationSchedule,
    HealthRestriction,
    HealthTarget,
    MealLog,
    UserCondition,
    WaterLog,
)
from core.repositories.hydration.water_log_repository import HydrationRepository
from core.services.condition_catalog_service import ConditionCatalogService
from core.services.constraints import ConstraintReadService
from core.services.condition_indicator_service import ConditionIndicatorService
from core.services.condition_medication_service import ConditionMedicationService
from core.services.condition_points_evaluator import ConditionPointsEvaluator
from core.services.nutrition_service import NutritionService
from core.services.chronic.lipid_panel_values import LipidPanelValues


@dataclass(frozen=True)
class NutritionTotals:
    calories: float = 0
    protein_g: float = 0
    carbs_g: float = 0
    fat_g: float = 0
    fiber_g: float = 0
    sugar_g: float = 0
    added_sugars_g: float = 0
    sodium_mg: float = 0
    saturated_fat_g: float = 0
    trans_fat_g: float = 0
    potassium_mg: float = 0
    cholesterol_mg: float = 0
    vitamin_c_mg: float = 0
    caffeine_mg: float = 0


class ChronicConditionService:
    DISCLAIMER = (
        "VitaMate supports day-to-day chronic-condition self-management and does not replace medical care."
    )

    @staticmethod
    def _system_local_now() -> datetime:
        return timezone.localtime()

    @staticmethod
    def _priority_for_source_type(source_type: str) -> int:
        return {
            HealthTarget.SOURCE_PHYSICIAN_OVERRIDE: 1,
            HealthTarget.SOURCE_DYNAMIC_CONDITION: 2,
            HealthTarget.SOURCE_USER_CUSTOM: 2,
            HealthTarget.SOURCE_COMPUTED_RULE: 3,
        }.get(source_type, 3)

    @staticmethod
    def _prefetched_items(instance, relation_name: str):
        prefetched = getattr(instance, "_prefetched_objects_cache", None) or {}
        return prefetched.get(relation_name)

    @classmethod
    def _ordered_targets_for_condition(cls, *, user_condition: UserCondition):
        prefetched = cls._prefetched_items(user_condition, "targets")
        if prefetched is not None:
            return sorted(prefetched, key=lambda item: (item.priority, -item.id))
        return list(user_condition.targets.order_by("priority", "-id"))

    @staticmethod
    def _serialize_target_payload(target: HealthTarget) -> dict:
        return {
            "id": target.id,
            "target_key": target.target_key,
            "target_name": target.target_name,
            "category": target.category,
            "metric_key": target.metric_key,
            "evaluation_mode": target.evaluation_mode,
            "status": target.status,
            "unit": target.unit,
            "min_value": target.min_value,
            "max_value": target.max_value,
            "current_value": target.last_evaluated_value,
            "last_evaluated_value": target.last_evaluated_value,
            "source_type": target.source_type,
            "priority": target.priority,
            "guidance": target.guidance,
            "evidence_source": target.evidence_source,
            "is_scored": target.is_scored,
            "is_inference": target.is_inference,
        }

    @classmethod
    def _latest_daily_evaluation(
        cls,
        *,
        user_condition: UserCondition,
        on_date: date,
    ) -> ConditionDailyEvaluation | None:
        prefetched = cls._prefetched_items(user_condition, "daily_evaluations")
        if prefetched is not None:
            for evaluation in prefetched:
                if evaluation.evaluation_date == on_date:
                    return evaluation
            return prefetched[0] if prefetched else None
        return user_condition.daily_evaluations.order_by("-evaluation_date", "-id").first()

    @classmethod
    def effective_targets_for_condition(cls, *, user_condition: UserCondition) -> list[HealthTarget]:
        selected: dict[str, HealthTarget] = {}
        for target in cls._ordered_targets_for_condition(user_condition=user_condition):
            existing = selected.get(target.target_key)
            if existing is None or target.priority < existing.priority:
                selected[target.target_key] = target
        return list(selected.values())

    @classmethod
    def apply_target_overrides(
        cls,
        *,
        user_condition: UserCondition,
        overrides: list[dict] | None,
    ) -> None:
        if overrides is None:
            return

        user_condition.targets.filter(
            source_type__in=(
                HealthTarget.SOURCE_PHYSICIAN_OVERRIDE,
                HealthTarget.SOURCE_USER_CUSTOM,
            )
        ).delete()

        computed_targets = {
            target.target_key: target
            for target in user_condition.targets.filter(
                source_type=HealthTarget.SOURCE_COMPUTED_RULE
            )
        }

        for override in overrides:
            target_key = override["target_key"]
            base_target = computed_targets.get(target_key)
            source_type = override.get(
                "source_type",
                HealthTarget.SOURCE_PHYSICIAN_OVERRIDE,
            )
            HealthTarget.objects.create(
                user_condition=user_condition,
                source_restriction=base_target.source_restriction if base_target else None,
                target_key=target_key,
                target_name=override.get("target_name")
                or (base_target.target_name if base_target else target_key.replace("_", " ").title()),
                category=override.get("category")
                or (base_target.category if base_target else HealthRestriction.CATEGORY_MONITORING),
                metric_key=override.get("metric_key")
                or (base_target.metric_key if base_target else target_key),
                evaluation_mode=override.get("evaluation_mode")
                or (base_target.evaluation_mode if base_target else "latest_indicator"),
                unit=override.get("unit") or (base_target.unit if base_target else ""),
                min_value=override.get("min_value"),
                max_value=override.get("max_value"),
                source_type=source_type,
                priority=cls._priority_for_source_type(source_type),
                is_scored=override.get(
                    "is_scored",
                    base_target.is_scored if base_target else False,
                ),
                guidance=override.get("guidance")
                or (base_target.guidance if base_target else ""),
                evidence_source=override.get("evidence_source")
                or (base_target.evidence_source if base_target else "Clinician or approved user override"),
                is_inference=override.get(
                    "is_inference",
                    base_target.is_inference if base_target else False,
                ),
            )

    @staticmethod
    @transaction.atomic
    def rebuild_targets_for_condition(user_condition: UserCondition) -> list[HealthTarget]:
        user_condition.targets.filter(
            source_type=HealthTarget.SOURCE_COMPUTED_RULE
        ).delete()

        restrictions = HealthRestriction.objects.filter(
            condition_type=user_condition.condition_type
        ).filter(severity_code__in=("", user_condition.severity_code))

        profile = getattr(user_condition.user, "userprofile", None)
        targets: list[HealthTarget] = []
        for restriction in restrictions:
            min_value = restriction.min_required_value
            max_value = restriction.max_allowed_value

            if restriction.metric_key == "water_liters" and profile is not None and min_value is None:
                min_value = float(profile.daily_water_target)

            target = HealthTarget.objects.create(
                user_condition=user_condition,
                source_restriction=restriction,
                target_key=restriction.restriction_key,
                target_name=restriction.title,
                category=restriction.category,
                metric_key=restriction.metric_key,
                evaluation_mode=restriction.evaluation_mode,
                unit=restriction.unit,
                min_value=min_value,
                max_value=max_value,
                source_type=HealthTarget.SOURCE_COMPUTED_RULE,
                priority=ChronicConditionService._priority_for_source_type(
                    HealthTarget.SOURCE_COMPUTED_RULE
                ),
                is_scored=restriction.is_scored,
                guidance=restriction.guidance,
                evidence_source=restriction.evidence_source,
                is_inference=restriction.is_inference,
            )
            targets.append(target)

        return targets

    @staticmethod
    def nutrition_totals_for_day(*, user, on_date: date) -> NutritionTotals:
        totals: dict[str, float] = {
            "calories": 0.0,
            "protein_g": 0.0,
            "carbs_g": 0.0,
            "fat_g": 0.0,
            "fiber_g": 0.0,
            "sugar_g": 0.0,
            "sodium_mg": 0.0,
            "saturated_fat_g": 0.0,
            "trans_fat_g": 0.0,
            "potassium_mg": 0.0,
            "cholesterol_mg": 0.0,
            "vitamin_c_mg": 0.0,
            "caffeine_mg": 0.0,
        }
        service_totals = NutritionService.nutrition_totals_for_day(user=user, on_date=on_date)
        totals["calories"] = service_totals["calories_kcal"]
        totals["protein_g"] = service_totals["protein_g"]
        totals["carbs_g"] = service_totals["carbs_g"]
        totals["fat_g"] = service_totals["fat_g"]
        totals["fiber_g"] = service_totals["fiber_g"]
        totals["sugar_g"] = service_totals["sugars_g"]
        totals["added_sugars_g"] = service_totals.get("added_sugars_g", 0.0)
        totals["sodium_mg"] = service_totals["sodium_mg"]
        totals["saturated_fat_g"] = service_totals["saturated_fat_g"]
        totals["trans_fat_g"] = service_totals["trans_fat_g"]
        totals["potassium_mg"] = service_totals["potassium_mg"]
        totals["cholesterol_mg"] = service_totals["cholesterol_mg"]
        totals["vitamin_c_mg"] = service_totals["vitamin_c_mg"]
        totals["caffeine_mg"] = service_totals["caffeine_mg"]
        return NutritionTotals(**totals)

    @staticmethod
    def metric_context(*, user, on_date: date) -> dict[str, float | None]:
        nutrition = ChronicConditionService.nutrition_totals_for_day(user=user, on_date=on_date)
        water_liters = HydrationRepository.total_hydration_for_user_on_date(user, on_date)
        week_start = on_date - timedelta(days=6)
        activity_minutes_7d = (
            ActivityLog.objects.filter(user=user, date__gte=week_start, date__lte=on_date).aggregate(
                Sum("duration_minutes")
            )["duration_minutes__sum"]
            or 0
        )
        calories = float(nutrition.calories)
        saturated_fat_pct_kcal = None
        if calories > 0:
            saturated_fat_pct_kcal = round(((nutrition.saturated_fat_g * 9) / calories) * 100, 2)
        fiber_per_1000_kcal = None
        if calories > 0:
            fiber_per_1000_kcal = round((nutrition.fiber_g / calories) * 1000, 2)

        return {
            "activity_minutes_7d": float(activity_minutes_7d),
            "water_liters": float(water_liters),
            "calories": calories,
            "protein_g": nutrition.protein_g,
            "carbs_g": nutrition.carbs_g,
            "fat_g": nutrition.fat_g,
            "fiber_g": nutrition.fiber_g,
            "sugar_g": nutrition.sugar_g,
            "added_sugars_g": nutrition.added_sugars_g,
            "sodium_mg": nutrition.sodium_mg,
            "saturated_fat_g": nutrition.saturated_fat_g,
            "saturated_fat_pct_kcal": saturated_fat_pct_kcal,
            "trans_fat_g": nutrition.trans_fat_g,
            "potassium_mg": nutrition.potassium_mg,
            "cholesterol_mg": nutrition.cholesterol_mg,
            "vitamin_c_mg": nutrition.vitamin_c_mg,
            "caffeine_mg": nutrition.caffeine_mg,
            "fiber_per_1000_kcal": fiber_per_1000_kcal,
        }

    @staticmethod
    def _latest_indicator_value(*, user_condition: UserCondition, indicator_name: str) -> float | None:
        return ConditionIndicatorService.latest_metric_value(
            user_condition=user_condition,
            metric_key=indicator_name,
        )

    @staticmethod
    def _evaluate_target_value(*, target: HealthTarget, context: dict[str, float | None]) -> float | None:
        if target.evaluation_mode in {"daily_total", "rolling_7d_total", "daily_ratio"}:
            raw = context.get(target.metric_key)
            return None if raw is None else float(raw)

        if target.evaluation_mode == "latest_indicator":
            return ChronicConditionService._latest_indicator_value(
                user_condition=target.user_condition,
                indicator_name=target.metric_key,
            )

        return None

    @staticmethod
    def _is_within_target(*, target: HealthTarget, value: float | None) -> bool | None:
        if value is None:
            return None
        if target.min_value is not None and value < target.min_value:
            return False
        if target.max_value is not None and value > target.max_value:
            return False
        return True

    @staticmethod
    def _ensure_alert(*, user_condition: UserCondition, alert_type: str, message: str, on_date: date) -> None:
        existing = user_condition.alerts.filter(
            alert_type=alert_type,
            message=message,
            created_at__date=on_date,
        ).exists()
        if not existing:
            ConditionAlert.objects.create(
                user_condition=user_condition,
                alert_type=alert_type,
                message=message,
            )

    @staticmethod
    @transaction.atomic
    def ensure_today_medication_logs(*, user_condition: UserCondition, now: datetime | None = None) -> None:
        ConditionMedicationService.ensure_today_medication_logs(
            user_condition=user_condition,
            now=now,
        )

    @staticmethod
    @transaction.atomic
    def mark_medication_taken(*, schedule: ConditionMedicationSchedule, now: datetime | None = None) -> ConditionMedicationLog:
        result = ConditionMedicationService.mark_taken(schedule=schedule, now=now)
        return result.log

    @staticmethod
    def _medication_adherence_percent(
        *,
        user_condition: UserCondition,
        on_date: date,
        now: datetime | None = None,
    ) -> float:
        now = now or ChronicConditionService._system_local_now()
        total = 0
        taken = 0
        for schedule in ConditionMedicationSchedule.objects.filter(
            medication__user_condition=user_condition,
            medication__is_active=True,
        ).select_related("medication"):
            if not ConditionMedicationService._schedule_is_active_for_date(
                schedule=schedule,
                target_date=on_date,
            ):
                continue
            if schedule.time_of_day > now.time() and on_date == now.date():
                continue
            total += 1
            log = schedule.logs.filter(scheduled_date=on_date).first()
            if log and log.status in {
                ConditionMedicationLog.STATUS_TAKEN,
                ConditionMedicationLog.STATUS_TAKEN_ON_TIME,
                ConditionMedicationLog.STATUS_TAKEN_LATE,
            }:
                taken += 1
        if total == 0:
            return 100.0
        return round((taken / total) * 100, 2)

    @staticmethod
    @transaction.atomic
    def evaluate_condition(*, user_condition: UserCondition, on_date: date | None = None) -> dict:
        on_date = on_date or ChronicConditionService._system_local_now().date()
        if not user_condition.targets.exists():
            ChronicConditionService.rebuild_targets_for_condition(user_condition)
        ChronicConditionService.ensure_today_medication_logs(user_condition=user_condition)

        context = ChronicConditionService.metric_context(user=user_condition.user, on_date=on_date)
        target_results = []
        scored_count = 0
        scored_success = 0

        for target in ChronicConditionService.effective_targets_for_condition(
            user_condition=user_condition
        ):
            value = ChronicConditionService._evaluate_target_value(target=target, context=context)
            within = ChronicConditionService._is_within_target(target=target, value=value)
            if within is None:
                target.status = HealthTarget.STATUS_NOT_EVALUATED
            elif within:
                target.status = HealthTarget.STATUS_WITHIN_TARGET
            else:
                target.status = HealthTarget.STATUS_OUT_OF_RANGE

            target.last_evaluated_value = value
            target.last_evaluated_at = timezone.now()
            target.save(
                update_fields=[
                    "status",
                    "last_evaluated_value",
                    "last_evaluated_at",
                ]
            )

            if target.is_scored and within is not None:
                scored_count += 1
                if within:
                    scored_success += 1
                else:
                    ChronicConditionService._ensure_alert(
                        user_condition=user_condition,
                        alert_type=ConditionAlert.TYPE_RESTRICTION,
                        message=f"Target out of range: {target.target_name}",
                        on_date=on_date,
                    )

            target_results.append(
                {
                    "id": target.id,
                    "target_key": target.target_key,
                    "target_name": target.target_name,
                    "category": target.category,
                    "metric_key": target.metric_key,
                    "evaluation_mode": target.evaluation_mode,
                    "unit": target.unit,
                    "min_value": target.min_value,
                    "max_value": target.max_value,
                    "status": target.status,
                    "current_value": value,
                    "source_type": target.source_type,
                    "priority": target.priority,
                    "guidance": target.guidance,
                    "evidence_source": target.evidence_source,
                    "is_inference": target.is_inference,
                    "is_scored": target.is_scored,
                }
            )

        restriction_adherence_percent = (
            round((scored_success / scored_count) * 100, 2) if scored_count else 0.0
        )
        medication_adherence_percent = ChronicConditionService._medication_adherence_percent(
            user_condition=user_condition,
            on_date=on_date,
            now=ChronicConditionService._system_local_now(),
        )

        desired_points_delta = 0
        evaluation, created = ConditionDailyEvaluation.objects.get_or_create(
            user_condition=user_condition,
            evaluation_date=on_date,
            defaults={
                "status": ConditionDailyEvaluation.STATUS_STABLE,
                "risk_flags": [],
                "recommendations_payload": [],
                "tracker_impacts_payload": [],
                "medication_adherence_percent": medication_adherence_percent,
                "restriction_adherence_percent": restriction_adherence_percent,
                "points_delta": 0,
            },
        )
        desired_points_delta = ConditionPointsEvaluator.apply_daily_evaluation_points(
            user_condition=user_condition,
            evaluation=evaluation,
            adherence_percent=restriction_adherence_percent,
            target_results=target_results,
        )

        evaluation.medication_adherence_percent = medication_adherence_percent
        evaluation.restriction_adherence_percent = restriction_adherence_percent
        evaluation.points_delta = desired_points_delta
        evaluation.notes = "Auto-evaluated from today's medication and lifestyle data."
        if not evaluation.status:
            evaluation.status = ConditionDailyEvaluation.STATUS_STABLE
        evaluation.save(
            update_fields=[
                "medication_adherence_percent",
                "restriction_adherence_percent",
                "points_delta",
                "notes",
                "status",
                "updated_at",
            ]
        )

        streak_bonus = ConditionPointsEvaluator.apply_streak_bonus(
            user_condition=user_condition,
            on_date=on_date,
        )

        return {
            "evaluation_date": str(on_date),
            "status": evaluation.status,
            "risk_flags": list(evaluation.risk_flags or []),
            "medication_adherence_percent": medication_adherence_percent,
            "restriction_adherence_percent": restriction_adherence_percent,
            "points_delta": desired_points_delta,
            "streak_bonus": streak_bonus,
            "recommendations": list(evaluation.recommendations_payload or []),
            "tracker_impacts": list(evaluation.tracker_impacts_payload or []),
            "latest_recorded_at": evaluation.latest_recorded_at.isoformat()
            if evaluation.latest_recorded_at
            else None,
            "targets": target_results,
        }

    @staticmethod
    def readings_timeline(*, user_condition: UserCondition) -> list[dict]:
        return ConditionIndicatorService.serialize_timeline(user_condition=user_condition)

    @staticmethod
    def _compact_summary_subtitle(slug: str) -> str:
        if slug == "diabetes":
            return "Last glucose reading recorded"
        if slug == "hypertension":
            return "Last blood pressure reading recorded"
        if slug == "dyslipidemia":
            return "Latest lipid follow-up recorded"
        return "Latest condition update"

    @staticmethod
    def _format_compact_metric(value: float | int | None) -> str:
        if value in (None, ""):
            return ""
        try:
            numeric = float(value)
        except (TypeError, ValueError):
            return str(value)
        if numeric == round(numeric):
            return str(int(round(numeric)))
        return f"{numeric:.1f}"

    @classmethod
    def _compact_summary_line(cls, *, slug: str, latest_reading) -> str:
        if latest_reading is not None:
            indicator_type = latest_reading.indicator_type or latest_reading.indicator_name
            payload = dict(latest_reading.payload or {})
            unit = (latest_reading.unit or "").strip()
            if indicator_type == "blood_pressure":
                systolic = cls._format_compact_metric(
                    payload.get("systolic") or latest_reading.value_1 or latest_reading.value
                )
                diastolic = cls._format_compact_metric(payload.get("diastolic") or latest_reading.value_2)
                return f"{systolic}/{diastolic} {unit}".strip()
            if indicator_type == "lipid_panel":
                ldl = cls._format_compact_metric(
                    LipidPanelValues.from_measurement(latest_reading).ldl_mg_dl
                )
                return f"LDL {ldl} {unit}".strip()
            primary = cls._format_compact_metric(latest_reading.value_1 or latest_reading.value)
            return f"{primary} {unit}".strip()
        if slug == "dyslipidemia":
            return "Track follow-ups and nutrition-linked insights."
        if slug == "hypertension":
            return "Track blood pressure and sodium-aware guidance."
        if slug == "diabetes":
            return "Track glucose and daily care guidance."
        return "Tracking summary not available yet."

    @staticmethod
    def _compact_secondary_summary_line(*, slug: str, alert_message: str = "") -> str:
        if alert_message.strip():
            return alert_message.strip()
        if slug == "dyslipidemia":
            return "Nutrition choices and follow-up targets stay connected."
        return "Open the tracking view for readings, targets, and guidance."

    @staticmethod
    def _compact_status_label(*, slug: str, classification: str, needs_attention: bool) -> str:
        if classification:
            if slug == "hypertension":
                if classification in {"in_range", "controlled"}:
                    return "Controlled"
                if classification == "elevated":
                    return "Elevated"
                if classification in {"high", "critical"}:
                    return "High"
            if slug == "diabetes":
                if classification in {"in_range", "normal"}:
                    return "In range"
                if classification == "low":
                    return "Low"
                if classification in {"high", "elevated", "critical"}:
                    return "High"
            if slug == "dyslipidemia":
                if classification in {"in_range", "normal", "controlled", "on_track"}:
                    return "On track"
                return "Needs attention"
            return classification.replace("_", " ").title()
        if slug == "dyslipidemia":
            return "Needs attention" if needs_attention else "On track"
        if slug == "hypertension":
            return "High" if needs_attention else "Controlled"
        if slug == "diabetes":
            return "High" if needs_attention else "In range"
        return "Needs attention" if needs_attention else "Active"

    @classmethod
    def _minimal_condition_type_payload(
        cls,
        *,
        user_condition: UserCondition,
    ) -> dict:
        condition_type = user_condition.condition_type
        return {
            "id": condition_type.id,
            "code": condition_type.code,
            "name": condition_type.name,
            "slug": condition_type.slug,
            "display_name": ConditionCatalogService.display_name(condition_type),
            "description": "",
            "can_add": False,
            "is_active_for_user": user_condition.is_active,
            "severity_options": [],
            "restrictions": [],
            "rule_profiles": [],
            "setup_fields": [],
            "measurement_types": [],
            "supports_direct_daily_reading": bool(
                (condition_type.setup_schema or {}).get("supports_direct_daily_reading")
            ),
        }

    @classmethod
    def condition_light_overview(
        cls,
        *,
        user_condition: UserCondition,
        on_date: date | None = None,
        include_targets: bool = True,
    ) -> dict:
        on_date = on_date or cls._system_local_now().date()
        latest_evaluation = cls._latest_daily_evaluation(
            user_condition=user_condition,
            on_date=on_date,
        )
        target_payload = (
            [
                cls._serialize_target_payload(target)
                for target in cls.effective_targets_for_condition(
                    user_condition=user_condition
                )
            ]
            if include_targets
            else []
        )
        tracker_impacts = (
            list(latest_evaluation.tracker_impacts_payload or [])
            if include_targets and latest_evaluation
            else []
        )
        latest_recorded_at = (
            latest_evaluation.latest_recorded_at.isoformat()
            if latest_evaluation and latest_evaluation.latest_recorded_at
            else ""
        )
        evaluation_status = (
            latest_evaluation.status
            if latest_evaluation and latest_evaluation.status
            else "stable"
        )
        needs_attention = evaluation_status in {"attention_needed", "critical"}
        slug = user_condition.condition_type.slug
        evaluation_payload = {
            "evaluation_date": str(
                latest_evaluation.evaluation_date if latest_evaluation else on_date
            ),
            "status": evaluation_status,
            "risk_flags": [],
            "medication_adherence_percent": 0.0,
            "restriction_adherence_percent": 0.0,
            "points_delta": 0,
            "streak_bonus": 0,
            "latest_recorded_at": latest_recorded_at,
            "recommendations": [],
            "tracker_impacts": tracker_impacts,
            "targets": [],
        }
        summary_payload = {
            "condition_id": user_condition.id,
            "status": evaluation_status,
            "risk_flags": [],
            "latest_recorded_at": latest_recorded_at,
            "recommendations": [],
            "tracker_impacts": [],
            "latest_reading": None,
            "alerts": [],
            "targets": [],
        }
        return {
            "view": "compact",
            "id": user_condition.id,
            "condition_type": cls._minimal_condition_type_payload(
                user_condition=user_condition
            ),
            "diagnosis_date": str(user_condition.diagnosis_date)
            if user_condition.diagnosis_date
            else None,
            "status": user_condition.status,
            "condition_status": user_condition.status,
            "severity_code": user_condition.severity_code,
            "severity": user_condition.severity_code,
            "notes": "",
            "profile_data": {},
            "is_active": user_condition.is_active,
            "targets": target_payload,
            "evaluation": evaluation_payload,
            "summary": summary_payload,
            "constraint_summary": [],
            "daily_medication_count": 0,
            "daily_pending_doses": 0,
            "open_alerts_count": 0,
            "latest_reading": None,
            "latest_recorded_at": latest_recorded_at or None,
            "evaluation_status": evaluation_status,
            "summary_status_label": cls._compact_status_label(
                slug=slug,
                classification="",
                needs_attention=needs_attention,
            ),
            "summary_subtitle": cls._compact_summary_subtitle(slug),
            "summary_line": cls._compact_summary_line(
                slug=slug,
                latest_reading=None,
            ),
            "secondary_summary_line": cls._compact_secondary_summary_line(
                slug=slug,
                alert_message="",
            ),
            "disclaimer": "",
        }

    @classmethod
    def condition_compact_overview(
        cls,
        *,
        user_condition: UserCondition,
        on_date: date | None = None,
    ) -> dict:
        on_date = on_date or cls._system_local_now().date()
        prefetched_readings = cls._prefetched_items(user_condition, "indicator_records")
        latest_reading = prefetched_readings[0] if prefetched_readings else None
        if prefetched_readings is None:
            latest_reading = user_condition.indicator_records.order_by("-recorded_at", "-id").first()

        prefetched_alerts = cls._prefetched_items(user_condition, "alerts")
        if prefetched_alerts is None:
            open_alerts = list(user_condition.alerts.filter(status="open").order_by("-created_at", "-id")[:1])
            open_alerts_count = user_condition.alerts.filter(status="open").count()
        else:
            open_alert_items = [alert for alert in prefetched_alerts if alert.status == "open"]
            open_alerts = open_alert_items[:1]
            open_alerts_count = len(open_alert_items)

        latest_evaluation = cls._latest_daily_evaluation(
            user_condition=user_condition,
            on_date=on_date,
        )
        target_payload = [
            cls._serialize_target_payload(target)
            for target in cls.effective_targets_for_condition(user_condition=user_condition)
        ]
        tracker_impacts = list(latest_evaluation.tracker_impacts_payload or []) if latest_evaluation else []
        recommendations = (
            list(latest_evaluation.recommendations_payload or [])
            if latest_evaluation
            else []
        )
        risk_flags = list(latest_evaluation.risk_flags or []) if latest_evaluation else []
        daily_medication_count = 0
        daily_pending_doses = 0
        prefetched_medications = cls._prefetched_items(user_condition, "medications")
        medications = (
            [item for item in prefetched_medications if item.is_active]
            if prefetched_medications is not None
            else user_condition.medications.filter(is_active=True).prefetch_related("schedules__logs")
        )
        for medication in medications:
            daily_medication_count += 1
            for schedule in medication.schedules.all():
                schedule_display = ConditionMedicationService.dose_display_for_today(
                    schedule=schedule,
                    today=on_date,
                )
                if schedule_display["today_status"] in {"pending", ConditionMedicationLog.STATUS_SNOOZED}:
                    daily_pending_doses += 1
        classification = (latest_reading.classification or "") if latest_reading else ""
        risk_level = (latest_reading.risk_level or "") if latest_reading else ""
        needs_attention = bool(
            open_alerts_count
            or classification in {"high", "low", "critical", "elevated", "needs_attention"}
            or risk_level in {"medium", "high", "critical"}
            or user_condition.status in {"needs_attention", "uncontrolled"}
        )
        slug = user_condition.condition_type.slug
        latest_recorded_at = ""
        if latest_evaluation and latest_evaluation.latest_recorded_at:
            latest_recorded_at = latest_evaluation.latest_recorded_at.isoformat()
        elif latest_reading and latest_reading.recorded_at:
            latest_recorded_at = latest_reading.recorded_at.isoformat()
        evaluation_status = (
            latest_evaluation.status
            if latest_evaluation and latest_evaluation.status
            else ("attention_needed" if needs_attention else "stable")
        )
        evaluation_payload = {
            "evaluation_date": str(latest_evaluation.evaluation_date)
            if latest_evaluation
            else str(on_date),
            "status": evaluation_status,
            "risk_flags": risk_flags,
            "medication_adherence_percent": (
                latest_evaluation.medication_adherence_percent if latest_evaluation else 0.0
            ),
            "restriction_adherence_percent": (
                latest_evaluation.restriction_adherence_percent if latest_evaluation else 0.0
            ),
            "points_delta": latest_evaluation.points_delta if latest_evaluation else 0,
            "streak_bonus": 0,
            "latest_recorded_at": latest_recorded_at,
            "recommendations": recommendations,
            "tracker_impacts": tracker_impacts,
            "targets": target_payload,
        }
        summary_payload = {
            "condition_id": user_condition.id,
            "status": evaluation_status,
            "risk_flags": risk_flags,
            "latest_recorded_at": latest_recorded_at,
            "recommendations": recommendations,
            "tracker_impacts": tracker_impacts,
            "latest_reading": ConditionIndicatorService.serialize_record(latest_reading)
            if latest_reading
            else None,
            "alerts": [],
            "targets": target_payload,
        }
        return {
            "view": "compact",
            "id": user_condition.id,
            "condition_type": {
                "id": user_condition.condition_type.id,
                "code": user_condition.condition_type.code,
                "name": user_condition.condition_type.name,
                "slug": user_condition.condition_type.slug,
                "display_name": ConditionCatalogService.display_name(user_condition.condition_type),
                "description": user_condition.condition_type.description,
                "can_add": False,
                "is_active_for_user": user_condition.is_active,
                "severity_options": user_condition.condition_type.severity_options,
                "restrictions": [],
                "rule_profiles": [],
                "setup_fields": [],
                "measurement_types": list(
                    (user_condition.condition_type.setup_schema or {}).get("measurement_types") or []
                ),
                "supports_direct_daily_reading": bool(
                    (user_condition.condition_type.setup_schema or {}).get("supports_direct_daily_reading")
                ),
            },
            "diagnosis_date": str(user_condition.diagnosis_date) if user_condition.diagnosis_date else None,
            "status": user_condition.status,
            "condition_status": user_condition.status,
            "severity_code": user_condition.severity_code,
            "severity": user_condition.severity_code,
            "notes": user_condition.notes,
            "profile_data": dict(user_condition.profile_data or {}),
            "is_active": user_condition.is_active,
            "targets": target_payload,
            "evaluation": evaluation_payload,
            "summary": summary_payload,
            "constraint_summary": [],
            "daily_medication_count": daily_medication_count,
            "daily_pending_doses": daily_pending_doses,
            "open_alerts_count": open_alerts_count,
            "latest_reading": ConditionIndicatorService.serialize_record(latest_reading) if latest_reading else None,
            "latest_recorded_at": latest_recorded_at or None,
            "evaluation_status": evaluation_status,
            "summary_status_label": cls._compact_status_label(
                slug=slug,
                classification=classification,
                needs_attention=needs_attention,
            ),
            "summary_subtitle": cls._compact_summary_subtitle(slug),
            "summary_line": cls._compact_summary_line(slug=slug, latest_reading=latest_reading),
            "secondary_summary_line": cls._compact_secondary_summary_line(
                slug=slug,
                alert_message=open_alerts[0].message if open_alerts else "",
            ),
            "disclaimer": cls.DISCLAIMER,
        }

    @staticmethod
    def condition_summary(
        *,
        user_condition: UserCondition,
        on_date: date | None = None,
        evaluation: dict | None = None,
    ) -> dict:
        on_date = on_date or ChronicConditionService._system_local_now().date()
        evaluation = evaluation or ChronicConditionService.evaluate_condition(
            user_condition=user_condition,
            on_date=on_date,
        )
        latest_reading = user_condition.indicator_records.order_by("-recorded_at", "-id").first()
        return {
            "condition_id": user_condition.id,
            "status": evaluation["status"],
            "risk_flags": evaluation["risk_flags"],
            "latest_recorded_at": evaluation["latest_recorded_at"],
            "recommendations": evaluation["recommendations"],
            "tracker_impacts": evaluation["tracker_impacts"],
            "latest_reading": ConditionIndicatorService.serialize_record(latest_reading) if latest_reading else None,
            "alerts": [
                {
                    "id": alert.id,
                    "code": alert.code,
                    "level": alert.level,
                    "message": alert.message,
                    "status": alert.status,
                    "created_at": alert.created_at.isoformat(),
                }
                for alert in user_condition.alerts.all()[:10]
            ],
            "targets": evaluation["targets"],
        }

    @staticmethod
    def condition_overview(*, user_condition: UserCondition, on_date: date | None = None) -> dict:
        on_date = on_date or ChronicConditionService._system_local_now().date()
        evaluation = ChronicConditionService.evaluate_condition(
            user_condition=user_condition,
            on_date=on_date,
        )
        materialized_constraints = list(
            ConstraintReadService.active_for_user(user=user_condition.user).filter(
                source_condition=user_condition,
            )
        )
        medications = []
        for medication in user_condition.medications.filter(is_active=True).prefetch_related("schedules__logs"):
            schedules = []
            for schedule in medication.schedules.all():
                schedules.append(
                    ConditionMedicationService.dose_display_for_today(
                        schedule=schedule,
                        today=on_date,
                    )
                )
            medications.append(
                {
                    "id": medication.id,
                    "name": medication.name,
                    "scientific_name": medication.scientific_name,
                    "dosage": medication.dosage,
                    "dosage_amount": medication.dosage_amount,
                    "dosage_unit": medication.dosage_unit,
                    "instructions": medication.instructions,
                    "relation_to_meal": medication.relation_to_meal,
                    "recurrence_pattern": medication.recurrence_pattern,
                    "start_date": str(medication.start_date) if medication.start_date else None,
                    "end_date": str(medication.end_date) if medication.end_date else None,
                    "is_active": medication.is_active,
                    "reminder_enabled": medication.reminder_enabled,
                    "reminder_lead_minutes": medication.reminder_lead_minutes,
                    "schedules": schedules,
                }
            )

        indicators = ChronicConditionService.readings_timeline(user_condition=user_condition)[:10]
        alerts = [
            {
                "id": alert.id,
                "code": alert.code,
                "level": alert.level,
                "message": alert.message,
                "alert_type": alert.alert_type,
                "status": alert.status,
                "created_at": alert.created_at.isoformat(),
            }
            for alert in user_condition.alerts.all()[:5]
        ]

        return {
            "id": user_condition.id,
            "condition_type": {
                "id": user_condition.condition_type.id,
                "code": user_condition.condition_type.code,
                "name": user_condition.condition_type.name,
                "slug": user_condition.condition_type.slug,
                "display_name": ConditionCatalogService.display_name(user_condition.condition_type),
                "description": user_condition.condition_type.description,
                "is_supported": user_condition.condition_type.is_supported,
                "setup_schema": user_condition.condition_type.setup_schema,
                "severity_options": user_condition.condition_type.severity_options,
            },
            "diagnosis_date": str(user_condition.diagnosis_date) if user_condition.diagnosis_date else None,
            "status": user_condition.status,
            "condition_status": user_condition.status,
            "severity_code": user_condition.severity_code,
            "severity": user_condition.severity_code,
            "profile_data": dict(user_condition.profile_data or {}),
            "notes": user_condition.notes,
            "is_active": user_condition.is_active,
            "targets": evaluation["targets"],
            "evaluation": evaluation,
            "medications": medications,
            "indicator_records": indicators,
            "alerts": alerts,
            "summary": ChronicConditionService.condition_summary(
                user_condition=user_condition,
                on_date=on_date,
                evaluation=evaluation,
            ),
            "constraint_summary": list(
                dict.fromkeys(
                    constraint.reason_summary
                    for constraint in materialized_constraints
                    if constraint.reason_summary
                )
            ),
            "daily_medication_count": len(medications),
            "daily_pending_doses": sum(
                1
                for medication in medications
                for schedule in medication["schedules"]
                if schedule["today_status"] in {"pending", ConditionMedicationLog.STATUS_SNOOZED}
            ),
            "disclaimer": ChronicConditionService.DISCLAIMER,
        }
