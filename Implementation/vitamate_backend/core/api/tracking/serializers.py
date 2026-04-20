from rest_framework import serializers

from core.models import ActivityLog, Exercise, SleepLog, StepLog


class StepLogSerializer(serializers.ModelSerializer):
    calories_burned = serializers.ReadOnlyField()
    burn_rate_kcal_per_km = serializers.ReadOnlyField()

    class Meta:
        model = StepLog
        fields = "__all__"
        read_only_fields = ("user", "date", "calories_burned", "burn_rate_kcal_per_km")


class ActivityLogSerializer(serializers.ModelSerializer):
    calories_burned = serializers.ReadOnlyField()
    exercise_name = serializers.CharField(source="exercise.name", read_only=True)

    class Meta:
        model = ActivityLog
        fields = ["id", "user", "exercise", "exercise_name", "duration_minutes", "date", "calories_burned"]
        read_only_fields = ["user", "date", "calories_burned"]


class ExerciseSerializer(serializers.ModelSerializer):
    class Meta:
        model = Exercise
        fields = ["id", "name", "met_value"]


class SleepLogSerializer(serializers.ModelSerializer):
    duration_hours = serializers.ReadOnlyField()
    points_earned = serializers.SerializerMethodField()

    def get_points_earned(self, obj):
        profile = getattr(obj.user, "userprofile", None)
        if not profile or not profile.recommended_sleep_hours:
            return 0
        goal = profile.recommended_sleep_hours
        return 10 if obj.duration_hours >= 0.9 * goal else 0

    class Meta:
        model = SleepLog
        fields = ["id", "user", "start_time", "end_time", "quality", "date", "duration_hours", "points_earned"]
        read_only_fields = ["user", "date", "duration_hours", "points_earned"]
