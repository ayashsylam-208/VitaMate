from django.core.management.base import BaseCommand

from core.management.commands._health_command_utils import (
    add_output_arguments,
    add_user_arguments,
    render_rows,
    selected_users,
)
from core.models import ConstraintResolutionRun, ResolvedTrackerConstraint
from core.services.constraints import ConstraintRecomputeDispatcher


class Command(BaseCommand):
    help = "Idempotently rebuild materialized constraints for one user or all users."

    def add_arguments(self, parser):
        add_output_arguments(parser)
        add_user_arguments(parser)
        parser.add_argument("--tracker", choices=[item[0] for item in ResolvedTrackerConstraint.TRACKER_TYPE_CHOICES])

    def handle(self, *args, **options):
        rows = []
        for user in selected_users(options):
            if options["dry_run"]:
                rows.append({"user_id": user.id, "status": "dry_run", "tracker": options.get("tracker") or "all"})
                continue
            run = ConstraintRecomputeDispatcher.dispatch_for_user(
                user=user,
                trigger_type=ConstraintResolutionRun.TRIGGER_MANUAL,
                trigger_reference=f"recovery:{user.id}:{options.get('tracker') or 'all'}",
                tracker_type=options.get("tracker"),
                correlation_id=f"constraint-recovery-{user.id}",
                metadata={"management_command": "rebuild_user_constraints"},
                sync_mode=ConstraintResolutionRun.SYNC_MODE_RECOVERY,
            )
            rows.append(
                {
                    "user_id": user.id,
                    "run_id": run.id,
                    "status": run.run_status,
                    "generated": run.total_constraints_generated,
                    "superseded": run.total_constraints_superseded,
                }
            )
        self.stdout.write(render_rows(rows, options["format"]))
