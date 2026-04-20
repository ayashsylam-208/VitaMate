from rest_framework import serializers

from core.models import (
    FoodCategory,
    FoodItem,
    FoodItemAlias,
    MealLog,
    NutritionFacts,
    NutritionServingOption,
)


class FoodCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodCategory
        fields = ["id", "code", "name", "parent", "sort_order", "is_active"]


class FoodItemAliasSerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodItemAlias
        fields = [
            "id",
            "food_item",
            "alias",
            "normalized_alias",
            "alias_type",
            "is_primary",
            "sort_order",
        ]
        read_only_fields = ["normalized_alias"]


class NutritionFactsSerializer(serializers.ModelSerializer):
    food_item = serializers.PrimaryKeyRelatedField(queryset=FoodItem.objects.all(), required=False)

    class Meta:
        model = NutritionFacts
        fields = "__all__"
        read_only_fields = ("created_at", "updated_at")


class NutritionServingOptionSerializer(serializers.ModelSerializer):
    food_item = serializers.PrimaryKeyRelatedField(queryset=FoodItem.objects.all(), required=False)

    class Meta:
        model = NutritionServingOption
        fields = "__all__"


class FoodItemSerializer(serializers.ModelSerializer):
    nutrition_facts = NutritionFactsSerializer(required=False, allow_null=True)
    serving_options = NutritionServingOptionSerializer(many=True, required=False)

    class Meta:
        model = FoodItem
        fields = "__all__"
        read_only_fields = ("created_at", "updated_at", "created_by")


class FoodAutocompleteSerializer(serializers.ModelSerializer):
    primary_category = FoodCategorySerializer(read_only=True)
    default_serving_summary = serializers.SerializerMethodField()

    class Meta:
        model = FoodItem
        fields = [
            "id",
            "name",
            "item_type",
            "primary_category",
            "category",
            "brand_name",
            "contains_caffeine",
            "is_hydration_trackable",
            "default_serving_summary",
        ]

    def get_default_serving_summary(self, obj):
        amount = obj.default_serving_size or obj.serving_grams or 100
        unit = obj.default_serving_unit or obj.default_reference_unit or "g"
        if float(amount).is_integer():
            amount = int(amount)
        return f"{amount} {unit}"


class MealLogSerializer(serializers.ModelSerializer):
    total_calories = serializers.ReadOnlyField()
    food_name = serializers.CharField(source="food.name", read_only=True)
    food_item = serializers.PrimaryKeyRelatedField(
        source="food",
        queryset=FoodItem.objects.all(),
        required=False,
        write_only=True,
    )

    def validate(self, attrs):
        attrs = super().validate(attrs)
        if "food" not in attrs and self.instance is None:
            raise serializers.ValidationError({"food": "This field is required."})
        return attrs

    class Meta:
        model = MealLog
        fields = [
            "id",
            "user",
            "food",
            "food_item",
            "food_name",
            "meal_type",
            "quantity_grams",
            "quantity",
            "unit",
            "grams_consumed",
            "milliliters_consumed",
            "servings_consumed",
            "serving_option",
            "consumed_at",
            "notes",
            "source",
            "date",
            "total_calories",
            "snapshot_calories_kcal",
            "snapshot_protein_g",
            "snapshot_carbohydrates_g",
            "snapshot_sugars_g",
            "snapshot_fiber_g",
            "snapshot_fat_g",
            "snapshot_saturated_fat_g",
            "snapshot_trans_fat_g",
            "snapshot_cholesterol_mg",
            "snapshot_sodium_mg",
            "snapshot_potassium_mg",
            "snapshot_calcium_mg",
            "snapshot_iron_mg",
            "snapshot_magnesium_mg",
            "snapshot_zinc_mg",
            "snapshot_phosphorus_mg",
            "snapshot_vitamin_a_mcg",
            "snapshot_vitamin_c_mg",
            "snapshot_vitamin_d_mcg",
            "snapshot_vitamin_b12_mcg",
            "snapshot_folate_mcg",
            "snapshot_monounsaturated_fat_g",
            "snapshot_polyunsaturated_fat_g",
            "snapshot_added_sugars_g",
            "snapshot_water_g",
            "snapshot_caffeine_mg",
            "snapshot_vitamin_e_mg",
            "snapshot_vitamin_k_mcg",
            "snapshot_vitamin_b1_mg",
            "snapshot_vitamin_b2_mg",
            "snapshot_vitamin_b3_mg",
            "snapshot_vitamin_b6_mg",
        ]
        read_only_fields = [
            "user",
            "date",
            "total_calories",
            "grams_consumed",
            "milliliters_consumed",
            "servings_consumed",
            "snapshot_calories_kcal",
            "snapshot_protein_g",
            "snapshot_carbohydrates_g",
            "snapshot_sugars_g",
            "snapshot_fiber_g",
            "snapshot_fat_g",
            "snapshot_saturated_fat_g",
            "snapshot_trans_fat_g",
            "snapshot_cholesterol_mg",
            "snapshot_sodium_mg",
            "snapshot_potassium_mg",
            "snapshot_calcium_mg",
            "snapshot_iron_mg",
            "snapshot_magnesium_mg",
            "snapshot_zinc_mg",
            "snapshot_phosphorus_mg",
            "snapshot_vitamin_a_mcg",
            "snapshot_vitamin_c_mg",
            "snapshot_vitamin_d_mcg",
            "snapshot_vitamin_b12_mcg",
            "snapshot_folate_mcg",
            "snapshot_monounsaturated_fat_g",
            "snapshot_polyunsaturated_fat_g",
            "snapshot_added_sugars_g",
            "snapshot_water_g",
            "snapshot_caffeine_mg",
            "snapshot_vitamin_e_mg",
            "snapshot_vitamin_k_mcg",
            "snapshot_vitamin_b1_mg",
            "snapshot_vitamin_b2_mg",
            "snapshot_vitamin_b3_mg",
            "snapshot_vitamin_b6_mg",
        ]
