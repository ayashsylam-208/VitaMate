from __future__ import annotations

from django.db import transaction
from django.utils import timezone
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
        origin_domain=WaterLog.ORIGIN_HYDRATION,
        origin_record_id="",
        correlation_id="",
        source_type=WaterLog.SOURCE_TYPE_DIRECT,
        source_ref="",
        reward_owner_domain="hydration",
        caffeine_mg=0,
        consumed_at=None,
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
            origin_domain=origin_domain,
            origin_record_id=origin_record_id,
            correlation_id=correlation_id,
            source_type=source_type,
            source_ref=source_ref,
            reward_owner_domain=reward_owner_domain,
            caffeine_mg=caffeine_mg,
            consumed_at=consumed_at,
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
        origin_domain=None,
        origin_record_id=None,
        correlation_id=None,
        source_type=None,
        source_ref=None,
        reward_owner_domain=None,
        caffeine_mg=None,
        consumed_at=None,
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
            origin_domain=origin_domain,
            origin_record_id=origin_record_id,
            correlation_id=correlation_id,
            source_type=source_type,
            source_ref=source_ref,
            reward_owner_domain=reward_owner_domain,
            caffeine_mg=caffeine_mg,
            consumed_at=consumed_at,
        )

    @staticmethod
    @transaction.atomic
    def delete_water_log(water_log):
        user = water_log.user
        water_log_id = water_log.id
        event_date = timezone.localdate(water_log.consumed_at)
        linked_meal_log = water_log.linked_meal_log
        from core.services.habits.habit_projection_service import TrackerToHabitProjectionService

        TrackerToHabitProjectionService.delete_for_water(water_log=water_log)
        PointsService.reverse_points_for_source(
            user=user,
            source_type="hydration",
            source_id=water_log_id,
            reason="Reversed hydration points after deleting water log.",
            event_date=event_date,
        )
        HydrationRepository.delete(water_log)
        if linked_meal_log is not None:
            MealLogRepository.delete(linked_meal_log)
        from gamification.services.motivation_service import MotivationService

        MotivationService.refresh_daily(
            user=user,
            target_date=event_date,
        )
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
        origin_domain,
        origin_record_id,
        correlation_id,
        source_type,
        source_ref,
        reward_owner_domain,
        caffeine_mg,
        consumed_at,
    ):
        previous_date = (
            timezone.localdate(existing_log.consumed_at)
            if existing_log is not None
            else None
        )
        effective_consumed_at = consumed_at or (
            existing_log.consumed_at if existing_log is not None else timezone.now()
        )
        if timezone.is_naive(effective_consumed_at):
            effective_consumed_at = timezone.make_aware(
                effective_consumed_at,
                timezone.get_current_timezone(),
            )
        effective_date = timezone.localdate(effective_consumed_at)
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
            caffeine_mg=caffeine_mg,
            amount_ml=amount_milliliters,
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
                consumed_at=effective_consumed_at,
                source=MealLog.SOURCE_MANUAL,
                sync_hydration=False,
                publish_event=False,
                origin_domain=origin_domain or WaterLog.ORIGIN_HYDRATION,
                origin_record_id=str(origin_record_id or ""),
                correlation_id=str(correlation_id or ""),
                source_type=source_type or WaterLog.SOURCE_TYPE_DIRECT,
                source_ref=str(source_ref or ""),
                reward_owner_domain=reward_owner_domain or "hydration",
            )
        else:
            linked_meal_log = NutritionService.update_meal_log(
                existing_log.linked_meal_log,
                food=resolved_food,
                quantity=amount_milliliters,
                unit="ml",
                consumed_at=effective_consumed_at,
                source=MealLog.SOURCE_MANUAL,
                sync_hydration=False,
                publish_event=False,
                origin_domain=origin_domain,
                origin_record_id=origin_record_id,
                correlation_id=correlation_id,
                source_type=source_type,
                source_ref=source_ref,
                reward_owner_domain=reward_owner_domain,
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
                caffeine_mg=float(caffeine_mg or 0),
                consumed_at=effective_consumed_at,
                origin_domain=origin_domain or WaterLog.ORIGIN_HYDRATION,
                origin_record_id=str(origin_record_id or ""),
                correlation_id=str(correlation_id or ""),
                source_type=source_type or WaterLog.SOURCE_TYPE_DIRECT,
                source_ref=str(source_ref or ""),
                reward_owner_domain=reward_owner_domain or "hydration",
            )
            if log.date != effective_date:
                log.date = effective_date
                log = HydrationRepository.save(log, update_fields=["date"])
            if log.reward_owner_domain == "hydration":
                PointsService.award_water_points(
                    user,
                    source_id=log.id,
                    event_date=effective_date,
                )
            from core.services.habits.habit_projection_service import TrackerToHabitProjectionService

            TrackerToHabitProjectionService.sync_from_water(water_log=log)
            from gamification.services.motivation_service import MotivationService

            MotivationService.refresh_daily(
                user=user,
                target_date=effective_date,
            )
            HealthStateEventPublisher.publish_on_commit(
                user=user,
                trigger_type=HealthStateTriggers.WATER_LOGGED,
                payload={
                    "trigger_reference": str(log.id),
                    "source_id": log.id,
                    "event_dates": [effective_date],
                },
            )
            return log

        existing_log.amount_liter = amount_liters
        existing_log.beverage_type = resolved_type
        existing_log.beverage_name = resolved_name
        existing_log.food_item = resolved_food
        existing_log.drink_item = resolved_food
        existing_log.linked_meal_log = linked_meal_log
        if caffeine_mg is not None:
            existing_log.caffeine_mg = float(caffeine_mg or 0)
        if origin_domain is not None:
            existing_log.origin_domain = origin_domain
        if origin_record_id is not None:
            existing_log.origin_record_id = str(origin_record_id or "")
        if correlation_id is not None:
            existing_log.correlation_id = str(correlation_id or "")
        if source_type is not None:
            existing_log.source_type = source_type
        if source_ref is not None:
            existing_log.source_ref = str(source_ref or "")
        if reward_owner_domain is not None:
            existing_log.reward_owner_domain = reward_owner_domain
        existing_log.consumed_at = effective_consumed_at
        existing_log.date = effective_date
        existing_log = HydrationRepository.save(
            existing_log,
            update_fields=[
                "amount_liter",
                "beverage_type",
                "beverage_name",
                "food_item",
                "drink_item",
                "linked_meal_log",
                "caffeine_mg",
                "origin_domain",
                "origin_record_id",
                "correlation_id",
                "source_type",
                "source_ref",
                "reward_owner_domain",
                "consumed_at",
                "date",
            ],
        )
        from core.services.habits.habit_projection_service import TrackerToHabitProjectionService

        TrackerToHabitProjectionService.sync_from_water(water_log=existing_log)
        from gamification.services.motivation_service import MotivationService

        MotivationService.refresh_daily(
            user=user,
            target_date=effective_date,
        )
        HealthStateEventPublisher.publish_on_commit(
            user=user,
            trigger_type=HealthStateTriggers.WATER_UPDATED,
            payload={
                "trigger_reference": str(existing_log.id),
                "source_id": existing_log.id,
                "event_dates": [previous_date, effective_date],
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
        caffeine_mg=0,
        amount_ml=0,
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

        if normalized_type == WaterLog.BEVERAGE_WATER or normalized_name.lower() == "water":
            return NutritionService.ensure_standard_water_item()

        fallback_beverage = WaterLoggingService._standard_beverage_payload(
            beverage_type=normalized_type,
            beverage_name=normalized_name,
            caffeine_mg=caffeine_mg,
            amount_ml=amount_ml,
        )
        if (
            fallback_beverage is not None
            and WaterLoggingService._is_generic_standard_name(
                beverage_type=normalized_type,
                beverage_name=normalized_name,
            )
        ):
            return WaterLoggingService._get_or_create_standard_beverage(
                user=user,
                beverage_data=fallback_beverage,
            )

        matched = WaterLoggingService._find_existing_beverage(
            user=user,
            beverage_name=normalized_name,
            beverage_type=normalized_type,
        )
        if matched is not None:
            return matched

        if fallback_beverage is not None:
            return WaterLoggingService._get_or_create_standard_beverage(
                user=user,
                beverage_data=fallback_beverage,
            )

        raise ValidationError(
            {
                "food_item": (
                    "No matching beverage was found. Select one from the beverage "
                    "catalog or provide custom_beverage."
                )
            },
        )

    @staticmethod
    def _standard_beverage_payload(*, beverage_type, beverage_name, caffeine_mg=0, amount_ml=0):
        defaults = {
            WaterLog.BEVERAGE_COFFEE: {"name": "Coffee", "water_g": 98},
            WaterLog.BEVERAGE_TEA: {"name": "Tea", "water_g": 99},
            WaterLog.BEVERAGE_JUICE: {"name": "Juice", "water_g": 88},
            WaterLog.BEVERAGE_MILK: {"name": "Milk", "water_g": 87},
            WaterLog.BEVERAGE_SODA: {"name": "Soda", "water_g": 90},
            WaterLog.BEVERAGE_OTHER: {"name": "Drink", "water_g": 100},
        }
        if beverage_type not in defaults:
            return None
        template = defaults[beverage_type]
        amount = float(amount_ml or 0)
        caffeine_total = float(caffeine_mg or 0)
        caffeine_per_100ml = 0 if amount <= 0 else caffeine_total / (amount / 100)
        return {
            "name": beverage_name or template["name"],
            "beverage_type": beverage_type,
            "calories_kcal": 0,
            "protein_g": 0,
            "carbohydrates_g": 0,
            "fat_g": 0,
            "sugars_g": 0,
            "fiber_g": 0,
            "sodium_mg": 0,
            "water_g": template["water_g"],
            "caffeine_mg": caffeine_per_100ml,
        }

    @staticmethod
    def _get_or_create_standard_beverage(*, user, beverage_data):
        existing = WaterLoggingService._find_user_standard_beverage(
            user=user,
            beverage_data=beverage_data,
        )
        if existing is not None:
            return existing
        return NutritionService.create_custom_beverage(
            user=user,
            beverage_data=beverage_data,
            save_for_reuse=True,
        )

    @staticmethod
    def _find_user_standard_beverage(*, user, beverage_data):
        name = str(beverage_data.get("name") or "").strip()
        beverage_type = str(beverage_data.get("beverage_type") or "").strip()
        water_g = float(beverage_data.get("water_g") or 0)
        caffeine_mg = float(beverage_data.get("caffeine_mg") or 0)
        queryset = FoodItem.objects.filter(
            created_by=user,
            item_type=FoodItem.TYPE_BEVERAGE,
            name__iexact=name,
            category__iexact=beverage_type,
            is_active=True,
            nutrition_facts__basis_type="per_100ml",
            nutrition_facts__water_g=water_g,
        )
        if caffeine_mg:
            queryset = queryset.filter(nutrition_facts__caffeine_mg=caffeine_mg)
        return queryset.order_by("-id").first()

    @staticmethod
    def _is_generic_standard_name(*, beverage_type, beverage_name):
        defaults = {
            WaterLog.BEVERAGE_COFFEE: "coffee",
            WaterLog.BEVERAGE_TEA: "tea",
            WaterLog.BEVERAGE_JUICE: "juice",
            WaterLog.BEVERAGE_MILK: "milk",
            WaterLog.BEVERAGE_SODA: "soda",
            WaterLog.BEVERAGE_OTHER: "drink",
        }
        normalized_name = str(beverage_name or "").strip().lower()
        return not normalized_name or normalized_name == defaults.get(beverage_type, "")

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
        if "milk" in text:
            return WaterLog.BEVERAGE_MILK
        if "soda" in text or "cola" in text or "soft drink" in text:
            return WaterLog.BEVERAGE_SODA
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
    def get_water_logs(*, user, on_date=None, start=None, end=None):
        if start is not None or end is not None:
            return HydrationRepository.list_for_user_between(
                user,
                start=start,
                end=end,
            )
        if on_date is None:
            return HydrationRepository.list_for_user_between(user)
        return HydrationRepository.list_for_user_on_date(user, on_date)

    @staticmethod
    def get_day_bounds(on_date):
        return HydrationRepository.day_bounds(on_date)


WaterService = WaterLoggingService
