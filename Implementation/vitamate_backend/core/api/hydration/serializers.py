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
    custom_beverage = serializers.JSONField(required=False, write_only=True)
    save_for_reuse = serializers.BooleanField(required=False, write_only=True, default=True)
    food_item_name = serializers.CharField(source="food_item.name", read_only=True)
    nutrition_preview = serializers.SerializerMethodField()
    hydration_ml = serializers.SerializerMethodField()

    def validate(self, attrs):
        attrs = super().validate(attrs)

        request = self.context.get("request")
        user = getattr(request, "user", None)

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
            "nutrition_preview",
            "hydration_ml",
            "custom_beverage",
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
        )
