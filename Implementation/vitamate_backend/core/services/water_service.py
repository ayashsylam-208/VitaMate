from gamification.services.points_service import PointsService
from core.repositories.water_log_repository import WaterLogRepository


class WaterService:
    @staticmethod
    def log_water(user, amount_liter):
        # Log water intake for the current user.
        log = WaterLogRepository.create_for_user(
            user=user,
            amount_liter=amount_liter,
        )

        # Award fixed points per water log.
        PointsService.award_water_points(user)

        return log
