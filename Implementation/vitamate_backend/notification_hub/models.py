from __future__ import annotations

from uuid import uuid4

from django.contrib.auth.models import User
from django.db import models
from django.utils import timezone as dj_timezone


def _plan_id() -> str:
    return uuid4().hex


def _event_id() -> str:
    return uuid4().hex


class NotificationDevice(models.Model):
    PLATFORM_ANDROID = "android"
    PLATFORM_IOS = "ios"
    PLATFORM_WEB = "web"
    PLATFORM_WINDOWS = "windows"
    PLATFORM_CHOICES = [
        (PLATFORM_ANDROID, "Android"),
        (PLATFORM_IOS, "iOS"),
        (PLATFORM_WEB, "Web"),
        (PLATFORM_WINDOWS, "Windows"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="notification_devices",
    )
    installation_id = models.CharField(max_length=191, db_index=True)
    platform = models.CharField(
        max_length=24,
        choices=PLATFORM_CHOICES,
        default=PLATFORM_ANDROID,
    )
    timezone = models.CharField(max_length=64, blank=True, default="UTC")
    locale = models.CharField(max_length=32, blank=True, default="")
    app_version = models.CharField(max_length=40, blank=True, default="")
    is_primary = models.BooleanField(default=False, db_index=True)
    is_active = models.BooleanField(default=True, db_index=True)
    revoked_at = models.DateTimeField(null=True, blank=True)
    assignment_version = models.PositiveBigIntegerField(default=1)
    notifications_authorized = models.BooleanField(default=False)
    permission_status = models.CharField(max_length=24, blank=True, default="unavailable")
    notifications_enabled_systemwide = models.BooleanField(default=False)
    permission_checked_at = models.DateTimeField(null=True, blank=True)
    exact_alarm_authorized = models.BooleanField(default=False)
    last_seen_at = models.DateTimeField(default=dj_timezone.now)
    last_sync_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-is_primary", "-updated_at", "-id")
        constraints = [
            models.UniqueConstraint(
                fields=("user", "installation_id"),
                name="unique_notification_device_installation",
            ),
            models.UniqueConstraint(
                fields=("user",),
                condition=models.Q(is_primary=True, is_active=True, revoked_at__isnull=True),
                name="unique_active_primary_notification_device",
            ),
        ]
        indexes = [
            models.Index(
                fields=("user", "is_primary", "updated_at"),
                name="nh_device_primary_idx",
            )
        ]

    def __str__(self):
        return f"{self.user_id}:{self.platform}:{self.installation_id}"


class NotificationPreferenceProfile(models.Model):
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="notification_preference_profile",
    )
    enable_routine_reminders = models.BooleanField(default=True)
    enable_motivation_reminders = models.BooleanField(default=True)
    enable_health_alerts = models.BooleanField(default=True)
    enable_medication_reminders = models.BooleanField(default=True)
    enable_sleep_reminders = models.BooleanField(default=False)
    enable_water_reminders = models.BooleanField(default=True)
    enable_meal_reminders = models.BooleanField(default=False)
    enable_activity_reminders = models.BooleanField(default=True)
    enable_step_reminders = models.BooleanField(default=False)
    enable_habit_reminders = models.BooleanField(default=True)
    quiet_hours_enabled = models.BooleanField(default=False)
    quiet_start = models.TimeField(null=True, blank=True)
    quiet_end = models.TimeField(null=True, blank=True)
    motivation_max_per_day = models.PositiveSmallIntegerField(default=2)
    motivation_type_cooldown_hours = models.PositiveSmallIntegerField(default=6)
    critical_bypass_quiet_hours = models.BooleanField(default=True)
    breakfast_reminder_time = models.TimeField(null=True, blank=True)
    lunch_reminder_time = models.TimeField(null=True, blank=True)
    dinner_reminder_time = models.TimeField(null=True, blank=True)
    steps_reminder_time = models.TimeField(null=True, blank=True)
    water_reminder_start_time = models.TimeField(null=True, blank=True)
    water_reminder_end_time = models.TimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("user_id",)

    def __str__(self):
        return f"notification-preferences:{self.user_id}"


