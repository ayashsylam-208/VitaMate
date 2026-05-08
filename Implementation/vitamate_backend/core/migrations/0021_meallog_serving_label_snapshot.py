from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0020_alter_activitylog_avg_speed_kmh_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="meallog",
            name="serving_label_snapshot",
            field=models.CharField(blank=True, default="", max_length=80),
        ),
    ]
