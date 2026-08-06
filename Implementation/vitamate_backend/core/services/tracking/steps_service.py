from django.core.exceptions import ValidationError
from django.utils import timezone

from users.models import UserProfile

from core.repositories.step_log_repository import StepRepository
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers
from users.repositories.user_profile_repository import UserProfileRepository
from gamification.services.points_service import PointsService


class StepsService:
    @staticmethod
    def log_steps(
        user,
        steps_count,
        distance_km,
        *,
        local_date=None,
        timezone_name="",
        installation_id="",
        measured_at=None,
        sensor_steps=None,
        manual_adjustment_steps=None,
        imported_adjustment_steps=None,
        sync_version=None,
    ):
        # Use today's date to keep one record per day.
        today = timezone.localdate()
        if local_date is not None and local_date != today:
            raise ValidationError("Stale step sync date rejected.")

        source_values_provided = any(
            value is not None
            for value in (sensor_steps, manual_adjustment_steps, imported_adjustment_steps)
        )
        if source_values_provided:
            sensor_steps = max(int(sensor_steps or 0), 0)
            manual_adjustment_steps = int(manual_adjustment_steps or 0)
            imported_adjustment_steps = int(imported_adjustment_steps or 0)
            steps_count = max(sensor_steps + manual_adjustment_steps + imported_adjustment_steps, 0)
        else:
            steps_count = max(int(steps_count or 0), 0)
            sensor_steps = steps_count
            manual_adjustment_steps = 0
            imported_adjustment_steps = 0

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
            sensor_steps=sensor_steps,
            manual_adjustment_steps=manual_adjustment_steps,
            imported_adjustment_steps=imported_adjustment_steps,
            timezone_name=timezone_name,
            installation_id=installation_id,
            measured_at=measured_at,
            sync_version=sync_version,
        )
        if log.date != today:
            log.date = today
            log = StepRepository.save(log, update_fields=["date"])

        # Award points based on the current step total.
        PointsService.award_steps_points(
            user,
            log.steps_count,
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
            step_log.steps_count = max(int(steps_count or 0), 0)
        if distance_km is not None:
            step_log.distance_km = max(float(distance_km or 0), 0)
        step_log = StepRepository.save(step_log)
        PointsService.award_steps_points(
            step_log.user,
            step_log.steps_count,
            source_id=step_log.id,
            event_date=step_log.date,
        )
        from gamification.services.motivation_service import MotivationService

        MotivationService.refresh_daily(
            user=step_log.user,
            target_date=step_log.date,
        )
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
        PointsService.award_steps_points(
            user,
            0,
            source_id=step_id,
            event_date=event_date,
        )
        from gamification.services.motivation_service import MotivationService

        MotivationService.refresh_daily(
            user=user,
            target_date=event_date,
        )
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
