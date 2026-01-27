from rest_framework import viewsets, views
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Sum
from datetime import date, timedelta

# استيراد النماذج (Models)
from .models import (
    MealLog, WaterLog, Medicine, StepLog,
    ActivityLog, SleepLog, Habit, HabitLog, FoodItem, Exercise
)

# استيراد السيريالايزر (Serializers)
from .serializers import (
    MealLogSerializer, WaterLogSerializer, MedicineSerializer,
    StepLogSerializer, ActivityLogSerializer, SleepLogSerializer,
    HabitSerializer, HabitLogSerializer, FoodItemSerializer, ExerciseSerializer
)

from users.models import UserProfile
from gamification.repositories.user_score_repository import UserScoreRepository
from core.services.water_service import WaterService
from core.services.sleep_service import SleepService
from core.services.nutrition_service import NutritionService
from core.services.steps_service import StepsService
from core.services.activity_service import ActivityService

# --- 1. التغذية والماء ---
class MealLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = MealLogSerializer
    def get_queryset(self): return MealLog.objects.filter(user=self.request.user, date=date.today())
    def perform_create(self, serializer):
        log = NutritionService.log_meal(
            user=self.request.user,
            food=serializer.validated_data["food"],
            meal_type=serializer.validated_data["meal_type"],
            quantity_grams=serializer.validated_data.get("quantity_grams", 100.0),
        )
        serializer.instance = log

class FoodItemViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = FoodItemSerializer
    queryset = FoodItem.objects.all().order_by('name')
    http_method_names = ['get', 'post', 'head', 'options']
    def perform_create(self, serializer):
        item = NutritionService.create_food_item(serializer.validated_data)
        serializer.instance = item

class WaterLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = WaterLogSerializer
    def get_queryset(self): return WaterLog.objects.filter(user=self.request.user, date=date.today())
    def perform_create(self, serializer): 
        log = WaterService.log_water(
            user=self.request.user,
            amount_liter=serializer.validated_data["amount_liter"],
        )
        serializer.instance = log

# --- 2. الأدوية ---
class MedicineViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = MedicineSerializer
    def get_queryset(self): return Medicine.objects.filter(user=self.request.user)

# --- 3. النشاط والحركة ) ---
class StepLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = StepLogSerializer
    def get_queryset(self): return StepLog.objects.filter(user=self.request.user)
    def perform_create(self, serializer):
        log = StepsService.log_steps(
            user=self.request.user,
            steps_count=serializer.validated_data.get('steps_count', 0),
            distance_km=serializer.validated_data.get('distance_km', 0),
        )
        serializer.instance = log

class ActivityLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = ActivityLogSerializer
    def get_queryset(self): return ActivityLog.objects.filter(user=self.request.user)
    def perform_create(self, serializer):
        log = ActivityService.log_activity(
            user=self.request.user,
            exercise=serializer.validated_data["exercise"],
            duration_minutes=serializer.validated_data["duration_minutes"],
        )
        serializer.instance = log

class ExerciseViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = ExerciseSerializer
    queryset = Exercise.objects.all().order_by('name')

