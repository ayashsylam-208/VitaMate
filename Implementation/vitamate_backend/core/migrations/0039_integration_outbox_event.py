from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0038_nutrition_catalog_constraints"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="IntegrationOutboxEvent",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("event_type", models.CharField(db_index=True, max_length=64)),
                ("dedupe_key", models.CharField(max_length=160, unique=True)),
                ("payload", models.JSONField(blank=True, default=dict)),
                ("status", models.CharField(choices=[("pending", "Pending"), ("processing", "Processing"), ("processed", "Processed"), ("failed", "Failed")], db_index=True, default="pending", max_length=16)),
                ("attempts", models.PositiveSmallIntegerField(default=0)),
                ("last_error", models.TextField(blank=True, default="")),
                ("created_at", models.DateTimeField(db_index=True, default=django.utils.timezone.now)),
                ("processed_at", models.DateTimeField(blank=True, null=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="integration_outbox_events", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ("created_at", "id")},
        ),
        migrations.AddIndex(
            model_name="integrationoutboxevent",
            index=models.Index(fields=["status", "created_at"], name="integration_outbox_pending_idx"),
        ),
    ]

