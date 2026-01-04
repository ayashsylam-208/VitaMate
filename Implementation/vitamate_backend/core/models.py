from django.db import models

# Create your models here.
from django.db import models
from django.contrib.auth.models import User
from users.models import UserProfile

# --- 1. التغذية (Nutrition) [cite: 164] FR-21 ---
class FoodItem(models.Model):
    name = models.CharField(max_length=100)
    calories = models.IntegerField()
    protein = models.FloatField(default=0)
    carbs = models.FloatField(default=0)
    fat = models.FloatField(default=0)

    def __str__(self): return self.name

class MealLog(models.Model):
    MEAL_TYPES = [('breakfast', 'فطور'), ('lunch', 'غداء'), ('dinner', 'عشاء'), ('snack', 'سناك')]
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    food = models.ForeignKey(FoodItem, on_delete=models.CASCADE)
    meal_type = models.CharField(max_length=20, choices=MEAL_TYPES)
    quantity = models.FloatField(default=1.0, help_text="عدد الحصص")
    date = models.DateField(auto_now_add=True)

    @property
    def total_calories(self):
        return int(self.food.calories * self.quantity)

# --- 2. الماء (Water)  FR-28 ---
class WaterLog(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    amount_liter = models.FloatField(help_text="كمية الماء باللتر")
    date = models.DateField(auto_now_add=True)

# --- 3. النشاط البدني والخطوات (Fitness)  FR-09, FR-11 ---
class Exercise(models.Model):
    name = models.CharField(max_length=100)
    met_value = models.FloatField(help_text="معدل الحرق (MET)") # [cite: 164] FR-13

    def __str__(self): return self.name

class ActivityLog(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    exercise = models.ForeignKey(Exercise, on_delete=models.CASCADE)
    duration_minutes = models.IntegerField()
    date = models.DateField(auto_now_add=True)
    # [FR-12] حقول إضافية خاصة بالركض/المشي
    distance_km = models.FloatField(default=0.0, help_text="المسافة المقطوعة (للركض)")
    avg_speed_kmh = models.FloatField(default=0.0, help_text="السرعة المتوسطة")

    def save(self, *args, **kwargs):
        # حساب السرعة تلقائياً إذا وجدت مسافة ووقت
        if self.distance_km > 0 and self.duration_minutes > 0:
            duration_hours = self.duration_minutes / 60
            self.avg_speed_kmh = round(self.distance_km / duration_hours, 2)
        super().save(*args, **kwargs)

    @property
    def calories_burned(self):
        # Calories = (MET * 3.5 * weight) / 200 * minutes
        weight = self.user.userprofile.weight
        return int((self.exercise.met_value * 3.5 * weight) / 200 * self.duration_minutes)

class StepLog(models.Model): #  FR-09
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    date = models.DateField(auto_now_add=True)
    steps_count = models.IntegerField(default=0)
    distance_km = models.FloatField(default=0.0) # [cite: 164] FR-12

    class Meta:
        unique_together = ('user', 'date')

# --- 4. النوم (Sleep)  FR-31 ---
class SleepLog(models.Model):
    QUALITY_CHOICES = [('Deep', 'عميق'), ('Light', 'خفيف'), ('Interrupted', 'متقطع')]
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    quality = models.CharField(max_length=20, choices=QUALITY_CHOICES)
    date = models.DateField(auto_now_add=True)

    @property
    def duration_hours(self):
        diff = self.end_time - self.start_time
        return round(diff.total_seconds() / 3600, 2)

# --- 5. الأدوية (Medicine) [cite: 40] FR-38 ---
class Medicine(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    dosage = models.CharField(max_length=50)
    time_to_take = models.TimeField()
    is_active = models.BooleanField(default=True)

class MedicineLog(models.Model):
    medicine = models.ForeignKey(Medicine, on_delete=models.CASCADE)
    taken_at = models.DateTimeField(auto_now_add=True)
    status = models.BooleanField(default=True) # تم أخذ الدواء

# --- 6. العادات (Habits) [cite: 39] FR-39 ---
class Habit(models.Model):
    HABIT_TYPE = [('good', 'عادة جيدة'), ('bad', 'عادة سيئة')] # بناء/تخلص
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    habit_type = models.CharField(max_length=10, choices=HABIT_TYPE)

class HabitLog(models.Model):
    habit = models.ForeignKey(Habit, on_delete=models.CASCADE)
    date = models.DateField(auto_now_add=True)
    completed = models.BooleanField(default=True)