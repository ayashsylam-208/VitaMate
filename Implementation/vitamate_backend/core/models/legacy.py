from django.contrib.auth.models import User
from django.db import models


class Medicine(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    dosage = models.CharField(max_length=50)
    time_to_take = models.TimeField()
    is_active = models.BooleanField(default=True)


class MedicineLog(models.Model):
    medicine = models.ForeignKey(Medicine, on_delete=models.CASCADE)
    taken_at = models.DateTimeField(auto_now_add=True)
    status = models.BooleanField(default=True)


class Habit(models.Model):
    HABIT_TYPE = [("good", "Good"), ("bad", "Bad")]
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    habit_type = models.CharField(max_length=10, choices=HABIT_TYPE)


class HabitLog(models.Model):
    habit = models.ForeignKey(Habit, on_delete=models.CASCADE)
    date = models.DateField(auto_now_add=True)
    completed = models.BooleanField(default=True)
