from core.models import WaterLog


class WaterLogRepository:
    @staticmethod
    def create_for_user(user, amount_liter):
        return WaterLog.objects.create(
            user=user,
            amount_liter=amount_liter,
        )
