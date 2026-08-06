from rest_framework import serializers

from core.models import (
    FoodCategory,
    FoodItem,
    FoodItemAlias,
    MealLog,
    MealLogComponent,
    Nutrient,
    NutritionFacts,
    NutritionServingOption,
)
from core.repositories.nutrition.food_item_repository import NutritionCatalogRepository
from core.services.nutrition.micronutrient_service import MicronutrientTrackingService


class FoodCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodCategory
        fields = ["id", "code", "name", "parent", "sort_order", "is_active"]


class FoodAutocompleteCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodCategory
        fields = ["id", "code", "name"]


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


class NutritionAutocompleteFactsSerializer(serializers.ModelSerializer):
    class Meta:
        model = NutritionFacts
        fields = [
            "sugars_g",
            "fiber_g",
            "sodium_mg",
            "water_g",
            "caffeine_mg",
        ]


class NutritionAutocompleteServingOptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = NutritionServingOption
        fields = [
            "id",
            "name",
            "amount",
            "unit",
            "grams_equivalent",
            "milliliters_equivalent",
            "is_default",
            "sort_order",
        ]


class MealLogComponentSerializer(serializers.ModelSerializer):
    food_name = serializers.CharField(source="display_name_snapshot", read_only=True)

    class Meta:
        model = MealLogComponent
        fields = [
            "id",
            "food_item",
            "food_name",
            "quantity_value",
            "quantity_unit",
            "resolved_grams",
            "resolved_milliliters",
            "confidence_score",
            "nutrition_snapshot",
            "source_label",
            "is_user_confirmed",
            "sort_order",
        ]
        read_only_fields = fields


class FoodItemSerializer(serializers.ModelSerializer):
    nutrition_facts = NutritionFactsSerializer(required=False, allow_null=True)
    serving_options = NutritionServingOptionSerializer(many=True, required=False)

    class Meta:
        model = FoodItem
        fields = "__all__"
        read_only_fields = ("created_at", "updated_at", "created_by")


class FoodAutocompleteSerializer(serializers.ModelSerializer):
    primary_category = FoodAutocompleteCategorySerializer(read_only=True)
    nutrition_facts = NutritionAutocompleteFactsSerializer(read_only=True)
    serving_options = NutritionAutocompleteServingOptionSerializer(many=True, read_only=True)

    class Meta:
        model = FoodItem
        fields = [
            "id",
            "name",
            "item_type",
            "primary_category",
            "category",
            "meal_tags",
            "default_serving_size",
            "default_serving_unit",
            "serving_label",
            "serving_grams",
            "calories_100g",
            "protein_100g",
            "carbs_100g",
            "fat_100g",
            "contains_caffeine",
            "is_hydration_trackable",
            "nutrition_facts",
            "serving_options",
        ]


