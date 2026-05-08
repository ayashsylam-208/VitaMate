from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0025_backfill_omelette_micronutrients"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="SleepPlan",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("plan_date", models.DateField(db_index=True)),
                ("planned_bed_time", models.DateTimeField()),
                ("latest_wake_time", models.DateTimeField()),
                ("flexibility_minutes", models.PositiveSmallIntegerField(default=0)),
                ("wake_window_start", models.DateTimeField()),
                ("wake_window_end", models.DateTimeField()),
                ("questionnaire", models.JSONField(blank=True, default=dict)),
                ("tracker_factors", models.JSONField(blank=True, default=dict)),
                ("estimated_sleep_start", models.DateTimeField()),
                ("wake_options", models.JSONField(blank=True, default=list)),
                ("selected_wake_time", models.DateTimeField(blank=True, null=True)),
                ("recommendation_reason", models.TextField(blank=True)),
                (
                    "primary_negative_factor",
                    models.CharField(
                        choices=[
                            ("none", "None"),
                            ("late_caffeine", "Late caffeine"),
                            ("late_heavy_meal", "Late heavy meal"),
                            ("high_stress", "High stress"),
                            ("high_screen", "High screen use"),
                            ("late_nap", "Late nap"),
                            ("late_intense_exercise", "Late intense exercise"),
                            ("low_activity", "Low activity"),
                        ],
                        default="none",
                        max_length=40,
                    ),
                ),
                ("night_tip", models.TextField(blank=True)),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("active", "Active"),
                            ("cancelled", "Cancelled"),
                            ("completed", "Completed"),
                        ],
                        default="active",
                        max_length=20,
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="sleep_plans",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ["-planned_bed_time", "-id"],
            },
        ),
        migrations.CreateModel(
            name="SleepMorningFeedback",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("quality_rating", models.PositiveSmallIntegerField()),
                (
                    "wake_feeling",
                    models.CharField(
                        choices=[
                            ("rested", "Rested"),
                            ("okay", "Okay"),
                            ("groggy", "Groggy"),
                            ("exhausted", "Exhausted"),
                        ],
                        max_length=20,
                    ),
                ),
                ("focus_rating", models.PositiveSmallIntegerField()),
                ("disruptor", models.CharField(blank=True, max_length=40)),
                ("actual_sleep_start", models.DateTimeField(blank=True, null=True)),
                ("actual_wake_time", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "plan",
                    models.OneToOneField(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="morning_feedback",
                        to="core.sleepplan",
                    ),
                ),
                (
                    "sleep_log",
                    models.OneToOneField(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="coach_feedback",
                        to="core.sleeplog",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="sleep_feedback",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ["-created_at", "-id"],
            },
        ),
        migrations.AddIndex(
            model_name="sleepplan",
            index=models.Index(fields=["user", "plan_date", "status"], name="core_sleepp_user_id_9f3ac5_idx"),
        ),
        migrations.AddIndex(
            model_name="sleepplan",
            index=models.Index(fields=["user", "selected_wake_time"], name="core_sleepp_user_id_32d7b0_idx"),
        ),
        migrations.AddIndex(
            model_name="sleepmorningfeedback",
            index=models.Index(fields=["user", "created_at"], name="core_sleepm_user_id_50301c_idx"),
        ),
        migrations.AddIndex(
            model_name="sleepmorningfeedback",
            index=models.Index(fields=["user", "quality_rating"], name="core_sleepm_user_id_e6a6f4_idx"),
        ),
    ]
