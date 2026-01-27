from users.models import UserProfile


class UserProfileRepository:
    @staticmethod
    def get_for_user(user):
        return UserProfile.objects.get(user=user)

    @staticmethod
    def get_or_create_for_user(user, defaults):
        return UserProfile.objects.get_or_create(user=user, defaults=defaults)
