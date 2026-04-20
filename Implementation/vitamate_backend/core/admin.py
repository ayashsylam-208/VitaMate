from django.contrib import admin
from .models import (
    FoodCategory, FoodItem, FoodItemAlias,
    MealLog, NutritionFacts, NutritionServingOption, WaterLog,
    Nutrient, ItemNutrientValue,
    Exercise, ActivityLog, StepLog, 
    SleepLog, Medicine, MedicineLog, 
    Habit, HabitLog,
    ConditionType, UserCondition, ConditionRuleProfile, HealthRestriction,
    ConditionNutrientRule, UserNutrientTarget,
    HealthTarget, HealthIndicatorRecord, ConditionAlert, ConditionDailyEvaluation,
    ConditionMedication, ConditionMedicationSchedule, ConditionMedicationLog,
    ConditionPointsAudit,
)

# --- Nutrition ---
@admin.register(FoodCategory)
class FoodCategoryAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'parent', 'sort_order', 'is_active')
    list_filter = ('is_active', 'parent')
    search_fields = ('code', 'name')


class FoodItemAliasInline(admin.TabularInline):
    model = FoodItemAlias
    extra = 0
    fields = ('alias', 'alias_type', 'is_primary', 'sort_order', 'normalized_alias')
    readonly_fields = ('normalized_alias',)


@admin.register(FoodItem)
class FoodItemAdmin(admin.ModelAdmin):
    inlines = (FoodItemAliasInline,)
    list_display = (
        'name', 'item_type', 'primary_category', 'category', 'source', 'calories_100g',
        'protein_100g', 'contains_caffeine', 'is_hydration_trackable',
        'is_verified', 'is_active', 'search_priority',
    )
    list_filter = (
        'item_type', 'primary_category', 'source', 'category',
        'is_hydration_trackable', 'contains_caffeine', 'is_verified', 'is_active',
    )
    search_fields = (
        'name', 'normalized_name', 'brand_name', 'normalized_brand_name',
        'barcode', 'source_reference', 'alias_records__alias',
    )
    readonly_fields = ('normalized_name', 'normalized_brand_name')


@admin.register(FoodItemAlias)
class FoodItemAliasAdmin(admin.ModelAdmin):
    list_display = ('food_item', 'alias', 'alias_type', 'is_primary', 'sort_order')
    list_filter = ('alias_type', 'is_primary')
    search_fields = ('alias', 'normalized_alias', 'food_item__name')
    readonly_fields = ('normalized_alias',)

@admin.register(NutritionFacts)
class NutritionFactsAdmin(admin.ModelAdmin):
    list_display = ('food_item', 'basis_type', 'basis_amount', 'basis_unit', 'calories_kcal', 'protein_g', 'carbohydrates_g', 'fat_g', 'caffeine_mg')
    search_fields = ('food_item__name', 'source_name', 'source_reference')

@admin.register(Nutrient)
class NutrientAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'unit', 'category', 'is_core')
    list_filter = ('category', 'is_core')
    search_fields = ('code', 'name')

@admin.register(ItemNutrientValue)
class ItemNutrientValueAdmin(admin.ModelAdmin):
    list_display = ('item', 'nutrient', 'amount', 'basis_amount', 'basis_unit')
    list_filter = ('nutrient__category', 'basis_unit')
    search_fields = ('item__name', 'nutrient__code', 'nutrient__name')

@admin.register(NutritionServingOption)
class NutritionServingOptionAdmin(admin.ModelAdmin):
    list_display = ('food_item', 'name', 'amount', 'unit', 'grams_equivalent', 'milliliters_equivalent', 'is_default')
    list_filter = ('unit', 'is_default')
    search_fields = ('food_item__name', 'name')

@admin.register(MealLog)
class MealLogAdmin(admin.ModelAdmin):
    list_display = ('user', 'food', 'meal_type', 'quantity_grams', 'unit', 'total_calories', 'source', 'date')
    list_filter = ('date', 'meal_type')

# --- Hydration ---
@admin.register(WaterLog)
class WaterLogAdmin(admin.ModelAdmin):
    list_display = ('user', 'beverage_name', 'beverage_type', 'drink_item', 'amount_liter', 'date')
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


@admin.register(ConditionType)
class ConditionTypeAdmin(admin.ModelAdmin):
    list_display = ('code', 'slug', 'display_name', 'is_supported', 'sort_order')
    list_filter = ('is_supported',)
    search_fields = ('code', 'slug', 'display_name', 'name')


