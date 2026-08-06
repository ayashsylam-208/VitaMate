from django.db import migrations, models


def backfill_step_sources(apps, schema_editor):
    StepLog = apps.get_model("core", "StepLog")
    for log in StepLog.objects.all().only("id", "steps_count", "sensor_steps"):
        if not log.sensor_steps and log.steps_count:
            log.sensor_steps = max(int(log.steps_count or 0), 0)
            log.save(update_fields=["sensor_steps"])


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0031_activitylog_source_session"),
    ]

    operations = [
        migrations.AddField(
            model_name="steplog",
            name="imported_adjustment_steps",
            field=models.IntegerField(default=0),
        ),
        migrations.AddField(
            model_name="steplog",
            name="installation_id",
            field=models.CharField(blank=True, default="", max_length=128),
        ),
        migrations.AddField(
            model_name="steplog",
            name="manual_adjustment_steps",
            field=models.IntegerField(default=0),
        ),
        migrations.AddField(
            model_name="steplog",
            name="measured_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="steplog",
            name="sensor_steps",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="steplog",
            name="sync_version",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="steplog",
            name="timezone",
            field=models.CharField(blank=True, default="", max_length=64),
        ),
        migrations.RunPython(backfill_step_sources, migrations.RunPython.noop),
    ]
