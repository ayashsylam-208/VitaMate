from django.db import models
from django.contrib.auth.models import User
from datetime import datetime, timedelta, date, time


class UserProfile(models.Model):
    """
    يمثل بيانات المستخدم الصحية الأساسية، مع أهداف يومية مشتقة تلقائياً.
    """

    GENDER_CHOICES = [('M', 'Male'), ('F', 'Female')]
    GOAL_CHOICES = [
        ('lose', 'خسارة وزن'),
        ('maintain', 'حفاظ'),
        ('gain', 'زيادة'),
        ('muscle', 'كتلة عضلية'),
    ]
    ACTIVITY_LEVELS = [
        (1.2, 'خامل'),
        (1.375, 'نشاط خفيف'),
        (1.55, 'نشاط متوسط'),
        (1.725, 'نشاط عالٍ'),
        (1.9, 'نشاط مرتفع جداً'),
    ]
    PREFERRED_ACTIVITY_CHOICES = [
        ('gym', 'تمارين نادي'),
        ('running', 'جري/مشي'),
        ('home', 'منزل'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE)
    birth_date = models.DateField()
    gender = models.CharField(max_length=1, choices=GENDER_CHOICES)
    height = models.FloatField(help_text="الطول بالسنتيمتر")
    weight = models.FloatField(help_text="الوزن بالكيلوغرام")
    activity_level = models.FloatField(choices=ACTIVITY_LEVELS, default=1.2)
    goal = models.CharField(max_length=20, choices=GOAL_CHOICES, default='maintain')

    # أهداف يومية
    daily_step_goal = models.IntegerField(default=6000)
    daily_burn_goal = models.IntegerField(default=300)

    # حقول محسوبة
    bmi = models.FloatField(default=0.0)
    daily_calorie_target = models.IntegerField(default=2000)
    daily_water_target = models.FloatField(default=2.5)
    weekly_activity_goal_hours = models.FloatField(default=2.5)
    enable_sleep_improvement = models.BooleanField(default=False)
    target_wake_time = models.TimeField(default=time(7, 0))
    target_bed_time = models.TimeField(null=True, blank=True)
    recommended_sleep_hours = models.FloatField(default=8.0)

    preferred_activity_type = models.CharField(
        max_length=20, choices=PREFERRED_ACTIVITY_CHOICES, default='home'
    )
    enable_activity_reminders = models.BooleanField(default=True)
    activity_reminder_interval_hours = models.IntegerField(default=2)
    enable_water_reminders = models.BooleanField(default=True)
    water_reminder_interval_minutes = models.IntegerField(default=60)

    def calculate_metrics(self):
        """
        يحسب الأهداف اليومية (سعرات، ماء، خطوات، حرق) بناءً على بيانات المستخدم.
        """
        today = date.today()
        age = today.year - self.birth_date.year - (
            (today.month, today.day) < (self.birth_date.month, self.birth_date.day)
        )

        # 1) BMR بطريقة Mifflin-St Jeor
        if self.gender == 'M':
            bmr = (10 * self.weight) + (6.25 * self.height) - (5 * age) + 5
        else:
            bmr = (10 * self.weight) + (6.25 * self.height) - (5 * age) - 161

        # 2) TDEE وتحديد هدف السعرات حسب الهدف الصحي
        tdee = bmr * self.activity_level
        if self.goal == 'lose':
            self.daily_calorie_target = int(tdee - 500)
        elif self.goal in ['gain', 'muscle']:
            self.daily_calorie_target = int(tdee + 500)
        else:
            self.daily_calorie_target = int(tdee)

        # 3) هدف الماء: 0.033 لتر لكل كغ
        self.daily_water_target = round((self.weight * 0.033), 2)

        # 4) هدف الخطوات: خط أساس 6000 مع زيادات بسيطة حسب الهدف والنشاط
        step_goal = 6000
        if self.goal == 'lose':
            step_goal += 2000
        elif self.goal in ['muscle', 'gain']:
            step_goal += 1000
        if self.activity_level >= 1.55:
            step_goal += 1000
        if self.activity_level >= 1.725:
            step_goal += 500
        self.daily_step_goal = max(5000, step_goal)

        # 5) هدف الحرق: حرق الخطوات + معامل نشاط + دفعة إضافية لمن يريد الخسارة
        steps_burn_target = int(self.daily_step_goal * 0.04)  # تقريب 0.04 سعرة لكل خطوة
        activity_component = int(self.activity_level * 150)
        goal_bonus = 100 if self.goal == 'lose' else 0
        self.daily_burn_goal = steps_burn_target + activity_component + goal_bonus

        # 6) BMI للمؤشرات العامة
        height_m = self.height / 100
        self.bmi = round(self.weight / (height_m * height_m), 2)

        # 7) وقت النوم المقترح من وقت الاستيقاظ ومدة النوم الموصى بها
        if self.target_wake_time:
            dummy_date = datetime.combine(date.today(), self.target_wake_time)
            bed_time = dummy_date - timedelta(hours=self.recommended_sleep_hours)
            self.target_bed_time = bed_time.time()

        self.save()

    def __str__(self):
        return self.user.username
