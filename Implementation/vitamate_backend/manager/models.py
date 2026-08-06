from __future__ import annotations

from django.contrib.auth.models import User
from django.db import models
from django.utils import timezone


class HealthGoalOverride(models.Model):
    GOAL_NUTRITION = "nutrition"
    GOAL_HYDRATION = "hydration"
    GOAL_STEPS = "steps"
    GOAL_ACTIVE_TIME = "active_time"
    GOAL_SLEEP = "sleep"
    GOAL_WEIGHT = "weight"
    GOAL_HABITS = "habits"
    GOAL_CHOICES = [
        (GOAL_NUTRITION, "Nutrition"),
        (GOAL_HYDRATION, "Hydration"),
        (GOAL_STEPS, "Steps"),
        (GOAL_ACTIVE_TIME, "Active time"),
        (GOAL_SLEEP, "Sleep"),
        (GOAL_WEIGHT, "Weight"),
        (GOAL_HABITS, "Habits"),
    ]

    SOURCE_USER_OVERRIDE = "user_override"

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="manager_goal_overrides",
    )
    key = models.CharField(max_length=40, choices=GOAL_CHOICES)
    custom_value = models.FloatField()
    unit = models.CharField(max_length=24, blank=True, default="")
    updated_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("key",)
        constraints = [
            models.UniqueConstraint(
                fields=("user", "key"),
                name="unique_manager_goal_override",
            )
        ]

    def __str__(self):
        return f"{self.user_id}:{self.key}:{self.custom_value}"


class PrivacyExportRequest(models.Model):
    STATUS_QUEUED = "queued"
    STATUS_READY = "ready"
    STATUS_FAILED = "failed"
    STATUS_CHOICES = [
        (STATUS_QUEUED, "Queued"),
        (STATUS_READY, "Ready"),
        (STATUS_FAILED, "Failed"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="privacy_export_requests",
    )
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default=STATUS_QUEUED)
    payload = models.JSONField(default=dict, blank=True)
    requested_at = models.DateTimeField(default=timezone.now)
    completed_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("-requested_at", "-id")

    def __str__(self):
        return f"privacy-export:{self.user_id}:{self.status}"


class AccountDeletionRequest(models.Model):
    STATUS_REQUESTED = "requested"
    STATUS_CANCELLED = "cancelled"
    STATUS_COMPLETED = "completed"
    STATUS_CHOICES = [
        (STATUS_REQUESTED, "Requested"),
        (STATUS_CANCELLED, "Cancelled"),
        (STATUS_COMPLETED, "Completed"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="account_deletion_requests",
    )
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default=STATUS_REQUESTED)
    reason = models.CharField(max_length=240, blank=True, default="")
    requested_at = models.DateTimeField(default=timezone.now)
    grace_period_ends_at = models.DateTimeField()
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("-requested_at", "-id")
        indexes = [
            models.Index(fields=("user", "status"), name="mgr_delete_user_status_idx"),
        ]

    def __str__(self):
        return f"account-deletion:{self.user_id}:{self.status}"
