from __future__ import annotations

from dataclasses import dataclass, field
from datetime import time
from typing import Any

from django.db.models import Q

from core.models import (
    ConditionMedication,
    ConditionNutrientRule,
    HealthIndicatorRecord,
    HealthRestriction,
    HealthTarget,
    Nutrient,
    ResolvedTrackerConstraint,
    UserCondition,
    UserNutrientTarget,
)
from users.models import UserProfile


@dataclass(frozen=True, slots=True)
class ConstraintCandidate:
    tracker_type: str
    category: str
    metric_key: str
    rule_type: str
    evaluation_mode: str = "daily_total"
    unit: str = ""
    min_value: float | None = None
    max_value: float | None = None
    target_value: float | None = None
    warning_value: float | None = None
    priority: int = 50
    is_blocking: bool = False
    is_scored: bool = True
    source_type: str = ResolvedTrackerConstraint.SOURCE_GENERAL_RECOMMENDATION
    source_condition: UserCondition | None = None
    source_restriction: HealthRestriction | None = None
    source_target: HealthTarget | None = None
    source_nutrient_rule: ConditionNutrientRule | None = None
    source_user_nutrient_target: UserNutrientTarget | None = None
    reason_summary: str = ""
    explanation_payload: dict[str, Any] = field(default_factory=dict)
    confidence_score: float | None = None
    source_model: str = ""
    source_object_id: str = ""

    def hash_payload(self) -> dict[str, Any]:
        return {
            "tracker_type": self.tracker_type,
            "category": self.category,
            "metric_key": self.metric_key,
            "rule_type": self.rule_type,
            "evaluation_mode": self.evaluation_mode,
            "unit": self.unit,
            "min_value": self.min_value,
            "max_value": self.max_value,
            "target_value": self.target_value,
            "warning_value": self.warning_value,
            "priority": self.priority,
            "is_blocking": self.is_blocking,
            "is_scored": self.is_scored,
            "source_type": self.source_type,
            "source_model": self.source_model,
            "source_object_id": self.source_object_id,
        }

    def source_trace_payload(self) -> dict[str, Any] | None:
        if not self.source_model:
            return None
        return {
            "source_model": self.source_model,
            "source_object_id": self.source_object_id,
            "priority_score": self.priority,
            "note": self.reason_summary,
        }


