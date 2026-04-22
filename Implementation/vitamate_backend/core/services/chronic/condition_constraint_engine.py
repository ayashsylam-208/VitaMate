from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from core.models import ConditionDailyEvaluation, ConditionRuleProfile, UserCondition
from core.services.condition_catalog_service import ConditionCatalogService
from core.services.condition_medication_service import ConditionMedicationService


@dataclass(frozen=True)
class EffectiveConditionConstraints:
    calories_target: int
    water_target_liters: float
    step_target: int
    burn_target: int
    exercise_intensity_mode: str
    applied_summaries: tuple[str, ...]
    active_condition_labels: tuple[str, ...]
    medication_count_today: int
    pending_doses_today: int
    adherence_percent: float
    sodium_limit_mg: float | None = None
    fasting_glucose_min: float | None = None
    fasting_glucose_max: float | None = None
    systolic_target: float | None = None
    diastolic_target: float | None = None
    ldl_target: float | None = None
    disclaimer: str = (
        "Chronic-condition guidance in VitaMate supports self-management and does not replace your clinician."
    )


class ConditionConstraintEngine:
    """Builds user-level effective targets from active chronic-condition rules."""

    SEVERE_CODES = {"diabetes_intensive", "stage_2", "very_high_ldl", "severe", "uncontrolled"}
    MODERATE_CODES = {"diabetes_managed", "stage_1", "high_ldl", "moderate", "needs_attention"}
    MILD_CODES = {"prediabetes", "elevated", "borderline_high_ldl", "mild", "controlled"}

    @classmethod
    def _severity_rank(cls, condition: UserCondition) -> int:
        if condition.status == UserCondition.STATUS_NEEDS_ATTENTION:
            return 3
        if condition.status == UserCondition.STATUS_CONTROLLED:
            return 1
        code = condition.severity_code
        if code in cls.SEVERE_CODES:
            return 3
        if code in cls.MODERATE_CODES:
            return 2
        if code in cls.MILD_CODES:
            return 1
        return 2

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
            )
            .select_related("condition_type")
            .prefetch_related("targets")
        )

    @staticmethod
    def _latest_adherence_percent(*, on_date: date, conditions: list[UserCondition]) -> float:
        if not conditions:
            return 0.0
        condition_ids = [condition.id for condition in conditions]
        condition_evaluations = [
            (medication + restriction) / 2
            for medication, restriction in ConditionDailyEvaluation.objects.filter(
                user_condition_id__in=condition_ids,
                evaluation_date=on_date,
            ).values_list("medication_adherence_percent", "restriction_adherence_percent")
        ]
        if not condition_evaluations:
            return 0.0
        return round(sum(condition_evaluations) / len(condition_evaluations), 2)

    @staticmethod
    def _rule_profiles_for_conditions(conditions: list[UserCondition]) -> list[ConditionRuleProfile]:
        if not conditions:
            return []
        condition_type_ids = {condition.condition_type_id for condition in conditions}
        severity_codes = {""}
        severity_codes.update(condition.severity_code for condition in conditions if condition.severity_code)
        return list(
            ConditionRuleProfile.objects.filter(
                condition_type_id__in=condition_type_ids,
                severity_code__in=severity_codes,
            )
        )

    @staticmethod
    def _rule_float_map(rule_profiles: list[ConditionRuleProfile], rule_key: str) -> list[float]:
        values: list[float] = []
        for profile in rule_profiles:
            if profile.rule_key != rule_key:
                continue
            try:
                values.append(float(profile.rule_value))
            except (TypeError, ValueError):
                continue
        return values

    @staticmethod
    def _effective_target_map(condition: UserCondition) -> dict[str, object]:
        selected = {}
        for target in sorted(condition.targets.all(), key=lambda item: (item.priority, -item.id)):
            existing = selected.get(target.target_key)
            if existing is None or target.priority < existing.priority:
                selected[target.target_key] = target
        return selected

    @classmethod
    def prepare_context(cls, *, user) -> dict:
        conditions = cls._active_conditions(user)
        return {
            "conditions": conditions,
            "rule_profiles": cls._rule_profiles_for_conditions(conditions),
            "effective_targets": [cls._effective_target_map(condition) for condition in conditions],
        }

    @classmethod
    def build_effective_constraints(
        cls,
        *,
        user,
        profile,
        on_date: date | None = None,
        prepared_context: dict | None = None,
    ) -> EffectiveConditionConstraints:
        on_date = on_date or date.today()
        prepared_context = prepared_context or {}
        conditions = prepared_context.get("conditions")
        if conditions is None:
            conditions = cls._active_conditions(user)
        if not conditions:
            return EffectiveConditionConstraints(
                calories_target=profile.daily_calorie_target,
                water_target_liters=profile.daily_water_target,
                step_target=profile.daily_step_goal,
                burn_target=profile.daily_burn_goal,
                exercise_intensity_mode="standard",
                applied_summaries=(),
                active_condition_labels=(),
                medication_count_today=0,
                pending_doses_today=0,
                adherence_percent=0.0,
            )

        severity_rank = max(cls._severity_rank(condition) for condition in conditions)
        rule_profiles = prepared_context.get("rule_profiles")
        if rule_profiles is None:
            rule_profiles = cls._rule_profiles_for_conditions(conditions)
        condition_slugs = {
            ConditionCatalogService.canonical_slug(condition.condition_type)
            for condition in conditions
        }
        labels = tuple(ConditionCatalogService.display_name(condition.condition_type) for condition in conditions)
        effective_targets = prepared_context.get("effective_targets")
        if effective_targets is None:
            effective_targets = [cls._effective_target_map(condition) for condition in conditions]

        effective_steps = profile.daily_step_goal
        effective_burn = profile.daily_burn_goal
        exercise_mode = "standard"
        if severity_rank >= 3:
            effective_steps = min(profile.daily_step_goal, 7000)
            effective_burn = min(profile.daily_burn_goal, 320)
            exercise_mode = "conservative"
        elif severity_rank == 2:
            effective_steps = min(profile.daily_step_goal, 8500)
            effective_burn = min(profile.daily_burn_goal, 420)
            exercise_mode = "moderate"

        calories_target = max(profile.daily_calorie_target, 1200)
        if "diabetes" in condition_slugs:
            floor_ratios = cls._rule_float_map(rule_profiles, "calorie_floor_ratio")
            if floor_ratios:
                calories_target = max(
                    calories_target,
                    int(round(profile.daily_calorie_target * max(floor_ratios))),
                )

        water_target = profile.daily_water_target
        hydration_floor = cls._rule_float_map(rule_profiles, "water_floor_liters")
        if hydration_floor:
            water_target = max(water_target, max(hydration_floor))

        def target_values(target_key: str, attribute: str) -> list[float]:
            values = []
            for target_map in effective_targets:
                target = target_map.get(target_key)
                if target is None:
                    continue
                value = getattr(target, attribute, None)
                if value is not None:
                    values.append(float(value))
            return values

        sodium_values = target_values("sodium_mg", "max_value") or cls._rule_float_map(rule_profiles, "sodium_limit_mg")
        fasting_min_values = target_values("fasting_glucose", "min_value") or cls._rule_float_map(rule_profiles, "fasting_glucose_min")
        fasting_max_values = target_values("fasting_glucose", "max_value") or cls._rule_float_map(rule_profiles, "fasting_glucose_max")
        systolic_values = target_values("blood_pressure_systolic", "max_value") or cls._rule_float_map(rule_profiles, "bp_systolic_max")
        diastolic_values = target_values("blood_pressure_diastolic", "max_value") or cls._rule_float_map(rule_profiles, "bp_diastolic_max")
        ldl_values = target_values("ldl_cholesterol", "max_value") or cls._rule_float_map(rule_profiles, "ldl_target")

        summaries: list[str] = []
        if sodium_values:
            summaries.append(
                f"Daily sodium limit set to {int(min(sodium_values))} mg."
            )
        if "diabetes" in condition_slugs:
            summaries.append("Unsweetened drinks are preferred for hydration.")
            summaries.append("Calorie guidance is kept conservative to avoid unsafe restriction.")
        if "hypertension" in condition_slugs:
            summaries.append("Activity guidance favors moderate, regular movement.")
        if "dyslipidemia" in condition_slugs:
            summaries.append("Heart-healthy fat and fiber guidance is active.")
        if exercise_mode != "standard":
            summaries.append("Activity targets were adjusted to a safer level for your condition mix.")

        medication_count_today, pending_doses_today = ConditionMedicationService.today_dose_counts(
            user=user,
            on_date=on_date,
        )

        return EffectiveConditionConstraints(
            calories_target=calories_target,
            water_target_liters=round(water_target, 2),
            step_target=effective_steps,
            burn_target=effective_burn,
            exercise_intensity_mode=exercise_mode,
            applied_summaries=tuple(dict.fromkeys(summaries)),
            active_condition_labels=labels,
            medication_count_today=medication_count_today,
            pending_doses_today=pending_doses_today,
            adherence_percent=cls._latest_adherence_percent(
                on_date=on_date,
                conditions=conditions,
            ),
            sodium_limit_mg=min(sodium_values) if sodium_values else None,
            fasting_glucose_min=max(fasting_min_values) if fasting_min_values else None,
            fasting_glucose_max=min(fasting_max_values) if fasting_max_values else None,
            systolic_target=min(systolic_values) if systolic_values else None,
            diastolic_target=min(diastolic_values) if diastolic_values else None,
            ldl_target=min(ldl_values) if ldl_values else None,
        )
