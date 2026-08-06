from __future__ import annotations

from django.db import transaction
from django.db.models import Max
from django.utils import timezone

from notification_hub.models import NotificationDevice, NotificationPlan


class DeviceRegistryService:
    CHANNELS_VERSION = 3
    PERMISSION_STATUSES = {
        "authorized",
        "denied",
        "not_determined",
        "provisional",
        "restricted",
        "unavailable",
    }

    @classmethod
    @transaction.atomic
    def register_device(
        cls,
        *,
        user,
        installation_id: str,
        platform: str,
        timezone_name: str,
        locale: str,
        app_version: str,
        notifications_authorized: bool,
        exact_alarm_authorized: bool,
        permission_status: str = "",
        notifications_enabled_systemwide: bool | None = None,
        permission_checked_at=None,
    ) -> NotificationDevice:
        normalized_installation = str(installation_id or "").strip()
        if not normalized_installation:
            raise ValueError("installation_id is required.")

        # Lock the account row so concurrent registrations cannot both become primary.
        user.__class__.objects.select_for_update().get(pk=user.pk)
        device, created = NotificationDevice.objects.get_or_create(
            user=user,
            installation_id=normalized_installation,
            defaults={
                "platform": str(platform or NotificationDevice.PLATFORM_ANDROID),
                "timezone": str(timezone_name or "UTC"),
                "locale": str(locale or ""),
                "app_version": str(app_version or ""),
                "notifications_authorized": bool(notifications_authorized),
                "exact_alarm_authorized": bool(exact_alarm_authorized),
                "permission_status": cls._permission_status(
                    permission_status,
                    notifications_authorized=notifications_authorized,
                ),
                "notifications_enabled_systemwide": bool(
                    notifications_authorized
                    if notifications_enabled_systemwide is None
                    else notifications_enabled_systemwide
                ),
                "permission_checked_at": permission_checked_at or timezone.now(),
                "last_seen_at": timezone.now(),
            },
        )
        if not created:
            device.platform = str(platform or device.platform)
            device.timezone = str(timezone_name or device.timezone or "UTC")
            device.locale = str(locale or device.locale)
            device.app_version = str(app_version or device.app_version)
            device.notifications_authorized = bool(notifications_authorized)
            device.exact_alarm_authorized = bool(exact_alarm_authorized)
            device.permission_status = cls._permission_status(
                permission_status,
                notifications_authorized=notifications_authorized,
            )
            device.notifications_enabled_systemwide = bool(
                notifications_authorized
                if notifications_enabled_systemwide is None
                else notifications_enabled_systemwide
            )
            device.permission_checked_at = permission_checked_at or timezone.now()
            device.last_seen_at = timezone.now()
            device.save(
                update_fields=[
                    "platform",
                    "timezone",
                    "locale",
                    "app_version",
                    "notifications_authorized",
                    "exact_alarm_authorized",
                    "permission_status",
                    "notifications_enabled_systemwide",
                    "permission_checked_at",
                    "last_seen_at",
                    "updated_at",
                ]
            )

        active_primary = NotificationDevice.objects.filter(
            user=user,
            is_primary=True,
            is_active=True,
            revoked_at__isnull=True,
        ).exists()
        if not active_primary:
            device.is_primary = True
            device.is_active = True
            device.revoked_at = None
            device.assignment_version = cls._next_assignment_version(user=user)
            device.save(
                update_fields=[
                    "is_primary",
                    "is_active",
                    "revoked_at",
                    "assignment_version",
                    "updated_at",
                ]
            )

        return device

    @classmethod
    def register_payload(cls, *, device: NotificationDevice) -> dict:
        return {
            "device_id": device.id,
            "is_primary": bool(device.is_primary),
            "is_active": bool(device.is_active and device.revoked_at is None),
            "assignment_version": int(device.assignment_version or 1),
            "delivery_enabled": bool(
                device.is_primary
                and device.is_active
                and device.revoked_at is None
                and device.notifications_authorized
                and device.notifications_enabled_systemwide
            ),
            "channels_version": cls.CHANNELS_VERSION,
            "capabilities": {
                "local_delivery": device.platform == NotificationDevice.PLATFORM_ANDROID,
                "exact_alarm_supported": True,
                "in_app_events": True,
            },
        }

    @classmethod
    def _permission_status(cls, raw: str, *, notifications_authorized: bool) -> str:
        normalized = str(raw or "").strip().lower()
        if normalized in cls.PERMISSION_STATUSES:
            return normalized
        return "authorized" if notifications_authorized else "denied"

    @classmethod
    def _next_assignment_version(cls, *, user) -> int:
        current = (
            NotificationDevice.objects.filter(user=user).aggregate(
                value=Max("assignment_version")
            )["value"]
            or 0
        )
        return int(current) + 1

    @classmethod
    @transaction.atomic
    def make_primary(cls, *, user, installation_id: str) -> NotificationDevice:
        user.__class__.objects.select_for_update().get(pk=user.pk)
        devices = list(
            NotificationDevice.objects.select_for_update()
            .filter(user=user, is_active=True, revoked_at__isnull=True)
            .order_by("id")
        )
        target = next(
            (item for item in devices if item.installation_id == installation_id),
            None,
        )
        if target is None:
            raise ValueError("Active notification device not found.")
        if target.is_primary:
            return target

        version = cls._next_assignment_version(user=user)
        old_ids = []
        for device in devices:
            if device.is_primary:
                old_ids.append(device.id)
            device.is_primary = device.id == target.id
            device.assignment_version = version
            device.save(update_fields=["is_primary", "assignment_version", "updated_at"])
        if old_ids:
            NotificationPlan.objects.filter(device_id__in=old_ids).exclude(
                status__in=[
                    NotificationPlan.STATUS_ACKNOWLEDGED,
                    NotificationPlan.STATUS_EXPIRED,
                    NotificationPlan.STATUS_CANCELLED,
                ]
            ).update(status=NotificationPlan.STATUS_CANCELLED)
        target.refresh_from_db()
        return target

    @classmethod
    def serialize_devices(cls, *, user) -> list[dict]:
        return [
            {
                "device_id": device.id,
                "installation_id": device.installation_id,
                "platform": device.platform,
                "app_version": device.app_version,
                "is_primary": bool(device.is_primary),
                "is_active": bool(device.is_active and device.revoked_at is None),
                "assignment_version": int(device.assignment_version or 1),
                "permission_status": device.permission_status,
                "notifications_enabled_systemwide": bool(
                    device.notifications_enabled_systemwide
                ),
                "last_seen_at": device.last_seen_at.isoformat(),
            }
            for device in NotificationDevice.objects.filter(user=user).order_by(
                "-is_primary", "-last_seen_at"
            )
        ]
