from core.repositories.activity_log_repository import ActivityRepository
from gamification.services.points_service import PointsService
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers
from django.utils import timezone


class ActivityService:
    @staticmethod
    def emit_activity_log_side_effects(activity_log, *, points_idempotency_key: str | None = None):
        if points_idempotency_key:
            from gamification.models import PointsTransaction

            PointsService.award_rule(
                activity_log.user,
                rule_code="ACTIVITY_SESSION_COMPLETED",
                source_type=PointsTransaction.SOURCE_ACTIVITY,
                source_id=activity_log.id,
                event_date=activity_log.date,
                idempotency_key=points_idempotency_key,
            )
        else:
            PointsService.award_activity_points(
                activity_log.user,
                source_id=activity_log.id,
                event_date=activity_log.date,
            )

        from gamification.services.motivation_service import MotivationService

        MotivationService.refresh_daily(
            user=activity_log.user,
            target_date=activity_log.date,
        )
        try:
            from notification_hub.services import NotificationHubRefreshService

            NotificationHubRefreshService.refresh_user(user=activity_log.user)
        except Exception:
            pass
        HealthStateEventPublisher.publish_on_commit(
            user=activity_log.user,
            trigger_type=HealthStateTriggers.ACTIVITY_LOGGED,
            payload={
                "trigger_reference": str(activity_log.id),
                "source_id": activity_log.id,
                "event_dates": [activity_log.date],
            },
        )

    @staticmethod
    def log_activity(user, exercise, duration_minutes, *, source_session=None, emit_side_effects=True):
        # Log a physical activity for the user.
        target_date = timezone.localdate()
        log = ActivityRepository.create_for_user(
            user=user,
            exercise=exercise,
            duration_minutes=duration_minutes,
            source_session=source_session,
        )
        if log.date != target_date:
            log.date = target_date
            log = ActivityRepository.save(log, update_fields=["date"])

        if emit_side_effects:
            ActivityService.emit_activity_log_side_effects(log)

        return log

    @staticmethod
    def update_activity_log(activity_log, *, exercise=None, duration_minutes=None):
        previous_date = activity_log.date
        if exercise is not None:
            activity_log.exercise = exercise
        if duration_minutes is not None:
            activity_log.duration_minutes = duration_minutes
        activity_log = ActivityRepository.save(activity_log)
        from gamification.services.motivation_service import MotivationService

        MotivationService.refresh_daily(
            user=activity_log.user,
            target_date=activity_log.date,
        )
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
        PointsService.reverse_points_for_source(
            user=user,
            source_type="activity",
            source_id=activity_id,
            reason="Reversed activity points after deleting activity log.",
            event_date=event_date,
        )
        from gamification.services.motivation_service import MotivationService

        MotivationService.refresh_daily(
            user=user,
            target_date=event_date,
        )
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