class NotificationPlan(models.Model):
    KIND_RULE = "rule"
    KIND_INTENT = "intent"
    KIND_IN_APP = "in_app"
    KIND_CHOICES = [
        (KIND_RULE, "Rule"),
        (KIND_INTENT, "Intent"),
        (KIND_IN_APP, "In-app"),
    ]

    CATEGORY_HEALTH_CRITICAL = "health_critical"
    CATEGORY_ROUTINE = "routine"
    CATEGORY_MOTIVATION = "motivation"
    CATEGORY_CELEBRATION = "celebration"
    CATEGORY_SYSTEM = "system"
    CATEGORY_CHOICES = [
        (CATEGORY_HEALTH_CRITICAL, "Health critical"),
        (CATEGORY_ROUTINE, "Routine"),
        (CATEGORY_MOTIVATION, "Motivation"),
        (CATEGORY_CELEBRATION, "Celebration"),
        (CATEGORY_SYSTEM, "System"),
    ]

    STATUS_PENDING = "pending"
    STATUS_PLANNED = "planned"
    STATUS_SCHEDULED_LOCAL = "scheduled_local"
    STATUS_PRESENTED_IN_APP = "presented_in_app"
    STATUS_DELIVERY_FAILED = "delivery_failed"
    STATUS_ACKNOWLEDGED = "acknowledged"
    STATUS_DISMISSED = "dismissed"
    STATUS_SUPPRESSED_BY_POLICY = "suppressed_by_policy"
    STATUS_CANCELLED = "cancelled"
    STATUS_EXPIRED = "expired"
    STATUS_DELIVERED = "delivered"
    # Compatibility aliases for callers that have not moved to canonical names.
    STATUS_SCHEDULED = STATUS_SCHEDULED_LOCAL
    STATUS_SUPPRESSED = STATUS_SUPPRESSED_BY_POLICY
    STATUS_FAILED = STATUS_DELIVERY_FAILED
    STATUS_CHOICES = [
        (STATUS_PENDING, "Pending"),
        (STATUS_PLANNED, "Planned"),
        (STATUS_SCHEDULED_LOCAL, "Scheduled locally"),
        (STATUS_PRESENTED_IN_APP, "Presented in app"),
        (STATUS_DELIVERY_FAILED, "Delivery failed"),
        (STATUS_ACKNOWLEDGED, "Acknowledged"),
        (STATUS_DISMISSED, "Dismissed"),
        (STATUS_SUPPRESSED_BY_POLICY, "Suppressed by policy"),
        (STATUS_CANCELLED, "Cancelled"),
        (STATUS_EXPIRED, "Expired"),
        (STATUS_DELIVERED, "Delivered"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="notification_plans",
    )
    device = models.ForeignKey(
        NotificationDevice,
        on_delete=models.CASCADE,
        related_name="plans",
    )
    plan_id = models.CharField(max_length=64, unique=True, default=_plan_id, db_index=True)
    revision = models.PositiveIntegerField(default=1)
    kind = models.CharField(max_length=16, choices=KIND_CHOICES, default=KIND_RULE)
    category = models.CharField(
        max_length=24,
        choices=CATEGORY_CHOICES,
        default=CATEGORY_ROUTINE,
    )
    type = models.CharField(max_length=80, db_index=True)
    priority = models.PositiveSmallIntegerField(default=50)
    title = models.CharField(max_length=120)
    body = models.CharField(max_length=240, blank=True, default="")
    route = models.CharField(max_length=64, blank=True, default="")
    payload = models.JSONField(default=dict, blank=True)
    schedule_spec = models.JSONField(default=dict, blank=True)
    deliver_at = models.DateTimeField(null=True, blank=True)
    expire_at = models.DateTimeField(null=True, blank=True)
    sound_profile = models.CharField(max_length=32, blank=True, default="")
    exact_required = models.BooleanField(default=False)
    foreground_behavior = models.CharField(max_length=32, blank=True, default="")
    dedupe_key = models.CharField(max_length=255, db_index=True)
    status = models.CharField(
        max_length=24,
        choices=STATUS_CHOICES,
        default=STATUS_PLANNED,
        db_index=True,
    )
    source_domain = models.CharField(max_length=80, blank=True, default="")
    source_ref = models.CharField(max_length=120, blank=True, default="")
    source_event_type = models.CharField(max_length=80, blank=True, default="")
    source_event_id = models.CharField(max_length=120, blank=True, default="")
    presented_at = models.DateTimeField(null=True, blank=True)
    acknowledged_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-priority", "plan_id")
        constraints = [
            models.UniqueConstraint(
                fields=("device", "dedupe_key"),
                name="unique_notification_plan_per_device_dedupe",
            )
        ]
        indexes = [
            models.Index(
                fields=("device", "status", "updated_at"),
                name="nh_plan_device_status_idx",
            ),
            models.Index(
                fields=("user", "category", "status"),
                name="nh_plan_user_category_idx",
            ),
        ]

    def __str__(self):
        return f"{self.plan_id}:{self.type}:{self.device_id}"


class NotificationPlanEvent(models.Model):
    EVENT_SCHEDULED_LOCAL = "scheduled_local"
    EVENT_PRESENTED_IN_APP = "presented_in_app"
    EVENT_DELIVERY_FAILED = "delivery_failed"
    EVENT_ACKNOWLEDGED = "acknowledged"
    EVENT_OPENED = "opened"
    EVENT_DISMISSED = "dismissed"
    EVENT_EXPIRED = "expired"
    EVENT_SUPPRESSED_BY_POLICY = "suppressed_by_policy"
    EVENT_DELIVERED = "delivered"
    EVENT_CANCELLED = "cancelled"
    # Legacy aliases are accepted only while old installed clients upgrade.
    EVENT_FOREGROUND_SUPPRESSED = "foreground_suppressed"
    EVENT_SCHEDULE_FAILED = "schedule_failed"
    EVENT_CANCELLED_LOCAL = "cancelled_local"
    EVENT_CHOICES = [
        (EVENT_SCHEDULED_LOCAL, "Scheduled locally"),
        (EVENT_PRESENTED_IN_APP, "Presented in app"),
        (EVENT_DELIVERY_FAILED, "Delivery failed"),
        (EVENT_ACKNOWLEDGED, "Acknowledged"),
        (EVENT_FOREGROUND_SUPPRESSED, "Foreground suppressed"),
        (EVENT_OPENED, "Opened"),
        (EVENT_DISMISSED, "Dismissed"),
        (EVENT_EXPIRED, "Expired"),
        (EVENT_SUPPRESSED_BY_POLICY, "Suppressed by policy"),
        (EVENT_DELIVERED, "Delivered"),
        (EVENT_SCHEDULE_FAILED, "Schedule failed"),
        (EVENT_CANCELLED_LOCAL, "Cancelled locally"),
        (EVENT_CANCELLED, "Cancelled"),
    ]

    plan = models.ForeignKey(
        NotificationPlan,
        on_delete=models.CASCADE,
        related_name="events",
    )
    device = models.ForeignKey(
        NotificationDevice,
        on_delete=models.CASCADE,
        related_name="plan_events",
    )
    event_id = models.CharField(max_length=96, unique=True, default=_event_id, db_index=True)
    plan_revision = models.PositiveIntegerField(default=1)
    event_type = models.CharField(max_length=32, choices=EVENT_CHOICES, db_index=True)
    event_at = models.DateTimeField(default=dj_timezone.now, db_index=True)
    failure_code = models.CharField(max_length=80, blank=True, default="")
    suppression_reason = models.CharField(max_length=120, blank=True, default="")
    payload = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-event_at", "-id")
        indexes = [
            models.Index(
                fields=("device", "event_type", "event_at"),
                name="nh_event_device_type_idx",
            ),
            models.Index(
                fields=("plan", "event_type", "event_at"),
                name="nh_event_plan_type_idx",
            ),
        ]

    def __str__(self):
        return f"{self.plan_id}:{self.event_type}"
