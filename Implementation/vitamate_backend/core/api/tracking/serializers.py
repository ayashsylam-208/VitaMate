from rest_framework import serializers

from core.models import ActivityLog, ActivitySession, Exercise, SleepLog, StepLog


class StepLogSerializer(serializers.ModelSerializer):
    calories_burned = serializers.ReadOnlyField()
    burn_rate_kcal_per_km = serializers.ReadOnlyField()
    local_date = serializers.DateField(write_only=True, required=False)

    def validate_steps_count(self, value):
        if value < 0:
            raise serializers.ValidationError("steps_count must be greater than or equal to 0.")
        return value

    def validate_distance_km(self, value):
        if value < 0:
            raise serializers.ValidationError("distance_km must be greater than or equal to 0.")
        return value

    class Meta:
        model = StepLog
        fields = "__all__"
        read_only_fields = ("user", "date", "calories_burned", "burn_rate_kcal_per_km")


class ActivityLogSerializer(serializers.ModelSerializer):
    calories_burned = serializers.ReadOnlyField()
    exercise_name = serializers.CharField(source="exercise.name", read_only=True)

    class Meta:
        model = ActivityLog
        fields = [
            "id",
            "user",
            "exercise",
            "exercise_name",
            "source_session",
            "duration_minutes",
            "date",
            "calories_burned",
        ]
        read_only_fields = ["user", "source_session", "date", "calories_burned"]


class ExerciseSerializer(serializers.ModelSerializer):
    class Meta:
        model = Exercise
        fields = [
            "id",
            "name",
            "met_value",
            "icon_key",
            "default_duration_minutes",
            "met_light",
            "met_moderate",
            "met_intense",
            "is_featured",
            "sort_order",
        ]


class ActivitySessionSerializer(serializers.ModelSerializer):
    exercise_name = serializers.CharField(source="exercise.name", read_only=True)
    exercise_icon_key = serializers.CharField(source="exercise.icon_key", read_only=True)
    final_activity_log_id = serializers.SerializerMethodField()
    actual_duration_seconds = serializers.SerializerMethodField()
    remaining_duration_seconds = serializers.SerializerMethodField()
    progress_percent = serializers.SerializerMethodField()
    calories_burned = serializers.SerializerMethodField()

    def get_actual_duration_seconds(self, obj):
        return obj.effective_elapsed_seconds()

    def get_remaining_duration_seconds(self, obj):
        return max(obj.target_duration_seconds - obj.effective_elapsed_seconds(), 0)

    def get_progress_percent(self, obj):
        if obj.target_duration_seconds <= 0:
            return 0
        return round(min(obj.effective_elapsed_seconds() / obj.target_duration_seconds, 1.0) * 100)

    def get_calories_burned(self, obj):
        return obj.effective_calories_burned()

    def get_final_activity_log_id(self, obj):
        try:
            return obj.final_activity_log.id
        except Exception:
            return None

    class Meta:
        model = ActivitySession
        fields = [
            "id",
            "exercise",
            "exercise_name",
            "exercise_icon_key",
            "status",
            "source",
            "intensity",
            "target_duration_seconds",
            "actual_duration_seconds",
            "remaining_duration_seconds",
            "progress_percent",
            "met_value_snapshot",
            "estimated_calories",
            "calories_burned",
            "final_activity_log_id",
            "started_at",
            "paused_at",
            "ended_at",
            "total_paused_seconds",
        ]
        read_only_fields = fields


class ActivitySessionCreateSerializer(serializers.Serializer):
    exercise = serializers.PrimaryKeyRelatedField(queryset=Exercise.objects.all())
    target_duration_seconds = serializers.IntegerField(min_value=60)
    intensity = serializers.ChoiceField(
        choices=[
            ActivitySession.INTENSITY_LIGHT,
            ActivitySession.INTENSITY_MODERATE,
            ActivitySession.INTENSITY_INTENSE,
        ],
        default=ActivitySession.INTENSITY_MODERATE,
    )
    source = serializers.ChoiceField(
        choices=[ActivitySession.SOURCE_LIVE, ActivitySession.SOURCE_GUIDED],
        default=ActivitySession.SOURCE_LIVE,
    )


class ActivitySessionEditSerializer(serializers.Serializer):
    exercise = serializers.PrimaryKeyRelatedField(
        queryset=Exercise.objects.all(),
        required=False,
    )
    target_duration_seconds = serializers.IntegerField(min_value=60, required=False)
    intensity = serializers.ChoiceField(
        choices=[
            ActivitySession.INTENSITY_LIGHT,
            ActivitySession.INTENSITY_MODERATE,
            ActivitySession.INTENSITY_INTENSE,
        ],
        required=False,
    )


class ActivitySessionFinishSerializer(serializers.Serializer):
    save_partial = serializers.BooleanField(default=False)


class SleepLogSerializer(serializers.ModelSerializer):
    duration_hours = serializers.ReadOnlyField()
    points_earned = serializers.SerializerMethodField()

    def get_points_earned(self, obj):
        profile = getattr(obj.user, "userprofile", None)
        if not profile or not profile.recommended_sleep_hours:
            return 0
        from core.services.constraints import EffectiveConstraintReader

        goal = EffectiveConstraintReader.get_effective_constraint(
            user=obj.user,
            tracker_type="sleep",
            constraint_key="sleep_hours",
            default_value=profile.recommended_sleep_hours,
            default_unit="hours",
            default_source="profile_fallback",
        ).value
        return 10 if obj.duration_hours >= 0.9 * goal else 0

    class Meta:
        model = SleepLog
        fields = ["id", "user", "start_time", "end_time", "quality", "date", "duration_hours", "points_earned"]
        read_only_fields = ["user", "date", "duration_hours", "points_earned"]


class SleepCoachPlanCreateSerializer(serializers.Serializer):
    planned_bed_time = serializers.DateTimeField()
    latest_wake_time = serializers.DateTimeField()
    flexibility_minutes = serializers.IntegerField(min_value=0, max_value=240, default=0)
    questionnaire = serializers.DictField(required=False, default=dict)


class SleepCoachFeedbackSerializer(serializers.Serializer):
    plan_id = serializers.IntegerField()
    quality_rating = serializers.IntegerField(min_value=1, max_value=5)
    wake_feeling = serializers.ChoiceField(
        choices=["rested", "okay", "groggy", "exhausted"]
    )
    focus_rating = serializers.IntegerField(min_value=1, max_value=5)
    disruptor = serializers.CharField(required=False, allow_blank=True, max_length=40)
    actual_sleep_start = serializers.DateTimeField(required=False, allow_null=True)
    actual_wake_time = serializers.DateTimeField(required=False, allow_null=True)
