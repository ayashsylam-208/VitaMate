from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated

from core.api.tracking.serializers import (
    ActivityLogSerializer,
    ExerciseSerializer,
    SleepLogSerializer,
    StepLogSerializer,
)
from core.models import Exercise
from core.services.tracking.activity_service import ActivityService
from core.services.tracking.sleep_service import SleepService
from core.services.tracking.steps_service import StepsService


class StepLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = StepLogSerializer

    def get_queryset(self):
        return StepsService.get_step_logs(user=self.request.user)

    def perform_create(self, serializer):
        log = StepsService.log_steps(
            user=self.request.user,
            steps_count=serializer.validated_data.get("steps_count", 0),
            distance_km=serializer.validated_data.get("distance_km", 0),
        )
        serializer.instance = log

    def perform_update(self, serializer):
        log = StepsService.update_step_log(
            serializer.instance,
            steps_count=serializer.validated_data.get("steps_count"),
            distance_km=serializer.validated_data.get("distance_km"),
        )
        serializer.instance = log

    def perform_destroy(self, instance):
        StepsService.delete_step_log(instance)


class ActivityLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = ActivityLogSerializer

    def get_queryset(self):
        return ActivityService.get_activity_logs(user=self.request.user)

    def perform_create(self, serializer):
        log = ActivityService.log_activity(
            user=self.request.user,
            exercise=serializer.validated_data["exercise"],
            duration_minutes=serializer.validated_data["duration_minutes"],
        )
        serializer.instance = log

    def perform_update(self, serializer):
        log = ActivityService.update_activity_log(
            serializer.instance,
            exercise=serializer.validated_data.get("exercise"),
            duration_minutes=serializer.validated_data.get("duration_minutes"),
        )
        serializer.instance = log

    def perform_destroy(self, instance):
        ActivityService.delete_activity_log(instance)


class ExerciseViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = ExerciseSerializer
    queryset = Exercise.objects.all().order_by("name")


class SleepLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = SleepLogSerializer

    def get_queryset(self):
        return SleepService.get_sleep_logs(user=self.request.user)

    def perform_create(self, serializer):
        log = SleepService.log_sleep(
            user=self.request.user,
            start_time=serializer.validated_data["start_time"],
            end_time=serializer.validated_data["end_time"],
            quality=serializer.validated_data["quality"],
        )
        serializer.instance = log

    def perform_update(self, serializer):
        log = SleepService.update_sleep_log(
            serializer.instance,
            start_time=serializer.validated_data.get("start_time"),
            end_time=serializer.validated_data.get("end_time"),
            quality=serializer.validated_data.get("quality"),
        )
        serializer.instance = log

    def perform_destroy(self, instance):
        SleepService.delete_sleep_log(instance)
