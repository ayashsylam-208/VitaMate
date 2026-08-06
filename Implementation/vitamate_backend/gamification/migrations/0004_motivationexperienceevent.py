from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):
    dependencies = [
        ("gamification", "0003_pointstransaction_event_type_and_more"),
    ]

    operations = [
        migrations.CreateModel(
            name="MotivationExperienceEvent",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                (
                    "event_type",
                    models.CharField(
                        choices=[
                            ("points_awarded", "Points awarded"),
                            ("mission_completed", "Mission completed"),
                            ("badge_earned", "Badge earned"),
                            ("level_up", "Level up"),
                            ("streak_milestone", "Streak milestone"),
                        ],
                        db_index=True,
                        max_length=32,
                    ),
                ),
                ("title", models.CharField(max_length=120)),
                ("subtitle", models.CharField(blank=True, default="", max_length=240)),
                ("points_delta", models.IntegerField(default=0)),
                ("animation", models.CharField(blank=True, default="burst", max_length=32)),
                ("route", models.CharField(blank=True, default="", max_length=64)),
                ("metadata", models.JSONField(blank=True, default=dict)),
                ("dedupe_key", models.CharField(db_index=True, max_length=191, unique=True)),
                ("is_acknowledged", models.BooleanField(db_index=True, default=False)),
                ("acknowledged_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(db_index=True, default=django.utils.timezone.now)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="motivation_experience_events",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ("-created_at", "-id"),
            },
        ),
        migrations.AddIndex(
            model_name="motivationexperienceevent",
            index=models.Index(
                fields=("user", "is_acknowledged", "created_at"),
                name="motivation_event_user_ack_idx",
            ),
        ),
        migrations.AddIndex(
            model_name="motivationexperienceevent",
            index=models.Index(
                fields=("user", "event_type", "created_at"),
                name="motivation_event_user_type_idx",
            ),
        ),
    ]
