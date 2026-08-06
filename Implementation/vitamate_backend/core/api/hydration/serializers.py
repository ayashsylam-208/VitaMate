from datetime import timedelta

from django.utils import timezone
from rest_framework import serializers

from core.models import FoodItem, WaterLog
from core.services.nutrition_service import NutritionService


class WaterLogSerializer(serializers.ModelSerializer):
    amount_liter = serializers.FloatField(required=False, allow_null=True)
    food_item = serializers.PrimaryKeyRelatedField(
        queryset=FoodItem.objects.all(),
        required=False,
        allow_null=True,
    )
    drink_item = serializers.PrimaryKeyRelatedField(
        queryset=FoodItem.objects.all(),
        required=False,
        allow_null=True,
    )
    linked_meal_log = serializers.PrimaryKeyRelatedField(read_only=True)
    amount_ml = serializers.FloatField(required=False, allow_null=True, write_only=True)
    drink_type = serializers.CharField(required=False, write_only=True, allow_blank=True)
    food_item_id = serializers.IntegerField(required=False, write_only=True, allow_null=True)
    custom_name = serializers.CharField(required=False, write_only=True, allow_blank=True)
    metadata = serializers.JSONField(required=False, write_only=True)
    custom_beverage = serializers.JSONField(required=False, write_only=True)
    save_for_reuse = serializers.BooleanField(required=False, write_only=True, default=True)
    food_item_name = serializers.CharField(source="food_item.name", read_only=True)
    nutrition_preview = serializers.SerializerMethodField()
    hydration_ml = serializers.SerializerMethodField()
    linked_habit_projection = serializers.SerializerMethodField()

    def validate(self, attrs):
        attrs = super().validate(attrs)

        request = self.context.get("request")
        user = getattr(request, "user", None)
        metadata = attrs.get("metadata") if isinstance(attrs.get("metadata"), dict) else {}
        drink_type = str(attrs.pop("drink_type", "") or "").strip().lower()
        custom_name = str(attrs.pop("custom_name", "") or "").strip()
        food_item_id = attrs.pop("food_item_id", None)

        if drink_type:
            allowed_types = {choice[0] for choice in WaterLog.BEVERAGE_CHOICES}
            if drink_type not in allowed_types:
                raise serializers.ValidationError({"drink_type": "Unsupported drink type."})
            attrs["beverage_type"] = drink_type
        if custom_name and not attrs.get("beverage_name"):
            attrs["beverage_name"] = custom_name
        if "caffeine_mg" not in attrs and metadata.get("caffeine_mg") is not None:
            attrs["caffeine_mg"] = metadata.get("caffeine_mg")
        if food_item_id is not None:
            if user is None or not user.is_authenticated:
                raise serializers.ValidationError({"food_item_id": "Authentication is required."})
            try:
                attrs["food_item"] = NutritionService.get_accessible_food_item(
                    user=user,
                    food_item_id=food_item_id,
                    item_type=FoodItem.TYPE_BEVERAGE,
                )
                attrs["drink_item"] = attrs["food_item"]
            except ValueError as exc:
                raise serializers.ValidationError({"food_item_id": str(exc)}) from exc

        if attrs.get("food_item") is not None and attrs.get("custom_beverage"):
            raise serializers.ValidationError(
                {"food_item": "Choose a beverage or submit custom_beverage, not both."},
            )
        if attrs.get("drink_item") is not None and attrs.get("custom_beverage"):
            raise serializers.ValidationError(
                {"drink_item": "Choose a beverage or submit custom_beverage, not both."},
            )
        if attrs.get("food_item") is not None and attrs.get("drink_item") is not None:
            if attrs["food_item"].id != attrs["drink_item"].id:
                raise serializers.ValidationError(
                    {"drink_item": "drink_item must match food_item when both are supplied."},
                )

        custom_beverage = attrs.get("custom_beverage")
        if custom_beverage is not None and not isinstance(custom_beverage, dict):
            raise serializers.ValidationError(
                {"custom_beverage": "custom_beverage must be an object."},
            )

        amount_ml = attrs.get("amount_ml")
        amount_liter = attrs.get("amount_liter")
        if amount_ml is not None:
            if amount_ml <= 0:
                raise serializers.ValidationError(
                    {"amount_ml": "amount_ml must be greater than 0."},
                )
            attrs["amount_liter"] = amount_ml / 1000.0
        elif amount_liter is not None:
            if amount_liter <= 0:
                raise serializers.ValidationError(
                    {"amount_liter": "amount_liter must be greater than 0."},
                )
        elif self.instance is not None:
            attrs["amount_liter"] = self.instance.amount_liter
        else:
            raise serializers.ValidationError(
                {"amount_ml": "Provide amount_ml or amount_liter."},
            )

        if amount_ml is None:
            attrs["amount_ml"] = float(attrs["amount_liter"]) * 1000.0

        if attrs.get("food_item") is None and attrs.get("drink_item") is not None:
            attrs["food_item"] = attrs["drink_item"]
        elif attrs.get("drink_item") is None and attrs.get("food_item") is not None:
            attrs["drink_item"] = attrs["food_item"]

        food_item = attrs.get("food_item")
        if food_item is not None and user is not None and user.is_authenticated:
            try:
                attrs["food_item"] = NutritionService.get_accessible_food_item(
                    user=user,
                    food_item_id=food_item.id,
                    item_type=FoodItem.TYPE_BEVERAGE,
                )
                attrs["drink_item"] = attrs["food_item"]
            except ValueError as exc:
                raise serializers.ValidationError({"food_item": str(exc)}) from exc

        consumed_at = attrs.get("consumed_at")
        if consumed_at is None and self.instance is not None:
            consumed_at = self.instance.consumed_at
        if consumed_at is not None:
            if timezone.is_naive(consumed_at):
                consumed_at = timezone.make_aware(consumed_at, timezone.get_current_timezone())
            now = timezone.now()
            if consumed_at > now + timedelta(minutes=5):
                raise serializers.ValidationError(
                    {"consumed_at": "consumed_at cannot be in the future."},
                )
            if consumed_at < now - timedelta(days=366):
                raise serializers.ValidationError(
                    {"consumed_at": "consumed_at is too far in the past."},
                )
            attrs["consumed_at"] = consumed_at

        return attrs

    def get_nutrition_preview(self, obj):
        meal = getattr(obj, "linked_meal_log", None)
        if meal is None:
            return None
        return {
            "calories": float(meal.snapshot_calories_kcal or 0),
            "protein": float(meal.snapshot_protein_g or 0),
            "carbs": float(meal.snapshot_carbohydrates_g or 0),
            "fat": float(meal.snapshot_fat_g or 0),
            "sugars": float(meal.snapshot_sugars_g or 0),
            "caffeine": float(meal.snapshot_caffeine_mg or 0),
        }

    def get_hydration_ml(self, obj):
        meal = getattr(obj, "linked_meal_log", None)
        if meal is not None and meal.snapshot_water_g:
            return int(round(float(meal.snapshot_water_g or 0)))
        return int(round(float(obj.amount_liter or 0) * 1000))

    def get_linked_habit_projection(self, obj):
        from core.models import UnhealthyHabitLog
        from core.services.habits.habit_evaluation_service import HabitEvaluationService

        log = (
            UnhealthyHabitLog.objects.filter(linked_water_log=obj)
            .select_related("habit")
            .order_by("-created_at", "-id")
            .first()
        )
        if log is None:
            return None
        return {
            "habit_log_id": log.id,
            "habit_id": log.habit_id,
            "habit_type": log.habit.habit_type,
            "source_type": log.source_type,
            "source_ref": log.source_ref,
            "reward_owner_domain": log.reward_owner_domain,
            "evaluation": HabitEvaluationService.evaluate_habit(
                habit=log.habit,
                target_date=log.log_date,
            ),
        }

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["amount_ml"] = int(round(float(instance.amount_liter or 0) * 1000))
        return data

    class Meta:
        model = WaterLog
        fields = [
            "id",
            "user",
            "food_item",
            "drink_item",
            "food_item_name",
            "linked_meal_log",
            "amount_liter",
            "amount_ml",
            "beverage_type",
            "beverage_name",
            "caffeine_mg",
            "consumed_at",
            "origin_domain",
            "origin_record_id",
            "correlation_id",
            "source_type",
            "source_ref",
            "projection_version",
            "reward_owner_domain",
            "nutrition_preview",
            "hydration_ml",
            "linked_habit_projection",
            "custom_beverage",
            "drink_type",
            "food_item_id",
            "custom_name",
            "metadata",
            "save_for_reuse",
            "date",
        ]
        read_only_fields = (
            "user",
            "date",
            "linked_meal_log",
            "food_item_name",
            "nutrition_preview",
            "hydration_ml",
            "origin_domain",
            "origin_record_id",
            "correlation_id",
            "source_type",
            "source_ref",
            "projection_version",
            "reward_owner_domain",
            "linked_habit_projection",
        )
