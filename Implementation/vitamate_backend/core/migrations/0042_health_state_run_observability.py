from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("core", "0041_constraint_resolution_run_observability")]

    operations = [
        migrations.AddField(
            model_name="healthstatecomputationrun",
            name="correlation_id",
            field=models.CharField(blank=True, db_index=True, max_length=64),
        ),
        migrations.AddField(
            model_name="healthstatecomputationrun",
            name="error_code",
            field=models.CharField(blank=True, max_length=80),
        ),
        migrations.AddField(
            model_name="healthstatecomputationrun",
            name="failed_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="healthstatecomputationrun",
            name="idempotency_key",
            field=models.CharField(blank=True, max_length=160, null=True, unique=True),
        ),
        migrations.AddField(
            model_name="healthstatecomputationrun",
            name="retry_count",
            field=models.PositiveIntegerField(default=0),
        ),
    ]
