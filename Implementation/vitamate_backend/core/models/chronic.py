from django.contrib.auth.models import User
from django.db import models
from django.utils import timezone

from core.models.legacy import Medicine
from core.models.nutrition import Nutrient


class ConditionType(models.Model):
    code = models.CharField(max_length=50, unique=True)
    slug = models.CharField(max_length=50, unique=True, blank=True)
    name = models.CharField(max_length=100)
    display_name = models.CharField(max_length=100, blank=True)
    description = models.TextField(blank=True)
    is_supported = models.BooleanField(default=False)
    sort_order = models.PositiveSmallIntegerField(default=0)
    setup_schema = models.JSONField(default=dict, blank=True)
    severity_options = models.JSONField(default=list, blank=True)

    class Meta:
        ordering = ("sort_order", "display_name", "name")

    def __str__(self):
        return self.display_name or self.name

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = self.code
        if not self.display_name:
            self.display_name = self.name
        super().save(*args, **kwargs)


class UserCondition(models.Model):
    STATUS_ACTIVE = "active"
    STATUS_CONTROLLED = "controlled"
    STATUS_NEEDS_ATTENTION = "needs_attention"
    STATUS_INACTIVE = "inactive"
    STATUS_CHOICES = [
        (STATUS_ACTIVE, "Active"),
        (STATUS_CONTROLLED, "Controlled"),
        (STATUS_NEEDS_ATTENTION, "Needs attention"),
        (STATUS_INACTIVE, "Inactive"),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="conditions")
    condition_type = models.ForeignKey(
        ConditionType,
        on_delete=models.PROTECT,
        related_name="user_conditions",
    )
    diagnosis_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_ACTIVE)
    severity_code = models.CharField(max_length=50)
    profile_data = models.JSONField(default=dict, blank=True)
    notes = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-diagnosis_date", "id")
        constraints = [
            models.UniqueConstraint(
                fields=("user", "condition_type"),
                condition=models.Q(is_active=True),
                name="unique_active_condition_per_user_type",
            )
        ]

    def __str__(self):
        return f"{self.user.username} - {self.condition_type.name}"


class ConditionRuleProfile(models.Model):
    condition_type = models.ForeignKey(
        ConditionType,
        on_delete=models.CASCADE,
        related_name="rule_profiles",
    )
    severity_code = models.CharField(max_length=50, blank=True)
    rule_key = models.CharField(max_length=80)
    rule_value = models.CharField(max_length=120)
    rule_unit = models.CharField(max_length=40, blank=True)
    source_label = models.CharField(max_length=255, blank=True)
    source_version = models.CharField(max_length=50, blank=True)
    effective_date = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)
    is_default = models.BooleanField(default=True)

    class Meta:
        ordering = ("condition_type__name", "severity_code", "rule_key")

    def __str__(self):
        return f"{self.condition_type.code}:{self.rule_key}"


class HealthRestriction(models.Model):
    CATEGORY_ACTIVITY = "activity"
    CATEGORY_NUTRITION = "nutrition"
    CATEGORY_HYDRATION = "hydration"
    CATEGORY_MEDICATION = "medication"
    CATEGORY_MONITORING = "monitoring"
    CATEGORY_CHOICES = [
        (CATEGORY_ACTIVITY, "Activity"),
        (CATEGORY_NUTRITION, "Nutrition"),
        (CATEGORY_HYDRATION, "Hydration"),
        (CATEGORY_MEDICATION, "Medication"),
        (CATEGORY_MONITORING, "Monitoring"),
    ]

    condition_type = models.ForeignKey(
        ConditionType,
        on_delete=models.CASCADE,
        related_name="restrictions",
    )
    severity_code = models.CharField(max_length=50, blank=True)
    restriction_key = models.CharField(max_length=80)
    title = models.CharField(max_length=120)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES)
    metric_key = models.CharField(max_length=80)
    evaluation_mode = models.CharField(max_length=50)
    unit = models.CharField(max_length=30, blank=True)
    min_required_value = models.FloatField(null=True, blank=True)
    max_allowed_value = models.FloatField(null=True, blank=True)
    is_forbidden = models.BooleanField(default=False)
    is_scored = models.BooleanField(default=True)
    guidance = models.TextField(blank=True)
    evidence_source = models.CharField(max_length=255, blank=True)
    source_label = models.CharField(max_length=255, blank=True)
    source_version = models.CharField(max_length=50, blank=True)
    effective_date = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)
    is_default = models.BooleanField(default=True)
    is_inference = models.BooleanField(default=False)

    class Meta:
        ordering = ("condition_type__name", "category", "title")

    def __str__(self):
        return f"{self.condition_type.code}:{self.restriction_key}"


