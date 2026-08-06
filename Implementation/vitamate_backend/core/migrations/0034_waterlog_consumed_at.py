from datetime import datetime, time

from django.db import migrations, models
from django.utils import timezone


def backfill_consumed_at(apps, schema_editor):
    WaterLog = apps.get_model("core", "WaterLog")
    current_tz = timezone.get_current_timezone()
    for log in WaterLog.objects.filter(consumed_at__isnull=True).only("id", "date"):
        log_date = log.date or timezone.localdate()
        log.consumed_at = timezone.make_aware(
            datetime.combine(log_date, time.min),
            current_tz,
        )
        log.save(update_fields=["consumed_at"])


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0033_meallog_correlation_id_meallog_is_fast_food_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="waterlog",
            name="consumed_at",
            field=models.DateTimeField(
                db_index=True,
                null=True,
            ),
        ),
        migrations.RunPython(backfill_consumed_at, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="waterlog",
            name="consumed_at",
            field=models.DateTimeField(
                db_index=True,
                default=timezone.now,
            ),
        ),
        migrations.AddIndex(
            model_name="waterlog",
            index=models.Index(
                fields=["user", "consumed_at"],
                name="water_log_consumed_at_idx",
            ),
        ),
        migrations.AlterField(
            model_name="waterlog",
            name="beverage_type",
            field=models.CharField(
                choices=[
                    ("water", "Water"),
                    ("tea", "Tea"),
                    ("coffee", "Coffee"),
                    ("juice", "Juice"),
                    ("milk", "Milk"),
                    ("soda", "Soda"),
                    ("smoothie", "Smoothie"),
                    ("other", "Other"),
                ],
                default="water",
                max_length=30,
            ),
        ),
    ]
