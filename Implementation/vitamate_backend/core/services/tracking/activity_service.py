from core.repositories.activity_log_repository import ActivityRepository
from gamification.services.points_service import PointsService
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers


class ActivityService:
    @staticmethod
    def log_activity(user, exercise, duration_minutes):
        # Log a physical activity for the user.
        log = ActivityRepository.create_for_user(
            user=user,
            exercise=exercise,
            duration_minutes=duration_minutes,
        )

        # Award fixed points per activity log.
        PointsService.award_activity_points(user)
        HealthStateEventPublisher.publish_on_commit(
            user=user,
            trigger_type=HealthStateTriggers.ACTIVITY_LOGGED,
            payload={
                "trigger_reference": str(log.id),
                "source_id": log.id,
                "event_dates": [log.date],
            },
        )

        return log

    @staticmethod
    def update_activity_log(activity_log, *, exercise=None, duration_minutes=None):
        previous_date = activity_log.date
        if exercise is not None:
            activity_log.exercise = exercise
        if duration_minutes is not None:
            activity_log.duration_minutes = duration_minutes
        activity_log = ActivityRepository.save(activity_log)
        HealthStateEventPublisher.publish_on_commit(
            user=activity_log.user,
            trigger_type=HealthStateTriggers.ACTIVITY_UPDATED,
            payload={
                "trigger_reference": str(activity_log.id),
                "source_id": activity_log.id,
                "event_dates": [previous_date, activity_log.date],
            },
        )
        return activity_log

    @staticmethod
    def delete_activity_log(activity_log):
        user = activity_log.user
        activity_id = activity_log.id
        event_date = activity_log.date
        ActivityRepository.delete(activity_log)
        HealthStateEventPublisher.publish_on_commit(
            user=user,
            trigger_type=HealthStateTriggers.ACTIVITY_DELETED,
            payload={
                "trigger_reference": str(activity_id),
                "source_id": activity_id,
                "event_dates": [event_date],
            },
        )

    @staticmethod
    def get_activity_logs(*, user, on_date=None):
        if on_date is not None:
            return ActivityRepository.list_for_user_on_date(user, on_date)
        return ActivityRepository.list_for_user(user)
