from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework import views
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from notification_hub.api.serializers import (
    DeviceRegisterSerializer,
    NotificationPrimaryDeviceSerializer,
    NotificationPreferencesPatchSerializer,
    NotificationReportSerializer,
    NotificationSyncSerializer,
)
from notification_hub.models import NotificationDevice
from notification_hub.services.device_registry_service import DeviceRegistryService
from notification_hub.services.planner import NotificationHubPlanner
from notification_hub.services.preferences_service import NotificationPreferencesService


class NotificationDeviceRegisterView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = DeviceRegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        device = DeviceRegistryService.register_device(
            user=request.user,
            installation_id=serializer.validated_data["installation_id"],
            platform=serializer.validated_data["platform"],
            timezone_name=serializer.validated_data.get("timezone", ""),
            locale=serializer.validated_data.get("locale", ""),
            app_version=serializer.validated_data.get("app_version", ""),
            notifications_authorized=serializer.validated_data.get(
                "notifications_authorized",
                False,
            ),
            exact_alarm_authorized=serializer.validated_data.get(
                "exact_alarm_authorized",
                False,
            ),
            permission_status=serializer.validated_data.get("permission_status", ""),
            notifications_enabled_systemwide=serializer.validated_data.get(
                "notifications_enabled_systemwide"
            ),
            permission_checked_at=serializer.validated_data.get("checked_at"),
        )
        return Response(DeviceRegistryService.register_payload(device=device))


class NotificationPreferencesView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(NotificationPreferencesService.serialize(user=request.user))

    def patch(self, request):
        serializer = NotificationPreferencesPatchSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(
            NotificationPreferencesService.apply_patch(
                user=request.user,
                payload=serializer.validated_data,
            )
        )


class NotificationDevicesView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response({"devices": DeviceRegistryService.serialize_devices(user=request.user)})


class NotificationPrimaryDeviceView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = NotificationPrimaryDeviceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            device = DeviceRegistryService.make_primary(
                user=request.user,
                installation_id=serializer.validated_data["installation_id"],
            )
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=404)
        return Response(DeviceRegistryService.register_payload(device=device))


class NotificationSyncView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = NotificationSyncSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        installation_id = serializer.validated_data["installation_id"]
        device = NotificationDevice.objects.filter(
            user=request.user,
            installation_id=installation_id,
        ).first()
        if device is None:
            device = DeviceRegistryService.register_device(
                user=request.user,
                installation_id=installation_id,
                platform="android",
                timezone_name=serializer.validated_data.get("timezone", ""),
                locale="",
                app_version="",
                notifications_authorized=bool(
                    (serializer.validated_data.get("permission_snapshot") or {}).get(
                        "notifications_authorized",
                        False,
                    )
                ),
                exact_alarm_authorized=bool(
                    (serializer.validated_data.get("permission_snapshot") or {}).get(
                        "exact_alarm_authorized",
                        False,
                    )
                ),
                permission_status=str(
                    (serializer.validated_data.get("permission_snapshot") or {}).get(
                        "permission_status",
                        "",
                    )
                ),
                notifications_enabled_systemwide=(
                    serializer.validated_data.get("permission_snapshot") or {}
                ).get("notifications_enabled_systemwide"),
                permission_checked_at=(
                    serializer.validated_data.get("permission_snapshot") or {}
                ).get("checked_at"),
            )
        else:
            snapshot = serializer.validated_data.get("permission_snapshot") or {}
            device.notifications_authorized = bool(
                snapshot.get("notifications_authorized", device.notifications_authorized)
            )
            device.exact_alarm_authorized = bool(
                snapshot.get("exact_alarm_authorized", device.exact_alarm_authorized)
            )
            device.notifications_enabled_systemwide = bool(
                snapshot.get(
                    "notifications_enabled_systemwide",
                    device.notifications_enabled_systemwide,
                )
            )
            status_value = str(snapshot.get("permission_status") or "").strip()
            if status_value in DeviceRegistryService.PERMISSION_STATUSES:
                device.permission_status = status_value
            checked_at = snapshot.get("checked_at")
            if checked_at is not None:
                device.permission_checked_at = (
                    checked_at
                    if hasattr(checked_at, "tzinfo")
                    else parse_datetime(str(checked_at))
                )
            device.timezone = serializer.validated_data.get("timezone") or device.timezone
            device.last_seen_at = timezone.now()
            device.save()
        payload = NotificationHubPlanner.sync(
            user=request.user,
            device=device,
            last_known_plan_ids=serializer.validated_data.get("last_known_plan_ids", []),
            foreground_state=serializer.validated_data.get("foreground_state", "background"),
            request_id=getattr(request, "request_id", ""),
        )
        return Response(payload)


class NotificationReportView(views.APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = NotificationReportSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        device = NotificationDevice.objects.filter(
            user=request.user,
            installation_id=serializer.validated_data["installation_id"],
        ).first()
        if device is None:
            return Response({"detail": "Device not registered."}, status=404)
        try:
            payload = NotificationHubPlanner.report(
                user=request.user,
                device=device,
                events=serializer.validated_data.get("events", []),
                request_id=getattr(request, "request_id", ""),
            )
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=400)
        return Response(payload)
