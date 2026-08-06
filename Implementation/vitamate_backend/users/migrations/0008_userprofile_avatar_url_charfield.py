from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0007_manager_profile_fields"),
    ]

    operations = [
        migrations.AlterField(
            model_name="userprofile",
            name="avatar_url",
            field=models.CharField(blank=True, default="", max_length=500),
        ),
    ]
