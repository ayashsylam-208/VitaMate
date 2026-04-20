from datetime import date

from rest_framework import views
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from core.services.tracking.health_tracker_coordinator import HealthTrackerCoordinator


health_tracker_coordinator = HealthTrackerCoordinator()


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


class HealthCheckView(views.APIView):
    permission_classes = []
    authentication_classes = []

    def get(self, request):
        return Response({"status": "ok"})
