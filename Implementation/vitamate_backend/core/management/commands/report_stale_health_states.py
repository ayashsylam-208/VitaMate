from django.core.management.base import BaseCommand
from django.db.models import Max

from core.management.commands._health_command_utils import (
    add_output_arguments,
    add_user_arguments,
    fail_if_strict,
    render_rows,
    selected_users,
)
from core.models import (
    ActivityLog,
    HealthIndicatorRecord,
    MealLog,
    SleepLog,
    StepLog,
    UnifiedHealthState,
    WaterLog,
)


class Command(BaseCommand):
    help = "Report users whose source data is newer than current UnifiedHealthState."

    def add_arguments(self, parser):
        add_output_arguments(parser)
        add_user_arguments(parser)

    def handle(self, *args, **options):
        rows = []
        for user in selected_users(options):
            state = UnifiedHealthState.objects.filter(
                user=user,
                window_kind=UnifiedHealthState.WINDOW_CURRENT,
            ).order_by("-state_date", "-last_computed_at").first()
            source_times = [
                MealLog.objects.filter(user=user).aggregate(value=Max("consumed_at"))["value"],
                WaterLog.objects.filter(user=user).aggregate(value=Max("consumed_at"))["value"],
                ActivityLog.objects.filter(
                    user=user,
                    source_session__isnull=False,
                ).aggregate(value=Max("source_session__updated_at"))["value"],
                StepLog.objects.filter(user=user).aggregate(value=Max("measured_at"))["value"],
                SleepLog.objects.filter(user=user).aggregate(value=Max("end_time"))["value"],
                HealthIndicatorRecord.objects.filter(user_condition__user=user).aggregate(value=Max("recorded_at"))["value"],
            ]
            latest_source = max((value for value in source_times if value is not None), default=None)
            stale = state is None or (
                latest_source is not None and latest_source > state.last_computed_at
            )
            rows.append(
                {
                    "user_id": user.id,
                    "state_id": state.id if state else None,
                    "state_version": state.version if state else None,
                    "state_computed_at": state.last_computed_at if state else None,
                    "latest_source_at": latest_source,
                    "stale": stale,
                    "timestamp_coverage_gaps": [
                        name
                        for name, exists in (
                            (
                                "legacy_meal_without_consumed_at",
                                MealLog.objects.filter(user=user, consumed_at__isnull=True).exists(),
                            ),
                            (
                                "manual_activity_without_timestamp",
                                ActivityLog.objects.filter(user=user, source_session__isnull=True).exists(),
                            ),
                        )
                        if exists
                    ],
                }
            )
        self.stdout.write(render_rows(rows, options["format"]))
        fail_if_strict(strict=options["strict"], issues=sum(bool(row["stale"]) for row in rows))
