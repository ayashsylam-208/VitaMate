from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from django.db import transaction
from django.utils import timezone

from rest_framework.exceptions import ValidationError

from users.models import UserProfile

from core.models import (
    FoodItem,
    MealLog,
    NutritionFacts,
    NutritionServingOption,
    WaterLog,
)
from core.repositories.hydration.water_log_repository import HydrationRepository
from core.repositories.food_item_repository import NutritionCatalogRepository
from core.repositories.meal_log_repository import MealLogRepository
from core.services.food_search_service import FoodSearchService
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers
from users.repositories.user_profile_repository import UserProfileRepository
from gamification.services.points_service import PointsService


NUTRIENT_FIELDS = [
    "calories_kcal",
    "protein_g",
    "carbohydrates_g",
    "sugars_g",
    "fiber_g",
    "fat_g",
    "saturated_fat_g",
    "trans_fat_g",
    "cholesterol_mg",
    "sodium_mg",
    "potassium_mg",
    "calcium_mg",
    "iron_mg",
    "magnesium_mg",
    "zinc_mg",
    "phosphorus_mg",
    "vitamin_a_mcg",
    "vitamin_c_mg",
    "vitamin_d_mcg",
    "vitamin_b12_mcg",
    "folate_mcg",
    "monounsaturated_fat_g",
    "polyunsaturated_fat_g",
    "added_sugars_g",
    "water_g",
    "caffeine_mg",
    "vitamin_e_mg",
    "vitamin_k_mcg",
    "vitamin_b1_mg",
    "vitamin_b2_mg",
    "vitamin_b3_mg",
    "vitamin_b6_mg",
]

SNAPSHOT_FIELD_MAP = {field: f"snapshot_{field}" for field in NUTRIENT_FIELDS}
SNAPSHOT_TOTAL_KEYS = {
    "calories_kcal": "calories_kcal",
    "protein_g": "protein_g",
    "carbohydrates_g": "carbs_g",
    "sugars_g": "sugars_g",
    "added_sugars_g": "added_sugars_g",
    "fiber_g": "fiber_g",
    "fat_g": "fat_g",
    "saturated_fat_g": "saturated_fat_g",
    "trans_fat_g": "trans_fat_g",
    "cholesterol_mg": "cholesterol_mg",
    "sodium_mg": "sodium_mg",
    "potassium_mg": "potassium_mg",
    "vitamin_c_mg": "vitamin_c_mg",
    "caffeine_mg": "caffeine_mg",
}


@dataclass(frozen=True)
class ConsumptionAmount:
    quantity: float
    unit: str
    grams: float | None
    milliliters: float | None
    servings: float | None


