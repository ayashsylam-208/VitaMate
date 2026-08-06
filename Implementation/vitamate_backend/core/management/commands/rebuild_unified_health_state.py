from django.core.management.base import BaseCommand
from django.utils import timezone

from core.management.commands._health_command_utils import (
    add_output_arguments,
    add_user_arguments,
    render_rows,
    selected_users,
)
from core.services.orchestration.health_state_orchestrator import HealthStateOrchestrator
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers


class Command(BaseCommand):
    help = "Synchronously rebuild current and daily UnifiedHealthState rows."

    def add_arguments(self, parser):
        add_output_arguments(parser)
        add_user_arguments(parser)

    def handle(self, *args, **options):
        rows = []
        today = timezone.localdate()
        for user in selected_users(options):
            if options["dry_run"]:
                rows.append({"user_id": user.id, "status": "dry_run", "state_date": today})
                continue
            result = HealthStateOrchestrator().handle_event(
                user=user,
                trigger_type=HealthStateTriggers.READ_MODEL_REFRESH_REQUESTED,
                payload={
                    "trigger_reference": f"manual-rebuild:{user.id}:{today}",
                    "event_dates": [today],
                    "today": today,
                },
                synchronous=True,
            )
            rows.append({"user_id": user.id, **result})
        self.stdout.write(render_rows(rows, options["format"]))
