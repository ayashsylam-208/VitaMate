from datetime import date

from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers
from users.repositories.user_profile_repository import UserProfileRepository
from users.services.profile_metrics_calculator import ProfileMetricsCalculator


class UserProfileService:
    DEFAULT_PROFILE = {
        "birth_date": date(2000, 1, 1),
        "gender": "M",
        "height": 170,
        "weight": 70,
        "gender_confirmed": False,
    }

    @staticmethod
    def ensure_profile(user):
        profile, created = UserProfileRepository.get_or_create_for_user(
            user=user,
            defaults=UserProfileService.DEFAULT_PROFILE,
        )
        if created:
            ProfileMetricsCalculator.apply(profile, persist=True)
        return profile

    @staticmethod
    def birth_date_from_age(age, *, reference_date=None):
        if reference_date is None:
            reference_date = date.today()
        age = int(age)
        target_year = reference_date.year - age
        try:
            return reference_date.replace(year=target_year)
        except ValueError:
            # Handle leap day conversion on non-leap years.
            return reference_date.replace(year=target_year, day=28)

    @staticmethod
    def update_user_and_profile(user, user_data, profile_data):
        # Update user fields first.
        user.first_name = user_data.get("first_name", user.first_name)
        user.last_name = user_data.get("last_name", user.last_name)
        user.email = user_data.get("email", user.email)
        user.save()

        # Ensure profile exists before updating.
        profile = UserProfileService.ensure_profile(user)

        # Update profile fields from any supported PATCH payload.
        fields_to_update = [
            "birth_date",
            "gender",
            "gender_confirmed",
            "pending_email",
            "email_verified",
            "avatar_url",
            "preferred_language",
            "region",
            "weight",
            "height",
            "activity_level",
            "goal",
            "daily_step_goal",
            "daily_water_target",
            "manual_daily_water_target",
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
        for field_name in fields_to_update:
            if field_name in profile_data:
                setattr(profile, field_name, profile_data[field_name])
        if "gender" in profile_data:
            profile.gender_confirmed = True

        # Recalculate derived metrics and persist.
        UserProfileService.recalculate_profile(profile)

        return user

    @staticmethod
    def recalculate_profile(profile):
        ProfileMetricsCalculator.apply(profile, persist=False)
        profile.save()
        HealthStateEventPublisher.publish_on_commit(
            user=profile.user,
            trigger_type=HealthStateTriggers.USER_PROFILE_UPDATED,
            payload={
                "trigger_reference": str(profile.id),
                "source_id": profile.id,
                "event_dates": [date.today()],
            },
        )
        return profile
