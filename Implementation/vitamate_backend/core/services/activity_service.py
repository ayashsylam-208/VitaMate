from core.repositories.activity_log_repository import ActivityLogRepository
from gamification.services.points_service import PointsService


class ActivityService:
    @staticmethod
    def log_activity(user, exercise, duration_minutes):
        # Log a physical activity for the user.
        log = ActivityLogRepository.create_for_user(
            user=user,
            exercise=exercise,
            duration_minutes=duration_minutes,
        )

        # Award fixed points per activity log.
        PointsService.award_activity_points(user)

        return log
