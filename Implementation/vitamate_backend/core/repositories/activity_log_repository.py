from core.models import ActivityLog


class ActivityLogRepository:
    @staticmethod
    def create_for_user(user, exercise, duration_minutes):
        return ActivityLog.objects.create(
            user=user,
            exercise=exercise,
            duration_minutes=duration_minutes,
        )
