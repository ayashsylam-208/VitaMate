from users.repositories.user_profile_repository import UserProfileRepository


class UserProfileService:
    DEFAULT_PROFILE = {
        "birth_date": "2000-01-01",
        "gender": "M",
        "height": 170,
        "weight": 70,
    }

    @staticmethod
    def ensure_profile(user):
        profile, _ = UserProfileRepository.get_or_create_for_user(
            user=user,
            defaults=UserProfileService.DEFAULT_PROFILE,
        )
        return profile

    @staticmethod
    def update_user_and_profile(user, user_data, profile_data):
        # Update user fields first.
        user.first_name = user_data.get("first_name", user.first_name)
        user.last_name = user_data.get("last_name", user.last_name)
        user.email = user_data.get("email", user.email)
        user.save()

        # Ensure profile exists before updating.
        profile = UserProfileService.ensure_profile(user)

        # Update profile fields.
        profile.weight = profile_data.get("weight", profile.weight)
        profile.height = profile_data.get("height", profile.height)
        profile.activity_level = profile_data.get("activity_level", profile.activity_level)
        profile.goal = profile_data.get("goal", profile.goal)
        profile.daily_step_goal = profile_data.get("daily_step_goal", profile.daily_step_goal)

        # Recalculate derived metrics and persist.
        profile.calculate_metrics()

        return user
