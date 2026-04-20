from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("core", "0018_resolvedtrackerconstraint_constraintsourcetrace_and_more"),
    ]

    operations = [
        migrations.CreateModel(
            name="HealthStateComputationRun",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("trigger_type", models.CharField(db_index=True, max_length=80)),
                ("trigger_reference", models.CharField(blank=True, max_length=255)),
                (
                    "run_status",
                    models.CharField(
                        choices=[
                            ("running", "Running"),
                            ("completed", "Completed"),
                            ("failed", "Failed"),
                            ("skipped", "Skipped"),
                        ],
                        db_index=True,
                        default="running",
                        max_length=20,
                    ),
                ),
                (
                    "sync_mode",
                    models.CharField(
                        choices=[
                            ("sync", "Sync"),
                            ("async_placeholder", "Async placeholder"),
                        ],
                        default="sync",
                        max_length=30,
                    ),
                ),
                ("affected_domains", models.JSONField(blank=True, default=list)),
                ("error_message", models.TextField(blank=True)),
                ("metadata", models.JSONField(blank=True, default=dict)),
                ("started_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("completed_at", models.DateTimeField(blank=True, null=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="health_state_runs",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ("-started_at", "-id"),
                "indexes": [
                    models.Index(
                        fields=["user", "run_status", "started_at"],
                        name="hscr_user_status_started_idx",
                    ),
                    models.Index(
                        fields=["user", "trigger_type", "started_at"],
                        name="hscr_user_trigger_started_idx",
                    ),
                ],
            },
        ),
        migrations.CreateModel(
            name="NotificationDispatchRecord",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("notification_type", models.CharField(db_index=True, max_length=80)),
                ("channel", models.CharField(blank=True, max_length=60)),
                ("priority", models.PositiveSmallIntegerField(default=50)),
                ("dedupe_key", models.CharField(db_index=True, max_length=255)),
                ("payload", models.JSONField(blank=True, default=dict)),
                ("cooldown_until", models.DateTimeField(blank=True, null=True)),
                ("last_dispatched_at", models.DateTimeField(blank=True, null=True)),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("pending", "Pending"),
                            ("dispatched", "Dispatched"),
                            ("suppressed", "Suppressed"),
                        ],
                        db_index=True,
                        default="pending",
                        max_length=20,
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="notification_dispatch_records",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ("-updated_at", "-id"),
                "indexes": [
                    models.Index(
                        fields=["user", "dedupe_key", "updated_at"],
                        name="ndr_user_dedupe_updated_idx",
                    ),
                    models.Index(
                        fields=["user", "status", "updated_at"],
                        name="ndr_user_status_updated_idx",
                    ),
                ],
            },
        ),
        migrations.CreateModel(
            name="UnifiedHealthState",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("state_date", models.DateField()),
                (
                    "window_kind",
                    models.CharField(
                        choices=[("current", "Current"), ("daily", "Daily")],
                        default="current",
                        max_length=20,
                    ),
                ),
                ("version", models.PositiveIntegerField(default=1)),
                ("last_computed_at", models.DateTimeField(db_index=True, default=django.utils.timezone.now)),
                ("affected_trackers", models.JSONField(blank=True, default=list)),
                ("tracker_snapshots", models.JSONField(blank=True, default=list)),
                ("progress_summary", models.JSONField(blank=True, default=dict)),
                ("active_targets", models.JSONField(blank=True, default=list)),
                ("active_constraints", models.JSONField(blank=True, default=dict)),
                ("warnings", models.JSONField(blank=True, default=list)),
                ("medication_summary", models.JSONField(blank=True, default=dict)),
                ("trigger_metadata", models.JSONField(blank=True, default=dict)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="unified_health_states",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ("-state_date", "window_kind", "-last_computed_at"),
                "indexes": [
                    models.Index(
                        fields=["user", "window_kind", "state_date"],
                        name="uhs_user_window_date_idx",
                    ),
                    models.Index(
                        fields=["user", "last_computed_at"],
                        name="uhs_user_computed_idx",
                    ),
                ],
                "constraints": [
                    models.UniqueConstraint(
                        fields=("user", "state_date", "window_kind"),
                        name="unique_user_health_state_window",
                    )
                ],
            },
        ),
        migrations.CreateModel(
            name="HealthStateDelta",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("state_date", models.DateField()),
                (
                    "window_kind",
                    models.CharField(
                        choices=[("current", "Current"), ("daily", "Daily")],
                        default="current",
                        max_length=20,
                    ),
                ),
                ("trigger_type", models.CharField(db_index=True, max_length=80)),
                ("trigger_reference", models.CharField(blank=True, max_length=255)),
                ("reason", models.CharField(blank=True, max_length=255)),
                ("changed_trackers", models.JSONField(blank=True, default=list)),
                ("metrics_before", models.JSONField(blank=True, default=dict)),
                ("metrics_after", models.JSONField(blank=True, default=dict)),
                ("warnings_added", models.JSONField(blank=True, default=list)),
                ("warnings_resolved", models.JSONField(blank=True, default=list)),
                ("achievements_added", models.JSONField(blank=True, default=list)),
                ("notification_candidates", models.JSONField(blank=True, default=list)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "computation_run",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="deltas",
                        to="core.healthstatecomputationrun",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="health_state_deltas",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ("-created_at", "-id"),
                "indexes": [
                    models.Index(
                        fields=["user", "state_date", "window_kind"],
                        name="hsd_user_state_window_idx",
                    ),
                    models.Index(
                        fields=["user", "trigger_type", "created_at"],
                        name="hsd_user_trigger_created_idx",
                    ),
                ],
            },
        ),
    ]
