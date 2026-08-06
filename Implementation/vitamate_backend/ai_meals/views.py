from django.db.models import Sum
from django.utils import timezone
from rest_framework import status, views
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ai_meals.gateway import AIServiceError
from ai_meals.serializers import (
    AnalyzeMealSerializer,
    ConfirmMealAnalysisSerializer,
    FinalizeMealAnalysisSerializer,
    MealAnalysisSessionSerializer,
)
from ai_meals.services import MealAnalysisService
from core.api.nutrition.serializers import MealLogSerializer
from core.services.nutrition.nutrition_service import NutritionService
from core.models import MealLog, UnhealthyHabitLog, WaterLog
from gamification.models import PointsTransaction, UserScore


class AnalyzeMealView(views.APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        serializer = AnalyzeMealSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        analysis_key = str(request.headers.get("Idempotency-Key") or "").strip()
        if analysis_key and (len(analysis_key) < 8 or len(analysis_key) > 120):
            return Response(
                {"idempotency_key": "Use an Idempotency-Key between 8 and 120 characters."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        service = MealAnalysisService()
        try:
            analysis = service.analyze(
                user=request.user,
                analysis_key=analysis_key,
                **serializer.validated_data,
            )
        except AIServiceError as exc:
            return Response(
                {
                    "detail": str(exc),
                    "code": exc.code,
                    "retryable": exc.retryable,
                    "analysis_id": str(getattr(exc, "analysis_id", "")),
                },
                status=(
                    status.HTTP_503_SERVICE_UNAVAILABLE
                    if exc.retryable
                    else status.HTTP_422_UNPROCESSABLE_ENTITY
                ),
            )
        analysis = service.get_for_user(
            user=request.user,
            analysis_id=analysis.id,
        )
        return Response(
            {"data": MealAnalysisSessionSerializer(analysis, context={"request": request}).data},
            status=status.HTTP_201_CREATED,
        )


class MealAnalysisDetailView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, analysis_id):
        analysis = MealAnalysisService.get_for_user(
            user=request.user,
            analysis_id=analysis_id,
        )
        return Response(
            {"data": MealAnalysisSessionSerializer(analysis, context={"request": request}).data}
        )

    def patch(self, request, analysis_id):
        serializer = ConfirmMealAnalysisSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        analysis = MealAnalysisService().confirm(
            user=request.user,
            analysis_id=analysis_id,
            payload=serializer.validated_data,
        )
        analysis = MealAnalysisService.get_for_user(
            user=request.user,
            analysis_id=analysis.id,
        )
        return Response(
            {"data": MealAnalysisSessionSerializer(analysis, context={"request": request}).data}
        )


class FinalizeMealAnalysisView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, analysis_id):
        idempotency_key = str(request.headers.get("Idempotency-Key") or "").strip()
        if len(idempotency_key) < 8 or len(idempotency_key) > 120:
            return Response(
                {"idempotency_key": "Provide an Idempotency-Key between 8 and 120 characters."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = FinalizeMealAnalysisSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        score_before = (
            UserScore.objects.filter(user=request.user)
            .values_list("total_points", flat=True)
            .first()
            or 0
        )
        analysis, meal, already_finalized = MealAnalysisService().finalize(
            user=request.user,
            analysis_id=analysis_id,
            idempotency_key=idempotency_key,
            notes=serializer.validated_data.get("notes", ""),
        )
        score = UserScore.objects.filter(user=request.user).first()
        score_total = int(getattr(score, "total_points", 0) or 0)
        score_level = int(getattr(score, "level", 1) or 1)
        daily_points = (
            PointsTransaction.objects.filter(
                user=request.user,
                event_date=meal.date,
            ).aggregate(total=Sum("points"))["total"]
            or 0
        )
        nutrition_summary = NutritionService.nutrition_totals_for_day(
            user=request.user,
            on_date=meal.date,
        )
        hydration_liters = (
            WaterLog.objects.filter(user=request.user, linked_meal_log=meal)
            .aggregate(total=Sum("amount_liter"))["total"]
            or 0
        )
        hydration_delta_ml = round(float(hydration_liters) * 1000, 2)
        habit_events = list(
            UnhealthyHabitLog.objects.filter(linked_meal_log=meal)
            .select_related("habit")
            .order_by("id")
            .values(
                "id",
                "habit_id",
                "habit__habit_type",
                "source_type",
                "source_ref",
                "quantity",
                "unit",
            )
        )
        for event in habit_events:
            event["habit_type"] = event.pop("habit__habit_type")

        meal = (
            MealLog.objects.filter(id=meal.id, user=request.user)
            .select_related("food", "serving_option")
            .prefetch_related("components__food_item")
            .get()
        )
        meal_nutrition = {
            "calories_kcal": float(meal.snapshot_calories_kcal or 0),
            "protein_g": float(meal.snapshot_protein_g or 0),
            "carbohydrates_g": float(meal.snapshot_carbohydrates_g or 0),
            "fat_g": float(meal.snapshot_fat_g or 0),
            "fiber_g": float(meal.snapshot_fiber_g or 0),
            "sugars_g": float(meal.snapshot_sugars_g or 0),
            "sodium_mg": float(meal.snapshot_sodium_mg or 0),
        }
        meal_data = MealLogSerializer(
            meal,
            context={
                "request": request,
                "skip_linked_habit_projection": True,
            },
        ).data
        points_delta = 0 if already_finalized else score_total - int(score_before)
        return Response(
            {
                "data": {
                    "analysis_id": str(analysis.id),
                    "meal": meal_data,
                    "nutrition_summary": meal_nutrition,
                    "hydration_delta_ml": hydration_delta_ml,
                    "habit_events": habit_events,
                    "points_delta": points_delta,
                    "today_summary": nutrition_summary,
                    "already_finalized": already_finalized,
                    # Compatibility aliases for clients predating the AI meal contract.
                    "summary": nutrition_summary,
                    "hydration": {"delta_ml": hydration_delta_ml},
                    "points": {
                        "daily_points": int(daily_points),
                        "total_points": score_total,
                        "level": score_level,
                    },
                    "finalized_at": timezone.now().isoformat(),
                }
            },
            status=status.HTTP_201_CREATED,
        )
