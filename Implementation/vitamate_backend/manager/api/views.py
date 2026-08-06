from rest_framework import status, views
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from manager.api.serializers import (
    AccountDeletionSerializer,
    AvatarUploadSerializer,
    HealthGoalPatchSerializer,
    PasswordChangeSerializer,
)
from manager.services.avatar_service import AvatarService
from manager.services.goals_service import ManagerGoalsService
from manager.services.privacy_service import PrivacyService
from manager.services.read_model_service import ManagerReadModelService
from notification_hub.services.preferences_service import NotificationPreferencesService
from users.serializers import UserUpdateSerializer


class ManagerOverviewView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(
            ManagerReadModelService.overview(
                user=request.user,
                request_id=getattr(request, "request_id", ""),
            )
        )


class ManagerGoalsView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response({"data": {"goals": ManagerGoalsService.list_goals(user=request.user)}})


class ManagerGoalDetailView(views.APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, key: str):
        serializer = HealthGoalPatchSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            goal = ManagerGoalsService.upsert_custom_goal(
                user=request.user,
                key=key,
                custom_value=serializer.validated_data.get("custom_value"),
            )
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=400)
        return Response({"data": {"goal": goal}})


class ManagerGoalsResetView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        return Response({"data": {"goals": ManagerGoalsService.reset_goals(user=request.user)}})


class ManagerNotificationsView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(NotificationPreferencesService.serialize(user=request.user))

    def patch(self, request):
        return Response(
            NotificationPreferencesService.apply_patch(
                user=request.user,
                payload=request.data if isinstance(request.data, dict) else {},
            )
        )


class ManagerSecurityView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(ManagerReadModelService.security(user=request.user))


class ManagerLogoutAllView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        # JWT blacklist is not enabled in this project; clients still clear local tokens.
        return Response({"data": {"revoked": False, "detail": "Local logout required on each device."}})


class ManagerChangePasswordView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = PasswordChangeSerializer(
            data=request.data,
            context={"user": request.user},
        )
        serializer.is_valid(raise_exception=True)
        request.user.set_password(serializer.validated_data["new_password"])
        request.user.save(update_fields=["password"])
        return Response({"data": {"password_changed": True}})


class ManagerAvatarView(views.APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        serializer = AvatarUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        avatar_url = AvatarService.replace_avatar(
            user=request.user,
            uploaded_file=serializer.validated_data["avatar"],
        )
        return Response(
            {
                "data": {
                    "avatar_url": avatar_url,
                    "user": UserUpdateSerializer(request.user).data,
                }
            },
            status=status.HTTP_200_OK,
        )

    def delete(self, request):
        AvatarService.clear_avatar(user=request.user)
        return Response({"data": {"avatar_url": ""}})


class ManagerPrivacyView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(ManagerReadModelService.privacy(user=request.user))


class ManagerPrivacyExportView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        return Response(PrivacyService.request_export(user=request.user))


class ManagerAccountDeletionView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = AccountDeletionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(
            PrivacyService.request_account_deletion(
                user=request.user,
                reason=serializer.validated_data.get("reason", ""),
            )
        )

    def delete(self, request):
        return Response(PrivacyService.cancel_account_deletion(user=request.user))
