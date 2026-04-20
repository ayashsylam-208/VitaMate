from core.models import SleepLog


class SleepRepository:
    @staticmethod
    def create_for_user(user, start_time, end_time, quality):
        return SleepLog.objects.create(
            user=user,
            start_time=start_time,
            end_time=end_time,
            quality=quality,
        )

    @staticmethod
    def has_other_log_for_date(user, log_date, exclude_id=None):
        qs = SleepLog.objects.filter(user=user, date=log_date)
        if exclude_id:
            qs = qs.exclude(id=exclude_id)
        return qs.exists()

    @staticmethod
    def list_for_user(user):
        return SleepLog.objects.filter(user=user).order_by("-date", "-id")

    @staticmethod
    def list_for_user_on_date(user, log_date):
        return SleepLog.objects.filter(user=user, date=log_date).order_by("start_time", "id")

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


SleepLogRepository = SleepRepository
