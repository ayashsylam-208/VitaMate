from django.db import migrations, models


def normalize_completed_status(apps, schema_editor):
    ConstraintResolutionRun = apps.get_model("core", "ConstraintResolutionRun")
    ConstraintResolutionRun.objects.filter(run_status="completed").update(run_status="succeeded")


def restore_completed_status(apps, schema_editor):
    ConstraintResolutionRun = apps.get_model("core", "ConstraintResolutionRun")
    ConstraintResolutionRun.objects.filter(run_status="succeeded").update(run_status="completed")


class Migration(migrations.Migration):
    dependencies = [("core", "0040_favorite_food")]

    operations = [
        migrations.AddField(
            model_name="constraintresolutionrun",
            name="affected_trackers",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="constraintresolutionrun",
            name="correlation_id",
            field=models.CharField(blank=True, db_index=True, max_length=64),
        ),
        migrations.AddField(
            model_name="constraintresolutionrun",
            name="error_code",
            field=models.CharField(blank=True, max_length=80),
        ),
        migrations.AddField(
            model_name="constraintresolutionrun",
            name="failed_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="constraintresolutionrun",
            name="idempotency_key",
            field=models.CharField(blank=True, max_length=128, null=True, unique=True),
        ),
        migrations.AddField(
            model_name="constraintresolutionrun",
            name="metadata",
            field=models.JSONField(blank=True, default=dict),
        ),
        migrations.AddField(
            model_name="constraintresolutionrun",
            name="retry_count",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="constraintresolutionrun",
            name="sync_mode",
            field=models.CharField(
                choices=[
                    ("synchronous", "Synchronous"),
                    ("queued", "Queued"),
                    ("recovery", "Recovery"),
                    ("manual", "Manual"),
                ],
                default="synchronous",
                max_length=20,
            ),
        ),
        migrations.RunPython(normalize_completed_status, restore_completed_status),
        migrations.AlterField(
            model_name="constraintresolutionrun",
            name="run_status",
            field=models.CharField(
                choices=[
                    ("pending", "Pending"),
                    ("running", "Running"),
                    ("succeeded", "Succeeded"),
                    ("partially_failed", "Partially failed"),
                    ("failed", "Failed"),
                    ("skipped", "Skipped"),
                ],
                db_index=True,
                default="running",
                max_length=20,
            ),
        ),
    ]