class ConditionNutrientRule(models.Model):
    RULE_MAX = "max"
    RULE_MIN = "min"
    RULE_AVOID = "avoid"
    RULE_WARN = "warn"
    RULE_TYPE_CHOICES = [
        (RULE_MAX, "Maximum"),
        (RULE_MIN, "Minimum"),
        (RULE_AVOID, "Avoid"),
        (RULE_WARN, "Warn"),
    ]

    condition_type = models.ForeignKey(
        ConditionType,
        on_delete=models.CASCADE,
        related_name="nutrient_rules",
    )
    nutrient = models.ForeignKey(
        Nutrient,
        on_delete=models.PROTECT,
        related_name="condition_rules",
    )
    rule_type = models.CharField(max_length=20, choices=RULE_TYPE_CHOICES)
    threshold_value = models.FloatField(null=True, blank=True)
    threshold_unit = models.CharField(max_length=30, blank=True)
    severity = models.CharField(max_length=50, blank=True)
    note = models.TextField(blank=True)

    class Meta:
        ordering = ("condition_type__code", "severity", "nutrient__code", "rule_type")
        constraints = [
            models.UniqueConstraint(
                fields=("condition_type", "nutrient", "rule_type", "severity"),
                name="unique_condition_nutrient_rule",
            )
        ]

    def __str__(self):
        return f"{self.condition_type.code}:{self.nutrient.code}:{self.rule_type}"


class UserNutrientTarget(models.Model):
    PERIOD_DAILY = "daily"
    PERIOD_WEEKLY = "weekly"
    PERIOD_CHOICES = [
        (PERIOD_DAILY, "Daily"),
        (PERIOD_WEEKLY, "Weekly"),
    ]
    SOURCE_DEFAULT = "default"
    SOURCE_CONDITION = "condition"
    SOURCE_MANUAL = "manual"
    SOURCE_CHOICES = [
        (SOURCE_DEFAULT, "Default"),
        (SOURCE_CONDITION, "Condition"),
        (SOURCE_MANUAL, "Manual"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="nutrient_targets",
    )
    nutrient = models.ForeignKey(
        Nutrient,
        on_delete=models.PROTECT,
        related_name="user_targets",
    )
    min_value = models.FloatField(null=True, blank=True)
    target_value = models.FloatField(null=True, blank=True)
    max_value = models.FloatField(null=True, blank=True)
    period = models.CharField(max_length=20, choices=PERIOD_CHOICES, default=PERIOD_DAILY)
    source = models.CharField(max_length=30, choices=SOURCE_CHOICES, default=SOURCE_DEFAULT)
    note = models.TextField(blank=True)
    lab_test_name = models.CharField(max_length=120, blank=True)
    lab_value = models.FloatField(null=True, blank=True)
    lab_unit = models.CharField(max_length=30, blank=True)
    lab_reference_min = models.FloatField(null=True, blank=True)
    lab_reference_max = models.FloatField(null=True, blank=True)
    lab_test_date = models.DateField(null=True, blank=True)
    clinician_recommended_value = models.FloatField(null=True, blank=True)
    calculation_basis = models.CharField(max_length=40, blank=True)
    current_medication_name = models.CharField(max_length=120, blank=True)
    current_medication_dose = models.CharField(max_length=80, blank=True)
    linked_medication = models.ForeignKey(
        "ConditionMedication",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="linked_nutrient_targets",
    )

    class Meta:
        ordering = ("user_id", "period", "nutrient__code", "source")
        constraints = [
            models.UniqueConstraint(
                fields=("user", "nutrient", "period", "source"),
                name="unique_user_nutrient_target",
            )
        ]

    def __str__(self):
        return f"{self.user_id}:{self.nutrient.code}:{self.period}"


class HealthTarget(models.Model):
    SOURCE_COMPUTED_RULE = "computed_condition_rule"
    SOURCE_DYNAMIC_CONDITION = "dynamic_condition_state"
    SOURCE_PHYSICIAN_OVERRIDE = "physician_override"
    SOURCE_USER_CUSTOM = "user_custom"
    SOURCE_TYPE_CHOICES = [
        (SOURCE_COMPUTED_RULE, "Computed condition rule"),
        (SOURCE_DYNAMIC_CONDITION, "Dynamic condition state"),
        (SOURCE_PHYSICIAN_OVERRIDE, "Physician override"),
        (SOURCE_USER_CUSTOM, "User custom"),
    ]
    STATUS_PENDING = "pending"
    STATUS_WITHIN_TARGET = "within_target"
    STATUS_OUT_OF_RANGE = "out_of_range"
    STATUS_NOT_EVALUATED = "not_evaluated"
    STATUS_CHOICES = [
        (STATUS_PENDING, "Pending"),
        (STATUS_WITHIN_TARGET, "Within target"),
        (STATUS_OUT_OF_RANGE, "Out of range"),
        (STATUS_NOT_EVALUATED, "Not evaluated"),
    ]

    user_condition = models.ForeignKey(
        UserCondition,
        on_delete=models.CASCADE,
        related_name="targets",
    )
    source_restriction = models.ForeignKey(
        HealthRestriction,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="generated_targets",
    )
    target_key = models.CharField(max_length=80)
    target_name = models.CharField(max_length=120)
    category = models.CharField(max_length=20)
    metric_key = models.CharField(max_length=80)
    evaluation_mode = models.CharField(max_length=50)
    unit = models.CharField(max_length=30, blank=True)
    min_value = models.FloatField(null=True, blank=True)
    max_value = models.FloatField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)
    source_type = models.CharField(
        max_length=30,
        choices=SOURCE_TYPE_CHOICES,
        default=SOURCE_COMPUTED_RULE,
    )
    priority = models.PositiveSmallIntegerField(default=3)
    is_scored = models.BooleanField(default=True)
    guidance = models.TextField(blank=True)
    evidence_source = models.CharField(max_length=255, blank=True)
    is_inference = models.BooleanField(default=False)
    last_evaluated_value = models.FloatField(null=True, blank=True)
    last_evaluated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("category", "target_name")

    def __str__(self):
        return f"{self.user_condition_id}:{self.target_key}"


