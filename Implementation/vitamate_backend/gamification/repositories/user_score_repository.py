from gamification.models import UserScore


class UserScoreRepository:
    @staticmethod
    def get_or_create_for_user(user):
        return UserScore.objects.get_or_create(user=user)

    @staticmethod
    def get_for_user(user):
        return UserScore.objects.get(user=user)
