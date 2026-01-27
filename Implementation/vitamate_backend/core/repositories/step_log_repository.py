from core.models import StepLog


class StepLogRepository:
    @staticmethod
    def get_for_user_on_date(user, log_date):
        return StepLog.objects.filter(user=user, date=log_date).first()

    @staticmethod
    def upsert_for_user_date(user, log_date, steps_count, distance_km):
        existing = StepLogRepository.get_for_user_on_date(user, log_date)
        if existing:
            existing.steps_count = steps_count or existing.steps_count
            existing.distance_km = distance_km or existing.distance_km
            existing.save()
            return existing

        return StepLog.objects.create(
            user=user,
            date=log_date,
            steps_count=steps_count,
            distance_km=distance_km,
        )
