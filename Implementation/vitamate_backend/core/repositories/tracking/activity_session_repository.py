from core.models import ActivitySession


class ActivitySessionRepository:
    @staticmethod
    def create_for_user(
        *,
        user,
        exercise,
        status,
        source,
        intensity,
        target_duration_seconds,
        met_value_snapshot,
        estimated_calories,
        calories_burned=0,
    ):
        return ActivitySession.objects.create(
            user=user,
            exercise=exercise,
            status=status,
            source=source,
            intensity=intensity,
            target_duration_seconds=target_duration_seconds,
            met_value_snapshot=met_value_snapshot,
            estimated_calories=estimated_calories,
            calories_burned=calories_burned,
        )

    @staticmethod
    def get_active_for_user(*, user):
        return (
            ActivitySession.objects.filter(
                user=user,
                status__in=[ActivitySession.STATUS_RUNNING, ActivitySession.STATUS_PAUSED],
            )
            .select_related("exercise")
            .order_by("-started_at", "-id")
            .first()
        )

    @staticmethod
    def get_for_user(*, user, session_id):
        return (
            ActivitySession.objects.filter(user=user, id=session_id)
            .select_related("exercise")
            .first()
        )

    @staticmethod
    def save(session, *, update_fields=None):
        if update_fields is None:
            session.save()
        else:
            session.save(update_fields=update_fields)
        return session
