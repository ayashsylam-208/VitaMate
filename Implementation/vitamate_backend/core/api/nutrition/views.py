from datetime import date

from rest_framework import status, views, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from core.api.nutrition.serializers import (
    FoodAutocompleteSerializer,
    FoodItemSerializer,
    MealLogSerializer,
    MicronutrientTargetSerializer,
    NutritionFactsSerializer,
    NutritionServingOptionSerializer,
)
from core.services.nutrition.micronutrient_service import MicronutrientTrackingService
from core.services.nutrition.food_search_service import FoodSearchService
from core.services.nutrition.nutrition_service import NutritionService


class MealLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = MealLogSerializer

    def get_queryset(self):
        return NutritionService.get_meal_logs(
            user=self.request.user,
            on_date=date.today(),
        )

    def perform_create(self, serializer):
        data = serializer.validated_data
        log = NutritionService.log_meal(
            user=self.request.user,
            food=data["food"],
            meal_type=data["meal_type"],
            quantity_grams=data.get("quantity_grams"),
            quantity=data.get("quantity"),
            unit=data.get("unit"),
            serving_option=data.get("serving_option"),
            serving_label_snapshot=data.get("serving_label_snapshot"),
            custom_serving_grams=data.get("serving_grams_equivalent"),
            custom_serving_milliliters=data.get("serving_milliliters_equivalent"),
            consumed_at=data.get("consumed_at"),
            notes=data.get("notes", ""),
            source=data.get("source", "manual"),
        )
        serializer.instance = log

    def perform_update(self, serializer):
        data = serializer.validated_data
        has_amount_override = any(field in data for field in ("quantity_grams", "quantity", "unit"))
        quantity_grams = data.get("quantity_grams")
        quantity = data.get("quantity")
        unit = data.get("unit")
        if not has_amount_override:
            quantity_grams = serializer.instance.quantity_grams
            quantity = serializer.instance.quantity
            unit = serializer.instance.unit
        log = NutritionService.update_meal_log(
            serializer.instance,
            food=data.get("food", serializer.instance.food),
            meal_type=data.get("meal_type", serializer.instance.meal_type),
            quantity_grams=quantity_grams,
            quantity=quantity,
            unit=unit,
            serving_option=data.get("serving_option", serializer.instance.serving_option),
            serving_label_snapshot=data.get(
                "serving_label_snapshot",
                serializer.instance.serving_label_snapshot,
            ),
            custom_serving_grams=data.get("serving_grams_equivalent"),
            custom_serving_milliliters=data.get("serving_milliliters_equivalent"),
            consumed_at=data["consumed_at"] if "consumed_at" in data else None,
            notes=data.get("notes", serializer.instance.notes),
            source=data.get("source", serializer.instance.source),
        )
        serializer.instance = log

    def perform_destroy(self, instance):
        NutritionService.delete_meal_log(instance)


class FoodItemViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = FoodItemSerializer
    http_method_names = ["get", "post", "put", "patch", "head", "options"]

    def get_queryset(self):
        own_only = self.action in {"update", "partial_update", "destroy"}
        params = self.request.query_params
        return NutritionService.accessible_foods(
            user=self.request.user,
            item_type=params.get("item_type"),
            query=params.get("q", "").strip(),
            category=params.get("category"),
            meal_slot=params.get("meal_slot"),
            contains_caffeine=params.get("contains_caffeine"),
            is_hydration_trackable=params.get("is_hydration_trackable"),
            limit=params.get("limit"),
            include_inactive=False,
            own_only=own_only,
        )

    def perform_create(self, serializer):
        data = {**serializer.validated_data, "created_by": self.request.user}
        item = NutritionService.create_food_item(data)
        serializer.instance = item

    def perform_update(self, serializer):
        item = NutritionService.update_food_item(serializer.instance, serializer.validated_data)
        serializer.instance = item

    @action(detail=False, methods=["get"], url_path="search")
    def search(self, request):
        results = FoodSearchService.search(
            user=request.user,
            q=request.query_params.get("q", "").strip(),
            item_type=request.query_params.get("item_type"),
            category=request.query_params.get("category"),
            meal_slot=request.query_params.get("meal_slot"),
            contains_caffeine=request.query_params.get("contains_caffeine"),
            is_hydration_trackable=request.query_params.get("is_hydration_trackable"),
            limit=request.query_params.get("limit"),
            include_inactive=False,
        )
        serializer = self.get_serializer(results, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=["get"], url_path="autocomplete")
    def autocomplete(self, request):
        results = FoodSearchService.autocomplete(
            user=request.user,
            q=request.query_params.get("q", "").strip(),
            item_type=request.query_params.get("item_type"),
            category=request.query_params.get("category"),
            meal_slot=request.query_params.get("meal_slot"),
            contains_caffeine=request.query_params.get("contains_caffeine"),
            is_hydration_trackable=request.query_params.get("is_hydration_trackable"),
            limit=request.query_params.get("limit"),
            include_inactive=False,
        )
        serializer = FoodAutocompleteSerializer(results, many=True)
        return Response(serializer.data)


class NutritionFactsViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = NutritionFactsSerializer

    def get_queryset(self):
        return NutritionService.get_nutrition_facts_queryset()

    def perform_create(self, serializer):
        serializer.instance = NutritionService.create_nutrition_facts(serializer.validated_data)

    def perform_update(self, serializer):
        serializer.instance = NutritionService.update_nutrition_facts(
            serializer.instance,
            serializer.validated_data,
        )

    def perform_destroy(self, instance):
        NutritionService.delete_nutrition_facts(instance)


class NutritionServingOptionViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = NutritionServingOptionSerializer

    def get_queryset(self):
        return NutritionService.get_serving_options_queryset()

    def perform_create(self, serializer):
        serializer.instance = NutritionService.create_serving_option(serializer.validated_data)

    def perform_update(self, serializer):
        serializer.instance = NutritionService.update_serving_option(
            serializer.instance,
            serializer.validated_data,
        )

    def perform_destroy(self, instance):
        NutritionService.delete_serving_option(instance)


class MicronutrientOverviewView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(
            MicronutrientTrackingService.overview(
                user=request.user,
                request_id=getattr(request, "request_id", ""),
            )
        )


class MicronutrientTargetView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = MicronutrientTargetSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = MicronutrientTrackingService.upsert_target(
            user=request.user,
            payload=serializer.validated_data,
            request_id=getattr(request, "request_id", ""),
        )
        return Response(payload, status=status.HTTP_201_CREATED)
