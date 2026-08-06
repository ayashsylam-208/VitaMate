from django.contrib.auth.models import User
from django.db import models
from django.db.models import Sum
from django.utils import timezone


class UserScore(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    total_points = models.IntegerField(default=0)
    level = models.IntegerField(default=1)
    current_streak = models.IntegerField(default=0)
    longest_streak = models.IntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)

    def add_points(self, points: int):
        self.total_points += int(points or 0)
        self.level = max((self.total_points // 1000) + 1, 1)
        self.save(update_fields=["total_points", "level", "updated_at"])

    def deduct_points(self, points: int):
        self.total_points -= int(points or 0)
        if self.total_points < 0:
            self.total_points = 0
        self.level = max((self.total_points // 1000) + 1, 1)
        self.save(update_fields=["total_points", "level", "updated_at"])

    @classmethod
    def rebuild_for_user(cls, *, user):
        total = (
            PointsTransaction.objects.filter(user=user)
            .aggregate(total=Sum("points"))
            .get("total")
            or 0
        )
        score, _ = cls.objects.get_or_create(user=user)
        score.total_points = max(int(total), 0)
        score.level = max((score.total_points // 1000) + 1, 1)
        score.save(update_fields=["total_points", "level", "updated_at"])
        return score


class PointsTransaction(models.Model):
    EVENT_AWARD = "award"
    EVENT_BONUS = "bonus"
    EVENT_CORRECTION = "correction"
    EVENT_REVERSAL = "reversal"
    EVENT_CHOICES = [
        (EVENT_AWARD, "Award"),
        (EVENT_BONUS, "Bonus"),
        (EVENT_CORRECTION, "Correction"),
        (EVENT_REVERSAL, "Reversal"),
    ]
    SOURCE_SYSTEM = "system"
    SOURCE_HYDRATION = "hydration"
    SOURCE_NUTRITION = "nutrition"
    SOURCE_ACTIVITY = "activity"
    SOURCE_STEPS = "steps"
    SOURCE_SLEEP = "sleep"
    SOURCE_MEDICATION = "medication"
    SOURCE_CHRONIC = "chronic"
    SOURCE_HABITS = "habits"
    SOURCE_MOTIVATION = "motivation"
    SOURCE_CHOICES = [
        (SOURCE_SYSTEM, "System"),
        (SOURCE_HYDRATION, "Hydration"),
        (SOURCE_NUTRITION, "Nutrition"),
        (SOURCE_ACTIVITY, "Activity"),
        (SOURCE_STEPS, "Steps"),
        (SOURCE_SLEEP, "Sleep"),
        (SOURCE_MEDICATION, "Medication"),
        (SOURCE_CHRONIC, "Chronic"),
        (SOURCE_HABITS, "Habits"),
        (SOURCE_MOTIVATION, "Motivation"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="points_transactions",
    )
    source_type = models.CharField(
        max_length=24,
        choices=SOURCE_CHOICES,
        default=SOURCE_SYSTEM,
    )
    source_id = models.CharField(max_length=64, blank=True, default="")
    event_type = models.CharField(
        max_length=20,
        choices=EVENT_CHOICES,
        default=EVENT_AWARD,
        db_index=True,
    )
    rule_code = models.CharField(max_length=64)
    points = models.IntegerField(default=0)
    reason = models.CharField(max_length=240, blank=True, default="")
    event_date = models.DateField(default=timezone.localdate, db_index=True)
    metadata = models.JSONField(default=dict, blank=True)
    idempotency_key = models.CharField(max_length=191, unique=True, db_index=True)
    reversal_of = models.ForeignKey(
        "self",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reversal_transactions",
    )
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ("-created_at", "-id")
        indexes = [
            models.Index(fields=("user", "event_date"), name="points_tx_user_date_idx"),
            models.Index(fields=("user", "source_type"), name="points_tx_user_source_idx"),
            models.Index(fields=("user", "rule_code"), name="points_tx_user_rule_idx"),
        ]


class DailyMission(models.Model):
    STATUS_PENDING = "pending"
    STATUS_IN_PROGRESS = "in_progress"
    STATUS_COMPLETED = "completed"
    STATUS_MISSED = "missed"
    STATUS_NOT_APPLICABLE = "not_applicable"
    STATUS_CHOICES = [
        (STATUS_PENDING, "Pending"),
        (STATUS_IN_PROGRESS, "In progress"),
        (STATUS_COMPLETED, "Completed"),
        (STATUS_MISSED, "Missed"),
        (STATUS_NOT_APPLICABLE, "Not applicable"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="daily_missions",
    )
    mission_date = models.DateField(db_index=True)
    mission_type = models.CharField(max_length=48, db_index=True)
    title = models.CharField(max_length=120)
    description = models.CharField(max_length=240, blank=True, default="")
    target_value = models.FloatField(default=0)
    current_value = models.FloatField(default=0)
    points_reward = models.IntegerField(default=0)
    status = models.CharField(
        max_length=24,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
        db_index=True,
    )
    reason = models.CharField(max_length=220, blank=True, default="")
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("mission_type", "id")
        constraints = [
            models.UniqueConstraint(
                fields=("user", "mission_date", "mission_type"),
                name="unique_daily_mission_per_type",
            )
        ]
        indexes = [
            models.Index(fields=("user", "mission_date"), name="daily_mission_user_date_idx"),
        ]


class UserStreak(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="motivation_streaks",
    )
    streak_type = models.CharField(max_length=48, db_index=True)
    current_count = models.IntegerField(default=0)
    longest_count = models.IntegerField(default=0)
    last_completed_date = models.DateField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("streak_type", "id")
        constraints = [
            models.UniqueConstraint(
                fields=("user", "streak_type"),
                name="unique_user_streak_type",
            )
        ]


class Badge(models.Model):
    CONDITION_STREAK = "streak"
    CONDITION_COUNTER = "counter"
    CONDITION_CHOICES = [
        (CONDITION_STREAK, "Streak"),
        (CONDITION_COUNTER, "Counter"),
    ]

    code = models.CharField(max_length=64, unique=True, db_index=True)
    name = models.CharField(max_length=120)
    description = models.CharField(max_length=240, blank=True, default="")
    icon = models.CharField(max_length=48, blank=True, default="")
    condition_type = models.CharField(
        max_length=24,
        choices=CONDITION_CHOICES,
        default=CONDITION_STREAK,
    )
    condition_key = models.CharField(max_length=64, db_index=True)
    required_value = models.IntegerField(default=1)
    points_bonus = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True, db_index=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("id",)


class UserBadge(models.Model):
    STATUS_IN_PROGRESS = "in_progress"
    STATUS_EARNED = "earned"
    STATUS_CHOICES = [
        (STATUS_IN_PROGRESS, "In progress"),
        (STATUS_EARNED, "Earned"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="user_badges",
    )
    badge = models.ForeignKey(
        Badge,
        on_delete=models.CASCADE,
        related_name="user_badges",
    )
    progress_value = models.IntegerField(default=0)
    status = models.CharField(
        max_length=24,
        choices=STATUS_CHOICES,
        default=STATUS_IN_PROGRESS,
        db_index=True,
    )
    earned_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("badge_id", "id")
        constraints = [
            models.UniqueConstraint(
                fields=("user", "badge"),
                name="unique_user_badge",
            )
        ]


class DailyStepPointsAward(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="daily_step_point_awards",
    )
    award_date = models.DateField(db_index=True)
    highest_threshold_awarded = models.IntegerField(default=0)
    points_awarded = models.IntegerField(default=0)
    goal_bonus_awarded = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-award_date", "-id")
        constraints = [
            models.UniqueConstraint(
                fields=("user", "award_date"),
                name="unique_daily_step_points_award",
            )
        ]


class DailyMotivationState(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="daily_motivation_states",
    )
    state_date = models.DateField(db_index=True)
    hydration_status = models.CharField(
        max_length=24,
        choices=DailyMission.STATUS_CHOICES,
        default=DailyMission.STATUS_PENDING,
    )
    nutrition_status = models.CharField(
        max_length=24,
        choices=DailyMission.STATUS_CHOICES,
        default=DailyMission.STATUS_PENDING,
    )
    activity_status = models.CharField(
        max_length=24,
        choices=DailyMission.STATUS_CHOICES,
        default=DailyMission.STATUS_PENDING,
    )
    sleep_status = models.CharField(
        max_length=24,
        choices=DailyMission.STATUS_CHOICES,
        default=DailyMission.STATUS_PENDING,
    )
    medication_status = models.CharField(
        max_length=24,
        choices=DailyMission.STATUS_CHOICES,
        default=DailyMission.STATUS_NOT_APPLICABLE,
    )
    habits_status = models.CharField(
        max_length=24,
        choices=DailyMission.STATUS_CHOICES,
        default=DailyMission.STATUS_NOT_APPLICABLE,
    )
    completed_missions_count = models.IntegerField(default=0)
    not_applicable_missions_count = models.IntegerField(default=0)
    total_daily_points = models.IntegerField(default=0)
    generated_at = models.DateTimeField(auto_now=True)
    metadata = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ("-state_date", "-id")
        constraints = [
            models.UniqueConstraint(
                fields=("user", "state_date"),
                name="unique_daily_motivation_state",
            )
        ]


class MotivationExperienceEvent(models.Model):
    TYPE_POINTS_AWARDED = "points_awarded"
    TYPE_MISSION_COMPLETED = "mission_completed"
    TYPE_BADGE_EARNED = "badge_earned"
    TYPE_LEVEL_UP = "level_up"
    TYPE_STREAK_MILESTONE = "streak_milestone"
    TYPE_CHOICES = [
        (TYPE_POINTS_AWARDED, "Points awarded"),
        (TYPE_MISSION_COMPLETED, "Mission completed"),
        (TYPE_BADGE_EARNED, "Badge earned"),
        (TYPE_LEVEL_UP, "Level up"),
        (TYPE_STREAK_MILESTONE, "Streak milestone"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="motivation_experience_events",
    )
    event_type = models.CharField(
        max_length=32,
        choices=TYPE_CHOICES,
        db_index=True,
    )
    title = models.CharField(max_length=120)
    subtitle = models.CharField(max_length=240, blank=True, default="")
    points_delta = models.IntegerField(default=0)
    animation = models.CharField(max_length=32, blank=True, default="burst")
    route = models.CharField(max_length=64, blank=True, default="")
    metadata = models.JSONField(default=dict, blank=True)
    dedupe_key = models.CharField(max_length=191, unique=True, db_index=True)
    is_acknowledged = models.BooleanField(default=False, db_index=True)
    acknowledged_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(default=timezone.now, db_index=True)

    class Meta:
        ordering = ("-created_at", "-id")
        indexes = [
            models.Index(
                fields=("user", "is_acknowledged", "created_at"),
                name="motivation_event_user_ack_idx",
            ),
            models.Index(
                fields=("user", "event_type", "created_at"),
                name="motivation_event_user_type_idx",
            ),
        ]
