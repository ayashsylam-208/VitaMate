from datetime import date
import json
import time

from rest_framework import views
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from core.services.orchestration.read_model_service import ReadModelService
from core.services.tracking.health_tracker_coordinator import HealthTrackerCoordinator


health_tracker_coordinator = HealthTrackerCoordinator()


def _mark_serializer_timing(request, payload) -> None:
    started = time.perf_counter()
    json.dumps(payload, default=str)
    request._perf_serializer_ms = round(
        float(getattr(request, "_perf_serializer_ms", 0.0))
        + ((time.perf_counter() - started) * 1000),
        2,
    )


class DashboardView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = health_tracker_coordinator.build_dashboard(
            user=request.user,
            today=date.today(),
        )
        if payload is None:
            return Response({"error": "Profile not found"}, status=404)
        return Response(payload)


class StatsHistoryView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        history = health_tracker_coordinator.build_history(
            user=request.user,
            today=date.today(),
            days=7,
        )
        if history is None:
            return Response({"error": "Profile not found"}, status=404)
        return Response({"history": history})


class HomeOverviewView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = ReadModelService.home_overview(
            user=request.user,
            request_id=request.request_id,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class ProgressOverviewView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = ReadModelService.progress_overview(
            user=request.user,
            request_id=request.request_id,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class ProgressHistoryView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = ReadModelService.progress_history(
            user=request.user,
            request_id=request.request_id,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class ProgressDetailView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, tracker: str):
        try:
            range_days = int(request.query_params.get("range_days", 7))
        except (TypeError, ValueError):
            range_days = 7
        payload = ReadModelService.progress_detail(
            user=request.user,
            request_id=request.request_id,
            tracker=tracker,
            range_days=range_days,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class NutritionSummaryView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = ReadModelService.nutrition_summary(
            user=request.user,
            request_id=request.request_id,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class HydrationSummaryView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = ReadModelService.hydration_summary(
            user=request.user,
            request_id=request.request_id,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class SleepSummaryView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = ReadModelService.sleep_summary(
            user=request.user,
            request_id=request.request_id,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class StepsSummaryView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = ReadModelService.steps_summary(
            user=request.user,
            request_id=request.request_id,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class ActivitySummaryView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = ReadModelService.activity_summary(
            user=request.user,
            request_id=request.request_id,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class MedicationsOverviewView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = ReadModelService.medications_overview(
            user=request.user,
            request_id=request.request_id,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class ChronicOverviewView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = ReadModelService.chronic_overview(
            user=request.user,
            request_id=request.request_id,
            view=request.query_params.get("view", ""),
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class OpenApiSchemaView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        schema = {
            "openapi": "3.0.3",
            "info": {
                "title": "VitaMate API",
                "version": "1.0.0",
            },
            "paths": {
                "/api/home/overview/": {"get": {"summary": "Home overview"}},
                "/api/progress/overview/": {"get": {"summary": "Progress overview"}},
                "/api/progress/history/": {"get": {"summary": "Progress history"}},
                "/api/progress/details/{tracker}/": {
                    "get": {"summary": "Progress tracker detail"}
                },
                "/api/nutrition/summary/": {"get": {"summary": "Nutrition summary"}},
                "/api/nutrition/micronutrients/": {
                    "get": {"summary": "Nutrition micronutrient overview"}
                },
                "/api/nutrition/micronutrients/targets/": {
                    "post": {"summary": "Create or update a micronutrient target"}
                },
                "/api/hydration/summary/": {"get": {"summary": "Hydration summary"}},
                "/api/sleep/summary/": {"get": {"summary": "Sleep summary"}},
                "/api/sleep/coach/today/": {
                    "get": {"summary": "Sleep coach current plan"}
                },
                "/api/sleep/coach/plans/": {
                    "post": {"summary": "Create a sleep coach plan"}
                },
                "/api/sleep/coach/plans/cancel/": {
                    "post": {"summary": "Cancel active sleep coach plans"}
                },
                "/api/sleep/coach/feedback/": {
                    "post": {"summary": "Save sleep coach morning feedback"}
                },
                "/api/steps/summary/": {"get": {"summary": "Steps summary"}},
                "/api/activity/summary/": {"get": {"summary": "Activity summary"}},
                "/api/medications/overview/": {
                    "get": {"summary": "Medications overview"}
                },
                "/api/chronic/overview/": {"get": {"summary": "Chronic overview"}},
                "/api/habits/unhealthy/overview/": {
                    "get": {"summary": "Unhealthy habits overview"}
                },
                "/api/habits/unhealthy/": {
                    "post": {"summary": "Create an unhealthy habit"}
                },
                "/api/habits/unhealthy/{id}/baseline/": {
                    "post": {"summary": "Create or update an unhealthy habit baseline"}
                },
                "/api/habits/unhealthy/{id}/plan/": {
                    "post": {"summary": "Create or update an unhealthy habit plan"}
                },
                "/api/habits/unhealthy/{id}/logs/": {
                    "post": {"summary": "Log an unhealthy habit event"}
                },
                "/api/habits/unhealthy/{id}/reminders/": {
                    "post": {"summary": "Replace unhealthy habit reminders"}
                },
                "/api/habits/unhealthy/{id}/pause/": {
                    "post": {"summary": "Pause an unhealthy habit"}
                },
            },
        }
        _mark_serializer_timing(request, schema)
        return Response(schema)


class HealthCheckView(views.APIView):
    permission_classes = []
    authentication_classes = []

    def get(self, request):
        return Response({"status": "ok"})
