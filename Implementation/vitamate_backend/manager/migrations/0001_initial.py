from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="AccountDeletionRequest",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("status", models.CharField(choices=[("requested", "Requested"), ("cancelled", "Cancelled"), ("completed", "Completed")], default="requested", max_length=16)),
                ("reason", models.CharField(blank=True, default="", max_length=240)),
                ("requested_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("grace_period_ends_at", models.DateTimeField()),
                ("resolved_at", models.DateTimeField(blank=True, null=True)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="account_deletion_requests", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ("-requested_at", "-id"),
            },
        ),
        migrations.CreateModel(
            name="HealthGoalOverride",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("key", models.CharField(choices=[("nutrition", "Nutrition"), ("hydration", "Hydration"), ("steps", "Steps"), ("active_time", "Active time"), ("sleep", "Sleep"), ("weight", "Weight"), ("habits", "Habits")], max_length=40)),
                ("custom_value", models.FloatField()),
                ("unit", models.CharField(blank=True, default="", max_length=24)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="manager_goal_overrides", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ("key",),
            },
        ),
        migrations.CreateModel(
            name="PrivacyExportRequest",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("status", models.CharField(choices=[("queued", "Queued"), ("ready", "Ready"), ("failed", "Failed")], default="queued", max_length=16)),
                ("payload", models.JSONField(blank=True, default=dict)),
                ("requested_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("completed_at", models.DateTimeField(blank=True, null=True)),
                ("expires_at", models.DateTimeField(blank=True, null=True)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="privacy_export_requests", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ("-requested_at", "-id"),
            },
        ),
        migrations.AddIndex(
            model_name="accountdeletionrequest",
            index=models.Index(fields=["user", "status"], name="mgr_delete_user_status_idx"),
        ),
        migrations.AddConstraint(
            model_name="healthgoaloverride",
            constraint=models.UniqueConstraint(fields=("user", "key"), name="unique_manager_goal_override"),
        ),
    ]
