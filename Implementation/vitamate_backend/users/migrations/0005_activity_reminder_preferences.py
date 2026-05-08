import datetime

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0004_alter_userprofile_activity_level"),
    ]

    operations = [
        migrations.AddField(
            model_name="userprofile",
            name="activity_reminder_days",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="activity_reminder_time",
            field=models.TimeField(default=datetime.time(10, 0)),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="inactive_reminder_enabled",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="inactive_reminder_hours",
            field=models.IntegerField(default=3),
        ),
    ]