class NutritionLoggingService:
    """Command-side service for nutrition item writes and consumption logging."""

    @staticmethod
    @transaction.atomic
    def create_food_item(data):
        facts_data = data.pop("nutrition_facts", None)
        serving_options_data = data.pop("serving_options", [])

        legacy_facts = NutritionLoggingService._facts_from_legacy_fields(data)
        if facts_data is None:
            facts_data = legacy_facts
        else:
            facts_data = {**legacy_facts, **facts_data}

        item_defaults = NutritionLoggingService._legacy_food_values_from_facts(
            data=data,
            facts_data=facts_data,
        )
        data.update(item_defaults)
        NutritionLoggingService._apply_item_metadata_defaults(data, facts_data)
        NutritionLoggingService._apply_category_defaults(data)

        if not serving_options_data:
            serving_options_data = NutritionLoggingService._default_serving_options(data)

        return NutritionCatalogRepository.create_item_aggregate(
            item_data=data,
            facts_data=facts_data,
            serving_options_data=serving_options_data,
        )

    @staticmethod
    @transaction.atomic
    def update_food_item(item, data):
        facts_data = data.pop("nutrition_facts", None)
        serving_options_data = data.pop("serving_options", None)

        if facts_data is not None:
            merged_facts = NutritionLoggingService._facts_from_legacy_fields(data)
            merged_facts.update(facts_data)
            data.update(
                NutritionLoggingService._legacy_food_values_from_facts(
                    data=data,
                    facts_data=merged_facts,
                )
            )
            NutritionLoggingService._apply_item_metadata_defaults(data, merged_facts)
            NutritionLoggingService._apply_category_defaults(data)
        return NutritionCatalogRepository.update_item_aggregate(
            item=item,
            item_data=data,
            facts_data=merged_facts if facts_data is not None else None,
            serving_options_data=serving_options_data,
        )

    @staticmethod
    @transaction.atomic
    def log_meal(
        *,
        user,
        food,
        meal_type,
        quantity_grams=None,
        quantity=None,
        unit=None,
        serving_option=None,
        consumed_at=None,
        notes="",
        source=MealLog.SOURCE_MANUAL,
        sync_hydration=True,
        publish_event=True,
    ):
        consumed_at_provided = consumed_at is not None
        amount = NutritionLoggingService._resolve_consumption_amount(
            food=food,
            quantity_grams=quantity_grams,
            quantity=quantity,
            unit=unit,
            serving_option=serving_option,
        )
        snapshot = NutritionLoggingService._calculate_snapshot(food=food, amount=amount)
        consumed_at = consumed_at or timezone.now()

        log = MealLogRepository.create_for_user(
            user=user,
            food=food,
            meal_type=meal_type,
            quantity_grams=amount.grams if amount.grams is not None else quantity_grams or 0,
            quantity=amount.quantity,
            unit=amount.unit,
            grams_consumed=amount.grams,
            milliliters_consumed=amount.milliliters,
            servings_consumed=amount.servings,
            serving_option=serving_option,
            consumed_at=consumed_at,
            notes=notes or "",
            source=source or MealLog.SOURCE_MANUAL,
            **snapshot,
        )
        if consumed_at:
            log.date = consumed_at.date() if consumed_at_provided else date.today()
            MealLogRepository.save(log, update_fields=["date"])

        if sync_hydration:
            NutritionLoggingService._sync_hydration_log_for_meal(log)

        meals = MealLogRepository.get_for_user_on_date(user, log.date)
        calories_in = sum(m.total_calories for m in meals)

        try:
            profile = UserProfileRepository.get_for_user(user)
        except UserProfile.DoesNotExist:
            profile = None

        if profile is not None:
            target = getattr(profile, "daily_calorie_target", None)
            if target:
                from core.services.constraints import ConstraintReadService

                target = ConstraintReadService.effective_numeric_value(
                    user=user,
                    tracker_type="nutrition",
                    metric_key="calories_kcal",
                    fallback=target,
                )
            if target:
                PointsService.apply_meal_points(user, calories_in, target)

        if publish_event:
            HealthStateEventPublisher.publish_on_commit(
                user=user,
                trigger_type=HealthStateTriggers.MEAL_LOGGED,
                payload={
                    "trigger_reference": str(log.id),
                    "source_id": log.id,
                    "event_dates": [log.date],
                },
            )

        return log

    @staticmethod
    def summarize_meal_logs(meals) -> dict[str, float]:
        totals = {key: 0.0 for key in SNAPSHOT_TOTAL_KEYS.values()}
        for meal in meals:
            if meal.snapshot_calories_kcal is not None:
                for field, key in SNAPSHOT_TOTAL_KEYS.items():
                    totals[key] += float(getattr(meal, SNAPSHOT_FIELD_MAP[field], 0) or 0)
                continue

            factor = (meal.quantity_grams or 0) / 100.0
            food = meal.food
            totals["calories_kcal"] += float(food.calories_100g or 0) * factor
            totals["protein_g"] += float(food.protein_100g or 0) * factor
            totals["carbs_g"] += float(food.carbs_100g or 0) * factor
            totals["fat_g"] += float(food.fat_100g or 0) * factor
            totals["fiber_g"] += float(food.fiber_100g or 0) * factor
            totals["sugars_g"] += float(food.sugar_100g or 0) * factor
            totals["sodium_mg"] += float(food.sodium_mg_100g or 0) * factor
            totals["saturated_fat_g"] += float(food.saturated_fat_100g or 0) * factor
            totals["trans_fat_g"] += float(food.trans_fat_100g or 0) * factor
            totals["potassium_mg"] += float(food.potassium_mg_100g or 0) * factor
            totals["cholesterol_mg"] += float(food.cholesterol_mg_100g or 0) * factor
            totals["vitamin_c_mg"] += float(food.vitamin_c_mg_100g or 0) * factor
        return totals

    @staticmethod
    def nutrition_totals_for_day(*, user, on_date: date) -> dict[str, float]:
        meals = MealLogRepository.get_for_user_on_date(user, on_date)
        return NutritionLoggingService.summarize_meal_logs(meals)

    @staticmethod
    def accessible_foods(
        *,
        user,
        item_type: str | None = None,
        query: str = "",
        category: str | None = None,
        contains_caffeine=None,
        is_hydration_trackable=None,
        limit=None,
        include_inactive: bool = False,
        own_only: bool = False,
    ):
        return FoodSearchService.search(
            user=user,
            q=query,
            item_type=item_type,
            category=category,
            contains_caffeine=contains_caffeine,
            is_hydration_trackable=is_hydration_trackable,
            limit=limit,
            include_inactive=include_inactive,
            own_only=own_only,
        )

    @staticmethod
    def get_accessible_food_item(*, user, food_item_id: int, item_type: str | None = None):
        queryset = NutritionLoggingService.accessible_foods(
            user=user,
            item_type=item_type,
            include_inactive=True,
        )
        item = queryset.filter(id=food_item_id).first()
        if item is None:
            raise ValueError("The selected beverage is not available.")
        return item

    @staticmethod
    @transaction.atomic
    def update_meal_log(
        meal_log,
        *,
        food,
        meal_type=None,
        quantity_grams=None,
        quantity=None,
        unit=None,
        serving_option=None,
        consumed_at=None,
        notes=None,
        source=None,
        sync_hydration=True,
        publish_event=True,
    ):
        previous_date = meal_log.date
        consumed_at_provided = consumed_at is not None
        amount = NutritionLoggingService._resolve_consumption_amount(
            food=food,
            quantity_grams=quantity_grams,
            quantity=quantity,
            unit=unit,
            serving_option=serving_option,
        )
        snapshot = NutritionLoggingService._calculate_snapshot(food=food, amount=amount)
        consumed_at = consumed_at or meal_log.consumed_at or timezone.now()

        meal_log.food = food
        meal_log.meal_type = meal_type or meal_log.meal_type
        meal_log.quantity_grams = amount.grams if amount.grams is not None else quantity_grams or 0
        meal_log.quantity = amount.quantity
        meal_log.unit = amount.unit
        meal_log.grams_consumed = amount.grams
        meal_log.milliliters_consumed = amount.milliliters
        meal_log.servings_consumed = amount.servings
        meal_log.serving_option = serving_option
        meal_log.consumed_at = consumed_at
        meal_log.notes = notes if notes is not None else meal_log.notes
        meal_log.source = source or meal_log.source or MealLog.SOURCE_MANUAL
        meal_log.date = consumed_at.date() if consumed_at_provided else previous_date
        for field, value in snapshot.items():
            setattr(meal_log, field, value)
        meal_log = MealLogRepository.save(meal_log)
        if sync_hydration:
            NutritionLoggingService._sync_hydration_log_for_meal(meal_log)
        if publish_event:
            HealthStateEventPublisher.publish_on_commit(
                user=meal_log.user,
                trigger_type=HealthStateTriggers.MEAL_UPDATED,
                payload={
                    "trigger_reference": str(meal_log.id),
                    "source_id": meal_log.id,
                    "event_dates": [previous_date, meal_log.date],
                },
            )
        return meal_log

    @staticmethod
    def delete_meal_log(meal_log, *, publish_event=True):
        user = meal_log.user
        meal_id = meal_log.id
        event_date = meal_log.date
        linked_water_log = HydrationRepository.get_for_linked_meal_log(meal_log)
        if linked_water_log is not None:
            HydrationRepository.delete(linked_water_log)
        MealLogRepository.delete(meal_log)
        if publish_event:
            HealthStateEventPublisher.publish_on_commit(
                user=user,
                trigger_type=HealthStateTriggers.MEAL_DELETED,
                payload={
                    "trigger_reference": str(meal_id),
                    "source_id": meal_id,
                    "event_dates": [event_date],
                },
            )

    @staticmethod
    @transaction.atomic
    def ensure_standard_water_item():
        existing = NutritionCatalogRepository.get_global_item_by_name(
            name="Water",
            item_type=FoodItem.TYPE_BEVERAGE,
        )
        if existing is not None:
            return existing

        return NutritionLoggingService.create_food_item(
            {
                "name": "Water",
                "item_type": FoodItem.TYPE_BEVERAGE,
                "category": "Water",
                "source": FoodItem.SOURCE_MANUAL,
                "default_serving_size": 250,
                "default_serving_unit": "ml",
                "default_reference_unit": "ml",
                "density_g_per_ml": 1.0,
                "is_hydration_trackable": True,
                "is_verified": True,
                "serving_label": "Glass",
                "serving_grams": 250,
                "nutrition_facts": {
                    "basis_type": NutritionFacts.BASIS_PER_100ML,
                    "basis_value": 100,
                    "basis_amount": 100,
                    "basis_unit": "ml",
                    "serving_size": 100,
                    "serving_unit": "ml",
                    "water_g": 100,
                },
                "serving_options": [
                    {
                        "name": "Glass 250ml",
                        "amount": 1,
                        "unit": "serving",
                        "grams_equivalent": 250,
                        "milliliters_equivalent": 250,
                        "is_default": True,
                    },
                ],
            }
        )

    @staticmethod
    @transaction.atomic
    def create_custom_beverage(*, user, beverage_data: dict, save_for_reuse: bool = True):
        name = str(beverage_data.get("name") or "").strip()
        if not name:
            raise ValidationError({"custom_beverage": {"name": "This field is required."}})

        category = str(
            beverage_data.get("category")
            or beverage_data.get("beverage_type")
            or "Custom Beverage",
        ).strip()

        facts = {
            "basis_type": NutritionFacts.BASIS_PER_100ML,
            "basis_value": 100,
            "basis_amount": 100,
            "basis_unit": "ml",
            "serving_size": 100,
            "serving_unit": "ml",
            "calories_kcal": NutritionLoggingService._numeric_custom_value(
                beverage_data,
                "calories_kcal",
            ),
            "protein_g": NutritionLoggingService._numeric_custom_value(
                beverage_data,
                "protein_g",
            ),
            "carbohydrates_g": NutritionLoggingService._numeric_custom_value(
                beverage_data,
                "carbohydrates_g",
            ),
            "fat_g": NutritionLoggingService._numeric_custom_value(beverage_data, "fat_g"),
            "sugars_g": NutritionLoggingService._numeric_custom_value(
                beverage_data,
                "sugars_g",
            ),
            "fiber_g": NutritionLoggingService._numeric_custom_value(beverage_data, "fiber_g"),
            "sodium_mg": NutritionLoggingService._numeric_custom_value(
                beverage_data,
                "sodium_mg",
            ),
            "caffeine_mg": NutritionLoggingService._numeric_custom_value(
                beverage_data,
                "caffeine_mg",
            ),
            "water_g": NutritionLoggingService._numeric_custom_value(beverage_data, "water_g"),
        }

        return NutritionLoggingService.create_food_item(
            {
                "name": name,
                "created_by": user,
                "item_type": FoodItem.TYPE_BEVERAGE,
                "category": category,
                "source": FoodItem.SOURCE_CUSTOM,
                "default_serving_size": 250,
                "default_serving_unit": "ml",
                "default_reference_unit": "ml",
                "density_g_per_ml": 1.0,
                "is_hydration_trackable": True,
                "is_verified": False,
                "is_active": save_for_reuse,
                "serving_label": "Glass",
                "serving_grams": 250,
                "nutrition_facts": facts,
                "serving_options": [
                    {
                        "name": "Glass 250ml",
                        "amount": 1,
                        "unit": "serving",
                        "grams_equivalent": 250,
                        "milliliters_equivalent": 250,
                        "is_default": True,
                    },
                ],
            }
        )

    @staticmethod
    def _sync_hydration_log_for_meal(meal_log: MealLog):
        linked_water_log = HydrationRepository.get_for_linked_meal_log(meal_log)
        if not NutritionLoggingService._should_sync_meal_to_hydration(meal_log):
            if linked_water_log is not None:
                HydrationRepository.delete(linked_water_log)
            return None

        beverage_volume_liters = NutritionLoggingService._meal_volume_liters(meal_log)
        if beverage_volume_liters <= 0:
            if linked_water_log is not None:
                HydrationRepository.delete(linked_water_log)
            return None

        beverage_type = NutritionLoggingService._beverage_choice_for_food(meal_log.food)
        beverage_name = meal_log.food.name.strip() or "Water"
        if linked_water_log is None:
            linked_water_log = HydrationRepository.create_for_user(
                user=meal_log.user,
                amount_liter=beverage_volume_liters,
                beverage_type=beverage_type,
                beverage_name=beverage_name,
                food_item=meal_log.food,
                drink_item=meal_log.food,
                linked_meal_log=meal_log,
            )
            if linked_water_log.date != meal_log.date:
                linked_water_log.date = meal_log.date
                HydrationRepository.save(linked_water_log, update_fields=["date"])
            return linked_water_log

        linked_water_log.amount_liter = beverage_volume_liters
        linked_water_log.beverage_type = beverage_type
        linked_water_log.beverage_name = beverage_name
        linked_water_log.food_item = meal_log.food
        linked_water_log.drink_item = meal_log.food
        linked_water_log.linked_meal_log = meal_log
        linked_water_log.date = meal_log.date
        return HydrationRepository.save(
            linked_water_log,
            update_fields=[
                "amount_liter",
                "beverage_type",
                "beverage_name",
                "food_item",
                "drink_item",
                "linked_meal_log",
                "date",
            ],
        )

    @staticmethod
    def _should_sync_meal_to_hydration(meal_log: MealLog) -> bool:
        return (
            meal_log.meal_type == "drink"
            and meal_log.food is not None
            and (meal_log.food.is_drink or meal_log.food.is_hydration_trackable)
        )

    @staticmethod
    def _meal_volume_liters(meal_log: MealLog) -> float:
        milliliters = float(meal_log.milliliters_consumed or 0)
        if milliliters > 0:
            return milliliters / 1000.0
        grams = float(meal_log.grams_consumed or 0)
        density = NutritionLoggingService._density_or_default(meal_log.food)
        if grams > 0 and density:
            return (grams / density) / 1000.0
        return 0.0

    @staticmethod
    def _beverage_choice_for_food(food_item: FoodItem) -> str:
        text = " ".join(
            part
            for part in [
                (food_item.name or "").strip().lower(),
                (food_item.category or "").strip().lower(),
                getattr(getattr(food_item, "primary_category", None), "code", ""),
            ]
            if part
        )
        if "water" in text:
            return WaterLog.BEVERAGE_WATER
        if "tea" in text:
            return WaterLog.BEVERAGE_TEA
        if "coffee" in text or "espresso" in text:
            return WaterLog.BEVERAGE_COFFEE
        if "juice" in text:
            return WaterLog.BEVERAGE_JUICE
        if "smoothie" in text or "shake" in text:
            return WaterLog.BEVERAGE_SMOOTHIE
        return WaterLog.BEVERAGE_OTHER

    @staticmethod
    def _resolve_consumption_amount(
        *,
        food: FoodItem,
        quantity_grams,
        quantity,
        unit,
        serving_option: NutritionServingOption | None,
    ) -> ConsumptionAmount:
        if quantity_grams is not None and quantity is None and unit is None:
            quantity = float(quantity_grams)
            unit = "g"

        quantity = float(quantity if quantity is not None else quantity_grams or 1)
        unit = (unit or ("serving" if serving_option else "g")).lower()
        density = NutritionLoggingService._density_or_default(food)

        grams = None
        milliliters = None
        servings = None

        if unit in {"g", "gram", "grams"}:
            unit = "g"
            grams = quantity
        elif unit in {"ml", "milliliter", "milliliters"}:
            unit = "ml"
            milliliters = quantity
            grams = quantity * density if density else None
        elif unit in {"serving", "servings"}:
            unit = "serving"
            servings = quantity
            if serving_option:
                if serving_option.grams_equivalent is not None:
                    grams = serving_option.grams_equivalent * quantity
                if serving_option.milliliters_equivalent is not None:
                    milliliters = serving_option.milliliters_equivalent * quantity
            else:
                default_unit = (food.default_serving_unit or "g").lower()
                if default_unit == "ml":
                    milliliters = food.default_serving_size * quantity
                    grams = milliliters * density if density else None
                else:
                    grams = food.default_serving_size * quantity
        else:
            unit = "g"
            grams = quantity

        if milliliters is None and grams is not None and food.is_drink:
            milliliters = grams / density if density else None
        if grams is None and milliliters is not None and density:
            grams = milliliters * density

        return ConsumptionAmount(
            quantity=quantity,
            unit=unit,
            grams=grams,
            milliliters=milliliters,
            servings=servings,
        )

    @staticmethod
    def _calculate_snapshot(*, food: FoodItem, amount: ConsumptionAmount) -> dict[str, float]:
        facts = getattr(food, "nutrition_facts", None)
        if facts is None:
            facts_values = NutritionLoggingService._facts_from_legacy_fields({})
            facts_values.update(
                {
                    "calories_kcal": float(food.calories_100g or 0),
                    "protein_g": float(food.protein_100g or 0),
                    "carbohydrates_g": float(food.carbs_100g or 0),
                    "sugars_g": float(food.sugar_100g or 0),
                    "fiber_g": float(food.fiber_100g or 0),
                    "fat_g": float(food.fat_100g or 0),
                    "saturated_fat_g": float(food.saturated_fat_100g or 0),
                    "trans_fat_g": float(food.trans_fat_100g or 0),
                    "cholesterol_mg": float(food.cholesterol_mg_100g or 0),
                    "sodium_mg": float(food.sodium_mg_100g or 0),
                    "potassium_mg": float(food.potassium_mg_100g or 0),
                    "vitamin_c_mg": float(food.vitamin_c_mg_100g or 0),
                }
            )
            factor = (amount.grams or 0) / 100.0
            return {
                SNAPSHOT_FIELD_MAP[field]: float(facts_values.get(field, 0) or 0) * factor
                for field in NUTRIENT_FIELDS
            }

        factor = NutritionLoggingService._snapshot_factor(food=food, facts=facts, amount=amount)
        return {
            SNAPSHOT_FIELD_MAP[field]: float(getattr(facts, field, 0) or 0) * factor
            for field in NUTRIENT_FIELDS
        }

    @staticmethod
    def _snapshot_factor(*, food: FoodItem, facts: NutritionFacts, amount: ConsumptionAmount) -> float:
        basis_value = facts.basis_amount or facts.basis_value or 100
        density = NutritionLoggingService._density_or_default(food)

        if facts.basis_type == NutritionFacts.BASIS_PER_100ML:
            ml = amount.milliliters
            if ml is None and amount.grams is not None and density:
                ml = amount.grams / density
            return (ml or 0) / basis_value

        if facts.basis_type == NutritionFacts.BASIS_PER_SERVING:
            if amount.servings is not None:
                return amount.servings
            serving_size = facts.serving_size or food.default_serving_size or 1
            serving_unit = (facts.serving_unit or food.default_serving_unit or "g").lower()
            if serving_unit == "ml":
                ml = amount.milliliters
                if ml is None and amount.grams is not None and density:
                    ml = amount.grams / density
                return (ml or 0) / serving_size
            return (amount.grams or 0) / serving_size

        grams = amount.grams
        if grams is None and amount.milliliters is not None and density:
            grams = amount.milliliters * density
        return (grams or 0) / basis_value

    @staticmethod
    def _facts_from_legacy_fields(data: dict) -> dict:
        basis_type = data.get("basis_type", NutritionFacts.BASIS_PER_100G)
        basis_unit = str(data.get("basis_unit") or "").strip().lower()
        if basis_unit not in {"g", "ml", "serving"}:
            if basis_type == NutritionFacts.BASIS_PER_100ML:
                basis_unit = "ml"
            elif basis_type == NutritionFacts.BASIS_PER_SERVING:
                basis_unit = "serving"
            else:
                basis_unit = "g"

        return {
            "basis_type": basis_type,
            "basis_value": data.get("basis_value") or data.get("basis_amount") or 100,
            "basis_amount": data.get("basis_amount") or data.get("basis_value") or 100,
            "basis_unit": basis_unit,
            "serving_size": data.get("serving_grams") or data.get("default_serving_size") or 100,
            "serving_unit": data.get("default_serving_unit") or "g",
            "calories_kcal": float(data.get("calories_100g") or 0),
            "protein_g": float(data.get("protein_100g") or 0),
            "carbohydrates_g": float(data.get("carbs_100g") or 0),
            "sugars_g": float(data.get("sugar_100g") or 0),
            "fiber_g": float(data.get("fiber_100g") or 0),
            "fat_g": float(data.get("fat_100g") or 0),
            "saturated_fat_g": float(data.get("saturated_fat_100g") or 0),
            "trans_fat_g": float(data.get("trans_fat_100g") or 0),
            "cholesterol_mg": float(data.get("cholesterol_mg_100g") or 0),
            "sodium_mg": float(data.get("sodium_mg_100g") or 0),
            "potassium_mg": float(data.get("potassium_mg_100g") or 0),
            "vitamin_c_mg": float(data.get("vitamin_c_mg_100g") or 0),
        }

    @staticmethod
    def _legacy_food_values_from_facts(*, data: dict, facts_data: dict) -> dict:
        factor = NutritionLoggingService._legacy_factor_for_facts(data=data, facts_data=facts_data)
        return {
            "calories_100g": int(round(float(facts_data.get("calories_kcal") or 0) * factor)),
            "protein_100g": float(facts_data.get("protein_g") or 0) * factor,
            "carbs_100g": float(facts_data.get("carbohydrates_g") or 0) * factor,
            "fat_100g": float(facts_data.get("fat_g") or 0) * factor,
            "fiber_100g": float(facts_data.get("fiber_g") or 0) * factor,
            "sugar_100g": float(facts_data.get("sugars_g") or 0) * factor,
            "sodium_mg_100g": float(facts_data.get("sodium_mg") or 0) * factor,
            "saturated_fat_100g": float(facts_data.get("saturated_fat_g") or 0) * factor,
            "trans_fat_100g": float(facts_data.get("trans_fat_g") or 0) * factor,
            "potassium_mg_100g": float(facts_data.get("potassium_mg") or 0) * factor,
            "cholesterol_mg_100g": float(facts_data.get("cholesterol_mg") or 0) * factor,
            "vitamin_c_mg_100g": float(facts_data.get("vitamin_c_mg") or 0) * factor,
        }

    @staticmethod
    def _legacy_factor_for_facts(*, data: dict, facts_data: dict) -> float:
        basis_type = facts_data.get("basis_type") or NutritionFacts.BASIS_PER_100G
        basis_value = float(facts_data.get("basis_amount") or facts_data.get("basis_value") or 100)
        if basis_type == NutritionFacts.BASIS_PER_100G:
            return 100.0 / basis_value
        if basis_type == NutritionFacts.BASIS_PER_100ML:
            density = data.get("density_g_per_ml") or 1
            return (100.0 / basis_value) / float(density)
        serving_size = float(facts_data.get("serving_size") or data.get("serving_grams") or 100)
        serving_unit = (facts_data.get("serving_unit") or data.get("default_serving_unit") or "g").lower()
        if serving_unit == "ml":
            density = data.get("density_g_per_ml") or 1
            serving_size = serving_size * float(density)
        return 100.0 / serving_size if serving_size else 1

    @staticmethod
    def _density_or_default(food: FoodItem) -> float | None:
        if food.density_g_per_ml:
            return float(food.density_g_per_ml)
        if food.is_drink:
            return 1.0
        return None

    @staticmethod
    def _apply_item_metadata_defaults(data: dict, facts_data: dict) -> None:
        item_type = str(data.get("item_type") or FoodItem.TYPE_FOOD).strip().lower()
        if item_type in {FoodItem.TYPE_BEVERAGE, FoodItem.TYPE_DRINK}:
            data.setdefault("default_reference_unit", "ml")
            data.setdefault("is_hydration_trackable", True)
            data.setdefault("density_g_per_ml", 1.0)
        else:
            data.setdefault("default_reference_unit", "g")
            data.setdefault("is_hydration_trackable", False)

        caffeine_mg = float(facts_data.get("caffeine_mg") or 0)
        data.setdefault("contains_caffeine", caffeine_mg > 0)

    @staticmethod
    def _apply_category_defaults(data: dict) -> None:
        if data.get("primary_category") is not None:
            return
        legacy_category = str(data.get("category") or "").strip()
        if not legacy_category:
            return
        category = NutritionCatalogRepository.resolve_category_by_legacy_name(legacy_category)
        if category is not None:
            data["primary_category"] = category

    @staticmethod
    def _default_serving_options(data: dict) -> list[dict]:
        return [
            {
                "name": data.get("serving_label") or "Serving",
                "amount": 1,
                "unit": data.get("default_serving_unit") or "g",
                "grams_equivalent": data.get("serving_grams")
                or data.get("default_serving_size"),
                "milliliters_equivalent": (
                    data.get("default_serving_size")
                    if data.get("default_serving_unit") == "ml"
                    else None
                ),
                "is_default": True,
                "sort_order": 0,
            }
        ]

    @staticmethod
    def _sync_alias_records(item: FoodItem) -> None:
        NutritionCatalogRepository.sync_alias_records(item=item)

    @staticmethod
    def _upsert_alias_record(
        *,
        item: FoodItem,
        alias,
        alias_type: str,
        is_primary: bool,
        sort_order: int,
    ) -> None:
        NutritionCatalogRepository.upsert_alias_record(
            item=item,
            alias=alias,
            alias_type=alias_type,
            is_primary=is_primary,
            sort_order=sort_order,
        )

    @staticmethod
    def get_meal_logs(*, user, on_date: date | None = None):
        if on_date is not None:
            return MealLogRepository.get_for_user_on_date(user, on_date)
        return MealLogRepository.list_for_user(user)

    @staticmethod
    def get_nutrition_facts_queryset():
        return NutritionCatalogRepository.nutrition_facts_queryset()

    @staticmethod
    def create_nutrition_facts(data):
        return NutritionCatalogRepository.create_nutrition_facts(**data)

    @staticmethod
    def update_nutrition_facts(instance, data):
        return NutritionCatalogRepository.update_nutrition_facts(instance, **data)

    @staticmethod
    def get_serving_options_queryset():
        return NutritionCatalogRepository.serving_options_queryset()

    @staticmethod
    def create_serving_option(data):
        return NutritionCatalogRepository.create_serving_option(**data)

    @staticmethod
    def update_serving_option(instance, data):
        return NutritionCatalogRepository.update_serving_option(instance, **data)

    @staticmethod
    def delete_nutrition_facts(instance):
        NutritionCatalogRepository.delete_nutrition_facts(instance)

    @staticmethod
    def delete_serving_option(instance):
        NutritionCatalogRepository.delete_serving_option(instance)

    @staticmethod
    def _numeric_custom_value(payload: dict, key: str) -> float:
        value = payload.get(key, 0)
        if value in (None, ""):
            return 0.0
        try:
            return float(value)
        except (TypeError, ValueError) as exc:
            raise ValidationError({"custom_beverage": {key: "Enter a valid number."}}) from exc


NutritionService = NutritionLoggingService
