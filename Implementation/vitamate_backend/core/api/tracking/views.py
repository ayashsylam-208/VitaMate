from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import status, views, viewsets
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from core.api.tracking.serializers import (
    ActivityLogSerializer,
    ActivitySessionCreateSerializer,
    ActivitySessionEditSerializer,
    ActivitySessionFinishSerializer,
    ActivitySessionSerializer,
    ExerciseSerializer,
    SleepCoachFeedbackSerializer,
    SleepCoachPlanCreateSerializer,
    SleepLogSerializer,
    StepLogSerializer,
)
from core.models import Exercise
from core.repositories.tracking.activity_session_repository import ActivitySessionRepository
from core.services.tracking.activity_session_service import ActivitySessionService
from core.services.tracking.activity_service import ActivityService
from core.services.tracking.sleep_coach_service import SleepCoachService
from core.services.tracking.sleep_service import SleepService
from core.services.tracking.steps_service import StepsService


class StepLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = StepLogSerializer

    def get_queryset(self):
        return StepsService.get_step_logs(user=self.request.user)

    def perform_create(self, serializer):
        try:
            log = StepsService.log_steps(
                user=self.request.user,
                steps_count=serializer.validated_data.get("steps_count", 0),
                distance_km=serializer.validated_data.get("distance_km", 0),
                local_date=serializer.validated_data.get("local_date"),
                timezone_name=serializer.validated_data.get("timezone", ""),
                installation_id=serializer.validated_data.get("installation_id", ""),
                measured_at=serializer.validated_data.get("measured_at"),
                sensor_steps=serializer.validated_data.get("sensor_steps"),
                manual_adjustment_steps=serializer.validated_data.get("manual_adjustment_steps"),
                imported_adjustment_steps=serializer.validated_data.get("imported_adjustment_steps"),
                sync_version=serializer.validated_data.get("sync_version"),
            )
        except DjangoValidationError as error:
            _raise_validation_error(error)
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
    queryset = Exercise.objects.all().order_by("sort_order", "name")


def _raise_validation_error(error: DjangoValidationError):
    if hasattr(error, "message_dict"):
        raise ValidationError(error.message_dict)
    messages = error.messages if hasattr(error, "messages") else [str(error)]
    raise ValidationError({"detail": messages})


class ActivityActiveSessionView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        session = ActivitySessionRepository.get_active_for_user(user=request.user)
        if session is None:
            return Response(None, status=status.HTTP_200_OK)
        return Response(ActivitySessionSerializer(session).data)


class ActivitySessionCreateView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ActivitySessionCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            session = ActivitySessionService.start_session(
                user=request.user,
                exercise=serializer.validated_data["exercise"],
                target_duration_seconds=serializer.validated_data["target_duration_seconds"],
                intensity=serializer.validated_data["intensity"],
                source=serializer.validated_data["source"],
            )
        except DjangoValidationError as error:
            _raise_validation_error(error)
        return Response(ActivitySessionSerializer(session).data, status=status.HTTP_201_CREATED)


class _ActivitySessionActionView(views.APIView):
    permission_classes = [IsAuthenticated]

    def _get_session(self, request, session_id):
        session = ActivitySessionRepository.get_for_user(user=request.user, session_id=session_id)
        if session is None:
            raise ValidationError({"detail": ["Session not found."]})
        return session


class ActivitySessionPauseView(_ActivitySessionActionView):
    def patch(self, request, session_id):
        try:
            session = ActivitySessionService.pause_session(self._get_session(request, session_id))
        except DjangoValidationError as error:
            _raise_validation_error(error)
        return Response(ActivitySessionSerializer(session).data)


class ActivitySessionResumeView(_ActivitySessionActionView):
    def patch(self, request, session_id):
        try:
            session = ActivitySessionService.resume_session(self._get_session(request, session_id))
        except DjangoValidationError as error:
            _raise_validation_error(error)
        return Response(ActivitySessionSerializer(session).data)


class ActivitySessionEditView(_ActivitySessionActionView):
    def patch(self, request, session_id):
        serializer = ActivitySessionEditSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            session = ActivitySessionService.edit_session(
                self._get_session(request, session_id),
                exercise=serializer.validated_data.get("exercise"),
                target_duration_seconds=serializer.validated_data.get("target_duration_seconds"),
                intensity=serializer.validated_data.get("intensity"),
            )
        except DjangoValidationError as error:
            _raise_validation_error(error)
        return Response(ActivitySessionSerializer(session).data)


class ActivitySessionFinishView(_ActivitySessionActionView):
    def post(self, request, session_id):
        serializer = ActivitySessionFinishSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            session = ActivitySessionService.finish_session(
                self._get_session(request, session_id),
                save_partial=serializer.validated_data["save_partial"],
            )
        except DjangoValidationError as error:
            _raise_validation_error(error)
        return Response(ActivitySessionSerializer(session).data)


class ActivitySessionCancelView(_ActivitySessionActionView):
    def post(self, request, session_id):
        try:
            session = ActivitySessionService.cancel_session(self._get_session(request, session_id))
        except DjangoValidationError as error:
            _raise_validation_error(error)
        return Response(ActivitySessionSerializer(session).data)


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


def _coach_envelope(data, request):
    return {
        "data": data,
        "meta": {
            "is_stale": False,
            "computed_at": None,
            "snapshot_version": "sleep-coach-v1",
            "request_id": getattr(request, "request_id", ""),
        },
    }


class SleepCoachTodayView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        payload = SleepCoachService.today_payload(user=request.user)
        return Response(_coach_envelope(payload, request))


class SleepCoachPlanView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = SleepCoachPlanCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        plan = SleepCoachService.create_plan(
            user=request.user,
            planned_bed_time=serializer.validated_data["planned_bed_time"],
            latest_wake_time=serializer.validated_data["latest_wake_time"],
            flexibility_minutes=serializer.validated_data["flexibility_minutes"],
            questionnaire=serializer.validated_data.get("questionnaire") or {},
        )
        return Response(
            _coach_envelope({"plan": SleepCoachService.serialize_plan(plan)}, request),
            status=status.HTTP_201_CREATED,
        )


class SleepCoachFeedbackView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = SleepCoachFeedbackSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        feedback = SleepCoachService.save_feedback(
            user=request.user,
            plan_id=serializer.validated_data["plan_id"],
            quality_rating=serializer.validated_data["quality_rating"],
            wake_feeling=serializer.validated_data["wake_feeling"],
            focus_rating=serializer.validated_data["focus_rating"],
            disruptor=serializer.validated_data.get("disruptor", ""),
            actual_sleep_start=serializer.validated_data.get("actual_sleep_start"),
            actual_wake_time=serializer.validated_data.get("actual_wake_time"),
        )
        return Response(
            _coach_envelope(
                {
                    "feedback": SleepCoachService.serialize_feedback(feedback),
                    "learning_summary": SleepCoachService.learning_summary(user=request.user),
                },
                request,
            )
        )


class SleepCoachCancelPlanView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        cancelled = SleepCoachService.cancel_active_plan(user=request.user)
        return Response(_coach_envelope({"cancelled": cancelled}, request))
