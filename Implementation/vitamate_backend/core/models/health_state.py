from django.contrib.auth.models import User
from django.db import models
from django.utils import timezone


class UnifiedHealthState(models.Model):
    WINDOW_CURRENT = "current"
    WINDOW_DAILY = "daily"
    WINDOW_CHOICES = [
        (WINDOW_CURRENT, "Current"),
        (WINDOW_DAILY, "Daily"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="unified_health_states",
    )
    state_date = models.DateField()
    window_kind = models.CharField(max_length=20, choices=WINDOW_CHOICES, default=WINDOW_CURRENT)
    version = models.PositiveIntegerField(default=1)
    last_computed_at = models.DateTimeField(default=timezone.now, db_index=True)
    affected_trackers = models.JSONField(default=list, blank=True)
    tracker_snapshots = models.JSONField(default=list, blank=True)
    progress_summary = models.JSONField(default=dict, blank=True)
    active_targets = models.JSONField(default=list, blank=True)
    active_constraints = models.JSONField(default=dict, blank=True)
    warnings = models.JSONField(default=list, blank=True)
    medication_summary = models.JSONField(default=dict, blank=True)
    trigger_metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-state_date", "window_kind", "-last_computed_at")
        constraints = [
            models.UniqueConstraint(
                fields=("user", "state_date", "window_kind"),
                name="unique_user_health_state_window",
            )
        ]
        indexes = [
            models.Index(
                fields=("user", "window_kind", "state_date"),
                name="uhs_user_window_date_idx",
            ),
            models.Index(
                fields=("user", "last_computed_at"),
                name="uhs_user_computed_idx",
            ),
        ]

    def __str__(self):
        return f"{self.user_id}:{self.window_kind}:{self.state_date}"


class HealthStateComputationRun(models.Model):
    STATUS_RUNNING = "running"
    STATUS_COMPLETED = "completed"
    STATUS_FAILED = "failed"
    STATUS_SKIPPED = "skipped"
    STATUS_CHOICES = [
        (STATUS_RUNNING, "Running"),
        (STATUS_COMPLETED, "Completed"),
        (STATUS_FAILED, "Failed"),
        (STATUS_SKIPPED, "Skipped"),
    ]

    SYNC_MODE_SYNC = "sync"
    SYNC_MODE_ASYNC_PLACEHOLDER = "async_placeholder"
    SYNC_MODE_CHOICES = [
        (SYNC_MODE_SYNC, "Sync"),
        (SYNC_MODE_ASYNC_PLACEHOLDER, "Async placeholder"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="health_state_runs",
    )
    trigger_type = models.CharField(max_length=80, db_index=True)
    trigger_reference = models.CharField(max_length=255, blank=True)
    run_status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=STATUS_RUNNING,
        db_index=True,
    )
    sync_mode = models.CharField(
        max_length=30,
        choices=SYNC_MODE_CHOICES,
        default=SYNC_MODE_SYNC,
    )
    affected_domains = models.JSONField(default=list, blank=True)
    correlation_id = models.CharField(max_length=64, blank=True, db_index=True)
    idempotency_key = models.CharField(max_length=160, null=True, blank=True, unique=True)
    retry_count = models.PositiveIntegerField(default=0)
    error_message = models.TextField(blank=True)
    error_code = models.CharField(max_length=80, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    started_at = models.DateTimeField(default=timezone.now)
    completed_at = models.DateTimeField(null=True, blank=True)
    failed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("-started_at", "-id")
        indexes = [
            models.Index(
                fields=("user", "run_status", "started_at"),
                name="hscr_user_status_started_idx",
            ),
            models.Index(
                fields=("user", "trigger_type", "started_at"),
                name="hscr_user_trigger_started_idx",
            ),
        ]

    def __str__(self):
        return f"{self.user_id}:{self.trigger_type}:{self.run_status}"


class HealthStateDelta(models.Model):
    WINDOW_CURRENT = UnifiedHealthState.WINDOW_CURRENT
    WINDOW_DAILY = UnifiedHealthState.WINDOW_DAILY
    WINDOW_CHOICES = UnifiedHealthState.WINDOW_CHOICES

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="health_state_deltas",
    )
    computation_run = models.ForeignKey(
        HealthStateComputationRun,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="deltas",
    )
    state_date = models.DateField()
    window_kind = models.CharField(max_length=20, choices=WINDOW_CHOICES, default=WINDOW_CURRENT)
    trigger_type = models.CharField(max_length=80, db_index=True)
    trigger_reference = models.CharField(max_length=255, blank=True)
    reason = models.CharField(max_length=255, blank=True)
    changed_trackers = models.JSONField(default=list, blank=True)
    metrics_before = models.JSONField(default=dict, blank=True)
    metrics_after = models.JSONField(default=dict, blank=True)
    warnings_added = models.JSONField(default=list, blank=True)
    warnings_resolved = models.JSONField(default=list, blank=True)
    achievements_added = models.JSONField(default=list, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at", "-id")
        indexes = [
            models.Index(
                fields=("user", "state_date", "window_kind"),
                name="hsd_user_state_window_idx",
            ),
            models.Index(
                fields=("user", "trigger_type", "created_at"),
                name="hsd_user_trigger_created_idx",
            ),
        ]

    def __str__(self):
        return f"{self.user_id}:{self.window_kind}:{self.state_date}:{self.trigger_type}"
