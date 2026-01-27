from users.models import UserProfile

from core.repositories.sleep_log_repository import SleepLogRepository
from users.repositories.user_profile_repository import UserProfileRepository
from gamification.services.points_service import PointsService


class SleepService:
    @staticmethod
    def log_sleep(user, start_time, end_time, quality):
        log = SleepLogRepository.create_for_user(
            user=user,
            start_time=start_time,
            end_time=end_time,
            quality=quality,
        )

        try:
            profile = UserProfileRepository.get_for_user(user)
        except UserProfile.DoesNotExist:
            return log

        goal_hours = getattr(profile, "recommended_sleep_hours", None)
        if not goal_hours:
            return log

        already_logged_today = SleepLogRepository.has_other_log_for_date(
            user=user,
            log_date=log.date,
            exclude_id=log.id,
        )
        if already_logged_today:
            return log

        PointsService.award_sleep_points_if_eligible(
            user=user,
            duration_hours=log.duration_hours,
            goal_hours=goal_hours,
        )

        return log
