import json
import time

from rest_framework import views
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.utils.dateparse import parse_date
from django.utils import timezone

from core.services.orchestration.read_model_service import ReadModelService
from core.services.tracking.health_tracker_coordinator import HealthTrackerCoordinator
from gamification.services.motivation_feed_service import MotivationFeedService
from gamification.services.motivation_service import MotivationService


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
            today=timezone.localdate(),
        )
        if payload is None:
            return Response({"error": "Profile not found"}, status=404)
        return Response(payload)


class StatsHistoryView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = ReadModelService.progress_history(
            user=request.user,
            request_id=getattr(request, "request_id", "legacy-history"),
            days=7,
        )
        history = list(dict(payload.get("data") or {}).get("history") or [])
        if history is None:
            return Response({"error": "Profile not found"}, status=404)
        _mark_serializer_timing(request, {"history": history})
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
        target_date = parse_date(request.query_params.get("date") or "") or timezone.localdate()
        payload = ReadModelService.hydration_summary(
            user=request.user,
            request_id=request.request_id,
            target_date=target_date,
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


class MotivationOverviewView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = MotivationService.overview(
            user=request.user,
            request_id=request.request_id,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class MotivationPointsView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            range_days = int(request.query_params.get("range_days", 7))
        except (TypeError, ValueError):
            range_days = 7
        payload = MotivationService.points(
            user=request.user,
            request_id=request.request_id,
            range_days=range_days,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class MotivationMissionsView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = MotivationService.missions(
            user=request.user,
            request_id=request.request_id,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class MotivationMissionRefreshView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, mission_id: int):
        try:
            payload = MotivationService.refresh_mission(
                user=request.user,
                mission_id=mission_id,
                request_id=request.request_id,
            )
        except ValueError:
            return Response({"detail": "Mission not found."}, status=404)
        _mark_serializer_timing(request, payload)
        return Response(payload)


class MotivationBadgesView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = MotivationService.badges(
            user=request.user,
            request_id=request.request_id,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class MotivationFeedView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = MotivationFeedService.feed(
            user=request.user,
            request_id=request.request_id,
        )
        _mark_serializer_timing(request, payload)
        return Response(payload)


class MotivationCelebrationsAckView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        raw_ids = request.data.get("ids", []) if isinstance(request.data, dict) else []
        if not isinstance(raw_ids, list):
            return Response({"detail": "ids must be a list."}, status=400)
        try:
            ids = [int(item) for item in raw_ids]
        except (TypeError, ValueError):
            return Response({"detail": "ids must contain integers."}, status=400)

        payload = MotivationFeedService.acknowledge_celebrations(
            user=request.user,
            ids=ids,
            request_id=request.request_id,
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
                "/api/motivation/overview/": {
                    "get": {"summary": "Motivation overview"}
                },
                "/api/motivation/points/": {
                    "get": {"summary": "Motivation points history"}
                },
                "/api/motivation/missions/": {
                    "get": {"summary": "Motivation daily missions"}
                },
                "/api/motivation/missions/{id}/refresh/": {
                    "post": {"summary": "Refresh mission progress"}
                },
                "/api/motivation/badges/": {
                    "get": {"summary": "Motivation badges and progress"}
                },
                "/api/motivation/feed/": {
                    "get": {"summary": "Motivation experience feed"}
                },
                "/api/motivation/celebrations/ack/": {
                    "post": {"summary": "Acknowledge motivation celebrations"}
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
