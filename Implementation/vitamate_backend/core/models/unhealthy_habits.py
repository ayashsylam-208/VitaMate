from django.contrib.auth.models import User
from django.db import models
from django.utils import timezone


class UnhealthyHabit(models.Model):
    TYPE_SMOKING = "smoking"
    TYPE_CAFFEINE = "caffeine"
    TYPE_FAST_FOOD = "fast_food"
    HABIT_TYPE_CHOICES = [
        (TYPE_SMOKING, "Smoking"),
        (TYPE_CAFFEINE, "Caffeine"),
        (TYPE_FAST_FOOD, "Fast food"),
    ]

    GOAL_REDUCE = "reduce"
    GOAL_QUIT = "quit"
    GOAL_CHOICES = [
        (GOAL_REDUCE, "Reduce"),
        (GOAL_QUIT, "Quit"),
    ]

    STATUS_ACTIVE = "active"
    STATUS_PAUSED = "paused"
    STATUS_COMPLETED = "completed"
    STATUS_CHOICES = [
        (STATUS_ACTIVE, "Active"),
        (STATUS_PAUSED, "Paused"),
        (STATUS_COMPLETED, "Completed"),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="unhealthy_habits")
    habit_type = models.CharField(max_length=20, choices=HABIT_TYPE_CHOICES, db_index=True)
    title = models.CharField(max_length=120, blank=True, default="")
    goal_type = models.CharField(max_length=20, choices=GOAL_CHOICES, default=GOAL_REDUCE)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_ACTIVE, db_index=True)
    start_date = models.DateField(default=timezone.localdate)
    target_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("habit_type", "id")
        indexes = [
            models.Index(fields=("user", "habit_type", "status"), name="unhealthy_habit_user_type_idx"),
        ]

    def __str__(self):
        return self.title or self.get_habit_type_display()


class UnhealthyHabitBaseline(models.Model):
    habit = models.OneToOneField(
        UnhealthyHabit,
        on_delete=models.CASCADE,
        related_name="baseline",
    )
    initial_frequency = models.FloatField(default=0)
    initial_quantity = models.FloatField(default=0)
    unit = models.CharField(max_length=30, blank=True, default="")
    common_trigger = models.CharField(max_length=80, blank=True, default="")
    common_time = models.TimeField(null=True, blank=True)
    notes = models.TextField(blank=True, default="")
    extra = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.habit}: baseline"


class UnhealthyHabitPlan(models.Model):
    habit = models.OneToOneField(
        UnhealthyHabit,
        on_delete=models.CASCADE,
        related_name="plan",
    )
    daily_limit = models.FloatField(null=True, blank=True)
    weekly_limit = models.FloatField(null=True, blank=True)
    target_quantity = models.FloatField(null=True, blank=True)
    reduction_percentage = models.FloatField(default=0)
    cutoff_time = models.TimeField(null=True, blank=True)
    plan_stage = models.CharField(max_length=80, blank=True, default="")
    healthy_replacement_required = models.BooleanField(default=False)
    reminder_time = models.TimeField(null=True, blank=True)
    notes = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.habit}: plan"


class UnhealthyHabitLog(models.Model):
    SOURCE_MANUAL = "manual"
    SOURCE_NUTRITION = "nutrition"
    SOURCE_HYDRATION = "hydration"
    SOURCE_CHOICES = [
        (SOURCE_MANUAL, "Manual"),
        (SOURCE_NUTRITION, "Nutrition"),
        (SOURCE_HYDRATION, "Hydration"),
    ]

    habit = models.ForeignKey(
        UnhealthyHabit,
        on_delete=models.CASCADE,
        related_name="logs",
    )
    logged_at = models.DateTimeField(default=timezone.now, db_index=True)
    log_date = models.DateField(db_index=True)
    quantity = models.FloatField(default=1)
    unit = models.CharField(max_length=30, blank=True, default="")
    trigger = models.CharField(max_length=80, blank=True, default="")
    mood = models.CharField(max_length=80, blank=True, default="")
    notes = models.TextField(blank=True, default="")
    is_relapse = models.BooleanField(default=False)
    is_within_limit = models.BooleanField(default=True)
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default=SOURCE_MANUAL)
    sync_to_tracker = models.BooleanField(default=False)
    linked_meal_log = models.ForeignKey(
        "core.MealLog",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="unhealthy_habit_logs",
    )
    linked_water_log = models.ForeignKey(
        "core.WaterLog",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="unhealthy_habit_logs",
    )
    caffeine_mg = models.FloatField(default=0)
    calories_kcal = models.FloatField(default=0)
    food_name = models.CharField(max_length=160, blank=True, default="")
    healthy_replacement = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ("-logged_at", "-id")
        indexes = [
            models.Index(fields=("habit", "log_date"), name="unhealthy_log_habit_date_idx"),
            models.Index(fields=("habit", "is_relapse"), name="unhealthy_log_relapse_idx"),
        ]

    def save(self, *args, **kwargs):
        if self.logged_at and not self.log_date:
            self.log_date = timezone.localtime(self.logged_at).date()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.habit}: {self.quantity} {self.unit}".strip()


class UnhealthyHabitReminder(models.Model):
    habit = models.ForeignKey(
        UnhealthyHabit,
        on_delete=models.CASCADE,
        related_name="reminders",
    )
    time_of_day = models.TimeField()
    message = models.CharField(max_length=180, blank=True, default="")
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("time_of_day", "id")

    def __str__(self):
        return f"{self.habit}: {self.time_of_day}"


class UnhealthyHabitPointEvent(models.Model):
    EVENT_LOGGED = "logged"
    EVENT_WITHIN_LIMIT = "within_limit"
    EVENT_IMPROVEMENT = "improvement"
    EVENT_HEALTHY_REPLACEMENT = "healthy_replacement"
    EVENT_CHOICES = [
        (EVENT_LOGGED, "Logged"),
        (EVENT_WITHIN_LIMIT, "Within limit"),
        (EVENT_IMPROVEMENT, "Improvement"),
        (EVENT_HEALTHY_REPLACEMENT, "Healthy replacement"),
    ]

    habit = models.ForeignKey(
        UnhealthyHabit,
        on_delete=models.CASCADE,
        related_name="point_events",
    )
    log = models.ForeignKey(
        UnhealthyHabitLog,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="point_events",
    )
    event_type = models.CharField(max_length=40, choices=EVENT_CHOICES)
    event_date = models.DateField(db_index=True)
    points = models.IntegerField(default=0)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ("-created_at", "-id")
        constraints = [
            models.UniqueConstraint(
                fields=("habit", "event_type", "event_date", "log"),
                name="unique_unhealthy_point_event",
            )
        ]

    def __str__(self):
        return f"{self.habit}: {self.event_type} {self.points}"
