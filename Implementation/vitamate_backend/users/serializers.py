from django.contrib.auth.models import User
from rest_framework import serializers

from users.services.user_profile_service import UserProfileService


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ("username", "password", "email", "first_name", "last_name")

    def create(self, validated_data):
        return User.objects.create_user(
            username=validated_data["username"],
            password=validated_data["password"],
            email=validated_data.get("email", ""),
            first_name=validated_data.get("first_name", ""),
            last_name=validated_data.get("last_name", ""),
        )


class UserUpdateSerializer(serializers.ModelSerializer):
    username = serializers.CharField(read_only=True)

    # Core profile fields
    weight = serializers.FloatField(source="userprofile.weight")
    height = serializers.FloatField(source="userprofile.height")
    activity_level = serializers.FloatField(source="userprofile.activity_level")
    goal = serializers.CharField(source="userprofile.goal")
    daily_step_goal = serializers.IntegerField(source="userprofile.daily_step_goal")
    gender = serializers.CharField(source="userprofile.gender", read_only=True)
    birth_date = serializers.DateField(source="userprofile.birth_date", required=False)

    # Backward-compatible onboarding field
    age = serializers.IntegerField(write_only=True, required=False, min_value=0, max_value=120)

    # Sleep + reminders settings used by frontend
    recommended_sleep_hours = serializers.FloatField(
        source="userprofile.recommended_sleep_hours",
        required=False,
    )
    target_wake_time = serializers.TimeField(source="userprofile.target_wake_time", required=False)
    target_bed_time = serializers.TimeField(
        source="userprofile.target_bed_time",
        required=False,
        allow_null=True,
    )
    enable_sleep_improvement = serializers.BooleanField(
        source="userprofile.enable_sleep_improvement",
        required=False,
    )
    preferred_activity_type = serializers.CharField(
        source="userprofile.preferred_activity_type",
        required=False,
    )
    enable_activity_reminders = serializers.BooleanField(
        source="userprofile.enable_activity_reminders",
        required=False,
    )
    activity_reminder_interval_hours = serializers.IntegerField(
        source="userprofile.activity_reminder_interval_hours",
        required=False,
    )
    activity_reminder_time = serializers.TimeField(
        source="userprofile.activity_reminder_time",
        required=False,
    )
    activity_reminder_days = serializers.ListField(
        source="userprofile.activity_reminder_days",
        required=False,
        child=serializers.IntegerField(min_value=1, max_value=7),
    )
    inactive_reminder_enabled = serializers.BooleanField(
        source="userprofile.inactive_reminder_enabled",
        required=False,
    )
    inactive_reminder_hours = serializers.IntegerField(
        source="userprofile.inactive_reminder_hours",
        required=False,
        min_value=1,
        max_value=24,
    )
    enable_water_reminders = serializers.BooleanField(
        source="userprofile.enable_water_reminders",
        required=False,
    )
    water_reminder_interval_minutes = serializers.IntegerField(
        source="userprofile.water_reminder_interval_minutes",
        required=False,
    )

    class Meta:
        model = User
        fields = [
            "username",
            "first_name",
            "last_name",
            "email",
            "weight",
            "height",
            "activity_level",
            "goal",
            "daily_step_goal",
            "gender",
            "birth_date",
            "age",
            "recommended_sleep_hours",
            "target_wake_time",
            "target_bed_time",
            "enable_sleep_improvement",
            "preferred_activity_type",
            "enable_activity_reminders",
            "activity_reminder_interval_hours",
            "activity_reminder_time",
            "activity_reminder_days",
            "inactive_reminder_enabled",
            "inactive_reminder_hours",
            "enable_water_reminders",
            "water_reminder_interval_minutes",
        ]

    def update(self, instance, validated_data):
        age = validated_data.pop("age", None)
        profile_data = validated_data.pop("userprofile", {})
        if age is not None and "birth_date" not in profile_data:
            profile_data["birth_date"] = UserProfileService.birth_date_from_age(age)

        return UserProfileService.update_user_and_profile(
            user=instance,
            user_data=validated_data,
            profile_data=profile_data,
        )
