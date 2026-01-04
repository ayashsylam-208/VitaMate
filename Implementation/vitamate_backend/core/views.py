from rest_framework import viewsets, views
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Sum
from datetime import date

# استيراد النماذج (Models)
from .models import (
    MealLog, WaterLog, Medicine, StepLog, 
    ActivityLog, SleepLog, Habit, HabitLog
)

# استيراد السيريالايزر (Serializers)
from .serializers import (
    MealLogSerializer, WaterLogSerializer, MedicineSerializer, 
    StepLogSerializer, ActivityLogSerializer, SleepLogSerializer, 
    HabitSerializer, HabitLogSerializer
)

from users.models import UserProfile
from gamification.models import UserScore

# --- 1. التغذية والماء ---
class MealLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = MealLogSerializer
    def get_queryset(self): return MealLog.objects.filter(user=self.request.user, date=date.today())
    def perform_create(self, serializer): serializer.save(user=self.request.user)

class WaterLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = WaterLogSerializer
    def get_queryset(self): return WaterLog.objects.filter(user=self.request.user, date=date.today())
    def perform_create(self, serializer): 
        serializer.save(user=self.request.user)
        score, _ = UserScore.objects.get_or_create(user=self.request.user)
        score.add_points(5)

# --- 2. الأدوية ---
class MedicineViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = MedicineSerializer
    def get_queryset(self): return Medicine.objects.filter(user=self.request.user)

# --- 3. النشاط والحركة (التي كانت مفقودة) ---
class StepLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = StepLogSerializer
    def get_queryset(self): return StepLog.objects.filter(user=self.request.user)
    def perform_create(self, serializer): serializer.save(user=self.request.user)

class ActivityLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = ActivityLogSerializer
    def get_queryset(self): return ActivityLog.objects.filter(user=self.request.user)
    def perform_create(self, serializer): serializer.save(user=self.request.user)

# --- 4. النوم (التي كانت مفقودة) ---
class SleepLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = SleepLogSerializer
    def get_queryset(self): return SleepLog.objects.filter(user=self.request.user).order_by('-date')
    def perform_create(self, serializer): serializer.save(user=self.request.user)

# --- 5. العادات (التي كانت مفقودة) ---
class HabitViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = HabitSerializer
    def get_queryset(self): return Habit.objects.filter(user=self.request.user)
    def perform_create(self, serializer): serializer.save(user=self.request.user)

class HabitLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = HabitLogSerializer
    def get_queryset(self): return HabitLog.objects.filter(habit__user=self.request.user)

# --- 6. لوحة التحكم (Dashboard) ---
class DashboardView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        today = date.today()
        
        try:
            profile = UserProfile.objects.get(user=user)
        except UserProfile.DoesNotExist:
            return Response({"error": "Profile not found"}, status=404)

        # حساب السعرات المستهلكة
        meals = MealLog.objects.filter(user=user, date=today)
        calories_in = sum([m.total_calories for m in meals])

        # حساب السعرات المحروقة (تمارين + خطوات)
        exercises = ActivityLog.objects.filter(user=user, date=today)
        exercise_burn = sum([e.calories_burned for e in exercises])
        exercise_minutes = sum([e.duration_minutes for e in exercises])

        steps_log, _ = StepLog.objects.get_or_create(user=user, date=today)
        steps_burn = int(steps_log.steps_count * 0.04) # معادلة تقريبية
        
        total_burned = exercise_burn + steps_burn

        # الماء
        water_logs = WaterLog.objects.filter(user=user, date=today)
        water_current = water_logs.aggregate(Sum('amount_liter'))['amount_liter__sum'] or 0
        # 2. [FR-26] تعديل هدف الماء بناءً على النشاط
        # القاعدة الطبية: إضافة 350 مل لكل 30 دقيقة تمرين
        extra_water_liters = (exercise_minutes / 30) * 0.35
        adjusted_water_target = profile.daily_water_target + extra_water_liters

        # النقاط
        score, _ = UserScore.objects.get_or_create(user=user)

        return Response({
            "summary": {
                "calories_target": profile.daily_calorie_target,
                "calories_consumed": calories_in,
                "calories_remaining": profile.daily_calorie_target - calories_in + total_burned,
                "calories_burned": total_burned,
            },
            "hydration": {
                "target": profile.daily_water_target,
                "current": water_current,
                "adjusted_target": round(adjusted_water_target, 2), # الهدف الديناميكي الجديد
            },
            "sleep": { # [FR-32] عرض توصية النوم
                "target_bed_time": profile.target_bed_time,
                "target_wake_time": profile.target_wake_time
            },
            "activity": {
                "steps": steps_log.steps_count,
                "steps_target": profile.daily_step_goal,
                "distance_km": steps_log.distance_km
            },
            "gamification": {
                "points": score.total_points,
                "level": score.level
            }
        })