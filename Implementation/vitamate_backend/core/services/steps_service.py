from datetime import date

from users.models import UserProfile

from core.repositories.step_log_repository import StepLogRepository
from users.repositories.user_profile_repository import UserProfileRepository
from gamification.services.points_service import PointsService


class StepsService:
    @staticmethod
    def log_steps(user, steps_count, distance_km):
        # Use today's date to keep one record per day.
        today = date.today()

        # Estimate distance when it is not provided.
        if not distance_km or distance_km <= 0:
            try:
                profile = UserProfileRepository.get_for_user(user)
            except UserProfile.DoesNotExist:
                profile = None

            if profile and profile.height:
                stride_factor = 0.415 if profile.gender == 'M' else 0.413
                stride_cm = profile.height * stride_factor
                distance_km = round((steps_count * stride_cm) / 100000, 3)
            else:
                distance_km = 0

        # Upsert the daily steps record.
        log = StepLogRepository.upsert_for_user_date(
            user=user,
            log_date=today,
            steps_count=steps_count,
            distance_km=distance_km,
        )

        # Award points based on the current step total.
        PointsService.award_steps_points(user, log.steps_count)

        return log
