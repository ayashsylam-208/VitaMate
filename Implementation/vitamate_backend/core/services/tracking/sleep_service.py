from users.models import UserProfile

from core.repositories.sleep_log_repository import SleepRepository
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers
from users.repositories.user_profile_repository import UserProfileRepository
from gamification.services.points_service import PointsService


class SleepLoggingService:
    """Command-side service for writing sleep logs and awarding points."""

    @staticmethod
    def log_sleep(user, start_time, end_time, quality):
        log = SleepRepository.create_for_user(
            user=user,
            start_time=start_time,
            end_time=end_time,
            quality=quality,
        )

        try:
            profile = UserProfileRepository.get_for_user(user)
        except UserProfile.DoesNotExist:
            profile = None

        goal_hours = getattr(profile, "recommended_sleep_hours", None) if profile is not None else None
        if goal_hours:
            from core.services.constraints import EffectiveConstraintReader

            goal_hours = EffectiveConstraintReader.get_effective_constraint(
                user=user,
                tracker_type="sleep",
                constraint_key="sleep_hours",
                default_value=goal_hours,
                default_unit="hours",
                default_source="profile_fallback",
            ).value

            already_logged_today = SleepRepository.has_other_log_for_date(
                user=user,
                log_date=log.date,
                exclude_id=log.id,
            )
            if not already_logged_today:
                PointsService.award_sleep_points_if_eligible(
                    user=user,
                    duration_hours=log.duration_hours,
                    goal_hours=goal_hours,
                    source_id=log.id,
                    event_date=log.date,
                )

        from gamification.services.motivation_service import MotivationService

        MotivationService.refresh_daily(
            user=user,
            target_date=log.date,
        )

        HealthStateEventPublisher.publish_on_commit(
            user=user,
            trigger_type=HealthStateTriggers.SLEEP_LOGGED,
            payload={
                "trigger_reference": str(log.id),
                "source_id": log.id,
                "event_dates": [log.date],
            },
        )

        return log

    @staticmethod
    def update_sleep_log(sleep_log, *, start_time=None, end_time=None, quality=None):
        previous_date = sleep_log.date
        if start_time is not None:
            sleep_log.start_time = start_time
        if end_time is not None:
            sleep_log.end_time = end_time
        if quality is not None:
            sleep_log.quality = quality
        sleep_log = SleepRepository.save(sleep_log)
        try:
            profile = UserProfileRepository.get_for_user(sleep_log.user)
        except UserProfile.DoesNotExist:
            profile = None

        goal_hours = getattr(profile, "recommended_sleep_hours", None) if profile is not None else None
        if goal_hours:
            from core.services.constraints import EffectiveConstraintReader

            goal_hours = EffectiveConstraintReader.get_effective_constraint(
                user=sleep_log.user,
                tracker_type="sleep",
                constraint_key="sleep_hours",
                default_value=goal_hours,
                default_unit="hours",
                default_source="profile_fallback",
            ).value

        desired_points = 0
        if goal_hours and not SleepRepository.has_other_log_for_date(
            user=sleep_log.user,
            log_date=sleep_log.date,
            exclude_id=sleep_log.id,
        ):
            if float(sleep_log.duration_hours or 0) >= 0.9 * float(goal_hours or 0):
                desired_points = 10

        PointsService.sync_source_rule_total(
            sleep_log.user,
            source_type="sleep",
            source_id=sleep_log.id,
            rule_code="SLEEP_GOAL_COMPLETED",
            desired_points=desired_points,
            event_date=sleep_log.date,
            reason="Adjusted sleep goal points after editing sleep log.",
        )
        from gamification.services.motivation_service import MotivationService

        MotivationService.refresh_daily(
            user=sleep_log.user,
            target_date=sleep_log.date,
        )
        HealthStateEventPublisher.publish_on_commit(
            user=sleep_log.user,
            trigger_type=HealthStateTriggers.SLEEP_UPDATED,
            payload={
                "trigger_reference": str(sleep_log.id),
                "source_id": sleep_log.id,
                "event_dates": [previous_date, sleep_log.date],
            },
        )
        return sleep_log

    @staticmethod
    def delete_sleep_log(sleep_log):
        user = sleep_log.user
        sleep_id = sleep_log.id
        event_date = sleep_log.date
        SleepRepository.delete(sleep_log)
        PointsService.reverse_points_for_source(
            user=user,
            source_type="sleep",
            source_id=sleep_id,
            reason="Reversed sleep points after deleting sleep log.",
            event_date=event_date,
        )
        from gamification.services.motivation_service import MotivationService

        MotivationService.refresh_daily(
            user=user,
            target_date=event_date,
        )
        HealthStateEventPublisher.publish_on_commit(
            user=user,
            trigger_type=HealthStateTriggers.SLEEP_DELETED,
            payload={
                "trigger_reference": str(sleep_id),
                "source_id": sleep_id,
                "event_dates": [event_date],
            },
        )

    @staticmethod
    def get_sleep_logs(*, user, on_date=None):
        if on_date is not None:
            return SleepRepository.list_for_user_on_date(user, on_date)
        return SleepRepository.list_for_user(user)


SleepService = SleepLoggingService