# --- 4. النوم ) ---
class SleepLogViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = SleepLogSerializer
    def get_queryset(self): return SleepLog.objects.filter(user=self.request.user).order_by('-date')
    def perform_create(self, serializer):
        log = SleepService.log_sleep(
            user=self.request.user,
            start_time=serializer.validated_data["start_time"],
            end_time=serializer.validated_data["end_time"],
            quality=serializer.validated_data["quality"],
        )
        serializer.instance = log

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
        steps_burn = int(steps_log.steps_count * 0.04)
        steps_burn_rate = 0
        if steps_log.distance_km:
            steps_burn_rate = round(steps_burn / steps_log.distance_km, 1)
        
        total_burned = exercise_burn + steps_burn

        # النوم: ساعات اليوم وتقدم الهدف
        sleep_logs = SleepLog.objects.filter(user=user, date=today)
        sleep_hours_today = sum([s.duration_hours for s in sleep_logs])
        sleep_goal_hours = profile.recommended_sleep_hours
        sleep_progress_pct = 0
        if sleep_goal_hours:
            sleep_progress_pct = min(100, int((sleep_hours_today / sleep_goal_hours) * 100))

        # الماء
        water_logs = WaterLog.objects.filter(user=user, date=today)
        water_current = water_logs.aggregate(Sum('amount_liter'))['amount_liter__sum'] or 0
        # 2. [FR-26] تعديل هدف الماء بناءً على النشاط
        # القاعدة الطبية: إضافة 350 مل لكل 30 دقيقة تمرين
        extra_water_liters = (exercise_minutes / 30) * 0.35
        adjusted_water_target = profile.daily_water_target + extra_water_liters

        # Points
        score, _ = UserScoreRepository.get_or_create_for_user(user)

        return Response({
            "summary": {
                "calories_target": profile.daily_calorie_target,
                "calories_consumed": calories_in,
                "calories_remaining": profile.daily_calorie_target - calories_in + total_burned,
                "calories_burned": total_burned,
                "burn_target": profile.daily_burn_goal,
            },
            "hydration": {
                "target": profile.daily_water_target,
                "current": water_current,
                "adjusted_target": round(adjusted_water_target, 2), # الهدف الديناميكي الجديد
            },
            "sleep": { # [FR-32] عرض توصية النوم
                "target_bed_time": profile.target_bed_time,
                "target_wake_time": profile.target_wake_time,
                "recommended_sleep_hours": profile.recommended_sleep_hours,
                "logged_hours_today": round(sleep_hours_today, 2),
                "progress_percent": sleep_progress_pct
            },
            "activity": {
                "steps": steps_log.steps_count,
                "steps_target": profile.daily_step_goal,
                "distance_km": steps_log.distance_km,
                "steps_burned": steps_burn,
                "steps_burn_rate": steps_burn_rate
            },
            "gamification": {
                "points": score.total_points,
                "level": score.level
            }
        })


# --- History (last 7 days) ---
class StatsHistoryView(views.APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        today = date.today()
        start = today - timedelta(days=6)

        try:
            profile = UserProfile.objects.get(user=user)
        except UserProfile.DoesNotExist:
            return Response({"error": "Profile not found"}, status=404)

        results = []
        for i in range(7):
            day = start + timedelta(days=i)

            water_sum = (
                WaterLog.objects.filter(user=user, date=day)
                .aggregate(Sum('amount_liter'))['amount_liter__sum'] or 0
            )

            steps_log = StepLog.objects.filter(user=user, date=day).first()
            steps = steps_log.steps_count if steps_log else 0
            distance_km = steps_log.distance_km if steps_log else 0

            meals = MealLog.objects.filter(user=user, date=day)
            calories_in = sum(m.total_calories for m in meals)

            activities = ActivityLog.objects.filter(user=user, date=day)
            calories_burned_activity = sum(a.calories_burned for a in activities)
            exercise_minutes = sum(a.duration_minutes for a in activities)
            steps_burn = int(steps * 0.04)
            steps_burn_rate = 0
            if distance_km:
                steps_burn_rate = round(steps_burn / distance_km, 1)
            calories_burned = calories_burned_activity + steps_burn

            sleep_logs = SleepLog.objects.filter(user=user, date=day)
            sleep_hours = sum([s.duration_hours for s in sleep_logs])

            sleep_target = profile.recommended_sleep_hours or 0
            water_target = profile.daily_water_target or 0
            steps_target = profile.daily_step_goal or 0
            calories_target = profile.daily_calorie_target or 0
            burn_target = profile.daily_burn_goal or 0

            day_points = 0
            if water_sum > 0:
                day_points += 5
            if steps > 0:
                day_points += max(1, (steps // 1000) * 5)
            if activities.exists():
                day_points += 5
            if calories_in > 0:
                if calories_target and calories_in > calories_target:
                    day_points -= 5
                else:
                    day_points += 5
            if sleep_target and sleep_hours >= 0.9 * sleep_target:
                day_points += 10

            results.append({
                "date": str(day),
                "water_current": round(water_sum, 3),
                "water_target": water_target,
                "steps": steps,
                "steps_target": steps_target,
                "distance_km": distance_km,
                "steps_burned": steps_burn,
                "steps_burn_rate": steps_burn_rate,
                "calories_in": calories_in,
                "calories_target": calories_target,
                "calories_burned": calories_burned,
                "sleep_hours": sleep_hours,
                "sleep_target": sleep_target,
                "exercise_minutes": exercise_minutes,
                "points_estimate": day_points,
                "burn_target": burn_target,
                "burn_current": calories_burned,
            })

        return Response({"history": results})
