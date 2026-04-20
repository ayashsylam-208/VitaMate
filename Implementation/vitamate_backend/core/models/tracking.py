from django.contrib.auth.models import User
from django.db import models


class Exercise(models.Model):
    name = models.CharField(max_length=100)
    met_value = models.FloatField(help_text="MET value")

    def __str__(self):
        return self.name


class ActivityLog(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    exercise = models.ForeignKey(Exercise, on_delete=models.CASCADE)
    duration_minutes = models.IntegerField()
    date = models.DateField(auto_now_add=True)
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


class StepLog(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    date = models.DateField(auto_now_add=True)
    steps_count = models.IntegerField(default=0)
    distance_km = models.FloatField(default=0.0)

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
    date = models.DateField(auto_now_add=True)

    @property
    def duration_hours(self):
        diff = self.end_time - self.start_time
        return round(diff.total_seconds() / 3600, 2)
