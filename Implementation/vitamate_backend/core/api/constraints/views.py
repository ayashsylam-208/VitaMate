from rest_framework import status, views
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from core.constraint_serializers import (
    ConstraintRecomputeSerializer,
    ConstraintResolutionRunSerializer,
    ResolvedTrackerConstraintSerializer,
)
from core.models import ConstraintResolutionRun
from core.services.constraints import ConstraintReadService, ConstraintRecomputeDispatcher


class HealthConstraintsView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, tracker_type=None):
        should_recompute = request.query_params.get("recompute") in {"1", "true", "True"}
        if should_recompute or not ConstraintReadService.has_active_constraints(user=request.user):
            ConstraintRecomputeDispatcher.dispatch_for_user(
                user=request.user,
                trigger_type=ConstraintResolutionRun.TRIGGER_MANUAL,
                trigger_reference="api_read",
                tracker_type=tracker_type,
            )
        constraints = ConstraintReadService.active_for_user(
            user=request.user,
            tracker_type=tracker_type,
        )
        serializer = ResolvedTrackerConstraintSerializer(constraints, many=True)
        return Response(
            {
                "tracker_type": tracker_type,
                "constraints": serializer.data,
                "summary": ConstraintReadService.active_summary_for_user(
                    user=request.user,
                    tracker_type=tracker_type,
                ),
            }
        )


class HealthConstraintRecomputeView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ConstraintRecomputeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        run = ConstraintRecomputeDispatcher.dispatch_for_user(
            user=request.user,
            trigger_type=serializer.validated_data.get(
                "trigger_type",
                ConstraintResolutionRun.TRIGGER_MANUAL,
            ),
            trigger_reference=serializer.validated_data.get("trigger_reference", ""),
            tracker_type=serializer.validated_data.get("tracker_type"),
            synchronous=True,
        )
        return Response(
            {
                "run": ConstraintResolutionRunSerializer(run).data,
                "summary": ConstraintReadService.active_summary_for_user(
                    user=request.user,
                    tracker_type=serializer.validated_data.get("tracker_type"),
                ),
            },
            status=status.HTTP_200_OK,
        )


class ConstraintResolutionRunListView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        runs = ConstraintResolutionRun.objects.filter(user=request.user).order_by("-started_at", "-id")[:25]
        serializer = ConstraintResolutionRunSerializer(runs, many=True)
        return Response({"runs": serializer.data})
