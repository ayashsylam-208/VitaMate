from datetime import date

from users.models import UserProfile

from core.repositories.step_log_repository import StepRepository
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers
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
        log = StepRepository.upsert_for_user_date(
            user=user,
            log_date=today,
            steps_count=steps_count,
            distance_km=distance_km,
        )

        # Award points based on the current step total.
        PointsService.award_steps_points(user, log.steps_count)
        HealthStateEventPublisher.publish_on_commit(
            user=user,
            trigger_type=HealthStateTriggers.STEPS_LOGGED,
            payload={
                "trigger_reference": str(log.id),
                "source_id": log.id,
                "event_dates": [log.date],
            },
        )

        return log

    @staticmethod
    def update_step_log(step_log, *, steps_count=None, distance_km=None):
        previous_date = step_log.date
        if steps_count is not None:
            step_log.steps_count = steps_count
        if distance_km is not None:
            step_log.distance_km = distance_km
        step_log = StepRepository.save(step_log)
        HealthStateEventPublisher.publish_on_commit(
            user=step_log.user,
            trigger_type=HealthStateTriggers.STEPS_UPDATED,
            payload={
                "trigger_reference": str(step_log.id),
                "source_id": step_log.id,
                "event_dates": [previous_date, step_log.date],
            },
        )
        return step_log

    @staticmethod
    def delete_step_log(step_log):
        user = step_log.user
        step_id = step_log.id
        event_date = step_log.date
        StepRepository.delete(step_log)
        HealthStateEventPublisher.publish_on_commit(
            user=user,
            trigger_type=HealthStateTriggers.STEPS_DELETED,
            payload={
                "trigger_reference": str(step_id),
                "source_id": step_id,
                "event_dates": [event_date],
            },
        )

    @staticmethod
    def get_step_logs(*, user):
        return StepRepository.list_for_user(user)
