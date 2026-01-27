from rest_framework import serializers
from .models import *
from users.models import UserProfile
from core.models import WaterLog

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        # من الأفضل تحديد الحقول بشكل صريح بدلاً من استخدام '__all__'
        # للحماية من الكشف غير المقصود عن البيانات ولزيادة وضوح الكود
        # بناءً على المتطلبات، هذه هي الحقول المتوقعة
        fields = ['id', 'user', 'height', 'weight', 'age', 'gender', 'activity_level', 'dietary_goal']
        read_only_fields = ['user']

class FoodItemSerializer(serializers.ModelSerializer):
    class Meta: model = FoodItem; fields = '__all__'

class MealLogSerializer(serializers.ModelSerializer):
    total_calories = serializers.ReadOnlyField()
    food_name = serializers.CharField(source='food.name', read_only=True)
    class Meta: 
        model = MealLog; 
        fields = ['id', 'user', 'food', 'food_name', 'meal_type', 'quantity_grams', 'date', 'total_calories']
        read_only_fields = ['user', 'date', 'total_calories']



class WaterLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = WaterLog
        fields = '__all__'
        read_only_fields = ('user', 'date')

class StepLogSerializer(serializers.ModelSerializer):
    calories_burned = serializers.ReadOnlyField()
    burn_rate_kcal_per_km = serializers.ReadOnlyField()

    class Meta:
        model = StepLog
        fields = '__all__'
        read_only_fields = ('user', 'date', 'calories_burned', 'burn_rate_kcal_per_km')

class MedicineSerializer(serializers.ModelSerializer):
    class Meta: model = Medicine; fields = '__all__'

class HabitSerializer(serializers.ModelSerializer):
    class Meta: model = Habit; fields = '__all__'

class ActivityLogSerializer(serializers.ModelSerializer):
    # حقل للقراءة فقط لجلب السعرات المحروقة المحسوبة تلقائياً في الموديل
    calories_burned = serializers.ReadOnlyField()
    # لجلب اسم التمرين بدلاً من رقمه فقط (اختياري لتحسين العرض)
    exercise_name = serializers.CharField(source='exercise.name', read_only=True)

    class Meta:
        model = ActivityLog
        fields = ['id', 'user', 'exercise', 'exercise_name', 'duration_minutes', 'date', 'calories_burned']
        read_only_fields = ['user', 'date', 'calories_burned']

class ExerciseSerializer(serializers.ModelSerializer):
    class Meta:
        model = Exercise
        fields = ['id', 'name', 'met_value']

class SleepLogSerializer(serializers.ModelSerializer):
    # حقل للقراءة فقط لجلب مدة النوم بالساعات
    duration_hours = serializers.ReadOnlyField()
    points_earned = serializers.SerializerMethodField()

    def get_points_earned(self, obj):
        profile = getattr(obj.user, 'userprofile', None)
        if not profile or not profile.recommended_sleep_hours:
            return 0
        goal = profile.recommended_sleep_hours
        return 10 if obj.duration_hours >= 0.9 * goal else 0

    class Meta:
        model = SleepLog
        fields = ['id', 'user', 'start_time', 'end_time', 'quality', 'date', 'duration_hours', 'points_earned']
        read_only_fields = ['user', 'date', 'duration_hours', 'points_earned']

class HabitLogSerializer(serializers.ModelSerializer):
    # لجلب اسم العادة وتفاصيلها
    habit_name = serializers.CharField(source='habit.name', read_only=True)
    
    class Meta:
        model = HabitLog
        fields = ['id', 'habit', 'habit_name', 'date', 'completed']
        read_only_fields = ['date']

class DailyReportSerializer(serializers.Serializer):
    """
    Serializer مخصص لإنشاء تقرير يومي. هذا السيريالايزر للقراءة فقط
    ويقوم بتجميع البيانات من مختلف السجلات لتقديم ملخص شامل.
    (FR-36)
    """
    date = serializers.DateField(read_only=True)
    total_calories_consumed = serializers.IntegerField(read_only=True)
    total_calories_burned = serializers.IntegerField(read_only=True)
    total_water_intake = serializers.IntegerField(read_only=True)
    total_steps = serializers.IntegerField(read_only=True)
    sleep_duration_hours = serializers.FloatField(read_only=True)
    points_earned = serializers.IntegerField(read_only=True)

    class Meta:
        read_only = True
