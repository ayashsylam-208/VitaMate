from __future__ import annotations

from decimal import Decimal, InvalidOperation

from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from core.models import MealLog, MealLogComponent
from core.repositories.meal_log_repository import MealLogRepository
from core.services.nutrition.nutrition_service import (
    NUTRIENT_FIELDS,
    SNAPSHOT_FIELD_MAP,
    NutritionLoggingService,
)
from core.services.orchestration.health_state_event_publisher import (
    HealthStateEventPublisher,
)
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers
from gamification.services.points_service import PointsService


class MealFinalizationService:
    """Create one immutable meal snapshot and run all downstream projections once."""

    @classmethod
    @transaction.atomic
    def finalize(
        cls,
        *,
        user,
        meal_type,
        components,
        display_name="",
        consumed_at=None,
        notes="",
        source=MealLog.SOURCE_MANUAL,
        sync_hydration=True,
        publish_event=True,
        origin_domain=MealLog.ORIGIN_NUTRITION,
        origin_record_id="",
        correlation_id="",
        source_type=MealLog.SOURCE_TYPE_DIRECT,
        source_ref="",
        reward_owner_domain="nutrition",
        is_fast_food=False,
        quality_tags=None,
        finalization_key="",
    ):
        if not components:
            raise ValidationError({"components": "At least one component is required."})

        finalization_key = str(finalization_key or "").strip()
        if finalization_key:
            # Lock the user row so concurrent retries serialize before the unique write.
            get_user_model().objects.select_for_update().only("id").get(id=user.id)
            existing = MealLog.objects.filter(
                user=user,
                finalization_key=finalization_key,
            ).first()
            if existing is not None:
                return existing

        resolved = [cls._resolve_component(user=user, value=value) for value in components]
        consumed_at = consumed_at or timezone.now()
        if timezone.is_naive(consumed_at):
            consumed_at = timezone.make_aware(
                consumed_at,
                timezone.get_current_timezone(),
            )

        aggregate_snapshot = {
            snapshot_field: sum(
                float(component["snapshot"].get(snapshot_field, 0) or 0)
                for component in resolved
            )
            for snapshot_field in SNAPSHOT_FIELD_MAP.values()
        }
        total_grams = sum(float(component["amount"].grams or 0) for component in resolved)
        total_milliliters = sum(
            float(component["amount"].milliliters or 0) for component in resolved
        )
        single = resolved[0] if len(resolved) == 1 else None
        parent_food = single["food"] if single is not None else None
        effective_name = str(display_name or "").strip()
        if not effective_name:
            effective_name = (
                single["food"].name
                if single is not None
                else ", ".join(component["food"].name for component in resolved[:3])
            )
        if len(resolved) > 3 and not display_name:
            effective_name = f"{effective_name} +{len(resolved) - 3}"

        if single is not None:
            parent_quantity = single["amount"].quantity
            parent_unit = single["amount"].unit
            parent_servings = single["amount"].servings
            parent_serving_option = single["serving_option"]
            serving_label = single["serving_label"]
        else:
            parent_quantity = total_grams or total_milliliters
            parent_unit = "g" if total_grams else "ml"
            parent_servings = None
            parent_serving_option = None
            serving_label = ""

        tags = [str(tag) for tag in (quality_tags or []) if str(tag).strip()]
        tags = [tag for tag in tags if tag != "fast_food"]
        if is_fast_food:
            tags.append("fast_food")

        meal_log = MealLogRepository.create_for_user(
            user=user,
            food=parent_food,
            meal_type=meal_type,
            quantity_grams=total_grams,
            display_name=effective_name,
            is_composite=len(resolved) > 1,
            quantity=parent_quantity,
            unit=parent_unit,
            grams_consumed=total_grams or None,
            milliliters_consumed=total_milliliters or None,
            servings_consumed=parent_servings,
            serving_option=parent_serving_option,
            serving_label_snapshot=serving_label,
            consumed_at=consumed_at,
            notes=notes or "",
            source=source or MealLog.SOURCE_MANUAL,
            origin_domain=origin_domain or MealLog.ORIGIN_NUTRITION,
            origin_record_id=str(origin_record_id or ""),
            correlation_id=str(correlation_id or ""),
            source_type=source_type or MealLog.SOURCE_TYPE_DIRECT,
            source_ref=str(source_ref or ""),
            reward_owner_domain=reward_owner_domain or "nutrition",
            finalization_key=finalization_key,
            is_fast_food=bool(is_fast_food),
            quality_tags=tags,
            **aggregate_snapshot,
        )
        meal_log.date = timezone.localdate(consumed_at)
        MealLogRepository.save(meal_log, update_fields=["date"])

        MealLogComponent.objects.bulk_create(
            [
                MealLogComponent(
                    meal_log=meal_log,
                    food_item=component["food"],
                    display_name_snapshot=component["food"].name,
                    quantity_value=cls._decimal(component["amount"].quantity),
                    quantity_unit=component["amount"].unit,
                    resolved_grams=cls._optional_decimal(component["amount"].grams),
                    resolved_milliliters=cls._optional_decimal(
                        component["amount"].milliliters
                    ),
                    confidence_score=component["confidence_score"],
                    nutrition_snapshot={
                        field: float(component["snapshot"].get(snapshot_field, 0) or 0)
                        for field, snapshot_field in SNAPSHOT_FIELD_MAP.items()
                    },
                    source_label=component["source_label"],
                    is_user_confirmed=True,
                    sort_order=index,
                )
                for index, component in enumerate(resolved)
            ]
        )

        cls._publish_integrations(
            meal_log=meal_log,
            sync_hydration=sync_hydration,
            publish_event=publish_event,
        )
        return meal_log

    @classmethod
    def sync_single_component(cls, *, meal_log, food, amount, snapshot):
        components = meal_log.components.order_by("sort_order", "id")
        if components.count() > 1:
            raise ValidationError(
                {"components": "Composite components need the dedicated edit workflow."}
            )
        component = components.first() or MealLogComponent(meal_log=meal_log)
        component.food_item = food
        component.display_name_snapshot = food.name
        component.quantity_value = cls._decimal(amount.quantity)
        component.quantity_unit = amount.unit
        component.resolved_grams = cls._optional_decimal(amount.grams)
        component.resolved_milliliters = cls._optional_decimal(amount.milliliters)
        component.nutrition_snapshot = {
            field: float(snapshot.get(snapshot_field, 0) or 0)
            for field, snapshot_field in SNAPSHOT_FIELD_MAP.items()
        }
        component.source_label = food.name
        component.is_user_confirmed = True
        component.sort_order = 0
        component.save()
        return component

    @staticmethod
    def _resolve_component(*, user, value):
        food = value.get("food")
        if food is None:
            raise ValidationError({"components": "Every component needs a mapped food item."})
        if food.created_by_id not in {None, user.id}:
            raise ValidationError({"components": "A component food item is not accessible."})
        if not food.is_active:
            raise ValidationError({"components": f"{food.name} is not active."})
        if not value.get("is_user_confirmed", True):
            raise ValidationError({"components": "All components must be confirmed first."})

        quantity = value.get("quantity")
        quantity_grams = value.get("quantity_grams")
        raw_quantity = quantity if quantity is not None else quantity_grams
        if raw_quantity is not None and float(raw_quantity) <= 0:
            raise ValidationError({"components": "Component quantities must be positive."})

        serving_option = value.get("serving_option")
        if serving_option is not None and serving_option.food_item_id != food.id:
            raise ValidationError(
                {"components": "A serving option does not belong to its food item."}
            )
        amount = NutritionLoggingService._resolve_consumption_amount(
            food=food,
            quantity_grams=quantity_grams,
            quantity=quantity,
            unit=value.get("unit"),
            serving_option=serving_option,
            custom_serving_grams=value.get("custom_serving_grams"),
            custom_serving_milliliters=value.get("custom_serving_milliliters"),
        )
        if float(amount.grams or 0) <= 0 and float(amount.milliliters or 0) <= 0:
            raise ValidationError({"components": "Component amount could not be resolved."})

        serving_label = ""
        if amount.unit == "serving":
            serving_label = (
                str(value.get("serving_label") or "").strip()
                or getattr(serving_option, "name", "").strip()
                or str(food.serving_label or "").strip()
                or "Serving"
            )
        confidence = value.get("confidence_score")
        confidence = MealFinalizationService._optional_decimal(confidence)
        if confidence is not None and (confidence < 0 or confidence > 1):
            raise ValidationError({"components": "Confidence must be between 0 and 1."})
        return {
            "food": food,
            "amount": amount,
            "serving_option": serving_option,
            "serving_label": serving_label,
            "snapshot": NutritionLoggingService._calculate_snapshot(
                food=food,
                amount=amount,
            ),
            "confidence_score": confidence,
            "source_label": str(value.get("source_label") or "")[:160],
        }

    @staticmethod
    def _publish_integrations(*, meal_log, sync_hydration, publish_event):
        if sync_hydration:
            NutritionLoggingService._sync_hydration_log_for_meal(meal_log)

        from core.services.habits.habit_projection_service import (
            TrackerToHabitProjectionService,
        )
        from core.services.orchestration.integration_outbox_service import (
            IntegrationOutboxService,
        )

        TrackerToHabitProjectionService.sync_from_meal(
            meal_log=meal_log,
            clear_stale_projections=False,
        )
        if meal_log.meal_type != "drink" and meal_log.reward_owner_domain == "nutrition":
            PointsService.sync_nutrition_day_points(
                meal_log.user,
                event_date=meal_log.date,
            )
        IntegrationOutboxService.enqueue_motivation_refresh(
            user=meal_log.user,
            target_date=meal_log.date,
            source_ref=f"meal:{meal_log.id}",
        )
        if publish_event:
            HealthStateEventPublisher.publish_on_commit(
                user=meal_log.user,
                trigger_type=HealthStateTriggers.MEAL_LOGGED,
                payload={
                    "trigger_reference": str(meal_log.id),
                    "source_id": meal_log.id,
                    "event_dates": [meal_log.date],
                },
                synchronous=True,
            )

    @staticmethod
    def _decimal(value):
        try:
            return Decimal(str(value)).quantize(Decimal("0.001"))
        except (InvalidOperation, TypeError, ValueError) as exc:
            raise ValidationError({"components": "Invalid component amount."}) from exc

    @classmethod
    def _optional_decimal(cls, value):
        if value is None:
            return None
        return cls._decimal(value)