class HealthIndicatorRecord(models.Model):
    user_condition = models.ForeignKey(
        UserCondition,
        on_delete=models.CASCADE,
        related_name="indicator_records",
    )
    indicator_name = models.CharField(max_length=100, blank=True)
    indicator_type = models.CharField(max_length=50, blank=True)
    value = models.FloatField(default=0)
    value_1 = models.FloatField(null=True, blank=True)
    value_2 = models.FloatField(null=True, blank=True)
    value_3 = models.FloatField(null=True, blank=True)
    unit = models.CharField(max_length=30)
    reading_context = models.CharField(max_length=50, blank=True)
    payload = models.JSONField(default=dict, blank=True)
    classification = models.CharField(max_length=50, blank=True)
    risk_level = models.CharField(max_length=30, blank=True)
    recorded_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ("-recorded_at",)


class ConditionAlert(models.Model):
    STATUS_OPEN = "open"
    STATUS_SEEN = "seen"
    STATUS_RESOLVED = "resolved"
    STATUS_CHOICES = [
        (STATUS_OPEN, "Open"),
        (STATUS_SEEN, "Seen"),
        (STATUS_RESOLVED, "Resolved"),
    ]
    TYPE_MEDICATION = "medication"
    TYPE_RESTRICTION = "restriction"
    TYPE_MONITORING = "monitoring"
    TYPE_CHOICES = [
        (TYPE_MEDICATION, "Medication"),
        (TYPE_RESTRICTION, "Restriction"),
        (TYPE_MONITORING, "Monitoring"),
    ]

    user_condition = models.ForeignKey(
        UserCondition,
        on_delete=models.CASCADE,
        related_name="alerts",
    )
    code = models.CharField(max_length=80, blank=True)
    level = models.CharField(max_length=20, blank=True)
    message = models.CharField(max_length=255)
    alert_type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_OPEN)

    class Meta:
        ordering = ("-created_at",)


