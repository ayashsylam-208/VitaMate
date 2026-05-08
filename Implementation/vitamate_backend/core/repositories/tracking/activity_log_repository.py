from core.models import ActivityLog


class ActivityRepository:
    @staticmethod
    def create_for_user(user, exercise, duration_minutes):
        return ActivityLog.objects.create(
            user=user,
            exercise=exercise,
            duration_minutes=duration_minutes,
        )

    @staticmethod
    def list_for_user(user):
        return ActivityLog.objects.filter(user=user).select_related("exercise").order_by("-date", "-id")

    @staticmethod
    def list_for_user_on_date(user, log_date):
        return (
            ActivityLog.objects.filter(user=user, date=log_date)
            .select_related("exercise")
            .order_by("id")
        )

    @staticmethod
    def list_for_user_between_dates(user, *, start_date, end_date):
        return (
            ActivityLog.objects.filter(user=user, date__gte=start_date, date__lte=end_date)
            .select_related("exercise")
            .order_by("-date", "-id")
        )

    @staticmethod
    def save(log, *, update_fields=None):
        if update_fields is None:
            log.save()
        else:
            log.save(update_fields=update_fields)
        return log

    @staticmethod
    def delete(log):
        log.delete()


ActivityLogRepository = ActivityRepository
