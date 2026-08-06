from rest_framework import serializers

from ai_meals.models import (
    MealAnalysisCandidate,
    MealAnalysisComponent,
    MealAnalysisSession,
)
from core.models import MealLog
from core.services.nutrition.nutrition_service import NutritionLoggingService


class AnalyzeMealSerializer(serializers.Serializer):
    image = serializers.FileField()
    auto_weight_mode = serializers.ChoiceField(
        choices=("try", "skip"),
        default="try",
        required=False,
    )
    dishware_profile_id = serializers.CharField(required=False, allow_blank=True)
    plate_diameter_cm = serializers.FloatField(required=False, min_value=5, max_value=80)


class MealAnalysisCandidateSerializer(serializers.ModelSerializer):
    mapped_food_name = serializers.CharField(source="mapped_food_item.name", read_only=True)

    class Meta:
        model = MealAnalysisCandidate
        fields = (
            "id",
            "kind",
            "provider_id",
            "label",
            "display_name_ar",
            "confidence_score",
            "rank",
            "mapped_food_item",
            "mapped_food_name",
        )


class MealAnalysisComponentSerializer(serializers.ModelSerializer):
    mapped_food_name = serializers.CharField(source="mapped_food_item.name", read_only=True)
    estimated_nutrition = serializers.SerializerMethodField()
    mapped_food_nutrition_100g = serializers.SerializerMethodField()

    class Meta:
        model = MealAnalysisComponent
        fields = (
            "id",
            "provider_id",
            "provider_label",
            "mapped_food_item",
            "mapped_food_name",
            "mapped_food_nutrition_100g",
            "confidence_score",
            "suggested_percentage",
            "suggested_grams",
            "confirmed_grams",
            "is_included",
            "is_user_confirmed",
            "estimated_nutrition",
            "sort_order",
        )

    def get_estimated_nutrition(self, obj):
        food = obj.mapped_food_item
        grams = obj.confirmed_grams or obj.suggested_grams
        if food is None or grams is None:
            return None
        amount = NutritionLoggingService._resolve_consumption_amount(
            food=food,
            quantity_grams=grams,
            quantity=None,
            unit=None,
            serving_option=None,
        )
        snapshot = NutritionLoggingService._calculate_snapshot(
            food=food,
            amount=amount,
        )
        return {
            "calories_kcal": snapshot.get("snapshot_calories_kcal", 0),
            "protein_g": snapshot.get("snapshot_protein_g", 0),
            "carbs_g": snapshot.get("snapshot_carbohydrates_g", 0),
            "fat_g": snapshot.get("snapshot_fat_g", 0),
        }

    def get_mapped_food_nutrition_100g(self, obj):
        food = obj.mapped_food_item
        if food is None:
            return None
        return {
            "calories_kcal": float(food.calories_100g or 0),
            "protein_g": float(food.protein_100g or 0),
            "carbs_g": float(food.carbs_100g or 0),
            "fat_g": float(food.fat_100g or 0),
        }


class MealAnalysisSessionSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()
    candidates = MealAnalysisCandidateSerializer(many=True, read_only=True)
    components = MealAnalysisComponentSerializer(many=True, read_only=True)
    mask_preview = serializers.SerializerMethodField()
    user_message = serializers.SerializerMethodField()
    weight_status = serializers.SerializerMethodField()
    weight_message = serializers.SerializerMethodField()
    weight_estimation_attempted = serializers.SerializerMethodField()
    finalized_meal_id = serializers.IntegerField(read_only=True)

    class Meta:
        model = MealAnalysisSession
        fields = (
            "id",
            "analysis_key",
            "status",
            "image_url",
            "provider_status",
            "decision_code",
            "finalize_allowed",
            "required_user_inputs",
            "selected_dish_id",
            "selected_dish_label",
            "estimated_weight_grams",
            "meal_type",
            "consumed_at",
            "candidates",
            "components",
            "mask_preview",
            "model_versions",
            "user_message",
            "weight_status",
            "weight_message",
            "weight_estimation_attempted",
            "failure_code",
            "failure_message",
            "finalized_meal_id",
            "expires_at",
            "created_at",
            "updated_at",
        )

    def get_image_url(self, obj):
        if not obj.image:
            return ""
        request = self.context.get("request")
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url

    def get_mask_preview(self, obj):
        value = obj.raw_analysis.get("mask_preview", {})
        return value if isinstance(value, dict) else {}

    def get_user_message(self, obj):
        return str(obj.raw_analysis.get("user_message") or "")

    def get_weight_status(self, obj):
        return str(obj.raw_analysis.get("weight_status") or "")

    def get_weight_message(self, obj):
        return str(obj.raw_analysis.get("weight_message") or "")

    def get_weight_estimation_attempted(self, obj):
        versions = obj.raw_analysis.get("model_versions") or {}
        return versions.get("auto_weight_mode") == "try"


class ConfirmedAnalysisComponentSerializer(serializers.Serializer):
    id = serializers.IntegerField(required=False)
    food_item_id = serializers.IntegerField()
    confirmed_grams = serializers.FloatField(min_value=0.1, max_value=10000)
    is_included = serializers.BooleanField(default=True, required=False)
    provider_id = serializers.CharField(required=False, allow_blank=True)
    provider_label = serializers.CharField(required=False, allow_blank=True, max_length=160)


class ConfirmMealAnalysisSerializer(serializers.Serializer):
    selected_dish_id = serializers.CharField(required=False, allow_blank=True, max_length=120)
    selected_dish_label = serializers.CharField(max_length=160)
    meal_type = serializers.ChoiceField(choices=MealLog.MEAL_TYPES)
    consumed_at = serializers.DateTimeField(required=False, allow_null=True)
    components = ConfirmedAnalysisComponentSerializer(many=True, allow_empty=False)


class FinalizeMealAnalysisSerializer(serializers.Serializer):
    notes = serializers.CharField(required=False, allow_blank=True, max_length=2000)
