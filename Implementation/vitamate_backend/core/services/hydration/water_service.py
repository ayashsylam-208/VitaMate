from __future__ import annotations

from datetime import date

from django.db import transaction
from rest_framework.exceptions import ValidationError

from core.models import FoodItem, MealLog, WaterLog
from core.repositories.meal_log_repository import MealLogRepository
from core.repositories.water_log_repository import HydrationRepository
from core.services.food_search_service import FoodSearchService
from core.services.nutrition_service import NutritionService
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers
from gamification.services.points_service import PointsService


class WaterLoggingService:
    """Command-side service for writing hydration logs and linking them to nutrition."""

    @staticmethod
    @transaction.atomic
    def log_water(
        user,
        amount_liter=None,
        amount_ml=None,
        beverage_type="water",
        beverage_name="Water",
        food_item=None,
        drink_item=None,
        custom_beverage=None,
        save_for_reuse=True,
    ):
        return WaterLoggingService._save_log(
            user=user,
            amount_liter=amount_liter,
            amount_ml=amount_ml,
            beverage_type=beverage_type,
            beverage_name=beverage_name,
            food_item=food_item,
            drink_item=drink_item,
            custom_beverage=custom_beverage,
            save_for_reuse=save_for_reuse,
            existing_log=None,
        )

    @staticmethod
    @transaction.atomic
    def update_water_log(
        water_log,
        *,
        amount_liter=None,
        amount_ml=None,
        beverage_type="water",
        beverage_name="Water",
        food_item=None,
        drink_item=None,
        custom_beverage=None,
        save_for_reuse=True,
    ):
        return WaterLoggingService._save_log(
            user=water_log.user,
            amount_liter=amount_liter,
            amount_ml=amount_ml,
            beverage_type=beverage_type,
            beverage_name=beverage_name,
            food_item=food_item,
            drink_item=drink_item,
            custom_beverage=custom_beverage,
            save_for_reuse=save_for_reuse,
            existing_log=water_log,
        )

    @staticmethod
    @transaction.atomic
    def delete_water_log(water_log):
        user = water_log.user
        water_log_id = water_log.id
        event_date = water_log.date
        linked_meal_log = water_log.linked_meal_log
        HydrationRepository.delete(water_log)
        if linked_meal_log is not None:
            MealLogRepository.delete(linked_meal_log)
        HealthStateEventPublisher.publish_on_commit(
            user=user,
            trigger_type=HealthStateTriggers.WATER_DELETED,
            payload={
                "trigger_reference": str(water_log_id),
                "source_id": water_log_id,
                "event_dates": [event_date],
            },
        )

    @staticmethod
    def _save_log(
        *,
        user,
        amount_liter,
        amount_ml,
        beverage_type,
        beverage_name,
        food_item,
        drink_item,
        custom_beverage,
        save_for_reuse,
        existing_log,
    ):
        previous_date = existing_log.date if existing_log is not None else None
        amount_liters, amount_milliliters = WaterLoggingService._normalize_amount(
            amount_liter=amount_liter,
            amount_ml=amount_ml,
        )
        resolved_food = WaterLoggingService._resolve_beverage(
            user=user,
            beverage_type=beverage_type,
            beverage_name=beverage_name,
            food_item=food_item or drink_item,
            custom_beverage=custom_beverage,
            save_for_reuse=save_for_reuse,
        )
        resolved_type = WaterLoggingService._beverage_choice_for_food(resolved_food)
        resolved_name = resolved_food.name.strip() or beverage_name or "Water"

        if existing_log is None or existing_log.linked_meal_log is None:
            linked_meal_log = NutritionService.log_meal(
                user=user,
                food=resolved_food,
                meal_type="drink",
                quantity=amount_milliliters,
                unit="ml",
                source=MealLog.SOURCE_MANUAL,
                sync_hydration=False,
                publish_event=False,
            )
        else:
            linked_meal_log = NutritionService.update_meal_log(
                existing_log.linked_meal_log,
                food=resolved_food,
                quantity=amount_milliliters,
                unit="ml",
                source=MealLog.SOURCE_MANUAL,
                sync_hydration=False,
                publish_event=False,
            )

        if existing_log is None:
            log = HydrationRepository.create_for_user(
                user=user,
                amount_liter=amount_liters,
                beverage_type=resolved_type,
                beverage_name=resolved_name,
                food_item=resolved_food,
                drink_item=resolved_food,
                linked_meal_log=linked_meal_log,
            )
            PointsService.award_water_points(user)
            HealthStateEventPublisher.publish_on_commit(
                user=user,
                trigger_type=HealthStateTriggers.WATER_LOGGED,
                payload={
                    "trigger_reference": str(log.id),
                    "source_id": log.id,
                    "event_dates": [log.date],
                },
            )
            return log

        existing_log.amount_liter = amount_liters
        existing_log.beverage_type = resolved_type
        existing_log.beverage_name = resolved_name
        existing_log.food_item = resolved_food
        existing_log.drink_item = resolved_food
        existing_log.linked_meal_log = linked_meal_log
        existing_log = HydrationRepository.save(
            existing_log,
            update_fields=[
                "amount_liter",
                "beverage_type",
                "beverage_name",
                "food_item",
                "drink_item",
                "linked_meal_log",
            ],
        )
        HealthStateEventPublisher.publish_on_commit(
            user=user,
            trigger_type=HealthStateTriggers.WATER_UPDATED,
            payload={
                "trigger_reference": str(existing_log.id),
                "source_id": existing_log.id,
                "event_dates": [previous_date, existing_log.date],
            },
        )
        return existing_log

    @staticmethod
    def _normalize_amount(*, amount_liter, amount_ml):
        parsed_liters = WaterLoggingService._to_float(amount_liter)
        parsed_ml = WaterLoggingService._to_float(amount_ml)

        if parsed_ml is None and parsed_liters is None:
            raise ValidationError(
                {"amount_ml": "Provide amount_ml or amount_liter."},
            )
        if parsed_ml is not None and parsed_ml <= 0:
            raise ValidationError({"amount_ml": "amount_ml must be greater than 0."})
        if parsed_liters is not None and parsed_liters <= 0:
            raise ValidationError(
                {"amount_liter": "amount_liter must be greater than 0."},
            )

        if parsed_ml is not None:
            return parsed_ml / 1000.0, parsed_ml
        return parsed_liters, parsed_liters * 1000.0

    @staticmethod
    def _resolve_beverage(
        *,
        user,
        beverage_type,
        beverage_name,
        food_item,
        custom_beverage,
        save_for_reuse,
    ):
        if food_item is not None:
            if not food_item.is_drink and not food_item.is_hydration_trackable:
                raise ValidationError(
                    {"food_item": "Only drink or hydration-trackable items can be logged in hydration."},
                )
            return food_item

        if custom_beverage:
            try:
                return NutritionService.create_custom_beverage(
                    user=user,
                    beverage_data=custom_beverage,
                    save_for_reuse=save_for_reuse,
                )
            except ValueError as exc:
                raise ValidationError({"custom_beverage": str(exc)}) from exc

        normalized_name = (beverage_name or "").strip()
        normalized_type = (beverage_type or "").strip().lower()

        if normalized_type == WaterLog.BEVERAGE_WATER and (
            not normalized_name or normalized_name.lower() == "water"
        ):
            return NutritionService.ensure_standard_water_item()

        matched = WaterLoggingService._find_existing_beverage(
            user=user,
            beverage_name=normalized_name,
            beverage_type=normalized_type,
        )
        if matched is not None:
            return matched

        if normalized_type == WaterLog.BEVERAGE_WATER or normalized_name.lower() == "water":
            return NutritionService.ensure_standard_water_item()

        raise ValidationError(
            {
                "food_item": (
                    "No matching beverage was found. Select one from the beverage "
                    "catalog or provide custom_beverage."
                )
            },
        )

    @staticmethod
    def _find_existing_beverage(*, user, beverage_name, beverage_type):
        return FoodSearchService.find_matching_beverage(
            user=user,
            beverage_name=beverage_name,
            beverage_type=beverage_type,
        )

    @staticmethod
    def _beverage_choice_for_food(food_item):
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
    def _to_float(value):
        if value is None or value == "":
            return None
        try:
            return float(value)
        except (TypeError, ValueError):
            return None

    @staticmethod
    def get_water_logs(*, user, on_date=None):
        if on_date is None:
            on_date = date.today()
        return HydrationRepository.list_for_user_on_date(user, on_date)


WaterService = WaterLoggingService
