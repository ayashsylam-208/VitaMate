from django.contrib.auth.models import User
from rest_framework import serializers

from users.models import UserProfile
from users.services.user_profile_service import UserProfileService


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ("username", "password", "email", "first_name", "last_name")

    def validate_email(self, value):
        email = (value or "").strip().lower()
        if email and User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError("This email is already in use.")
        return email

    def create(self, validated_data):
        return User.objects.create_user(
            username=validated_data["username"],
            password=validated_data["password"],
            email=(validated_data.get("email", "") or "").strip().lower(),
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
    gender = serializers.ChoiceField(
        source="userprofile.gender",
        choices=[choice[0] for choice in UserProfile.GENDER_CHOICES],
        required=False,
    )
    birth_date = serializers.DateField(source="userprofile.birth_date", required=False)
    bmi = serializers.FloatField(source="userprofile.bmi", read_only=True)
    bmr = serializers.SerializerMethodField()
    daily_calorie_target = serializers.IntegerField(
        source="userprofile.daily_calorie_target",
        read_only=True,
    )
    daily_water_target = serializers.FloatField(
        source="userprofile.daily_water_target",
        required=False,
        min_value=0.5,
        max_value=8,
    )
    daily_burn_goal = serializers.IntegerField(
        source="userprofile.daily_burn_goal",
        read_only=True,
    )
    gender_confirmed = serializers.BooleanField(
        source="userprofile.gender_confirmed",
        read_only=True,
    )
    email_verified = serializers.BooleanField(
        source="userprofile.email_verified",
        read_only=True,
    )
    pending_email = serializers.EmailField(
        source="userprofile.pending_email",
        read_only=True,
    )
    avatar_url = serializers.CharField(
        source="userprofile.avatar_url",
        required=False,
        allow_blank=True,
        max_length=500,
    )
    preferred_language = serializers.CharField(
        source="userprofile.preferred_language",
        required=False,
        allow_blank=False,
        max_length=40,
    )
    region = serializers.CharField(
        source="userprofile.region",
        required=False,
        allow_blank=False,
        max_length=80,
    )

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
    enable_motivation_reminders = serializers.BooleanField(
        source="userprofile.enable_motivation_reminders",
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
            "daily_burn_goal",
            "gender",
            "gender_confirmed",
            "birth_date",
            "age",
            "bmi",
            "bmr",
            "daily_calorie_target",
            "daily_water_target",
            "email_verified",
            "pending_email",
            "avatar_url",
            "preferred_language",
            "region",
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
            "enable_motivation_reminders",
        ]

    def get_bmr(self, instance):
        profile = UserProfileService.ensure_profile(instance)
        from manager.services.read_model_service import ManagerReadModelService

        return ManagerReadModelService._bmr(profile=profile)

    def validate_email(self, value):
        email = (value or "").strip().lower()
        if not email:
            return ""
        current_user = self.instance
        user_conflict = User.objects.filter(email__iexact=email).exclude(
            pk=getattr(current_user, "pk", None)
        )
        pending_conflict = UserProfile.objects.filter(pending_email__iexact=email).exclude(
            user=getattr(current_user, "pk", None)
        )
        if user_conflict.exists() or pending_conflict.exists():
            raise serializers.ValidationError("This email is already in use.")
        return email

    def update(self, instance, validated_data):
        age = validated_data.pop("age", None)
        profile_data = validated_data.pop("userprofile", {})
        if age is not None and "birth_date" not in profile_data:
            profile_data["birth_date"] = UserProfileService.birth_date_from_age(age)
        requested_email = validated_data.pop("email", None)
        if requested_email is not None:
            normalized = (requested_email or "").strip().lower()
            profile = UserProfileService.ensure_profile(instance)
            if normalized and normalized != (instance.email or "").strip().lower():
                profile_data["pending_email"] = normalized
                profile_data["email_verified"] = False
            else:
                validated_data["email"] = normalized
        if "daily_water_target" in profile_data:
            profile_data["manual_daily_water_target"] = profile_data["daily_water_target"]

        return UserProfileService.update_user_and_profile(
            user=instance,
            user_data=validated_data,
            profile_data=profile_data,
        )
