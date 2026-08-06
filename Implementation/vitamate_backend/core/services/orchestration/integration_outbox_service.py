from __future__ import annotations

from datetime import date

from django.db import transaction
from django.utils import timezone

from core.models import IntegrationOutboxEvent


class IntegrationOutboxService:
    EVENT_MOTIVATION_REFRESH = "motivation.refresh_daily"

    @classmethod
    def enqueue_motivation_refresh(cls, *, user, target_date: date, source_ref: str):
        event, created = IntegrationOutboxEvent.objects.get_or_create(
            dedupe_key=f"motivation:{user.id}:{target_date}:{source_ref}",
            defaults={
                "user": user,
                "event_type": cls.EVENT_MOTIVATION_REFRESH,
                "payload": {"target_date": target_date.isoformat()},
            },
        )

        def _dispatch():
            from core.tasks import dispatch_integration_outbox_event

            dispatch_integration_outbox_event(event_id=event.id)

        if created:
            transaction.on_commit(_dispatch)
        return event

    @classmethod
    def process(cls, *, event_id: int):
        with transaction.atomic():
            event = (
                IntegrationOutboxEvent.objects.select_for_update()
                .select_related("user")
                .filter(id=event_id)
                .first()
            )
            if event is None or event.status in {
                IntegrationOutboxEvent.STATUS_PROCESSING,
                IntegrationOutboxEvent.STATUS_PROCESSED,
            }:
                return event
            event.status = IntegrationOutboxEvent.STATUS_PROCESSING
            event.attempts += 1
            event.last_error = ""
            event.save(update_fields=("status", "attempts", "last_error", "updated_at"))

        try:
            cls._handle(event)
        except Exception as exc:
            IntegrationOutboxEvent.objects.filter(id=event.id).update(
                status=IntegrationOutboxEvent.STATUS_FAILED,
                last_error=str(exc)[:2000],
            )
            raise

        IntegrationOutboxEvent.objects.filter(id=event.id).update(
            status=IntegrationOutboxEvent.STATUS_PROCESSED,
            processed_at=timezone.now(),
            last_error="",
        )
        event.refresh_from_db()
        return event

    @classmethod
    def _handle(cls, event):
        if event.event_type == cls.EVENT_MOTIVATION_REFRESH:
            from gamification.services.motivation_service import MotivationService

            MotivationService.refresh_daily(
                user=event.user,
                target_date=date.fromisoformat(event.payload["target_date"]),
            )
            return
        raise ValueError(f"Unsupported integration outbox event: {event.event_type}")
