from django.db import models
from django.contrib.auth.models import User

class UserScore(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    total_points = models.IntegerField(default=0)
    level = models.IntegerField(default=1)

    def add_points(self, points):
        self.total_points += points
        # كل 1000 نقطة مستوى جديد  
        new_level = (self.total_points // 1000) + 1
        if new_level > self.level:
            self.level = new_level
        self.save()
            #خصم نقاط في حال عددم تحقيق الهدف

    def deduct_points(self, points):
        
        self.total_points -= points
        if self.total_points < 0:
            self.total_points = 0
        self.save()