@admin.register(UserCondition)
class UserConditionAdmin(admin.ModelAdmin):
    list_display = ('user', 'condition_type', 'severity_code', 'status', 'is_active', 'diagnosis_date')
    list_filter = ('status', 'is_active', 'condition_type')
    search_fields = ('user__username', 'condition_type__code', 'condition_type__display_name')


@admin.register(ConditionRuleProfile)
class ConditionRuleProfileAdmin(admin.ModelAdmin):
    list_display = ('condition_type', 'severity_code', 'rule_key', 'rule_value', 'is_default')
    list_filter = ('condition_type', 'is_default')
    search_fields = ('condition_type__code', 'rule_key', 'rule_value')


@admin.register(HealthRestriction)
class HealthRestrictionAdmin(admin.ModelAdmin):
    list_display = ('condition_type', 'restriction_key', 'category', 'severity_code', 'is_default', 'is_inference')
    list_filter = ('condition_type', 'category', 'is_default', 'is_inference')
    search_fields = ('condition_type__code', 'restriction_key', 'title')


@admin.register(ConditionNutrientRule)
class ConditionNutrientRuleAdmin(admin.ModelAdmin):
    list_display = ('condition_type', 'nutrient', 'rule_type', 'threshold_value', 'threshold_unit', 'severity')
    list_filter = ('condition_type', 'rule_type', 'severity', 'nutrient__category')
    search_fields = ('condition_type__code', 'nutrient__code', 'nutrient__name', 'note')


@admin.register(UserNutrientTarget)
class UserNutrientTargetAdmin(admin.ModelAdmin):
    list_display = ('user', 'nutrient', 'period', 'source', 'min_value', 'target_value', 'max_value')
    list_filter = ('period', 'source', 'nutrient__category')
    search_fields = ('user__username', 'nutrient__code', 'nutrient__name')


@admin.register(HealthTarget)
class HealthTargetAdmin(admin.ModelAdmin):
    list_display = ('user_condition', 'target_key', 'source_type', 'status', 'priority')
    list_filter = ('source_type', 'status', 'category')
    search_fields = ('user_condition__user__username', 'target_key', 'target_name')


@admin.register(HealthIndicatorRecord)
class HealthIndicatorRecordAdmin(admin.ModelAdmin):
    list_display = ('user_condition', 'indicator_type', 'classification', 'risk_level', 'recorded_at')
    list_filter = ('indicator_type', 'classification', 'risk_level')
    search_fields = ('user_condition__user__username', 'indicator_name', 'indicator_type')


@admin.register(ConditionAlert)
class ConditionAlertAdmin(admin.ModelAdmin):
    list_display = ('user_condition', 'code', 'level', 'alert_type', 'status', 'created_at')
    list_filter = ('alert_type', 'status', 'level')
    search_fields = ('user_condition__user__username', 'code', 'message')


@admin.register(ConditionDailyEvaluation)
class ConditionDailyEvaluationAdmin(admin.ModelAdmin):
    list_display = ('user_condition', 'evaluation_date', 'status', 'medication_adherence_percent', 'restriction_adherence_percent', 'points_delta')
    list_filter = ('status', 'evaluation_date')
    search_fields = ('user_condition__user__username',)


@admin.register(ConditionMedication)
class ConditionMedicationAdmin(admin.ModelAdmin):
    list_display = ('user', 'user_condition', 'display_name', 'source_type', 'dosage', 'is_active')
    list_filter = ('source_type', 'relation_to_meal', 'is_active')
    search_fields = ('user__username', 'user_condition__user__username', 'name', 'display_name')


@admin.register(ConditionMedicationSchedule)
class ConditionMedicationScheduleAdmin(admin.ModelAdmin):
    list_display = ('medication', 'schedule_type', 'time_of_day', 'is_active')


@admin.register(ConditionMedicationLog)
class ConditionMedicationLogAdmin(admin.ModelAdmin):
    list_display = ('medication', 'schedule', 'scheduled_date', 'status', 'taken_at', 'points_applied')
    list_filter = ('status', 'scheduled_date')


@admin.register(ConditionPointsAudit)
class ConditionPointsAuditAdmin(admin.ModelAdmin):
    list_display = ('user', 'user_condition', 'event_type', 'points_delta', 'created_at')
    list_filter = ('event_type',)
    search_fields = ('user__username', 'reason')
