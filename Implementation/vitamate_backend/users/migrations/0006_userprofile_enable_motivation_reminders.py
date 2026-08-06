from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0005_activity_reminder_preferences"),
    ]

    operations = [
        migrations.AddField(
            model_name="userprofile",
            name="enable_motivation_reminders",
            field=models.BooleanField(default=True),
        ),
    ]
