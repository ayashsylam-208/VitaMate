from core.models import SleepLog


class SleepLogRepository:
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
