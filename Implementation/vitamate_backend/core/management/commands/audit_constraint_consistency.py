from collections import Counter

from django.core.management.base import BaseCommand
from django.utils import timezone

from core.management.commands._health_command_utils import (
    add_output_arguments,
    fail_if_strict,
    render_rows,
)
from core.models import ResolvedTrackerConstraint


class Command(BaseCommand):
    help = "Audit active materialized constraints for consistency and traceability."

    def add_arguments(self, parser):
        add_output_arguments(parser)
        parser.add_argument("--user-id", type=int)

    def handle(self, *args, **options):
        queryset = ResolvedTrackerConstraint.objects.filter(
            status=ResolvedTrackerConstraint.STATUS_ACTIVE
        ).prefetch_related("source_traces").order_by("user_id", "tracker_type", "metric_key", "id")
        if options.get("user_id"):
            queryset = queryset.filter(user_id=options["user_id"])
        constraints = list(queryset)
        counts = Counter(
            (item.user_id, item.tracker_type, item.metric_key, item.rule_type)
            for item in constraints
        )
        valid_trackers = {item[0] for item in ResolvedTrackerConstraint.TRACKER_TYPE_CHOICES}
        now = timezone.now()
        rows = []
        for item in constraints:
            issues = []
            key = (item.user_id, item.tracker_type, item.metric_key, item.rule_type)
            if counts[key] > 1:
                issues.append("duplicate_active_scope")
            if item.tracker_type not in valid_trackers:
                issues.append("unknown_tracker")
            if item.effective_to and item.effective_to <= now:
                issues.append("expired_but_active")
            if not item.unit:
                issues.append("missing_unit")
            if not item.source_traces.all():
                issues.append("missing_source_trace")
            if not item.reason_summary:
                issues.append("missing_reason")
            rows.append({"constraint_id": item.id, "user_id": item.user_id, "issues": ",".join(issues)})
        self.stdout.write(render_rows(rows, options["format"]))
        fail_if_strict(strict=options["strict"], issues=sum(bool(row["issues"]) for row in rows))
