from django.conf import settings
from django.db import migrations, models


def _exercise_metadata(name: str, met_value: float) -> tuple[str, int, int]:
    lower = (name or "").lower()
    default_duration = 30
    icon_key = "fitness_center"
    sort_order = 50

    if "walk" in lower:
        icon_key = "directions_walk"
        default_duration = 30
        sort_order = 10
    elif "run" in lower or "jog" in lower:
        icon_key = "directions_run"
        default_duration = 20
        sort_order = 20
    elif "cycl" in lower:
        icon_key = "directions_bike"
        default_duration = 30
        sort_order = 30
    elif "box" in lower or "martial" in lower:
        icon_key = "sports_mma"
        default_duration = 20
        sort_order = 40
    elif "yoga" in lower or "pilates" in lower:
        icon_key = "self_improvement"
        default_duration = 25
        sort_order = 60
    elif "swim" in lower:
        icon_key = "pool"
        default_duration = 25
        sort_order = 70
    elif "weight" in lower or "bodyweight" in lower or "hiit" in lower:
        icon_key = "fitness_center"
        default_duration = 30
        sort_order = 80
    elif "dance" in lower:
        icon_key = "music_note"
        default_duration = 30
        sort_order = 90
    elif "row" in lower:
        icon_key = "rowing"
        default_duration = 25
        sort_order = 95

    return icon_key, default_duration, sort_order


def populate_exercise_metadata(apps, schema_editor):
    Exercise = apps.get_model("core", "Exercise")
    for exercise in Exercise.objects.all():
        icon_key, default_duration, sort_order = _exercise_metadata(
            exercise.name,
            float(exercise.met_value or 0),
        )
        moderate = round(float(exercise.met_value or 0), 1)
        light = round(max(moderate * 0.85, 1.5), 1)
        intense = round(max(moderate * 1.15, moderate), 1)
        exercise.icon_key = icon_key
        exercise.default_duration_minutes = default_duration
        exercise.met_light = light
        exercise.met_moderate = moderate
        exercise.met_intense = intense
        exercise.is_featured = sort_order <= 95
        exercise.sort_order = sort_order
        exercise.save(
            update_fields=[
                "icon_key",
                "default_duration_minutes",
                "met_light",
                "met_moderate",
                "met_intense",
                "is_featured",
                "sort_order",
            ]
        )


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0028_fooditem_meal_tags"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name="exercise",
            name="default_duration_minutes",
            field=models.PositiveIntegerField(default=30),
        ),
        migrations.AddField(
            model_name="exercise",
            name="icon_key",
            field=models.CharField(default="fitness_center", max_length=50),
        ),
        migrations.AddField(
            model_name="exercise",
            name="is_featured",
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name="exercise",
            name="met_intense",
            field=models.FloatField(default=0.0),
        ),
        migrations.AddField(
            model_name="exercise",
            name="met_light",
            field=models.FloatField(default=0.0),
        ),
        migrations.AddField(
            model_name="exercise",
            name="met_moderate",
            field=models.FloatField(default=0.0),
        ),
        migrations.AddField(
            model_name="exercise",
            name="sort_order",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.CreateModel(
            name="ActivitySession",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("running", "Running"),
                            ("paused", "Paused"),
                            ("completed", "Completed"),
                            ("cancelled", "Cancelled"),
                        ],
                        default="running",
                        max_length=20,
                    ),
                ),
                (
                    "source",
                    models.CharField(
                        choices=[("live", "Live"), ("guided", "Guided")],
                        default="live",
                        max_length=20,
                    ),
                ),
                (
                    "intensity",
                    models.CharField(
                        choices=[
                            ("light", "Light"),
                            ("moderate", "Moderate"),
                            ("intense", "Intense"),
                        ],
                        default="moderate",
                        max_length=20,
                    ),
                ),
                ("target_duration_seconds", models.PositiveIntegerField(default=1800)),
                ("actual_duration_seconds", models.PositiveIntegerField(default=0)),
                ("met_value_snapshot", models.FloatField(default=0.0)),
                ("estimated_calories", models.PositiveIntegerField(default=0)),
                ("calories_burned", models.PositiveIntegerField(default=0)),
                ("started_at", models.DateTimeField(auto_now_add=True)),
                ("paused_at", models.DateTimeField(blank=True, null=True)),
                ("ended_at", models.DateTimeField(blank=True, null=True)),
                ("total_paused_seconds", models.PositiveIntegerField(default=0)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("exercise", models.ForeignKey(on_delete=models.deletion.CASCADE, to="core.exercise")),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=models.deletion.CASCADE,
                        related_name="activity_sessions",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ["-started_at", "-id"],
            },
        ),
        migrations.AddIndex(
            model_name="activitysession",
            index=models.Index(fields=["user", "status"], name="core_actsess_user_status_idx"),
        ),
        migrations.AddIndex(
            model_name="activitysession",
            index=models.Index(fields=["user", "started_at"], name="core_actsess_user_started_idx"),
        ),
        migrations.RunPython(populate_exercise_metadata, migrations.RunPython.noop),
    ]
