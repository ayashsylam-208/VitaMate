from django.core.management.base import BaseCommand

from core.management.commands._health_command_utils import (
    add_output_arguments,
    add_user_arguments,
    fail_if_strict,
    render_rows,
    selected_users,
)
from core.services.constraints.constraint_engine_comparison_service import (
    ConstraintEngineComparisonService,
)


class Command(BaseCommand):
    help = "Compare legacy condition-engine targets with materialized constraints."

    def add_arguments(self, parser):
        add_output_arguments(parser)
        add_user_arguments(parser)

    def handle(self, *args, **options):
        rows = []
        for user in selected_users(options):
            rows.extend(ConstraintEngineComparisonService.compare_user(user=user))
        self.stdout.write(render_rows(rows, options["format"]))
        issues = sum(row["status"] in {"legacy_only", "unexplained_difference"} for row in rows)
        fail_if_strict(strict=options["strict"], issues=issues)
