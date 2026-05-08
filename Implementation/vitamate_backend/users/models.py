from datetime import time

from django.contrib.auth.models import User
from django.db import models

from users.services.profile_metrics_calculator import ProfileMetricsCalculator


class UserProfile(models.Model):
    """
    يمثل بيانات المستخدم الصحية الأساسية، مع أهداف يومية مشتقة تلقائيًا.
    """

    GENDER_CHOICES = [("M", "Male"), ("F", "Female")]
    GOAL_CHOICES = [
        ("lose", "خسارة وزن"),
        ("maintain", "حفاظ"),
        ("gain", "زيادة"),
        ("muscle", "كتلة عضلية"),
    ]
    ACTIVITY_LEVELS = [
        (1.2, "خامل"),
        (1.375, "نشاط خفيف"),
        (1.55, "نشاط متوسط"),
        (1.725, "نشاط عالٍ"),
        (1.9, "نشاط مرتفع جدًا"),
    ]
    PREFERRED_ACTIVITY_CHOICES = [
        ("gym", "تمارين نادي"),
        ("running", "جري/مشي"),
        ("home", "منزل"),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE)
    birth_date = models.DateField()
    gender = models.CharField(max_length=1, choices=GENDER_CHOICES)
    height = models.FloatField(help_text="الطول بالسنتيمتر")
    weight = models.FloatField(help_text="الوزن بالكيلوغرام")
    activity_level = models.FloatField(choices=ACTIVITY_LEVELS, default=1.2)
    goal = models.CharField(max_length=20, choices=GOAL_CHOICES, default="maintain")

    daily_step_goal = models.IntegerField(default=6000)
    daily_burn_goal = models.IntegerField(default=300)

    bmi = models.FloatField(default=0.0)
    daily_calorie_target = models.IntegerField(default=2000)
    daily_water_target = models.FloatField(default=2.5)
    weekly_activity_goal_hours = models.FloatField(default=2.5)
    enable_sleep_improvement = models.BooleanField(default=False)
    target_wake_time = models.TimeField(default=time(7, 0))
    target_bed_time = models.TimeField(null=True, blank=True)
    recommended_sleep_hours = models.FloatField(default=8.0)

    preferred_activity_type = models.CharField(
        max_length=20,
        choices=PREFERRED_ACTIVITY_CHOICES,
        default="home",
    )
    enable_activity_reminders = models.BooleanField(default=True)
    activity_reminder_interval_hours = models.IntegerField(default=2)
    activity_reminder_time = models.TimeField(default=time(10, 0))
    activity_reminder_days = models.JSONField(default=list, blank=True)
    inactive_reminder_enabled = models.BooleanField(default=False)
    inactive_reminder_hours = models.IntegerField(default=3)
    enable_water_reminders = models.BooleanField(default=True)
    water_reminder_interval_minutes = models.IntegerField(default=60)

    def calculate_metrics(self):
        """
        يحسب الأهداف اليومية (سعرات، ماء، خطوات، حرق) بناءً على بيانات المستخدم.
        """
        ProfileMetricsCalculator.apply(self, persist=False)
        self.save()

    def __str__(self):
        return self.user.username
