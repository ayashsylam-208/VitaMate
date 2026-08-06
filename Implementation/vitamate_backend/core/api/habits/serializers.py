from rest_framework import serializers

from core.models import UnhealthyHabit


class UnhealthyHabitCreateSerializer(serializers.Serializer):
    habit_type = serializers.ChoiceField(choices=UnhealthyHabit.HABIT_TYPE_CHOICES)
    goal_type = serializers.ChoiceField(
        choices=UnhealthyHabit.GOAL_CHOICES,
        required=False,
        default=UnhealthyHabit.GOAL_REDUCE,
    )
    title = serializers.CharField(required=False, allow_blank=True, default="")
    start_date = serializers.DateField(required=False)
    target_date = serializers.DateField(required=False, allow_null=True)
    idempotency_key = serializers.CharField(required=False, allow_blank=True, default="")


class UnhealthyHabitBaselineSerializer(serializers.Serializer):
    initial_frequency = serializers.FloatField(required=False, min_value=0, default=0)
    initial_quantity = serializers.FloatField(required=False, min_value=0, default=0)
    unit = serializers.CharField(required=False, allow_blank=True, default="")
    common_trigger = serializers.CharField(required=False, allow_blank=True, default="")
    common_time = serializers.TimeField(required=False, allow_null=True)
    notes = serializers.CharField(required=False, allow_blank=True, default="")
    extra = serializers.DictField(required=False, default=dict)


class UnhealthyHabitPlanSerializer(serializers.Serializer):
    goal_type = serializers.ChoiceField(
        choices=UnhealthyHabit.GOAL_CHOICES,
        required=False,
    )
    daily_limit = serializers.FloatField(required=False, allow_null=True, min_value=0)
    weekly_limit = serializers.FloatField(required=False, allow_null=True, min_value=0)
    target_quantity = serializers.FloatField(required=False, allow_null=True, min_value=0)
    reduction_percentage = serializers.FloatField(required=False, min_value=0, max_value=100)
    cutoff_time = serializers.TimeField(required=False, allow_null=True)
    plan_stage = serializers.CharField(required=False, allow_blank=True, default="")
    healthy_replacement_required = serializers.BooleanField(required=False)
    reminder_time = serializers.TimeField(required=False, allow_null=True)
    target_date = serializers.DateField(required=False, allow_null=True)
    notes = serializers.CharField(required=False, allow_blank=True, default="")


class UnhealthyHabitLogSerializer(serializers.Serializer):
    logged_at = serializers.DateTimeField(required=False)
    quantity = serializers.FloatField(required=False, min_value=0, default=1)
    unit = serializers.CharField(required=False, allow_blank=True, default="")
    trigger = serializers.CharField(required=False, allow_blank=True, default="")
    mood = serializers.CharField(required=False, allow_blank=True, default="")
    notes = serializers.CharField(required=False, allow_blank=True, default="")
    is_relapse = serializers.BooleanField(required=False, default=False)
    sync_to_tracker = serializers.BooleanField(required=False, default=False)
    caffeine_mg = serializers.FloatField(required=False, min_value=0, default=0)
    calories_kcal = serializers.FloatField(required=False, min_value=0, default=0)
    food_name = serializers.CharField(required=False, allow_blank=True, default="")
    food_id = serializers.IntegerField(required=False, allow_null=True, min_value=1)
    tracker_quantity = serializers.FloatField(required=False, min_value=0)
    tracker_unit = serializers.CharField(required=False, allow_blank=True, default="")
    healthy_replacement = serializers.BooleanField(required=False, default=False)
    meal_type = serializers.ChoiceField(
        choices=["breakfast", "lunch", "dinner", "snack", "drink", "unknown"],
        required=False,
        default="unknown",
    )
    idempotency_key = serializers.CharField(required=False, allow_blank=True, default="")


class UnhealthyHabitReminderSerializer(serializers.Serializer):
    time_of_day = serializers.TimeField()
    message = serializers.CharField(required=False, allow_blank=True, default="")
    is_active = serializers.BooleanField(required=False, default=True)


class UnhealthyHabitRemindersSerializer(serializers.Serializer):
    reminders = UnhealthyHabitReminderSerializer(many=True, required=False, default=list)


class UnhealthyHabitAtomicSetupSerializer(serializers.Serializer):
    habit = UnhealthyHabitCreateSerializer()
    baseline = UnhealthyHabitBaselineSerializer()
    plan = UnhealthyHabitPlanSerializer(required=False, default=dict)
    reminders = UnhealthyHabitReminderSerializer(many=True, required=False, default=list)
    idempotency_key = serializers.CharField(required=False, allow_blank=True, default="")


class UnhealthyHabitDailyCheckInSerializer(serializers.Serializer):
    date = serializers.DateField(required=False)
    used = serializers.BooleanField()
    idempotency_key = serializers.CharField(required=False, allow_blank=True, default="")