class MealLogSerializer(serializers.ModelSerializer):
    total_calories = serializers.ReadOnlyField()
    food_name = serializers.SerializerMethodField()
    components = MealLogComponentSerializer(many=True, read_only=True)
    serving_option_name = serializers.CharField(source="serving_option.name", read_only=True)
    serving_grams_equivalent = serializers.FloatField(required=False, allow_null=True, write_only=True)
    serving_milliliters_equivalent = serializers.FloatField(required=False, allow_null=True, write_only=True)
    linked_habit_projection = serializers.SerializerMethodField()
    food_item = serializers.PrimaryKeyRelatedField(
        source="food",
        queryset=FoodItem.objects.all(),
        required=False,
        write_only=True,
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request is None or not request.user.is_authenticated:
            return
        foods = NutritionCatalogRepository.accessible_to_user(
            user=request.user,
            include_inactive=False,
        )
        self.fields["food"].queryset = foods
        self.fields["food_item"].queryset = foods
        self.fields["serving_option"].queryset = NutritionServingOption.objects.filter(
            food_item__in=foods,
        )

    def validate(self, attrs):
        attrs = super().validate(attrs)
        if "food" not in attrs and self.instance is None:
            raise serializers.ValidationError({"food": "This field is required."})
        if self.instance is not None and self.instance.is_composite:
            component_fields = {
                "food",
                "quantity_grams",
                "quantity",
                "unit",
                "serving_option",
                "serving_label_snapshot",
                "serving_grams_equivalent",
                "serving_milliliters_equivalent",
            }
            if component_fields.intersection(attrs):
                raise serializers.ValidationError(
                    {
                        "components": (
                            "Composite meal components cannot be edited through the "
                            "legacy meal endpoint."
                        )
                    }
                )
        food = attrs.get("food") or getattr(self.instance, "food", None)
        serving_option = attrs.get("serving_option")
        if serving_option is not None and food is not None:
            if serving_option.food_item_id != food.id:
                raise serializers.ValidationError(
                    {"serving_option": "The selected serving option does not belong to this food item."}
                )
        return attrs

    def get_food_name(self, obj):
        return obj.display_name or getattr(obj.food, "name", "")

    def get_linked_habit_projection(self, obj):
        if self.context.get("skip_linked_habit_projection", False):
            return None
        from core.models import UnhealthyHabitLog
        from core.services.habits.habit_evaluation_service import HabitEvaluationService

        log = (
            UnhealthyHabitLog.objects.filter(linked_meal_log=obj)
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

    class Meta:
        model = MealLog
        fields = [
            "id",
            "user",
            "food",
            "food_item",
            "food_name",
            "display_name",
            "is_composite",
            "components",
            "meal_type",
            "quantity_grams",
            "quantity",
            "unit",
            "grams_consumed",
            "milliliters_consumed",
            "servings_consumed",
            "serving_option",
            "serving_option_name",
            "serving_label_snapshot",
            "serving_grams_equivalent",
            "serving_milliliters_equivalent",
            "consumed_at",
            "notes",
            "source",
            "origin_domain",
            "origin_record_id",
            "correlation_id",
            "source_type",
            "source_ref",
            "finalization_key",
            "projection_version",
            "reward_owner_domain",
            "is_fast_food",
            "quality_tags",
            "linked_habit_projection",
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
            "origin_domain",
            "origin_record_id",
            "correlation_id",
            "source_type",
            "source_ref",
            "projection_version",
            "reward_owner_domain",
            "source",
            "quality_tags",
            "display_name",
            "is_composite",
            "components",
            "finalization_key",
            "linked_habit_projection",
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


class MicronutrientTargetSerializer(serializers.Serializer):
    nutrient_code = serializers.ChoiceField(
        choices=MicronutrientTrackingService.supported_codes(),
    )
    min_value = serializers.FloatField(required=False, allow_null=True, min_value=0)
    target_value = serializers.FloatField(required=False, allow_null=True, min_value=0)
    max_value = serializers.FloatField(required=False, allow_null=True, min_value=0)
    note = serializers.CharField(required=False, allow_blank=True, default="")
    lab_test_name = serializers.CharField(required=False, allow_blank=True, default="")
    lab_value = serializers.FloatField(required=False, allow_null=True, min_value=0)
    lab_unit = serializers.CharField(required=False, allow_blank=True, default="")
    lab_reference_min = serializers.FloatField(required=False, allow_null=True, min_value=0)
    lab_reference_max = serializers.FloatField(required=False, allow_null=True, min_value=0)
    lab_test_date = serializers.DateField(required=False, allow_null=True)
    clinician_recommended_value = serializers.FloatField(
        required=False,
        allow_null=True,
        min_value=0,
    )
    current_medication_name = serializers.CharField(required=False, allow_blank=True, default="")
    current_medication_dose = serializers.CharField(required=False, allow_blank=True, default="")
    create_medication_plan = serializers.BooleanField(required=False, default=False)
    supplement_name = serializers.CharField(required=False, allow_blank=True, default="")
    supplement_amount = serializers.FloatField(required=False, allow_null=True, min_value=0)
    supplement_unit = serializers.CharField(required=False, allow_blank=True, default="")
    schedule_time = serializers.TimeField(required=False, allow_null=True)

    def validate(self, attrs):
        has_lab_context = (
            attrs.get("lab_value") is not None
            or attrs.get("clinician_recommended_value") is not None
        )
        if (
            attrs.get("min_value") is None
            and attrs.get("target_value") is None
            and attrs.get("max_value") is None
            and not has_lab_context
        ):
            raise serializers.ValidationError(
                {
                    "target_value": (
                        "Provide at least one min, target, max value, "
                        "clinician recommendation, or lab result."
                    )
                }
            )
        if (
            attrs.get("lab_reference_min") is not None
            and attrs.get("lab_reference_max") is not None
            and attrs["lab_reference_min"] > attrs["lab_reference_max"]
        ):
            raise serializers.ValidationError(
                {"lab_reference_min": "Reference min cannot be above reference max."}
            )
        nutrient = Nutrient.objects.filter(code=attrs["nutrient_code"]).first()
        if nutrient is None:
            raise serializers.ValidationError({"nutrient_code": "Nutrient is not available."})
        attrs["nutrient"] = nutrient
        return attrs
