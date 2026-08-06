from django.contrib.auth.models import User
from django.db import models
from django.utils import timezone


class Exercise(models.Model):
    name = models.CharField(max_length=100)
    met_value = models.FloatField(help_text="MET value")
    icon_key = models.CharField(max_length=50, default="fitness_center")
    default_duration_minutes = models.PositiveIntegerField(default=30)
    met_light = models.FloatField(default=0.0)
    met_moderate = models.FloatField(default=0.0)
    met_intense = models.FloatField(default=0.0)
    is_featured = models.BooleanField(default=True)
    sort_order = models.PositiveIntegerField(default=0)

    def save(self, *args, **kwargs):
        if self.default_duration_minutes <= 0:
            self.default_duration_minutes = 30
        if self.met_light <= 0:
            self.met_light = round(max(self.met_value * 0.85, 1.5), 1)
        if self.met_moderate <= 0:
            self.met_moderate = round(self.met_value, 1)
        if self.met_intense <= 0:
            self.met_intense = round(max(self.met_value * 1.15, self.met_value), 1)
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name


class ActivityLog(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    exercise = models.ForeignKey(Exercise, on_delete=models.CASCADE)
    source_session = models.OneToOneField(
        "ActivitySession",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="final_activity_log",
    )
    duration_minutes = models.IntegerField()
    date = models.DateField(default=timezone.localdate)
    distance_km = models.FloatField(default=0.0, help_text="Distance covered")
    avg_speed_kmh = models.FloatField(default=0.0, help_text="Average speed")

    def save(self, *args, **kwargs):
        if self.distance_km > 0 and self.duration_minutes > 0:
            duration_hours = self.duration_minutes / 60
            self.avg_speed_kmh = round(self.distance_km / duration_hours, 2)
        super().save(*args, **kwargs)

    @property
    def calories_burned(self):
        weight = self.user.userprofile.weight
        return int((self.exercise.met_value * 3.5 * weight) / 200 * self.duration_minutes)


class ActivitySession(models.Model):
    STATUS_RUNNING = "running"
    STATUS_PAUSED = "paused"
    STATUS_COMPLETED = "completed"
    STATUS_CANCELLED = "cancelled"
    STATUS_CHOICES = [
        (STATUS_RUNNING, "Running"),
        (STATUS_PAUSED, "Paused"),
        (STATUS_COMPLETED, "Completed"),
        (STATUS_CANCELLED, "Cancelled"),
    ]

    SOURCE_LIVE = "live"
    SOURCE_GUIDED = "guided"
    SOURCE_CHOICES = [
        (SOURCE_LIVE, "Live"),
        (SOURCE_GUIDED, "Guided"),
    ]

    INTENSITY_LIGHT = "light"
    INTENSITY_MODERATE = "moderate"
    INTENSITY_INTENSE = "intense"
    INTENSITY_CHOICES = [
        (INTENSITY_LIGHT, "Light"),
        (INTENSITY_MODERATE, "Moderate"),
        (INTENSITY_INTENSE, "Intense"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="activity_sessions",
    )
    exercise = models.ForeignKey(Exercise, on_delete=models.CASCADE)
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=STATUS_RUNNING,
    )
    source = models.CharField(
        max_length=20,
        choices=SOURCE_CHOICES,
        default=SOURCE_LIVE,
    )
    intensity = models.CharField(
        max_length=20,
        choices=INTENSITY_CHOICES,
        default=INTENSITY_MODERATE,
    )
    target_duration_seconds = models.PositiveIntegerField(default=1800)
    actual_duration_seconds = models.PositiveIntegerField(default=0)
    met_value_snapshot = models.FloatField(default=0.0)
    estimated_calories = models.PositiveIntegerField(default=0)
    calories_burned = models.PositiveIntegerField(default=0)
    started_at = models.DateTimeField(auto_now_add=True)
    paused_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    total_paused_seconds = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "status"], name="core_actsess_user_status_idx"),
            models.Index(fields=["user", "started_at"], name="core_actsess_user_started_idx"),
        ]
        ordering = ["-started_at", "-id"]

    def __str__(self):
        return f"{self.user.username} {self.exercise.name} {self.status}"

    @property
    def is_active(self) -> bool:
        return self.status in {self.STATUS_RUNNING, self.STATUS_PAUSED}

    def effective_elapsed_seconds(self, now=None) -> int:
        now = now or timezone.now()
        if self.ended_at is not None:
            reference = self.ended_at
        elif self.status == self.STATUS_PAUSED and self.paused_at is not None:
            reference = self.paused_at
        else:
            reference = now
        elapsed = int((reference - self.started_at).total_seconds()) - int(
            self.total_paused_seconds or 0
        )
        return max(elapsed, int(self.actual_duration_seconds or 0), 0)

    def effective_calories_burned(self, now=None) -> int:
        weight = getattr(getattr(self.user, "userprofile", None), "weight", 0) or 0
        elapsed_minutes = self.effective_elapsed_seconds(now=now) / 60
        return int((self.met_value_snapshot * 3.5 * weight) / 200 * elapsed_minutes)


