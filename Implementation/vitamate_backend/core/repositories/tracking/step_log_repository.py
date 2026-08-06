from core.models import StepLog


class StepRepository:
    @staticmethod
    def get_for_user_on_date(user, log_date):
        return StepLog.objects.filter(user=user, date=log_date).first()

    @staticmethod
    def upsert_for_user_date(
        user,
        log_date,
        steps_count,
        distance_km,
        *,
        sensor_steps=None,
        manual_adjustment_steps=None,
        imported_adjustment_steps=None,
        timezone_name="",
        installation_id="",
        measured_at=None,
        sync_version=None,
    ):
        existing = StepRepository.get_for_user_on_date(user, log_date)
        if existing:
            update_fields = []
            if steps_count is not None:
                existing.steps_count = steps_count
                update_fields.append("steps_count")
            if distance_km is not None:
                existing.distance_km = distance_km
                update_fields.append("distance_km")
            optional_fields = {
                "sensor_steps": sensor_steps,
                "manual_adjustment_steps": manual_adjustment_steps,
                "imported_adjustment_steps": imported_adjustment_steps,
                "timezone": timezone_name,
                "installation_id": installation_id,
                "measured_at": measured_at,
                "sync_version": sync_version,
            }
            for field, value in optional_fields.items():
                if value is not None:
                    setattr(existing, field, value)
                    update_fields.append(field)
            if update_fields:
                existing.save(update_fields=sorted(set(update_fields)))
            return existing

        created = StepLog.objects.create(
            user=user,
            date=log_date,
            steps_count=steps_count,
            distance_km=distance_km,
            sensor_steps=sensor_steps if sensor_steps is not None else max(int(steps_count or 0), 0),
            manual_adjustment_steps=manual_adjustment_steps or 0,
            imported_adjustment_steps=imported_adjustment_steps or 0,
            timezone=timezone_name or "",
            installation_id=installation_id or "",
            measured_at=measured_at,
            sync_version=sync_version or 0,
        )
        if created.date != log_date:
            created.date = log_date
            created.save(update_fields=["date"])
        return created

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
