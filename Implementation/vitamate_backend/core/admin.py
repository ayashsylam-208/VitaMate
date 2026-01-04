from django.contrib import admin
from .models import (
    FoodItem, MealLog, WaterLog, 
    Exercise, ActivityLog, StepLog, 
    SleepLog, Medicine, MedicineLog, 
    Habit, HabitLog
)

# --- Nutrition ---
@admin.register(FoodItem)
class FoodItemAdmin(admin.ModelAdmin):
    list_display = ('name', 'calories', 'protein', 'carbs', 'fat')
    search_fields = ('name',)

@admin.register(MealLog)
class MealLogAdmin(admin.ModelAdmin):
    list_display = ('user', 'food', 'meal_type', 'quantity', 'total_calories', 'date')
    list_filter = ('date', 'meal_type')

# --- Hydration ---
@admin.register(WaterLog)
class WaterLogAdmin(admin.ModelAdmin):
    list_display = ('user', 'amount_liter', 'date')
    list_filter = ('date',)

# --- Fitness ---
@admin.register(Exercise)
class ExerciseAdmin(admin.ModelAdmin):
    list_display = ('name', 'met_value')

@admin.register(ActivityLog)
class ActivityLogAdmin(admin.ModelAdmin):
    list_display = ('user', 'exercise', 'duration_minutes', 'calories_burned', 'date')

@admin.register(StepLog)
class StepLogAdmin(admin.ModelAdmin):
    list_display = ('user', 'steps_count', 'distance_km', 'date')

# --- Sleep ---
@admin.register(SleepLog)
class SleepLogAdmin(admin.ModelAdmin):
    list_display = ('user', 'start_time', 'end_time', 'quality', 'date')

# --- Medicine ---
@admin.register(Medicine)
class MedicineAdmin(admin.ModelAdmin):
    list_display = ('name', 'user', 'dosage', 'is_active')

@admin.register(MedicineLog)
class MedicineLogAdmin(admin.ModelAdmin):
    list_display = ('medicine', 'taken_at', 'status')

# --- Habits ---
@admin.register(Habit)
class HabitAdmin(admin.ModelAdmin):
    list_display = ('name', 'user', 'habit_type')

@admin.register(HabitLog)
class HabitLogAdmin(admin.ModelAdmin):
    list_display = ('habit', 'date', 'completed')