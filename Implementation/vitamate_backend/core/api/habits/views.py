from rest_framework import status, views
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from core.api.habits.serializers import (
    UnhealthyHabitAtomicSetupSerializer,
    UnhealthyHabitBaselineSerializer,
    UnhealthyHabitCreateSerializer,
    UnhealthyHabitDailyCheckInSerializer,
    UnhealthyHabitLogSerializer,
    UnhealthyHabitPlanSerializer,
    UnhealthyHabitRemindersSerializer,
)
from core.services.habits import UnhealthyHabitService


class UnhealthyHabitOverviewView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(
            UnhealthyHabitService.overview(
                user=request.user,
                request_id=getattr(request, "request_id", ""),
            )
        )


class UnhealthyHabitCreateView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = UnhealthyHabitCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = UnhealthyHabitService.create_habit(
            user=request.user,
            payload=serializer.validated_data,
            request_id=getattr(request, "request_id", ""),
        )
        return Response(payload, status=status.HTTP_201_CREATED)


class UnhealthyHabitAtomicSetupView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = UnhealthyHabitAtomicSetupSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = UnhealthyHabitService.setup_habit(
            user=request.user,
            payload=serializer.validated_data,
            request_id=getattr(request, "request_id", ""),
        )
        return Response(payload, status=status.HTTP_201_CREATED)


class UnhealthyHabitBaselineView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, habit_id: int):
        habit = UnhealthyHabitService.get_habit_for_user(user=request.user, habit_id=habit_id)
        serializer = UnhealthyHabitBaselineSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = UnhealthyHabitService.upsert_baseline(
            habit=habit,
            payload=serializer.validated_data,
            request_id=getattr(request, "request_id", ""),
        )
        return Response(payload)


class UnhealthyHabitPlanView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, habit_id: int):
        habit = UnhealthyHabitService.get_habit_for_user(user=request.user, habit_id=habit_id)
        serializer = UnhealthyHabitPlanSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = UnhealthyHabitService.upsert_plan(
            habit=habit,
            payload=serializer.validated_data,
            request_id=getattr(request, "request_id", ""),
        )
        return Response(payload)


class UnhealthyHabitLogView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, habit_id: int):
        habit = UnhealthyHabitService.get_habit_for_user(user=request.user, habit_id=habit_id)
        serializer = UnhealthyHabitLogSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = UnhealthyHabitService.log_habit(
            habit=habit,
            payload=serializer.validated_data,
            request_id=getattr(request, "request_id", ""),
        )
        return Response(payload, status=status.HTTP_201_CREATED)


class UnhealthyHabitLogDetailView(views.APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, habit_id: int, log_id: int):
        habit = UnhealthyHabitService.get_habit_for_user(user=request.user, habit_id=habit_id)
        serializer = UnhealthyHabitLogSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        payload = UnhealthyHabitService.update_habit_log(
            habit=habit,
            log_id=log_id,
            payload=serializer.validated_data,
            request_id=getattr(request, "request_id", ""),
        )
        return Response(payload)

    def delete(self, request, habit_id: int, log_id: int):
        habit = UnhealthyHabitService.get_habit_for_user(user=request.user, habit_id=habit_id)
        payload = UnhealthyHabitService.delete_habit_log(
            habit=habit,
            log_id=log_id,
            request_id=getattr(request, "request_id", ""),
        )
        return Response(payload)


class UnhealthyHabitDailyCheckInView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, habit_id: int):
        habit = UnhealthyHabitService.get_habit_for_user(user=request.user, habit_id=habit_id)
        serializer = UnhealthyHabitDailyCheckInSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = UnhealthyHabitService.daily_check_in(
            habit=habit,
            payload=serializer.validated_data,
            request_id=getattr(request, "request_id", ""),
        )
        return Response(payload, status=status.HTTP_201_CREATED)


class UnhealthyHabitReminderView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, habit_id: int):
        habit = UnhealthyHabitService.get_habit_for_user(user=request.user, habit_id=habit_id)
        serializer = UnhealthyHabitRemindersSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = UnhealthyHabitService.replace_reminders(
            habit=habit,
            reminders=serializer.validated_data.get("reminders") or [],
            request_id=getattr(request, "request_id", ""),
        )
        return Response(payload)


class UnhealthyHabitPauseView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, habit_id: int):
        habit = UnhealthyHabitService.get_habit_for_user(user=request.user, habit_id=habit_id)
        payload = UnhealthyHabitService.pause_habit(
            habit=habit,
            request_id=getattr(request, "request_id", ""),
        )
        return Response(payload)


class UnhealthyHabitResumeView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, habit_id: int):
        habit = UnhealthyHabitService.get_habit_for_user(user=request.user, habit_id=habit_id)
        payload = UnhealthyHabitService.resume_habit(
            habit=habit,
            request_id=getattr(request, "request_id", ""),
        )
        return Response(payload)
