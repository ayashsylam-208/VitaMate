from django.core.management.base import BaseCommand

from core.models import IntegrationOutboxEvent
from core.services.orchestration.integration_outbox_service import IntegrationOutboxService


class Command(BaseCommand):
    help = "Process pending or failed integration outbox events."

    def add_arguments(self, parser):
        parser.add_argument("--limit", type=int, default=100)

    def handle(self, *args, **options):
        event_ids = list(
            IntegrationOutboxEvent.objects.filter(
                status__in=(
                    IntegrationOutboxEvent.STATUS_PENDING,
                    IntegrationOutboxEvent.STATUS_FAILED,
                )
            )
            .order_by("created_at", "id")
            .values_list("id", flat=True)[: max(options["limit"], 1)]
        )
        processed = 0
        for event_id in event_ids:
            try:
                IntegrationOutboxService.process(event_id=event_id)
                processed += 1
            except Exception as exc:
                self.stderr.write(f"Event {event_id} failed: {exc}")
        self.stdout.write(self.style.SUCCESS(f"Processed {processed}/{len(event_ids)} events."))