class StepLog(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    date = models.DateField(default=timezone.localdate)
    timezone = models.CharField(max_length=64, blank=True, default="")
    installation_id = models.CharField(max_length=128, blank=True, default="")
    measured_at = models.DateTimeField(null=True, blank=True)
    sensor_steps = models.PositiveIntegerField(default=0)
    manual_adjustment_steps = models.IntegerField(default=0)
    imported_adjustment_steps = models.IntegerField(default=0)
    steps_count = models.IntegerField(default=0)
    distance_km = models.FloatField(default=0.0)
    sync_version = models.PositiveIntegerField(default=0)

    class Meta:
        unique_together = ("user", "date")

    @property
    def calories_burned(self):
        return int(self.steps_count * 0.04)

    @property
    def burn_rate_kcal_per_km(self):
        if self.distance_km <= 0:
            return 0
        return round(self.calories_burned / self.distance_km, 1)


class SleepLog(models.Model):
    QUALITY_CHOICES = [("Deep", "Deep"), ("Light", "Light"), ("Interrupted", "Interrupted")]
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    quality = models.CharField(max_length=20, choices=QUALITY_CHOICES)
    date = models.DateField(default=timezone.localdate)

    @property
    def duration_hours(self):
        diff = self.end_time - self.start_time
        return round(diff.total_seconds() / 3600, 2)


class SleepPlan(models.Model):
    STATUS_ACTIVE = "active"
    STATUS_CANCELLED = "cancelled"
    STATUS_COMPLETED = "completed"
    STATUS_CHOICES = [
        (STATUS_ACTIVE, "Active"),
        (STATUS_CANCELLED, "Cancelled"),
        (STATUS_COMPLETED, "Completed"),
    ]

    FACTOR_NONE = "none"
    FACTOR_LATE_CAFFEINE = "late_caffeine"
    FACTOR_LATE_HEAVY_MEAL = "late_heavy_meal"
    FACTOR_HIGH_STRESS = "high_stress"
    FACTOR_HIGH_SCREEN = "high_screen"
    FACTOR_LATE_NAP = "late_nap"
    FACTOR_LATE_INTENSE_EXERCISE = "late_intense_exercise"
    FACTOR_LOW_ACTIVITY = "low_activity"

    NEGATIVE_FACTOR_CHOICES = [
        (FACTOR_NONE, "None"),
        (FACTOR_LATE_CAFFEINE, "Late caffeine"),
        (FACTOR_LATE_HEAVY_MEAL, "Late heavy meal"),
        (FACTOR_HIGH_STRESS, "High stress"),
        (FACTOR_HIGH_SCREEN, "High screen use"),
        (FACTOR_LATE_NAP, "Late nap"),
        (FACTOR_LATE_INTENSE_EXERCISE, "Late intense exercise"),
        (FACTOR_LOW_ACTIVITY, "Low activity"),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="sleep_plans")
    plan_date = models.DateField(db_index=True)
    planned_bed_time = models.DateTimeField()
    latest_wake_time = models.DateTimeField()
    flexibility_minutes = models.PositiveSmallIntegerField(default=0)
    wake_window_start = models.DateTimeField()
    wake_window_end = models.DateTimeField()
    questionnaire = models.JSONField(default=dict, blank=True)
    tracker_factors = models.JSONField(default=dict, blank=True)
    estimated_sleep_start = models.DateTimeField()
    wake_options = models.JSONField(default=list, blank=True)
    selected_wake_time = models.DateTimeField(null=True, blank=True)
    recommendation_reason = models.TextField(blank=True)
    primary_negative_factor = models.CharField(
        max_length=40,
        choices=NEGATIVE_FACTOR_CHOICES,
        default=FACTOR_NONE,
    )
    night_tip = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_ACTIVE)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "plan_date", "status"], name="core_sleepp_user_id_9f3ac5_idx"),
            models.Index(fields=["user", "selected_wake_time"], name="core_sleepp_user_id_32d7b0_idx"),
        ]
        ordering = ["-planned_bed_time", "-id"]

    def __str__(self):
        return f"{self.user.username} sleep plan {self.plan_date}"


class SleepMorningFeedback(models.Model):
    WAKE_RESTED = "rested"
    WAKE_OKAY = "okay"
    WAKE_GROGGY = "groggy"
    WAKE_EXHAUSTED = "exhausted"
    WAKE_FEELING_CHOICES = [
        (WAKE_RESTED, "Rested"),
        (WAKE_OKAY, "Okay"),
        (WAKE_GROGGY, "Groggy"),
        (WAKE_EXHAUSTED, "Exhausted"),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="sleep_feedback")
    plan = models.OneToOneField(
        SleepPlan,
        on_delete=models.CASCADE,
        related_name="morning_feedback",
    )
    sleep_log = models.OneToOneField(
        SleepLog,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="coach_feedback",
    )
    quality_rating = models.PositiveSmallIntegerField()
    wake_feeling = models.CharField(max_length=20, choices=WAKE_FEELING_CHOICES)
    focus_rating = models.PositiveSmallIntegerField()
    disruptor = models.CharField(max_length=40, blank=True)
    actual_sleep_start = models.DateTimeField(null=True, blank=True)
    actual_wake_time = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "created_at"], name="core_sleepm_user_id_50301c_idx"),
            models.Index(fields=["user", "quality_rating"], name="core_sleepm_user_id_e6a6f4_idx"),
        ]
        ordering = ["-created_at", "-id"]

    def __str__(self):
        return f"{self.user.username} sleep feedback {self.quality_rating}/5"