class ConstraintSourceCollector:
    """Collects source-table rules and translates them into normalized candidates."""

    PRIORITY = {
        ResolvedTrackerConstraint.SOURCE_PHYSICIAN_OVERRIDE: 100,
        ResolvedTrackerConstraint.SOURCE_SAFETY_CRITICAL_CONDITION_RULE: 90,
        ResolvedTrackerConstraint.SOURCE_DYNAMIC_CONDITION_STATE: 80,
        ResolvedTrackerConstraint.SOURCE_CONDITION_NUTRIENT_RULE: 70,
        ResolvedTrackerConstraint.SOURCE_USER_CUSTOM_TARGET: 60,
        ResolvedTrackerConstraint.SOURCE_PROFILE_DERIVED_DEFAULT: 40,
        ResolvedTrackerConstraint.SOURCE_GENERAL_RECOMMENDATION: 20,
    }

    METRIC_ALIASES = {
        "water_liters": ("hydration", "daily_water_liters", "liters"),
        "daily_water_liters": ("hydration", "daily_water_liters", "liters"),
        "fluid_liters": ("hydration", "total_fluid_intake_liters", "liters"),
        "total_fluid_intake_liters": ("hydration", "total_fluid_intake_liters", "liters"),
        "blood_pressure_systolic": ("monitoring", "systolic_bp", "mmHg"),
        "bp_systolic": ("monitoring", "systolic_bp", "mmHg"),
        "systolic_bp": ("monitoring", "systolic_bp", "mmHg"),
        "blood_pressure_diastolic": ("monitoring", "diastolic_bp", "mmHg"),
        "bp_diastolic": ("monitoring", "diastolic_bp", "mmHg"),
        "diastolic_bp": ("monitoring", "diastolic_bp", "mmHg"),
        "ldl_cholesterol": ("monitoring", "ldl", "mg/dL"),
        "hdl_cholesterol": ("monitoring", "hdl", "mg/dL"),
        "triglyceride": ("monitoring", "triglycerides", "mg/dL"),
        "triglycerides": ("monitoring", "triglycerides", "mg/dL"),
        "fasting_glucose": ("monitoring", "fasting_glucose", "mg/dL"),
        "postprandial_glucose": ("monitoring", "postprandial_glucose", "mg/dL"),
        "sugar_g": ("nutrition", "sugars_g", "g"),
        "carbs_g": ("nutrition", "carbohydrates_g", "g"),
        "carbohydrates_g": ("nutrition", "carbohydrates_g", "g"),
        "sodium_mg": ("nutrition", "sodium_mg", "mg"),
        "caffeine_mg": ("nutrition", "caffeine_mg", "mg"),
        "calories": ("nutrition", "calories_kcal", "kcal"),
        "calories_kcal": ("nutrition", "calories_kcal", "kcal"),
        "activity_minutes": ("activity", "activity_minutes", "minutes"),
        "exercise_minutes": ("activity", "activity_minutes", "minutes"),
        "calories_burned": ("activity", "calories_burned", "kcal"),
        "steps": ("steps", "steps_count", "steps"),
        "steps_count": ("steps", "steps_count", "steps"),
        "sleep_hours": ("sleep", "sleep_hours", "hours"),
    }

    CATEGORY_TRACKERS = {
        HealthRestriction.CATEGORY_ACTIVITY: ResolvedTrackerConstraint.TRACKER_ACTIVITY,
        HealthRestriction.CATEGORY_NUTRITION: ResolvedTrackerConstraint.TRACKER_NUTRITION,
        HealthRestriction.CATEGORY_HYDRATION: ResolvedTrackerConstraint.TRACKER_HYDRATION,
        HealthRestriction.CATEGORY_MEDICATION: ResolvedTrackerConstraint.TRACKER_MEDICATION,
        HealthRestriction.CATEGORY_MONITORING: ResolvedTrackerConstraint.TRACKER_MONITORING,
        "sleep": ResolvedTrackerConstraint.TRACKER_SLEEP,
        "steps": ResolvedTrackerConstraint.TRACKER_STEPS,
        "habit": ResolvedTrackerConstraint.TRACKER_HABIT,
        "micronutrient": ResolvedTrackerConstraint.TRACKER_MICRONUTRIENT,
    }

    @classmethod
    def collect_for_user(cls, *, user, tracker_type: str | None = None) -> list[ConstraintCandidate]:
        candidates: list[ConstraintCandidate] = []
        profile = getattr(user, "userprofile", None)
        if profile is not None:
            candidates.extend(cls._from_profile(profile=profile))

        conditions = cls._active_conditions(user)
        candidates.extend(cls._from_health_targets(conditions=conditions))
        candidates.extend(cls._from_health_restrictions(conditions=conditions))
        candidates.extend(cls._from_condition_nutrient_rules(conditions=conditions))
        candidates.extend(cls._from_user_nutrient_targets(user=user))
        candidates.extend(cls._from_latest_indicator_records(conditions=conditions))
        candidates.extend(cls._from_medication_plans(user=user))

        if tracker_type:
            return [candidate for candidate in candidates if candidate.tracker_type == tracker_type]
        return candidates

    @staticmethod
    def _active_conditions(user) -> list[UserCondition]:
        return list(
            UserCondition.objects.filter(
                user=user,
                is_active=True,
                status__in=(
                    UserCondition.STATUS_ACTIVE,
                    UserCondition.STATUS_CONTROLLED,
                    UserCondition.STATUS_NEEDS_ATTENTION,
                ),
            ).select_related("condition_type")
        )

    @classmethod
    def _from_profile(cls, *, profile: UserProfile) -> list[ConstraintCandidate]:
        source_type = ResolvedTrackerConstraint.SOURCE_PROFILE_DERIVED_DEFAULT
        priority = cls.PRIORITY[source_type]
        candidates = [
            cls._candidate(
                tracker_type=ResolvedTrackerConstraint.TRACKER_NUTRITION,
                category="profile",
                metric_key="calories_kcal",
                rule_type=ResolvedTrackerConstraint.RULE_TARGET,
                unit="kcal",
                target_value=float(profile.daily_calorie_target or 0),
                source_type=source_type,
                priority=priority,
                reason_summary="Daily calorie target derived from the user's profile.",
                source_model="UserProfile",
                source_object_id=profile.id,
                confidence_score=0.95,
            ),
            cls._candidate(
                tracker_type=ResolvedTrackerConstraint.TRACKER_HYDRATION,
                category="profile",
                metric_key="daily_water_liters",
                rule_type=ResolvedTrackerConstraint.RULE_TARGET,
                unit="liters",
                target_value=float(profile.daily_water_target or 0),
                source_type=source_type,
                priority=priority,
                reason_summary="Daily water target derived from the user's profile.",
                source_model="UserProfile",
                source_object_id=profile.id,
                confidence_score=0.95,
            ),
            cls._candidate(
                tracker_type=ResolvedTrackerConstraint.TRACKER_STEPS,
                category="profile",
                metric_key="steps_count",
                rule_type=ResolvedTrackerConstraint.RULE_TARGET,
                unit="steps",
                target_value=float(profile.daily_step_goal or 0),
                source_type=source_type,
                priority=priority,
                reason_summary="Daily step target derived from the user's profile.",
                source_model="UserProfile",
                source_object_id=profile.id,
                confidence_score=0.95,
            ),
            cls._candidate(
                tracker_type=ResolvedTrackerConstraint.TRACKER_ACTIVITY,
                category="profile",
                metric_key="calories_burned",
                rule_type=ResolvedTrackerConstraint.RULE_TARGET,
                unit="kcal",
                target_value=float(profile.daily_burn_goal or 0),
                source_type=source_type,
                priority=priority,
                reason_summary="Daily burn target derived from the user's profile.",
                source_model="UserProfile",
                source_object_id=profile.id,
                confidence_score=0.95,
            ),
            cls._candidate(
                tracker_type=ResolvedTrackerConstraint.TRACKER_SLEEP,
                category="profile",
                metric_key="sleep_hours",
                rule_type=ResolvedTrackerConstraint.RULE_TARGET,
                unit="hours",
                target_value=float(profile.recommended_sleep_hours or 0),
                source_type=source_type,
                priority=priority,
                reason_summary="Recommended sleep duration derived from the user's profile.",
                source_model="UserProfile",
                source_object_id=profile.id,
                confidence_score=0.95,
            ),
        ]
        if profile.target_bed_time:
            candidates.append(
                cls._time_candidate(
                    profile=profile,
                    metric_key="bed_time",
                    value=profile.target_bed_time,
                    reason_summary="Target bed time derived from the user's sleep profile.",
                )
            )
        if profile.target_wake_time:
            candidates.append(
                cls._time_candidate(
                    profile=profile,
                    metric_key="wake_time",
                    value=profile.target_wake_time,
                    reason_summary="Target wake time derived from the user's sleep profile.",
                )
            )
        return candidates

    @classmethod
    def _time_candidate(
        cls,
        *,
        profile: UserProfile,
        metric_key: str,
        value: time,
        reason_summary: str,
    ) -> ConstraintCandidate:
        source_type = ResolvedTrackerConstraint.SOURCE_PROFILE_DERIVED_DEFAULT
        hour_value = round(value.hour + (value.minute / 60) + (value.second / 3600), 2)
        return cls._candidate(
            tracker_type=ResolvedTrackerConstraint.TRACKER_SLEEP,
            category="profile",
            metric_key=metric_key,
            rule_type=ResolvedTrackerConstraint.RULE_TARGET,
            evaluation_mode="time_of_day",
            unit="hour_of_day",
            target_value=hour_value,
            source_type=source_type,
            priority=cls.PRIORITY[source_type],
            reason_summary=reason_summary,
            source_model="UserProfile",
            source_object_id=profile.id,
            confidence_score=0.9,
        )

    @classmethod
    def _from_health_targets(cls, *, conditions: list[UserCondition]) -> list[ConstraintCandidate]:
        candidates: list[ConstraintCandidate] = []
        for condition in conditions:
            targets = condition.targets.select_related("source_restriction").all()
            for target in targets:
                tracker, metric_key, unit = cls._normalize_tracker_metric(
                    category=target.category,
                    metric_key=target.metric_key or target.target_key,
                    unit=target.unit,
                )
                source_type = cls._source_type_for_health_target(target.source_type)
                priority = max(1, cls.PRIORITY[source_type] - int(target.priority or 0))
                candidates.append(
                    cls._candidate(
                        tracker_type=tracker,
                        category=target.category or tracker,
                        metric_key=metric_key,
                        rule_type=cls._rule_type_from_values(
                            min_value=target.min_value,
                            max_value=target.max_value,
                        ),
                        evaluation_mode=target.evaluation_mode or "daily_total",
                        unit=unit,
                        min_value=cls._float_or_none(target.min_value),
                        max_value=cls._float_or_none(target.max_value),
                        source_type=source_type,
                        priority=priority,
                        is_scored=target.is_scored,
                        source_condition=condition,
                        source_restriction=target.source_restriction,
                        source_target=target,
                        reason_summary=target.guidance or f"{target.target_name} from {condition.condition_type}.",
                        source_model="HealthTarget",
                        source_object_id=target.id,
                        confidence_score=0.9 if not target.is_inference else 0.75,
                    )
                )
        return candidates

    @classmethod
    def _from_health_restrictions(cls, *, conditions: list[UserCondition]) -> list[ConstraintCandidate]:
        candidates: list[ConstraintCandidate] = []
        for condition in conditions:
            restrictions = HealthRestriction.objects.filter(
                condition_type=condition.condition_type,
            ).filter(Q(severity_code="") | Q(severity_code=condition.severity_code))
            for restriction in restrictions:
                if (
                    restriction.min_required_value is None
                    and restriction.max_allowed_value is None
                    and not restriction.is_forbidden
                ):
                    continue
                tracker, metric_key, unit = cls._normalize_tracker_metric(
                    category=restriction.category,
                    metric_key=restriction.metric_key,
                    unit=restriction.unit,
                )
                source_type = ResolvedTrackerConstraint.SOURCE_SAFETY_CRITICAL_CONDITION_RULE
                max_value = cls._float_or_none(restriction.max_allowed_value)
                if restriction.is_forbidden and max_value is None:
                    max_value = 0.0
                candidates.append(
                    cls._candidate(
                        tracker_type=tracker,
                        category=restriction.category or tracker,
                        metric_key=metric_key,
                        rule_type=(
                            ResolvedTrackerConstraint.RULE_AVOID
                            if restriction.is_forbidden
                            else cls._rule_type_from_values(
                                min_value=restriction.min_required_value,
                                max_value=restriction.max_allowed_value,
                            )
                        ),
                        evaluation_mode=restriction.evaluation_mode or "daily_total",
                        unit=unit,
                        min_value=cls._float_or_none(restriction.min_required_value),
                        max_value=max_value,
                        source_type=source_type,
                        priority=cls.PRIORITY[source_type],
                        is_blocking=restriction.is_forbidden,
                        is_scored=restriction.is_scored,
                        source_condition=condition,
                        source_restriction=restriction,
                        reason_summary=restriction.guidance or restriction.title,
                        source_model="HealthRestriction",
                        source_object_id=restriction.id,
                        confidence_score=0.9 if not restriction.is_inference else 0.75,
                    )
                )
        return candidates

    @classmethod
    def _from_condition_nutrient_rules(cls, *, conditions: list[UserCondition]) -> list[ConstraintCandidate]:
        candidates: list[ConstraintCandidate] = []
        source_type = ResolvedTrackerConstraint.SOURCE_CONDITION_NUTRIENT_RULE
        for condition in conditions:
            rules = ConditionNutrientRule.objects.filter(
                condition_type=condition.condition_type,
            ).filter(Q(severity="") | Q(severity=condition.severity_code)).select_related("nutrient")
            for rule in rules:
                tracker = cls._tracker_for_nutrient(rule.nutrient)
                metric_key = cls._nutrient_metric_key(rule.nutrient)
                threshold = cls._float_or_none(rule.threshold_value)
                max_value = threshold if rule.rule_type in {"max", "avoid"} else None
                min_value = threshold if rule.rule_type == "min" else None
                warning_value = threshold if rule.rule_type == "warn" else None
                if rule.rule_type == "avoid" and max_value is None:
                    max_value = 0.0
                candidates.append(
                    cls._candidate(
                        tracker_type=tracker,
                        category=rule.nutrient.category,
                        metric_key=metric_key,
                        rule_type=rule.rule_type,
                        evaluation_mode="daily_total",
                        unit=rule.threshold_unit or rule.nutrient.unit,
                        min_value=min_value,
                        max_value=max_value,
                        warning_value=warning_value,
                        source_type=source_type,
                        priority=cls.PRIORITY[source_type],
                        is_blocking=rule.rule_type == ConditionNutrientRule.RULE_AVOID,
                        source_condition=condition,
                        source_nutrient_rule=rule,
                        reason_summary=rule.note or f"{rule.nutrient.name} rule for {condition.condition_type}.",
                        source_model="ConditionNutrientRule",
                        source_object_id=rule.id,
                        confidence_score=0.85,
                    )
                )
        return candidates

    @classmethod
    def _from_user_nutrient_targets(cls, *, user) -> list[ConstraintCandidate]:
        candidates: list[ConstraintCandidate] = []
        targets = UserNutrientTarget.objects.filter(user=user).select_related("nutrient")
        for target in targets:
            source_type = cls._source_type_for_user_nutrient_target(target.source)
            tracker = cls._tracker_for_nutrient(target.nutrient)
            candidates.append(
                cls._candidate(
                    tracker_type=tracker,
                    category=target.nutrient.category,
                    metric_key=cls._nutrient_metric_key(target.nutrient),
                    rule_type=cls._rule_type_from_values(
                        min_value=target.min_value,
                        max_value=target.max_value,
                        target_value=target.target_value,
                    ),
                    evaluation_mode=f"{target.period}_total",
                    unit=target.nutrient.unit,
                    min_value=cls._float_or_none(target.min_value),
                    max_value=cls._float_or_none(target.max_value),
                    target_value=cls._float_or_none(target.target_value),
                    source_type=source_type,
                    priority=cls.PRIORITY[source_type],
                    source_user_nutrient_target=target,
                    reason_summary=f"{target.nutrient.name} {target.period} target.",
                    source_model="UserNutrientTarget",
                    source_object_id=target.id,
                    confidence_score=0.8,
                )
            )
        return candidates

    @classmethod
    def _from_latest_indicator_records(cls, *, conditions: list[UserCondition]) -> list[ConstraintCandidate]:
        candidates: list[ConstraintCandidate] = []
        source_type = ResolvedTrackerConstraint.SOURCE_DYNAMIC_CONDITION_STATE
        for condition in conditions:
            seen: set[str] = set()
            latest_records = []
            for record in HealthIndicatorRecord.objects.filter(user_condition=condition).order_by(
                "-recorded_at", "-id"
            ):
                if record.indicator_type in seen:
                    continue
                seen.add(record.indicator_type)
                latest_records.append(record)
            for record in latest_records:
                metric_key, value = cls._indicator_metric(record)
                if not metric_key or value is None:
                    continue
                if record.classification not in {"high", "low", "critical"} and record.risk_level not in {
                    "medium",
                    "high",
                    "critical",
                }:
                    continue
                candidates.append(
                    cls._candidate(
                        tracker_type=ResolvedTrackerConstraint.TRACKER_MONITORING,
                        category="monitoring",
                        metric_key=metric_key,
                        rule_type=ResolvedTrackerConstraint.RULE_WARN,
                        evaluation_mode="latest_indicator",
                        unit=record.unit,
                        warning_value=float(value),
                        source_type=source_type,
                        priority=cls.PRIORITY[source_type],
                        source_condition=condition,
                        reason_summary=(
                            f"Latest {record.indicator_type} reading is "
                            f"{record.classification or record.risk_level}."
                        ),
                        source_model="HealthIndicatorRecord",
                        source_object_id=record.id,
                        confidence_score=0.7,
                    )
                )
        return candidates

    @classmethod
    def _from_medication_plans(cls, *, user) -> list[ConstraintCandidate]:
        active_medications = ConditionMedication.objects.filter(user=user, is_active=True).select_related(
            "user_condition"
        )
        first_medication = active_medications.first()
        if first_medication is None:
            return []
        source_type = ResolvedTrackerConstraint.SOURCE_GENERAL_RECOMMENDATION
        priority = cls.PRIORITY[source_type]
        source_condition = first_medication.user_condition
        source_model = "ConditionMedication"
        source_object_id = first_medication.id
        return [
            cls._candidate(
                tracker_type=ResolvedTrackerConstraint.TRACKER_MEDICATION,
                category="medication",
                metric_key="adherence_percent",
                rule_type=ResolvedTrackerConstraint.RULE_TARGET,
                evaluation_mode="rolling_7d_percent",
                unit="percent",
                target_value=90.0,
                source_type=source_type,
                priority=priority,
                source_condition=source_condition,
                reason_summary="Medication adherence target for active medication plans.",
                source_model=source_model,
                source_object_id=source_object_id,
                confidence_score=0.7,
            ),
            cls._candidate(
                tracker_type=ResolvedTrackerConstraint.TRACKER_MEDICATION,
                category="medication",
                metric_key="missed_doses_count",
                rule_type=ResolvedTrackerConstraint.RULE_MAX,
                evaluation_mode="daily_count",
                unit="count",
                max_value=0.0,
                source_type=source_type,
                priority=priority,
                source_condition=source_condition,
                reason_summary="Missed doses should be avoided for active medication plans.",
                source_model=source_model,
                source_object_id=source_object_id,
                confidence_score=0.7,
            ),
        ]

    @classmethod
    def _candidate(cls, **kwargs) -> ConstraintCandidate:
        payload = dict(kwargs.pop("explanation_payload", {}) or {})
        payload.setdefault("source_model", kwargs.get("source_model") or "")
        payload.setdefault("source_object_id", str(kwargs.get("source_object_id") or ""))
        payload.setdefault("source_type", kwargs.get("source_type"))
        return ConstraintCandidate(
            source_object_id=str(kwargs.pop("source_object_id", "") or ""),
            explanation_payload=payload,
            **kwargs,
        )

    @classmethod
    def _normalize_tracker_metric(
        cls,
        *,
        category: str,
        metric_key: str,
        unit: str,
    ) -> tuple[str, str, str]:
        normalized_key = str(metric_key or "").strip()
        alias = cls.METRIC_ALIASES.get(normalized_key)
        if alias:
            tracker, metric, default_unit = alias
            return tracker, metric, unit or default_unit
        tracker = cls.CATEGORY_TRACKERS.get(category, category or ResolvedTrackerConstraint.TRACKER_MONITORING)
        return tracker, normalized_key, unit or ""

    @staticmethod
    def _rule_type_from_values(
        *,
        min_value=None,
        max_value=None,
        target_value=None,
    ) -> str:
        if target_value is not None and min_value is None and max_value is None:
            return ResolvedTrackerConstraint.RULE_TARGET
        if min_value is not None and max_value is not None:
            return ResolvedTrackerConstraint.RULE_RANGE
        if max_value is not None:
            return ResolvedTrackerConstraint.RULE_MAX
        if min_value is not None:
            return ResolvedTrackerConstraint.RULE_MIN
        return ResolvedTrackerConstraint.RULE_TARGET

    @staticmethod
    def _source_type_for_health_target(source_type: str) -> str:
        if source_type == HealthTarget.SOURCE_PHYSICIAN_OVERRIDE:
            return ResolvedTrackerConstraint.SOURCE_PHYSICIAN_OVERRIDE
        if source_type == HealthTarget.SOURCE_DYNAMIC_CONDITION:
            return ResolvedTrackerConstraint.SOURCE_DYNAMIC_CONDITION_STATE
        if source_type == HealthTarget.SOURCE_USER_CUSTOM:
            return ResolvedTrackerConstraint.SOURCE_USER_CUSTOM_TARGET
        return ResolvedTrackerConstraint.SOURCE_SAFETY_CRITICAL_CONDITION_RULE

    @staticmethod
    def _source_type_for_user_nutrient_target(source: str) -> str:
        if source == UserNutrientTarget.SOURCE_MANUAL:
            return ResolvedTrackerConstraint.SOURCE_USER_CUSTOM_TARGET
        if source == UserNutrientTarget.SOURCE_CONDITION:
            return ResolvedTrackerConstraint.SOURCE_CONDITION_NUTRIENT_RULE
        return ResolvedTrackerConstraint.SOURCE_GENERAL_RECOMMENDATION

    @staticmethod
    def _tracker_for_nutrient(nutrient: Nutrient) -> str:
        if nutrient.is_core or nutrient.category in {Nutrient.CATEGORY_MACRO, Nutrient.CATEGORY_STIMULANT}:
            return ResolvedTrackerConstraint.TRACKER_NUTRITION
        if nutrient.category in {Nutrient.CATEGORY_VITAMIN, Nutrient.CATEGORY_MINERAL}:
            return ResolvedTrackerConstraint.TRACKER_MICRONUTRIENT
        return ResolvedTrackerConstraint.TRACKER_NUTRITION

    @staticmethod
    def _nutrient_metric_key(nutrient: Nutrient) -> str:
        return str(nutrient.code or "").strip()

    @staticmethod
    def _indicator_metric(record: HealthIndicatorRecord) -> tuple[str | None, float | None]:
        indicator_type = str(record.indicator_type or "").strip()
        if indicator_type == "blood_pressure":
            return "systolic_bp", record.value_1 if record.value_1 is not None else record.value
        if indicator_type == "glucose":
            if record.reading_context in {"fasting", "before_meal"}:
                return "fasting_glucose", record.value
            return "postprandial_glucose", record.value
        if indicator_type == "lipid_panel":
            if record.value_2 is not None:
                return "triglycerides", record.value_2
            return "ldl", record.value
        if indicator_type:
            return indicator_type, record.value
        return None, None

    @staticmethod
    def _float_or_none(value) -> float | None:
        if value is None:
            return None
        try:
            return float(value)
        except (TypeError, ValueError):
            return None
