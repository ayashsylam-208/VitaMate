from django.contrib.auth.models import User
from django.db import models
from django.utils import timezone

from core.models.chronic import (
    ConditionNutrientRule,
    HealthRestriction,
    HealthTarget,
    UserCondition,
    UserNutrientTarget,
)


class ResolvedTrackerConstraint(models.Model):
    TRACKER_NUTRITION = "nutrition"
    TRACKER_HYDRATION = "hydration"
    TRACKER_ACTIVITY = "activity"
    TRACKER_STEPS = "steps"
    TRACKER_SLEEP = "sleep"
    TRACKER_MEDICATION = "medication"
    TRACKER_MONITORING = "monitoring"
    TRACKER_HABIT = "habit"
    TRACKER_MICRONUTRIENT = "micronutrient"
    TRACKER_TYPE_CHOICES = [
        (TRACKER_NUTRITION, "Nutrition"),
        (TRACKER_HYDRATION, "Hydration"),
        (TRACKER_ACTIVITY, "Activity"),
        (TRACKER_STEPS, "Steps"),
        (TRACKER_SLEEP, "Sleep"),
        (TRACKER_MEDICATION, "Medication"),
        (TRACKER_MONITORING, "Monitoring"),
        (TRACKER_HABIT, "Habit"),
        (TRACKER_MICRONUTRIENT, "Micronutrient"),
    ]

    RULE_TARGET = "target"
    RULE_MIN = "min"
    RULE_MAX = "max"
    RULE_WARN = "warn"
    RULE_AVOID = "avoid"
    RULE_RANGE = "range"
    RULE_TYPE_CHOICES = [
        (RULE_TARGET, "Target"),
        (RULE_MIN, "Minimum"),
        (RULE_MAX, "Maximum"),
        (RULE_WARN, "Warning"),
        (RULE_AVOID, "Avoid"),
        (RULE_RANGE, "Range"),
    ]

    SOURCE_PHYSICIAN_OVERRIDE = "physician_override"
    SOURCE_SAFETY_CRITICAL_CONDITION_RULE = "safety_critical_condition_rule"
    SOURCE_DYNAMIC_CONDITION_STATE = "dynamic_condition_state"
    SOURCE_CONDITION_NUTRIENT_RULE = "condition_nutrient_rule"
    SOURCE_USER_CUSTOM_TARGET = "user_custom_target"
    SOURCE_PROFILE_DERIVED_DEFAULT = "profile_derived_default"
    SOURCE_GENERAL_RECOMMENDATION = "general_recommendation"
    SOURCE_TYPE_CHOICES = [
        (SOURCE_PHYSICIAN_OVERRIDE, "Physician override"),
        (SOURCE_SAFETY_CRITICAL_CONDITION_RULE, "Safety critical condition rule"),
        (SOURCE_DYNAMIC_CONDITION_STATE, "Dynamic condition state"),
        (SOURCE_CONDITION_NUTRIENT_RULE, "Condition nutrient rule"),
        (SOURCE_USER_CUSTOM_TARGET, "User custom target"),
        (SOURCE_PROFILE_DERIVED_DEFAULT, "Profile derived default"),
        (SOURCE_GENERAL_RECOMMENDATION, "General recommendation"),
    ]

    STATUS_ACTIVE = "active"
    STATUS_SUPERSEDED = "superseded"
    STATUS_EXPIRED = "expired"
    STATUS_CHOICES = [
        (STATUS_ACTIVE, "Active"),
        (STATUS_SUPERSEDED, "Superseded"),
        (STATUS_EXPIRED, "Expired"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="resolved_tracker_constraints",
    )
    tracker_type = models.CharField(max_length=30, choices=TRACKER_TYPE_CHOICES, db_index=True)
    category = models.CharField(max_length=50, blank=True, db_index=True)
    metric_key = models.CharField(max_length=100, db_index=True)
    rule_type = models.CharField(max_length=30, choices=RULE_TYPE_CHOICES, default=RULE_TARGET)
    evaluation_mode = models.CharField(max_length=60, blank=True, default="daily_total")
    unit = models.CharField(max_length=30, blank=True)
    min_value = models.FloatField(null=True, blank=True)
    max_value = models.FloatField(null=True, blank=True)
    target_value = models.FloatField(null=True, blank=True)
    warning_value = models.FloatField(null=True, blank=True)
    priority = models.PositiveSmallIntegerField(default=50)
    is_blocking = models.BooleanField(default=False)
    is_scored = models.BooleanField(default=True)
    source_type = models.CharField(
        max_length=50,
        choices=SOURCE_TYPE_CHOICES,
        default=SOURCE_GENERAL_RECOMMENDATION,
        db_index=True,
    )
    source_condition = models.ForeignKey(
        UserCondition,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="resolved_constraints",
    )
    source_restriction = models.ForeignKey(
        HealthRestriction,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="resolved_constraints",
    )
    source_target = models.ForeignKey(
        HealthTarget,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="resolved_constraints",
    )
    source_nutrient_rule = models.ForeignKey(
        ConditionNutrientRule,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="resolved_constraints",
    )
    source_user_nutrient_target = models.ForeignKey(
        UserNutrientTarget,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="resolved_constraints",
    )
    reason_summary = models.CharField(max_length=255, blank=True)
    explanation_payload = models.JSONField(default=dict, blank=True)
    confidence_score = models.FloatField(null=True, blank=True)
    effective_from = models.DateTimeField(default=timezone.now)
    effective_to = models.DateTimeField(null=True, blank=True)
    computed_at = models.DateTimeField(default=timezone.now)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_ACTIVE, db_index=True)
    version_hash = models.CharField(max_length=64, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("tracker_type", "metric_key", "-priority", "-computed_at")
        indexes = [
            models.Index(fields=("user", "tracker_type", "status"), name="rtc_user_tracker_status_idx"),
            models.Index(fields=("user", "category", "status"), name="rtc_user_category_status_idx"),
            models.Index(fields=("user", "metric_key", "status"), name="rtc_user_metric_status_idx"),
            models.Index(fields=("user", "effective_to", "status"), name="rtc_user_to_status_idx"),
            models.Index(fields=("user", "source_type", "status"), name="rtc_user_source_status_idx"),
        ]

    def __str__(self):
        return f"{self.user_id}:{self.tracker_type}:{self.metric_key}:{self.rule_type}"


class ConstraintResolutionRun(models.Model):
    TRIGGER_MANUAL = "manual"
    TRIGGER_USER_PROFILE = "user_profile"
    TRIGGER_USER_CONDITION = "user_condition"
    TRIGGER_HEALTH_TARGET = "health_target"
    TRIGGER_USER_NUTRIENT_TARGET = "user_nutrient_target"
    TRIGGER_HEALTH_INDICATOR_RECORD = "health_indicator_record"
    TRIGGER_CONDITION_RULE_CATALOG = "condition_rule_catalog"
    TRIGGER_MEDICATION_PLAN = "medication_plan"
    TRIGGER_NIGHTLY_SAFETY = "nightly_safety_recompute"
    TRIGGER_CHOICES = [
        (TRIGGER_MANUAL, "Manual"),
        (TRIGGER_USER_PROFILE, "User profile"),
        (TRIGGER_USER_CONDITION, "User condition"),
        (TRIGGER_HEALTH_TARGET, "Health target"),
        (TRIGGER_USER_NUTRIENT_TARGET, "User nutrient target"),
        (TRIGGER_HEALTH_INDICATOR_RECORD, "Health indicator record"),
        (TRIGGER_CONDITION_RULE_CATALOG, "Condition rule catalog"),
        (TRIGGER_MEDICATION_PLAN, "Medication plan"),
        (TRIGGER_NIGHTLY_SAFETY, "Nightly safety recompute"),
    ]

    STATUS_PENDING = "pending"
    STATUS_RUNNING = "running"
    STATUS_SUCCEEDED = "succeeded"
    STATUS_COMPLETED = STATUS_SUCCEEDED
    STATUS_PARTIALLY_FAILED = "partially_failed"
    STATUS_FAILED = "failed"
    STATUS_SKIPPED = "skipped"
    RUN_STATUS_CHOICES = [
        (STATUS_PENDING, "Pending"),
        (STATUS_RUNNING, "Running"),
        (STATUS_SUCCEEDED, "Succeeded"),
        (STATUS_PARTIALLY_FAILED, "Partially failed"),
        (STATUS_FAILED, "Failed"),
        (STATUS_SKIPPED, "Skipped"),
    ]

    SYNC_MODE_SYNCHRONOUS = "synchronous"
    SYNC_MODE_QUEUED = "queued"
    SYNC_MODE_RECOVERY = "recovery"
    SYNC_MODE_MANUAL = "manual"
    SYNC_MODE_ASYNC_PLACEHOLDER = SYNC_MODE_QUEUED
    SYNC_MODE_CHOICES = [
        (SYNC_MODE_SYNCHRONOUS, "Synchronous"),
        (SYNC_MODE_QUEUED, "Queued"),
        (SYNC_MODE_RECOVERY, "Recovery"),
        (SYNC_MODE_MANUAL, "Manual"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="constraint_resolution_runs",
    )
    trigger_type = models.CharField(max_length=60, choices=TRIGGER_CHOICES, default=TRIGGER_MANUAL)
    trigger_reference = models.CharField(max_length=255, blank=True)
    input_signature = models.CharField(max_length=64, db_index=True)
    run_status = models.CharField(max_length=20, choices=RUN_STATUS_CHOICES, default=STATUS_RUNNING, db_index=True)
    sync_mode = models.CharField(
        max_length=20,
        choices=SYNC_MODE_CHOICES,
        default=SYNC_MODE_SYNCHRONOUS,
    )
    correlation_id = models.CharField(max_length=64, blank=True, db_index=True)
    idempotency_key = models.CharField(max_length=128, null=True, blank=True, unique=True)
    metadata = models.JSONField(default=dict, blank=True)
    affected_trackers = models.JSONField(default=list, blank=True)
    total_constraints_generated = models.PositiveIntegerField(default=0)
    total_constraints_superseded = models.PositiveIntegerField(default=0)
    retry_count = models.PositiveIntegerField(default=0)
    started_at = models.DateTimeField(default=timezone.now)
    completed_at = models.DateTimeField(null=True, blank=True)
    failed_at = models.DateTimeField(null=True, blank=True)
    error_code = models.CharField(max_length=80, blank=True)
    error_message = models.TextField(blank=True)

    class Meta:
        ordering = ("-started_at", "-id")
        indexes = [
            models.Index(fields=("user", "run_status", "started_at"), name="crr_user_status_started_idx"),
            models.Index(fields=("user", "trigger_type", "started_at"), name="crr_user_trigger_started_idx"),
            models.Index(fields=("user", "input_signature", "run_status"), name="crr_user_signature_status_idx"),
        ]

    def __str__(self):
        return f"{self.user_id}:{self.trigger_type}:{self.run_status}"


class ConstraintSourceTrace(models.Model):
    CONTRIBUTION_SELECTED = "selected"
    CONTRIBUTION_SUPERSEDED = "superseded"
    CONTRIBUTION_SUPPORTING = "supporting"
    CONTRIBUTION_CHOICES = [
        (CONTRIBUTION_SELECTED, "Selected"),
        (CONTRIBUTION_SUPERSEDED, "Superseded"),
        (CONTRIBUTION_SUPPORTING, "Supporting"),
    ]

    resolved_constraint = models.ForeignKey(
        ResolvedTrackerConstraint,
        on_delete=models.CASCADE,
        related_name="source_traces",
    )
    source_model = models.CharField(max_length=120)
    source_object_id = models.CharField(max_length=64, blank=True)
    contribution_type = models.CharField(
        max_length=30,
        choices=CONTRIBUTION_CHOICES,
        default=CONTRIBUTION_SELECTED,
    )
    priority_score = models.PositiveSmallIntegerField(default=50)
    note = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("resolved_constraint_id", "contribution_type", "source_model")
        indexes = [
            models.Index(fields=("resolved_constraint", "contribution_type"), name="cst_constraint_type_idx"),
            models.Index(fields=("source_model", "source_object_id"), name="cst_source_object_idx"),
        ]

    def __str__(self):
        return f"{self.source_model}:{self.source_object_id}"
