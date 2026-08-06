from __future__ import annotations

from dataclasses import dataclass
from datetime import date, time
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from core.models import (
    ConditionMedication,
    ConditionMedicationLog,
    ConditionMedicationSchedule,
    Nutrient,
    UserNutrientTarget,
)
from core.services.constraints import EffectiveConstraintReader
from core.services.medication_plan_service import MedicationPlanService
from core.services.nutrition.nutrition_service import NutritionService
from core.services.orchestration.health_state_orchestrator import HealthStateOrchestrator
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers


@dataclass(frozen=True)
class MicronutrientSpec:
    code: str
    label: str
    unit: str
    category: str


@dataclass(frozen=True)
class LabReferenceRange:
    test_name: str
    unit: str
    min_value: float
    max_value: float


class MicronutrientTrackingService:
    """Read/write service for daily vitamin and mineral tracking."""

    SPECS = [
        MicronutrientSpec("sodium_mg", "Sodium", "mg", "mineral"),
        MicronutrientSpec("potassium_mg", "Potassium", "mg", "mineral"),
        MicronutrientSpec("calcium_mg", "Calcium", "mg", "mineral"),
        MicronutrientSpec("iron_mg", "Iron", "mg", "mineral"),
        MicronutrientSpec("magnesium_mg", "Magnesium", "mg", "mineral"),
        MicronutrientSpec("zinc_mg", "Zinc", "mg", "mineral"),
        MicronutrientSpec("phosphorus_mg", "Phosphorus", "mg", "mineral"),
        MicronutrientSpec("vitamin_a_mcg", "Vitamin A", "mcg", "vitamin"),
        MicronutrientSpec("vitamin_c_mg", "Vitamin C", "mg", "vitamin"),
        MicronutrientSpec("vitamin_d_mcg", "Vitamin D", "mcg", "vitamin"),
        MicronutrientSpec("vitamin_e_mg", "Vitamin E", "mg", "vitamin"),
        MicronutrientSpec("vitamin_k_mcg", "Vitamin K", "mcg", "vitamin"),
        MicronutrientSpec("vitamin_b1_mg", "Vitamin B1", "mg", "vitamin"),
        MicronutrientSpec("vitamin_b2_mg", "Vitamin B2", "mg", "vitamin"),
        MicronutrientSpec("vitamin_b3_mg", "Vitamin B3", "mg", "vitamin"),
        MicronutrientSpec("vitamin_b6_mg", "Vitamin B6", "mg", "vitamin"),
        MicronutrientSpec("vitamin_b12_mcg", "Vitamin B12", "mcg", "vitamin"),
        MicronutrientSpec("folate_mcg", "Folate", "mcg", "vitamin"),
    ]
    SPECS_BY_CODE = {spec.code: spec for spec in SPECS}
    # App defaults for interpreting user-entered lab values. Labs may use
    # different reference intervals, so these remain informational defaults.
    LAB_RANGES = {
        "sodium_mg": LabReferenceRange("Serum sodium", "mEq/L", 135.0, 145.0),
        "potassium_mg": LabReferenceRange("Serum potassium", "mEq/L", 3.7, 5.2),
        "calcium_mg": LabReferenceRange("Serum calcium", "mg/dL", 8.6, 10.2),
        "iron_mg": LabReferenceRange("Serum iron", "mcg/dL", 60.0, 170.0),
        "magnesium_mg": LabReferenceRange("Serum magnesium", "mg/dL", 1.7, 2.2),
        "zinc_mg": LabReferenceRange("Serum zinc", "mcg/dL", 60.0, 120.0),
        "phosphorus_mg": LabReferenceRange("Serum phosphorus", "mg/dL", 2.5, 4.5),
        "vitamin_a_mcg": LabReferenceRange("Vitamin A", "mcg/dL", 20.0, 60.0),
        "vitamin_c_mg": LabReferenceRange("Vitamin C", "mg/dL", 0.4, 2.0),
        "vitamin_d_mcg": LabReferenceRange("25-OH Vitamin D", "ng/mL", 30.0, 100.0),
        "vitamin_e_mg": LabReferenceRange("Vitamin E", "mg/L", 5.5, 17.0),
        "vitamin_k_mcg": LabReferenceRange("Vitamin K", "ng/mL", 0.13, 1.88),
        "vitamin_b1_mg": LabReferenceRange("Vitamin B1", "nmol/L", 70.0, 180.0),
        "vitamin_b2_mg": LabReferenceRange("Vitamin B2", "mcg/L", 1.0, 19.0),
        "vitamin_b3_mg": LabReferenceRange("Vitamin B3", "mcg/mL", 0.5, 8.45),
        "vitamin_b6_mg": LabReferenceRange("Vitamin B6", "ng/mL", 5.0, 50.0),
        "vitamin_b12_mcg": LabReferenceRange("Vitamin B12", "pg/mL", 160.0, 950.0),
        "folate_mcg": LabReferenceRange("Folate", "ng/mL", 2.0, 20.0),
    }
    TAKEN_STATUSES = {
        ConditionMedicationLog.STATUS_TAKEN,
        ConditionMedicationLog.STATUS_TAKEN_ON_TIME,
        ConditionMedicationLog.STATUS_TAKEN_LATE,
    }

    @classmethod
    def supported_codes(cls) -> list[str]:
        return [spec.code for spec in cls.SPECS]

    @classmethod
    def ensure_catalog(cls) -> None:
        cls._ensure_supported_nutrients()

    @classmethod
    def overview(cls, *, user, on_date: date | None = None, request_id: str = "") -> dict:
        tracking_date = on_date or timezone.localdate()
        cls.ensure_catalog()
        totals = NutritionService.nutrition_totals_for_day(
            user=user,
            on_date=tracking_date,
        )
        custom_targets = {
            target.nutrient.code: target
            for target in UserNutrientTarget.objects.filter(
                user=user,
                period=UserNutrientTarget.PERIOD_DAILY,
            )
            .select_related("nutrient", "linked_medication")
            .order_by("source", "nutrient__code")
        }
        nutrients_by_code = {
            nutrient.code: nutrient
            for nutrient in Nutrient.objects.filter(code__in=cls.supported_codes())
        }
        resolved_rows_by_tracker_code: dict[tuple[str, str], list[dict]] = {}
        for tracker_type in ("nutrition", "micronutrient"):
            for row in EffectiveConstraintReader.get_effective_tracker_constraints(
                user=user,
                tracker_type=tracker_type,
            ):
                key = (tracker_type, str(row.get("metric_key") or ""))
                resolved_rows_by_tracker_code.setdefault(key, []).append(row)
        profile_gender = cls._profile_gender(user)
        profile_age = cls._profile_age(user, today=tracking_date)
        target_definitions = {}
        for spec in cls.SPECS:
            nutrient = nutrients_by_code.get(spec.code)
            tracker_type = "micronutrient"
            if nutrient is not None and (
                nutrient.is_core
                or nutrient.category
                in {Nutrient.CATEGORY_MACRO, Nutrient.CATEGORY_STIMULANT}
            ):
                tracker_type = "nutrition"
            target_definitions[spec.code] = {
                "tracker_type": tracker_type,
                "default": cls._default_target(
                    user=user,
                    code=spec.code,
                    gender=profile_gender,
                    age=profile_age,
                ),
            }
        effective_constraints = EffectiveConstraintReader.get_effective_constraints(
            user=user,
            requests=[
                {
                    "tracker_type": target_definitions[spec.code]["tracker_type"],
                    "constraint_key": spec.code,
                    "default_value": target_definitions[spec.code]["default"][
                        "target_value"
                    ],
                    "default_unit": spec.unit,
                    "default_source": "profile_derived_default",
                }
                for spec in cls.SPECS
            ],
        )
        supplements = cls._supplement_totals(user=user, on_date=tracking_date)
        items = []
        for spec in cls.SPECS:
            custom = custom_targets.get(spec.code)
            target_definition = target_definitions[spec.code]
            tracker_type = target_definition["tracker_type"]
            default_target = target_definition["default"]
            lab_range = cls._lab_range_for(spec.code)
            food_consumed = cls._round(totals.get(spec.code, 0.0))
            supplement_consumed = cls._round(supplements.get(spec.code, 0.0))
            total_consumed = cls._round(food_consumed + supplement_consumed)
            effective = effective_constraints[(tracker_type, spec.code)]
            materialized_rows = resolved_rows_by_tracker_code.get(
                (tracker_type, spec.code),
                [],
            )
            min_candidates = [
                float(row["min_value"])
                for row in materialized_rows
                if row.get("min_value") is not None
            ]
            max_candidates = [
                float(row["max_value"])
                for row in materialized_rows
                if row.get("max_value") is not None
            ]
            min_value = cls._round(max(min_candidates)) if min_candidates else None
            target_value = cls._round(effective.value)
            max_value = (
                cls._round(min(max_candidates))
                if max_candidates
                else default_target.get("max_value")
            )
            progress_percent = 0.0
            if target_value and target_value > 0:
                progress_percent = cls._round(min((total_consumed / target_value) * 100, 999.0))
            items.append(
                {
                    "code": spec.code,
                    "name": spec.label,
                    "unit": spec.unit,
                    "category": spec.category,
                    "food_consumed": food_consumed,
                    "supplement_consumed": supplement_consumed,
                    "total_consumed": total_consumed,
                    "min_value": min_value,
                    "target_value": target_value,
                    "max_value": max_value,
                    "progress_percent": progress_percent,
                    "target_source": effective.source_type,
                    "source_label": effective.reason,
                    "constraint_id": effective.constraint_id,
                    "constraint_priority": effective.priority,
                    "constraint_expires_at": effective.effective_to,
                    "deficiency_tracked": bool(custom),
                    "status": cls._status(
                        total=total_consumed,
                        min_value=min_value,
                        target_value=target_value,
                        max_value=max_value,
                    ),
                    "note": custom.note if custom else "",
                    "lab_context": cls._lab_context_payload(
                        target=custom,
                        default_target=default_target["target_value"],
                        lab_range=lab_range,
                    ),
                    "lab_range": cls._lab_range_payload(lab_range),
                    "linked_medication": cls._linked_medication_payload(custom),
                }
            )
        return {
            "data": {
                "date": str(tracking_date),
                "items": items,
                "disclaimer": (
                    "Micronutrient tracking is informational and does not replace "
                    "medical advice. Review supplements with a clinician, especially "
                    "when taking medications."
                ),
            },
            "meta": {
                "is_stale": False,
                "computed_at": timezone.now().isoformat(),
                "snapshot_version": "micronutrient-v1",
                "request_id": request_id,
            },
        }

    @classmethod
    def upsert_target(cls, *, user, payload: dict, request_id: str = "") -> dict:
        target, medication = cls._persist_target(user=user, payload=payload)
        HealthStateOrchestrator().handle_event(
            user=user,
            trigger_type=HealthStateTriggers.USER_NUTRIENT_TARGET_CHANGED,
            payload={
                "trigger_reference": str(target.id),
                "source_id": target.id,
                "event_dates": [timezone.localdate()],
                "nutrient_code": target.nutrient.code,
                "linked_medication_id": (
                    medication.id if medication else target.linked_medication_id
                ),
            },
            synchronous=True,
        )
        return cls.overview(user=user, request_id=request_id)

    @classmethod
    @transaction.atomic
    def _persist_target(cls, *, user, payload: dict):
        cls.ensure_catalog()
        nutrient = payload["nutrient"]
        default_target = cls._default_target(
            user=user,
            code=nutrient.code,
            gender=cls._profile_gender(user),
            age=cls._profile_age(user, today=timezone.localdate()),
        )
        lab_range = cls._lab_range_for(nutrient.code)
        normalized_payload = {
            **payload,
            "lab_test_name": payload.get("lab_test_name") or lab_range.test_name,
            "lab_unit": payload.get("lab_unit") or lab_range.unit,
            "lab_reference_min": (
                payload.get("lab_reference_min")
                if payload.get("lab_reference_min") is not None
                else lab_range.min_value
            ),
            "lab_reference_max": (
                payload.get("lab_reference_max")
                if payload.get("lab_reference_max") is not None
                else lab_range.max_value
            ),
        }
        suggestion = cls._suggest_daily_target(
            default_value=default_target["target_value"],
            payload=normalized_payload,
        )
        target_value = normalized_payload.get("target_value")
        calculation_basis = "manual"
        if target_value is None and suggestion["target_value"] is not None:
            target_value = suggestion["target_value"]
            calculation_basis = suggestion["basis"]
        elif normalized_payload.get("clinician_recommended_value") is not None:
            calculation_basis = "clinician"
        elif normalized_payload.get("lab_value") is not None:
            calculation_basis = suggestion["basis"]
        min_value = normalized_payload.get("min_value")
        max_value = normalized_payload.get("max_value")
        if calculation_basis == "lab_below_range" and min_value is None:
            min_value = target_value
        if calculation_basis == "lab_above_range" and max_value is None:
            max_value = target_value

        target, _ = UserNutrientTarget.objects.update_or_create(
            user=user,
            nutrient=nutrient,
            period=UserNutrientTarget.PERIOD_DAILY,
            source=UserNutrientTarget.SOURCE_MANUAL,
            defaults={
                "min_value": min_value,
                "target_value": target_value,
                "max_value": max_value,
                "note": normalized_payload.get("note", ""),
                "lab_test_name": normalized_payload.get("lab_test_name", ""),
                "lab_value": normalized_payload.get("lab_value"),
                "lab_unit": normalized_payload.get("lab_unit", ""),
                "lab_reference_min": normalized_payload.get("lab_reference_min"),
                "lab_reference_max": normalized_payload.get("lab_reference_max"),
                "lab_test_date": normalized_payload.get("lab_test_date"),
                "clinician_recommended_value": normalized_payload.get("clinician_recommended_value"),
                "calculation_basis": calculation_basis,
                "current_medication_name": normalized_payload.get("current_medication_name", ""),
                "current_medication_dose": normalized_payload.get("current_medication_dose", ""),
            },
        )
        medication = None
        if payload.get("create_medication_plan"):
            medication = cls._create_or_update_supplement_medication(
                user=user,
                target=target,
                nutrient=nutrient,
                payload=payload,
            )
            target.linked_medication = medication
            target.save(update_fields=["linked_medication"])
        return target, medication

    @classmethod
    def _create_or_update_supplement_medication(
        cls,
        *,
        user,
        target: UserNutrientTarget,
        nutrient: Nutrient,
        payload: dict,
    ) -> ConditionMedication:
        schedule_time = payload.get("schedule_time") or time(hour=9, minute=0)
        amount = payload.get("supplement_amount")
        unit = payload.get("supplement_unit") or nutrient.unit
        dose_note = (payload.get("current_medication_dose") or "").strip()
        name = (
            payload.get("supplement_name")
            or payload.get("current_medication_name")
            or f"{nutrient.name} supplement"
        )
        dosage = f"{amount:g} {unit}".strip() if amount is not None else dose_note
        if not dosage:
            dosage = unit
        medication_payload = {
            "display_name": name,
            "name": name,
            "source_type": ConditionMedication.SOURCE_MANUAL,
            "dose_amount": str(amount or ""),
            "dose_unit": unit,
            "dosage": dosage,
            "form": "supplement",
            "instructions": (
                "Supplement linked to micronutrient tracking. Confirm dosing "
                "with your clinician."
            ),
            "start_date": timezone.localdate(),
            "is_active": True,
            "is_prn": False,
            "adherence_mode": ConditionMedication.ADHERENCE_FLEXIBLE,
            "reminder_enabled": True,
            "schedules": [
                {
                    "schedule_type": ConditionMedicationSchedule.TYPE_DAILY,
                    "time": schedule_time,
                    "meal_relation": ConditionMedicationSchedule.MEAL_WITH_FOOD,
                    "grace_period_minutes": 120,
                    "snooze_default_minutes": 15,
                    "is_active": True,
                }
            ],
            "supplement_nutrient_id": nutrient.id,
            "supplement_nutrient_amount": amount,
            "supplement_nutrient_unit": unit,
        }
        if target.linked_medication_id:
            medication = MedicationPlanService.update_medication_plan(
                user=user,
                medication_id=target.linked_medication_id,
                payload=medication_payload,
            )
        else:
            medication = MedicationPlanService.create_medication_plan(
                user=user,
                payload=medication_payload,
            )
        medication.supplement_nutrient = nutrient
        medication.supplement_nutrient_amount = amount
        medication.supplement_nutrient_unit = unit
        medication.save(
            update_fields=[
                "supplement_nutrient",
                "supplement_nutrient_amount",
                "supplement_nutrient_unit",
                "updated_at",
            ]
        )
        return medication

    @classmethod
    def _supplement_totals(cls, *, user, on_date: date) -> dict[str, float]:
        totals = {code: 0.0 for code in cls.supported_codes()}
        logs = (
            ConditionMedicationLog.objects.filter(
                medication__user=user,
                medication__supplement_nutrient__code__in=cls.supported_codes(),
                scheduled_date=on_date,
                status__in=cls.TAKEN_STATUSES,
            )
            .select_related("medication__supplement_nutrient")
            .order_by("id")
        )
        for log in logs:
            medication = log.medication
            if medication is None or medication.supplement_nutrient is None:
                continue
            code = medication.supplement_nutrient.code
            amount = medication.supplement_nutrient_amount
            if log.dose_taken_amount is not None:
                amount = cls._decimal_to_float(log.dose_taken_amount)
            totals[code] = totals.get(code, 0.0) + float(amount or 0)
        return totals

    @classmethod
    def _ensure_supported_nutrients(cls) -> None:
        for spec in cls.SPECS:
            Nutrient.objects.get_or_create(
                code=spec.code,
                defaults={
                    "name": spec.label,
                    "unit": spec.unit,
                    "category": spec.category,
                    "is_core": False,
                },
            )

    @staticmethod
    def _profile_gender(user) -> str:
        profile = getattr(user, "userprofile", None)
        return (getattr(profile, "gender", "") or "").upper()

    @staticmethod
    def _profile_age(user, *, today: date) -> int:
        profile = getattr(user, "userprofile", None)
        birth_date = getattr(profile, "birth_date", None)
        if birth_date is None:
            return 30
        return max(1, today.year - birth_date.year - ((today.month, today.day) < (birth_date.month, birth_date.day)))

    @classmethod
    def _default_target(cls, *, user, code: str, gender: str, age: int) -> dict:
        male = gender == "M"
        source = "profile_derived_default"
        if code == "sodium_mg":
            return {"target_value": 1500.0, "max_value": 2300.0, "source": source}
        if code == "potassium_mg":
            return {"target_value": 3400.0 if male else 2600.0, "source": source}
        if code == "calcium_mg":
            target = 1200.0 if (age >= 71 or (not male and age >= 51) or age <= 18) else 1000.0
            return {"target_value": target, "source": source}
        if code == "iron_mg":
            target = 18.0 if (not male and 19 <= age <= 50) else 8.0
            if age <= 18:
                target = 11.0 if male else 15.0
            return {"target_value": target, "source": source}
        if code == "magnesium_mg":
            if age <= 18:
                target = 410.0 if male else 360.0
            elif age <= 30:
                target = 400.0 if male else 310.0
            else:
                target = 420.0 if male else 320.0
            return {"target_value": target, "source": source}
        if code == "zinc_mg":
            return {"target_value": 11.0 if male else 8.0, "source": source}
        if code == "phosphorus_mg":
            return {"target_value": 1250.0 if age <= 18 else 700.0, "source": source}
        if code == "vitamin_a_mcg":
            return {"target_value": 900.0 if male else 700.0, "source": source}
        if code == "vitamin_c_mg":
            return {"target_value": 90.0 if male else 75.0, "source": source}
        if code == "vitamin_d_mcg":
            return {"target_value": 20.0 if age >= 71 else 15.0, "source": source}
        if code == "vitamin_e_mg":
            return {"target_value": 15.0, "source": source}
        if code == "vitamin_k_mcg":
            return {"target_value": 120.0 if male else 90.0, "source": source}
        if code == "vitamin_b1_mg":
            return {"target_value": 1.2 if male else 1.1, "source": source}
        if code == "vitamin_b2_mg":
            return {"target_value": 1.3 if male else 1.1, "source": source}
        if code == "vitamin_b3_mg":
            return {"target_value": 16.0 if male else 14.0, "source": source}
        if code == "vitamin_b6_mg":
            if age >= 51:
                return {"target_value": 1.7 if male else 1.5, "source": source}
            return {"target_value": 1.3, "source": source}
        if code == "vitamin_b12_mcg":
            return {"target_value": 2.4, "source": source}
        if code == "folate_mcg":
            return {"target_value": 400.0, "source": source}
        return {"target_value": 0.0, "source": source}

    @staticmethod
    def _source_label(*, custom: UserNutrientTarget | None) -> str:
        if custom is None:
            return "Default daily need based on age and profile."
        if custom.calculation_basis == "clinician":
            return "Custom target based on clinician recommendation."
        if custom.calculation_basis in {"lab_below_range", "lab_above_range", "lab_in_range"}:
            return "Custom target adjusted from lab context."
        if custom.linked_medication_id:
            return "Deficiency target linked to supplement reminders."
        return "Custom deficiency tracking target."

    @staticmethod
    def _status(
        *,
        total: float,
        min_value: float | None,
        target_value: float | None,
        max_value: float | None,
    ) -> str:
        if max_value is not None and total > max_value:
            return "over_limit"
        if min_value is not None and total < min_value:
            return "below_min"
        if target_value and target_value > 0:
            if total >= target_value:
                return "met"
            if total < target_value * 0.5:
                return "low"
        return "in_progress"

    @classmethod
    def _linked_medication_payload(cls, target: UserNutrientTarget | None) -> dict | None:
        if target is None or target.linked_medication is None:
            return None
        medication = target.linked_medication
        return {
            "id": medication.id,
            "display_name": medication.display_name or medication.name,
            "dose_amount": medication.dosage_amount,
            "dose_unit": medication.dosage_unit,
            "is_active": medication.is_active,
        }

    @classmethod
    def _suggest_daily_target(cls, *, default_value: float, payload: dict) -> dict:
        clinician_value = payload.get("clinician_recommended_value")
        if clinician_value is not None and clinician_value > 0:
            return {
                "target_value": cls._round(clinician_value),
                "basis": "clinician",
                "reason": "Clinician recommendation provided by the user.",
            }

        lab_value = payload.get("lab_value")
        if lab_value is None or default_value <= 0:
            return {
                "target_value": None,
                "basis": "manual",
                "reason": "No lab context was provided.",
            }

        reference_min = payload.get("lab_reference_min")
        reference_max = payload.get("lab_reference_max")
        if reference_min is not None and lab_value < reference_min:
            return {
                "target_value": cls._round(default_value * 1.25),
                "basis": "lab_below_range",
                "reason": (
                    "Lab value is below this nutrient's normal range. "
                    "The app raises the daily intake target and supports a "
                    "food-first plan with optional supplements."
                ),
            }
        if reference_max is not None and lab_value > reference_max:
            return {
                "target_value": cls._round(default_value * 0.8),
                "basis": "lab_above_range",
                "reason": (
                    "Lab value is above this nutrient's normal range. "
                    "The app lowers the daily target pressure and marks extra "
                    "supplement intake as something to avoid."
                ),
            }
        return {
            "target_value": cls._round(default_value),
            "basis": "lab_in_range",
            "reason": (
                "Lab value is within the provided reference range, so the profile "
                "daily need remains the suggested tracking target."
            ),
        }

    @classmethod
    def _lab_context_payload(
        cls,
        *,
        target: UserNutrientTarget | None,
        default_target: float,
        lab_range: LabReferenceRange,
    ) -> dict | None:
        if target is None:
            return None
        suggestion = cls._suggest_daily_target(
            default_value=default_target,
            payload={
                "lab_value": target.lab_value,
                "lab_reference_min": target.lab_reference_min
                if target.lab_reference_min is not None
                else lab_range.min_value,
                "lab_reference_max": target.lab_reference_max
                if target.lab_reference_max is not None
                else lab_range.max_value,
                "clinician_recommended_value": target.clinician_recommended_value,
            },
        )
        if (
            target.lab_value is None
            and target.clinician_recommended_value is None
            and not target.current_medication_name
        ):
            return None
        plan = cls._improvement_plan(
            lab_value=target.lab_value,
            reference_min=target.lab_reference_min
            if target.lab_reference_min is not None
            else lab_range.min_value,
            reference_max=target.lab_reference_max
            if target.lab_reference_max is not None
            else lab_range.max_value,
            suggested_target=suggestion["target_value"],
            default_target=default_target,
        )
        return {
            "test_name": target.lab_test_name,
            "value": cls._round(target.lab_value) if target.lab_value is not None else None,
            "unit": target.lab_unit or lab_range.unit,
            "reference_min": (
                cls._round(target.lab_reference_min)
                if target.lab_reference_min is not None
                else cls._round(lab_range.min_value)
            ),
            "reference_max": (
                cls._round(target.lab_reference_max)
                if target.lab_reference_max is not None
                else cls._round(lab_range.max_value)
            ),
            "test_date": str(target.lab_test_date) if target.lab_test_date else "",
            "clinician_recommended_value": (
                cls._round(target.clinician_recommended_value)
                if target.clinician_recommended_value is not None
                else None
            ),
            "calculation_basis": target.calculation_basis or suggestion["basis"],
            "suggested_target_value": suggestion["target_value"],
            "suggested_target_reason": suggestion["reason"],
            "improvement_plan": plan,
            "current_medication_name": target.current_medication_name,
            "current_medication_dose": target.current_medication_dose,
        }

    @classmethod
    def _improvement_plan(
        cls,
        *,
        lab_value: float | None,
        reference_min: float | None,
        reference_max: float | None,
        suggested_target: float | None,
        default_target: float,
    ) -> dict:
        if lab_value is None:
            return {
                "status": "not_configured",
                "review_after_weeks": 8,
                "daily_food_target": cls._round(default_target),
                "supplement_gap": 0.0,
                "message": "Add the current lab value to build a plan.",
            }
        if reference_min is not None and lab_value < reference_min:
            gap = max((suggested_target or default_target) - default_target, 0)
            return {
                "status": "build_up",
                "review_after_weeks": 8,
                "daily_food_target": cls._round(default_target),
                "supplement_gap": cls._round(gap),
                "message": (
                    "Focus on foods that contain this nutrient first. "
                    "Use the supplement gap only if a supplement plan is enabled."
                ),
            }
        if reference_max is not None and lab_value > reference_max:
            return {
                "status": "avoid_excess",
                "review_after_weeks": 8,
                "daily_food_target": cls._round(suggested_target or default_target),
                "supplement_gap": 0.0,
                "message": "Avoid extra supplement pressure and keep food intake moderate.",
            }
        return {
            "status": "maintain",
            "review_after_weeks": 12,
            "daily_food_target": cls._round(default_target),
            "supplement_gap": 0.0,
            "message": "Maintain the regular daily target and recheck later.",
        }

    @classmethod
    def _lab_range_for(cls, code: str) -> LabReferenceRange:
        return cls.LAB_RANGES.get(
            code,
            LabReferenceRange("Lab value", "", 0.0, 0.0),
        )

    @classmethod
    def _lab_range_payload(cls, lab_range: LabReferenceRange) -> dict:
        return {
            "test_name": lab_range.test_name,
            "unit": lab_range.unit,
            "reference_min": cls._round(lab_range.min_value),
            "reference_max": cls._round(lab_range.max_value),
        }

    @staticmethod
    def _round(value) -> float:
        return round(float(value or 0), 2)

    @staticmethod
    def _decimal_to_float(value: Decimal) -> float:
        return float(value)
