from core.models import StepLog


class StepRepository:
    @staticmethod
    def get_for_user_on_date(user, log_date):
        return StepLog.objects.filter(user=user, date=log_date).first()

    @staticmethod
    def upsert_for_user_date(user, log_date, steps_count, distance_km):
        existing = StepRepository.get_for_user_on_date(user, log_date)
        if existing:
            update_fields = []
            if steps_count is not None:
                existing.steps_count = steps_count
                update_fields.append("steps_count")
            if distance_km is not None:
                existing.distance_km = distance_km
                update_fields.append("distance_km")
            if update_fields:
                existing.save(update_fields=update_fields)
            return existing

        return StepLog.objects.create(
            user=user,
            date=log_date,
            steps_count=steps_count,
            distance_km=distance_km,
        )

    @staticmethod
    def get_or_create_for_user_on_date(user, log_date):
        return StepLog.objects.get_or_create(user=user, date=log_date)

    @staticmethod
    def list_for_user(user):
        return StepLog.objects.filter(user=user).order_by("-date")

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


StepLogRepository = StepRepository
