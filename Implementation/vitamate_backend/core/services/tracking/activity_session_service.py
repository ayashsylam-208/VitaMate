from __future__ import annotations

from collections import defaultdict
from datetime import date, timedelta

from django.core.exceptions import ValidationError
from django.db import transaction
from django.utils import timezone

from core.models import ActivityLog, ActivitySession, Exercise
from core.repositories.tracking.activity_log_repository import ActivityRepository
from core.repositories.tracking.activity_session_repository import ActivitySessionRepository
from core.services.health_progress.movement_evaluator import MovementEvaluator
from core.services.tracking.activity_service import ActivityService


class ActivitySessionService:
    @staticmethod
    def system_local_date() -> date:
        return timezone.localdate()

    @staticmethod
    def met_for_intensity(*, exercise: Exercise, intensity: str) -> float:
        if intensity == ActivitySession.INTENSITY_LIGHT:
            return float(exercise.met_light or exercise.met_value)
        if intensity == ActivitySession.INTENSITY_INTENSE:
            return float(exercise.met_intense or exercise.met_value)
        return float(exercise.met_moderate or exercise.met_value)

    @staticmethod
    def calculate_calories(*, weight_kg: float, met_value: float, duration_seconds: int) -> int:
        duration_minutes = max(duration_seconds, 0) / 60
        return int((met_value * 3.5 * weight_kg) / 200 * duration_minutes)

    @classmethod
    def ensure_no_active_session(cls, *, user) -> None:
        active = ActivitySessionRepository.get_active_for_user(user=user)
        if active is not None:
            raise ValidationError("An active workout session already exists.")

    @classmethod
    def start_session(
        cls,
        *,
        user,
        exercise: Exercise,
        target_duration_seconds: int,
        intensity: str = ActivitySession.INTENSITY_MODERATE,
        source: str = ActivitySession.SOURCE_LIVE,
    ) -> ActivitySession:
        cls.ensure_no_active_session(user=user)
        target_duration_seconds = max(int(target_duration_seconds or 0), 60)
        met_value = cls.met_for_intensity(exercise=exercise, intensity=intensity)
        weight = getattr(getattr(user, "userprofile", None), "weight", 0) or 0
        estimated_calories = cls.calculate_calories(
            weight_kg=weight,
            met_value=met_value,
            duration_seconds=target_duration_seconds,
        )
        return ActivitySessionRepository.create_for_user(
            user=user,
            exercise=exercise,
            status=ActivitySession.STATUS_RUNNING,
            source=source,
            intensity=intensity,
            target_duration_seconds=target_duration_seconds,
            met_value_snapshot=met_value,
            estimated_calories=estimated_calories,
        )

    @classmethod
    def pause_session(cls, session: ActivitySession) -> ActivitySession:
        if session.status != ActivitySession.STATUS_RUNNING:
            raise ValidationError("Only running sessions can be paused.")
        now = timezone.now()
        session.actual_duration_seconds = session.effective_elapsed_seconds(now=now)
        session.calories_burned = session.effective_calories_burned(now=now)
        session.status = ActivitySession.STATUS_PAUSED
        session.paused_at = now
        return ActivitySessionRepository.save(
            session,
            update_fields=[
                "actual_duration_seconds",
                "calories_burned",
                "status",
                "paused_at",
                "updated_at",
            ],
        )

    @classmethod
    def resume_session(cls, session: ActivitySession) -> ActivitySession:
        if session.status != ActivitySession.STATUS_PAUSED or session.paused_at is None:
            raise ValidationError("Only paused sessions can be resumed.")
        now = timezone.now()
        paused_seconds = int((now - session.paused_at).total_seconds())
        session.total_paused_seconds = int(session.total_paused_seconds or 0) + max(paused_seconds, 0)
        session.status = ActivitySession.STATUS_RUNNING
        session.paused_at = None
        return ActivitySessionRepository.save(
            session,
            update_fields=[
                "total_paused_seconds",
                "status",
                "paused_at",
                "updated_at",
            ],
        )

    @classmethod
    def edit_session(
        cls,
        session: ActivitySession,
        *,
        exercise: Exercise | None = None,
        target_duration_seconds: int | None = None,
        intensity: str | None = None,
    ) -> ActivitySession:
        if session.status not in {ActivitySession.STATUS_RUNNING, ActivitySession.STATUS_PAUSED}:
            raise ValidationError("Only active sessions can be edited.")
        if exercise is not None:
            session.exercise = exercise
        if target_duration_seconds is not None:
            session.target_duration_seconds = max(int(target_duration_seconds), 60)
        if intensity is not None:
            session.intensity = intensity
        session.met_value_snapshot = cls.met_for_intensity(
            exercise=session.exercise,
            intensity=session.intensity,
        )
        weight = getattr(getattr(session.user, "userprofile", None), "weight", 0) or 0
        session.estimated_calories = cls.calculate_calories(
            weight_kg=weight,
            met_value=session.met_value_snapshot,
            duration_seconds=session.target_duration_seconds,
        )
        session.actual_duration_seconds = session.effective_elapsed_seconds()
        session.calories_burned = session.effective_calories_burned()
        return ActivitySessionRepository.save(
            session,
            update_fields=[
                "exercise",
                "target_duration_seconds",
                "intensity",
                "met_value_snapshot",
                "estimated_calories",
                "actual_duration_seconds",
                "calories_burned",
                "updated_at",
            ],
        )

    @classmethod
    def finish_session(cls, session: ActivitySession, *, save_partial: bool = False) -> ActivitySession:
        with transaction.atomic():
            locked = (
                ActivitySession.objects.select_for_update()
                .select_related("exercise", "user")
                .get(id=session.id, user=session.user)
            )
            final_log = ActivityLog.objects.filter(source_session=locked).first()
            if locked.status == ActivitySession.STATUS_COMPLETED and final_log is not None:
                return locked
            if locked.status not in {ActivitySession.STATUS_RUNNING, ActivitySession.STATUS_PAUSED}:
                raise ValidationError("Only active sessions can be finished.")

            now = timezone.now()
            elapsed_seconds = locked.effective_elapsed_seconds(now=now)
            if elapsed_seconds < locked.target_duration_seconds and not save_partial:
                raise ValidationError("Use partial save or resume the workout.")

            duration_minutes = max(1, round(elapsed_seconds / 60))
            target_date = timezone.localdate(now)
            final_log, log_created = ActivityLog.objects.get_or_create(
                source_session=locked,
                defaults={
                    "user": locked.user,
                    "exercise": locked.exercise,
                    "duration_minutes": duration_minutes,
                },
            )
            log_changed_fields = []
            if final_log.date != target_date:
                final_log.date = target_date
                log_changed_fields.append("date")
            if final_log.duration_minutes != duration_minutes:
                final_log.duration_minutes = duration_minutes
                log_changed_fields.append("duration_minutes")
            if log_changed_fields:
                final_log.save(update_fields=log_changed_fields)

            locked.status = ActivitySession.STATUS_COMPLETED
            locked.ended_at = now
            locked.actual_duration_seconds = elapsed_seconds
            locked.calories_burned = final_log.calories_burned
            locked = ActivitySessionRepository.save(
                locked,
                update_fields=[
                    "status",
                    "ended_at",
                    "actual_duration_seconds",
                    "calories_burned",
                    "updated_at",
                ],
            )
            if log_created:
                log_id = final_log.id
                session_id = locked.id
                transaction.on_commit(
                    lambda: cls._emit_session_completed_side_effects(
                        activity_log_id=log_id,
                        session_id=session_id,
                    )
                )
            return locked

    @staticmethod
    def _emit_session_completed_side_effects(*, activity_log_id: int, session_id: int) -> None:
        try:
            activity_log = ActivityLog.objects.select_related("user", "exercise").get(id=activity_log_id)
        except ActivityLog.DoesNotExist:
            return
        ActivityService.emit_activity_log_side_effects(
            activity_log,
            points_idempotency_key=f"activity_session_completed:{session_id}",
        )

    @classmethod
    def cancel_session(cls, session: ActivitySession) -> ActivitySession:
        if session.status not in {ActivitySession.STATUS_RUNNING, ActivitySession.STATUS_PAUSED}:
            raise ValidationError("Only active sessions can be cancelled.")
        now = timezone.now()
        session.status = ActivitySession.STATUS_CANCELLED
        session.ended_at = now
        session.actual_duration_seconds = session.effective_elapsed_seconds(now=now)
        session.calories_burned = session.effective_calories_burned(now=now)
        return ActivitySessionRepository.save(
            session,
            update_fields=[
                "status",
                "ended_at",
                "actual_duration_seconds",
                "calories_burned",
                "updated_at",
            ],
        )

    @classmethod
    def serialize_session(cls, session: ActivitySession | None) -> dict | None:
        if session is None:
            return None
        elapsed_seconds = session.effective_elapsed_seconds()
        calories_burned = session.effective_calories_burned()
        progress_percent = 0
        if session.target_duration_seconds > 0:
            progress_percent = round(
                min(elapsed_seconds / session.target_duration_seconds, 1.0) * 100
            )
        return {
            "id": session.id,
            "exercise": session.exercise_id,
            "exercise_name": session.exercise.name,
            "exercise_icon_key": session.exercise.icon_key,
            "status": session.status,
            "source": session.source,
            "intensity": session.intensity,
            "target_duration_seconds": session.target_duration_seconds,
            "actual_duration_seconds": elapsed_seconds,
            "remaining_duration_seconds": max(session.target_duration_seconds - elapsed_seconds, 0),
            "progress_percent": progress_percent,
            "met_value_snapshot": round(session.met_value_snapshot, 2),
            "estimated_calories": int(session.estimated_calories or 0),
            "calories_burned": calories_burned,
            "started_at": session.started_at.isoformat() if session.started_at else None,
            "paused_at": session.paused_at.isoformat() if session.paused_at else None,
            "ended_at": session.ended_at.isoformat() if session.ended_at else None,
            "total_paused_seconds": int(session.total_paused_seconds or 0),
        }

    @classmethod
    def active_session_payload(cls, *, user) -> dict | None:
        session = ActivitySessionRepository.get_active_for_user(user=user)
        return cls.serialize_session(session)

    @classmethod
    def build_today_summary(cls, *, user) -> dict:
        today = cls.system_local_date()
        movement = MovementEvaluator.evaluate(user=user, target_date=today)
        steps_component = dict(movement["components"]["steps"])
        exercise_component = dict(movement["components"]["exercise"])
        active_calories = dict(movement["active_calories"])
        steps = int(steps_component.get("current") or 0)
        steps_target = int(steps_component.get("target") or 0)
        active_minutes = int(exercise_component.get("current") or 0)
        calories_burned = int(active_calories.get("value") or 0)
        burn_target = int(active_calories.get("target") or 0)
        burn_progress = int(active_calories.get("percent") or 0)
        steps_progress = int(steps_component.get("progress_percent") or 0)
        goal_progress = int(movement.get("score") or 0)
        if burn_target > 0 and calories_burned >= burn_target and movement.get("is_complete"):
            message = "Daily burn goal completed. Keep the momentum going."
        elif burn_target > 0:
            message = f"You are {max(burn_target - calories_burned, 0)} kcal away from your daily burn goal."
        elif active_minutes > 0:
            message = "Great progress today. Keep moving."
        else:
            message = "Start a live workout or add a manual log to build momentum."
        return {
            "steps": steps,
            "steps_target": steps_target,
            "active_minutes": active_minutes,
            "calories_burned": calories_burned,
            "burn_target": burn_target,
            "goal_progress_percent": goal_progress,
            "burn_progress_percent": burn_progress,
            "steps_progress_percent": steps_progress,
            "movement": movement,
            "active_calories": active_calories,
            "message": message,
        }

    @staticmethod
    def _week_bounds(reference_date=None):
        today = reference_date or ActivitySessionService.system_local_date()
        week_start = today - timedelta(days=today.weekday())
        week_end = week_start + timedelta(days=6)
        return week_start, week_end

    @classmethod
    def weekly_logs(cls, *, user):
        week_start, week_end = cls._week_bounds()
        return list(
            ActivityRepository.list_for_user_between_dates(
                user,
                start_date=week_start,
                end_date=week_end,
            )
        )

    @classmethod
    def build_weekly_summary(cls, *, user) -> dict:
        profile = getattr(user, "userprofile", None)
        weekly_goal_minutes = round((getattr(profile, "weekly_activity_goal_hours", 0) or 0) * 60)
        logs = cls.weekly_logs(user=user)
        total_minutes = sum(int(log.duration_minutes or 0) for log in logs)
        total_calories = sum(int(log.calories_burned or 0) for log in logs)
        active_days = len({log.date for log in logs})
        totals_by_exercise = defaultdict(lambda: {"minutes": 0, "calories": 0})
        for log in logs:
            bucket = totals_by_exercise[log.exercise.name]
            bucket["minutes"] += int(log.duration_minutes or 0)
            bucket["calories"] += int(log.calories_burned or 0)
        best_activity = ""
        if totals_by_exercise:
            best_activity = max(
                totals_by_exercise.items(),
                key=lambda item: (item[1]["minutes"], item[1]["calories"], item[0]),
            )[0]
        achievement = round(min(total_minutes / weekly_goal_minutes, 1.0) * 100) if weekly_goal_minutes > 0 else 0
        return {
            "week_start": str(cls._week_bounds()[0]),
            "week_end": str(cls._week_bounds()[1]),
            "active_days": active_days,
            "weekly_minutes": total_minutes,
            "weekly_kcal": total_calories,
            "goal_target_minutes": weekly_goal_minutes,
            "goal_achievement_rate": achievement,
            "remaining_minutes": max(weekly_goal_minutes - total_minutes, 0),
            "best_activity": best_activity,
            "active_time": MovementEvaluator.weekly_active_time(
                user=user,
                target_date=cls.system_local_date(),
            ),
        }

    @classmethod
    def build_suggestions(cls, *, user) -> list[dict]:
        profile = getattr(user, "userprofile", None)
        weekly_summary = cls.build_weekly_summary(user=user)
        weekly_remaining = int(weekly_summary.get("remaining_minutes") or 0)
        preferred = str(getattr(profile, "preferred_activity_type", "") or "").lower()
        weight = getattr(profile, "weight", 0) or 0
        exercises = list(
            Exercise.objects.filter(is_featured=True)
            .order_by("sort_order", "name")[:6]
        )
        suggestions = []
        for exercise in exercises:
            duration_minutes = int(exercise.default_duration_minutes or 30)
            if weekly_remaining > 0 and weekly_remaining < duration_minutes:
                duration_minutes = max(10, weekly_remaining)
            elif weekly_remaining > duration_minutes * 2:
                duration_minutes = min(duration_minutes + 5, 60)
            intensity = ActivitySession.INTENSITY_MODERATE
            met_value = cls.met_for_intensity(exercise=exercise, intensity=intensity)
            estimated_calories = cls.calculate_calories(
                weight_kg=weight,
                met_value=met_value,
                duration_seconds=duration_minutes * 60,
            )
            reason = "Good balance for today."
            normalized_name = exercise.name.lower()
            if preferred and preferred in normalized_name:
                reason = "Matches your preferred activity type."
            elif weekly_remaining > 0:
                reason = "Helps close your weekly activity goal."
            suggestions.append(
                {
                    "exercise": exercise.id,
                    "exercise_name": exercise.name,
                    "icon_key": exercise.icon_key,
                    "intensity": intensity,
                    "recommended_duration_minutes": duration_minutes,
                    "estimated_calories": estimated_calories,
                    "reason": reason,
                }
            )
        return suggestions