class ConditionMedication(models.Model):
    SOURCE_MANUAL = "manual"
    SOURCE_CONDITION = "condition"
    SOURCE_TYPE_CHOICES = [
        (SOURCE_MANUAL, "Manual"),
        (SOURCE_CONDITION, "Condition"),
    ]
    ADHERENCE_STRICT = "strict"
    ADHERENCE_FLEXIBLE = "flexible"
    ADHERENCE_MODE_CHOICES = [
        (ADHERENCE_STRICT, "Strict"),
        (ADHERENCE_FLEXIBLE, "Flexible"),
    ]
    RELATION_BEFORE_MEAL = "before_meal"
    RELATION_WITH_MEAL = "with_meal"
    RELATION_AFTER_MEAL = "after_meal"
    RELATION_ANYTIME = "anytime"
    RELATION_CHOICES = [
        (RELATION_BEFORE_MEAL, "Before meal"),
        (RELATION_WITH_MEAL, "With meal"),
        (RELATION_AFTER_MEAL, "After meal"),
        (RELATION_ANYTIME, "Anytime"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="medication_plans",
    )
    medicine = models.ForeignKey(
        Medicine,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="condition_medication_plans",
    )
    user_condition = models.ForeignKey(
        UserCondition,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="medications",
    )
    name = models.CharField(max_length=100)
    display_name = models.CharField(max_length=100, blank=True)
    source_type = models.CharField(
        max_length=20,
        choices=SOURCE_TYPE_CHOICES,
        default=SOURCE_CONDITION,
    )
    scientific_name = models.CharField(max_length=100, blank=True)
    dosage = models.CharField(max_length=80)
    dosage_amount = models.CharField(max_length=40, blank=True)
    dosage_unit = models.CharField(max_length=40, blank=True)
    form = models.CharField(max_length=40, blank=True)
    instructions = models.CharField(max_length=200, blank=True)
    relation_to_meal = models.CharField(
        max_length=20,
        choices=RELATION_CHOICES,
        default=RELATION_ANYTIME,
    )
    recurrence_pattern = models.JSONField(default=list, blank=True)
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    is_prn = models.BooleanField(default=False)
    timezone = models.CharField(max_length=64, default="UTC")
    adherence_mode = models.CharField(
        max_length=20,
        choices=ADHERENCE_MODE_CHOICES,
        default=ADHERENCE_STRICT,
    )
    reminder_enabled = models.BooleanField(default=True)
    reminder_lead_minutes = models.PositiveSmallIntegerField(default=15)
    supplement_nutrient = models.ForeignKey(
        Nutrient,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="supplement_medication_plans",
    )
    supplement_nutrient_amount = models.FloatField(null=True, blank=True)
    supplement_nutrient_unit = models.CharField(max_length=30, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("name",)

    def __str__(self):
        return self.display_name or self.name


class ConditionMedicationSchedule(models.Model):
    TYPE_DAILY = "daily"
    TYPE_SPECIFIC_DAYS = "specific_days"
    TYPE_INTERVAL = "interval"
    TYPE_AS_NEEDED = "as_needed"
    SCHEDULE_TYPE_CHOICES = [
        (TYPE_DAILY, "Daily"),
        (TYPE_SPECIFIC_DAYS, "Specific days"),
        (TYPE_INTERVAL, "Interval"),
        (TYPE_AS_NEEDED, "As needed"),
    ]
    MEAL_BEFORE = "before_meal"
    MEAL_AFTER = "after_meal"
    MEAL_WITH_FOOD = "with_food"
    MEAL_NONE = "none"
    MEAL_RELATION_CHOICES = [
        (MEAL_BEFORE, "Before meal"),
        (MEAL_AFTER, "After meal"),
        (MEAL_WITH_FOOD, "With food"),
        (MEAL_NONE, "None"),
    ]

    medication = models.ForeignKey(
        ConditionMedication,
        on_delete=models.CASCADE,
        related_name="schedules",
    )
    schedule_type = models.CharField(
        max_length=20,
        choices=SCHEDULE_TYPE_CHOICES,
        default=TYPE_DAILY,
    )
    time_of_day = models.TimeField()
    days_of_week = models.JSONField(default=list, blank=True)
    recurrence_days = models.JSONField(default=list, blank=True)
    interval_hours = models.PositiveSmallIntegerField(null=True, blank=True)
    meal_relation = models.CharField(
        max_length=20,
        choices=MEAL_RELATION_CHOICES,
        default=MEAL_NONE,
    )
    grace_period_minutes = models.PositiveSmallIntegerField(default=60)
    snooze_default_minutes = models.PositiveSmallIntegerField(default=15)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ("time_of_day", "id")
        constraints = [
            models.UniqueConstraint(
                fields=("medication", "schedule_type", "time_of_day", "interval_hours"),
                condition=models.Q(is_active=True),
                name="unique_active_med_schedule_time",
            ),
        ]


class ConditionMedicationLog(models.Model):
    STATUS_PENDING = "pending"
    STATUS_TAKEN = "taken"
    STATUS_OVERDUE = "overdue"
    STATUS_SNOOZED = "snoozed"
    STATUS_TAKEN_ON_TIME = "taken_on_time"
    STATUS_TAKEN_LATE = "taken_late"
    STATUS_MISSED = "missed"
    STATUS_SKIPPED = "skipped"
    STATUS_CHOICES = [
        (STATUS_PENDING, "Pending"),
        (STATUS_TAKEN, "Taken"),
        (STATUS_OVERDUE, "Overdue"),
        (STATUS_SNOOZED, "Snoozed"),
        (STATUS_TAKEN_ON_TIME, "Taken on time"),
        (STATUS_TAKEN_LATE, "Taken late"),
        (STATUS_MISSED, "Missed"),
        (STATUS_SKIPPED, "Skipped"),
    ]
    ACTION_USER = "user"
    ACTION_SYSTEM = "system"
    ACTION_SOURCE_CHOICES = [
        (ACTION_USER, "User"),
        (ACTION_SYSTEM, "System"),
    ]

    medication = models.ForeignKey(
        ConditionMedication,
        on_delete=models.CASCADE,
        related_name="dose_logs",
        null=True,
        blank=True,
    )
    schedule = models.ForeignKey(
        ConditionMedicationSchedule,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="logs",
    )
    scheduled_date = models.DateField()
    scheduled_for = models.DateTimeField(null=True, blank=True)
    taken_at = models.DateTimeField(null=True, blank=True)
    snoozed_until = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)
    skip_reason = models.CharField(max_length=255, blank=True)
    dose_taken_amount = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    action_source = models.CharField(
        max_length=20,
        choices=ACTION_SOURCE_CHOICES,
        default=ACTION_SYSTEM,
    )
    notes = models.CharField(max_length=255, blank=True)
    adherence_credit = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    points_applied = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-scheduled_date", "-id")
        constraints = [
            models.UniqueConstraint(
                fields=("medication", "scheduled_for"),
                name="unique_medication_scheduled_for",
            ),
        ]


class ConditionDailyEvaluation(models.Model):
    STATUS_STABLE = "stable"
    STATUS_ATTENTION_NEEDED = "attention_needed"
    STATUS_CRITICAL = "critical"
    STATUS_CHOICES = [
        (STATUS_STABLE, "Stable"),
        (STATUS_ATTENTION_NEEDED, "Attention needed"),
        (STATUS_CRITICAL, "Critical"),
    ]

    user_condition = models.ForeignKey(
        UserCondition,
        on_delete=models.CASCADE,
        related_name="daily_evaluations",
    )
    evaluation_date = models.DateField()
    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default=STATUS_STABLE)
    risk_flags = models.JSONField(default=list, blank=True)
    recommendations_payload = models.JSONField(default=list, blank=True)
    tracker_impacts_payload = models.JSONField(default=list, blank=True)
    latest_recorded_at = models.DateTimeField(null=True, blank=True)
    medication_adherence_percent = models.FloatField(default=0)
    restriction_adherence_percent = models.FloatField(default=0)
    points_delta = models.IntegerField(default=0)
    notes = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("user_condition", "evaluation_date")
        ordering = ("-evaluation_date", "-id")


class ConditionPointsAudit(models.Model):
    EVENT_MEDICATION = "medication"
    EVENT_RESTRICTION = "restriction"
    EVENT_STREAK = "streak"
    EVENT_SYSTEM = "system"
    EVENT_CHOICES = [
        (EVENT_MEDICATION, "Medication"),
        (EVENT_RESTRICTION, "Restriction"),
        (EVENT_STREAK, "Streak"),
        (EVENT_SYSTEM, "System"),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="condition_points_audit")
    user_condition = models.ForeignKey(
        UserCondition,
        on_delete=models.CASCADE,
        related_name="points_audit",
        null=True,
        blank=True,
    )
    medication_log = models.ForeignKey(
        ConditionMedicationLog,
        on_delete=models.SET_NULL,
        related_name="points_audit",
        null=True,
        blank=True,
    )
    event_type = models.CharField(max_length=20, choices=EVENT_CHOICES)
    points_delta = models.IntegerField()
    reason = models.CharField(max_length=255)
    explanation = models.TextField(blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at", "-id")
