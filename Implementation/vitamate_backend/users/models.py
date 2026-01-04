from django.db import models

# Create your models here.
from django.db import models
from django.contrib.auth.models import User
from datetime import datetime, timedelta, date, time

class UserProfile(models.Model):
    # الخيارات بناءً على المعادلات الصحية القياسية
    GENDER_CHOICES = [('M', 'Male'), ('F', 'Female')]
    GOAL_CHOICES = [
        ('lose', 'إنقاص الوزن'),
        ('maintain', 'الحفاظ على الوزن'),
        ('gain', 'زيادة الوزن'),
        ('muscle', 'بناء عضلات'), # [cite: 164] FR-18
    ]
    ACTIVITY_LEVELS = [
        (1.2, 'خامل (عمل مكتبي، لا رياضة)'),
        (1.375, 'نشاط خفيف (1-3 أيام)'),
        (1.55, 'نشاط متوسط (3-5 أيام)'),
        (1.725, 'نشاط عالي (6-7 أيام)'),
        (1.9, 'نشاط فائق (عمل شاق)'),
    ]

    # [FR-08] الطريقة المفضلة (تأكدنا من وجودها)
    PREFERRED_ACTIVITY_CHOICES = [
        ('gym', 'نادي رياضي'),
        ('running', 'ركض'),
        ('home', 'تمارين منزلية'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE)
    birth_date = models.DateField()
    gender = models.CharField(max_length=1, choices=GENDER_CHOICES)
    height = models.FloatField(help_text="الطول بالسم")
    weight = models.FloatField(help_text="الوزن بالكغ")
    activity_level = models.FloatField(choices=ACTIVITY_LEVELS, default=1.2)
    goal = models.CharField(max_length=20, choices=GOAL_CHOICES, default='maintain')
    
    #  FR-07: هدف النشاط البدني
    daily_step_goal = models.IntegerField(default=6000) 

    # الحقول المحسوبة (Calculated Fields)
    bmi = models.FloatField(default=0.0) # [cite: 164] FR-17
    daily_calorie_target = models.IntegerField(default=2000) # [cite: 164] FR-19
    daily_water_target = models.FloatField(default=2.5) #  FR-25
    # [FR-15] هدف ساعات النشاط الأسبوعي
    weekly_activity_goal_hours = models.FloatField(default=2.5, help_text="الهدف الأسبوعي بالساعات")
    # [FR-30, FR-33] إعدادات النوم
    enable_sleep_improvement = models.BooleanField(default=False) # تفعيل خيار تحسين النوم
    target_wake_time = models.TimeField(default=time(7, 0)) # وقت الاستيقاظ المفضل
    target_bed_time = models.TimeField(null=True, blank=True) # سيحسبه النظام
    recommended_sleep_hours = models.FloatField(default=8.0) # [FR-32] ساعات النوم اللازمة
    
    preferred_activity_type = models.CharField(max_length=20, choices=PREFERRED_ACTIVITY_CHOICES, default='home')
    # --- [FR-16] إعدادات تذكير النشاط البدني ---
    enable_activity_reminders = models.BooleanField(default=True, help_text="تفعيل تنبيهات الحركة")
    activity_reminder_interval_hours = models.IntegerField(default=2, help_text="ذكرني بالحركة كل X ساعات")

    # --- [FR-27] إعدادات تذكير شرب الماء ---
    enable_water_reminders = models.BooleanField(default=True, help_text="تفعيل تنبيهات شرب الماء")
    water_reminder_interval_minutes = models.IntegerField(default=60, help_text="ذكرني بالشرب كل X دقيقة")  


    def calculate_metrics(self):
        """
        دالة شاملة لحساب الاحتياجات بناءً على البيانات المدخلة
        """
        today = date.today()
        age = today.year - self.birth_date.year - ((today.month, today.day) < (self.birth_date.month, self.birth_date.day))

        # 1. حساب BMR (Mifflin-St Jeor)
        if self.gender == 'M':
            bmr = (10 * self.weight) + (6.25 * self.height) - (5 * age) + 5
        else:
            bmr = (10 * self.weight) + (6.25 * self.height) - (5 * age) - 161
        
        # 2. حساب TDEE وتعديله حسب الهدف [cite: 164] FR-14
        tdee = bmr * self.activity_level
        if self.goal == 'lose':
            self.daily_calorie_target = int(tdee - 500)
        elif self.goal == 'gain' or self.goal == 'muscle':
            self.daily_calorie_target = int(tdee + 500)
        else:
            self.daily_calorie_target = int(tdee)

        # 3. حساب احتياج الماء (33 مل لكل كغ)  FR-25
        self.daily_water_target = round((self.weight * 0.033), 2)

        # 4. حساب BMI وتصنيف الحالة
        height_m = self.height / 100
        self.bmi = round(self.weight / (height_m * height_m), 2)

        # [FR-32] حساب وقت النوم المقترح
        # إذا كان المستخدم يريد الاستيقاظ 7:00 ويحتاج 8 ساعات، فالنوم يجب أن يكون 23:00
        if self.target_wake_time:
            # عملية حسابية بسيطة للوقت (Pseudo-logic for time subtraction)
            dummy_date = datetime.combine(date.today(), self.target_wake_time)
            bed_time = dummy_date - timedelta(hours=self.recommended_sleep_hours)
            self.target_bed_time = bed_time.time()
        
        self.save()

    def __str__(self):
        return self.user.username