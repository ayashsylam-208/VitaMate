from rest_framework import serializers


class DeviceRegisterSerializer(serializers.Serializer):
    installation_id = serializers.CharField(max_length=191)
    platform = serializers.CharField(max_length=24)
    timezone = serializers.CharField(max_length=64, required=False, allow_blank=True)
    locale = serializers.CharField(max_length=32, required=False, allow_blank=True)
    app_version = serializers.CharField(max_length=40, required=False, allow_blank=True)
    notifications_authorized = serializers.BooleanField(required=False, default=False)
    exact_alarm_authorized = serializers.BooleanField(required=False, default=False)
    permission_status = serializers.ChoiceField(
        choices=[
            "authorized",
            "denied",
            "not_determined",
            "provisional",
            "restricted",
            "unavailable",
        ],
        required=False,
    )
    notifications_enabled_systemwide = serializers.BooleanField(required=False)
    checked_at = serializers.DateTimeField(required=False)


class NotificationPrimaryDeviceSerializer(serializers.Serializer):
    installation_id = serializers.CharField(max_length=191)


class NotificationPreferencesPatchSerializer(serializers.Serializer):
    enable_routine_reminders = serializers.BooleanField(required=False)
    enable_motivation_reminders = serializers.BooleanField(required=False)
    enable_health_alerts = serializers.BooleanField(required=False)
    enable_medication_reminders = serializers.BooleanField(required=False)
    enable_sleep_reminders = serializers.BooleanField(required=False)
    enable_water_reminders = serializers.BooleanField(required=False)
    enable_meal_reminders = serializers.BooleanField(required=False)
    enable_activity_reminders = serializers.BooleanField(required=False)
    enable_step_reminders = serializers.BooleanField(required=False)
    enable_habit_reminders = serializers.BooleanField(required=False)
    quiet_hours_enabled = serializers.BooleanField(required=False)
    quiet_start = serializers.TimeField(required=False, allow_null=True)
    quiet_end = serializers.TimeField(required=False, allow_null=True)
    motivation_max_per_day = serializers.IntegerField(required=False, min_value=1, max_value=5)
    motivation_type_cooldown_hours = serializers.IntegerField(required=False, min_value=1, max_value=24)
    critical_bypass_quiet_hours = serializers.BooleanField(required=False)
    breakfast_reminder_time = serializers.TimeField(required=False, allow_null=True)
    lunch_reminder_time = serializers.TimeField(required=False, allow_null=True)
    dinner_reminder_time = serializers.TimeField(required=False, allow_null=True)
    steps_reminder_time = serializers.TimeField(required=False, allow_null=True)
    daily_water_target_ml = serializers.IntegerField(required=False, min_value=500, max_value=8000)
    water_reminder_interval_minutes = serializers.IntegerField(required=False, min_value=15, max_value=240)
    water_reminder_start_time = serializers.TimeField(required=False, allow_null=True)
    water_reminder_end_time = serializers.TimeField(required=False, allow_null=True)
    activity_reminder_interval_hours = serializers.IntegerField(required=False, min_value=1, max_value=12)
    activity_reminder_time = serializers.TimeField(required=False)
    activity_reminder_days = serializers.ListField(
        required=False,
        child=serializers.IntegerField(min_value=1, max_value=7),
    )
    inactive_reminder_enabled = serializers.BooleanField(required=False)
    inactive_reminder_hours = serializers.IntegerField(required=False, min_value=1, max_value=24)
    target_wake_time = serializers.TimeField(required=False)
    target_bed_time = serializers.TimeField(required=False, allow_null=True)


class NotificationSyncSerializer(serializers.Serializer):
    installation_id = serializers.CharField(max_length=191)
    last_known_plan_ids = serializers.ListField(
        required=False,
        child=serializers.CharField(max_length=64),
        default=list,
    )
    foreground_state = serializers.ChoiceField(
        choices=["foreground", "background"],
        required=False,
        default="background",
    )
    timezone = serializers.CharField(max_length=64, required=False, allow_blank=True)
    permission_snapshot = serializers.DictField(required=False, default=dict)
    reason = serializers.CharField(max_length=64, required=False, allow_blank=True)


class NotificationReportEventSerializer(serializers.Serializer):
    event_id = serializers.CharField(max_length=96)
    plan_id = serializers.CharField(max_length=64)
    revision = serializers.IntegerField(required=False, min_value=1)
    outcome = serializers.ChoiceField(
        choices=[
            "scheduled_local",
            "presented_in_app",
            "delivery_failed",
            "acknowledged",
            "opened",
            "dismissed",
            "expired",
            "suppressed_by_policy",
            "delivered",
            "cancelled",
        ]
    )
    occurred_at = serializers.DateTimeField(required=False)
    failure_code = serializers.CharField(max_length=80, required=False, allow_blank=True)
    suppression_reason = serializers.CharField(max_length=120, required=False, allow_blank=True)
    metadata = serializers.DictField(required=False, default=dict)

    def validate(self, attrs):
        if attrs.get("outcome") == "suppressed_by_policy" and not str(
            attrs.get("suppression_reason") or ""
        ).strip():
            raise serializers.ValidationError(
                {"suppression_reason": "A named policy reason is required."}
            )
        return attrs


class NotificationReportSerializer(serializers.Serializer):
    installation_id = serializers.CharField(max_length=191)
    events = NotificationReportEventSerializer(many=True, required=False, default=list)
