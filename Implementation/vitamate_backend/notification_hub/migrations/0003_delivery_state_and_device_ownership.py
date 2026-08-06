from django.db import migrations, models
import django.db.models.deletion
import notification_hub.models
from uuid import uuid4


def normalize_legacy_states(apps, schema_editor):
    Plan = apps.get_model("notification_hub", "NotificationPlan")
    Device = apps.get_model("notification_hub", "NotificationDevice")
    mappings = {
        "scheduled": "scheduled_local",
        "suppressed": "suppressed_by_policy",
        "failed": "delivery_failed",
    }
    for old, new in mappings.items():
        Plan.objects.filter(status=old).update(status=new)
    user_ids = Device.objects.filter(is_primary=True).values_list("user_id", flat=True).distinct()
    for user_id in user_ids:
        primary_ids = list(
            Device.objects.filter(user_id=user_id, is_primary=True)
            .order_by("-updated_at", "-id")
            .values_list("id", flat=True)
        )
        if len(primary_ids) > 1:
            Device.objects.filter(id__in=primary_ids[1:]).update(is_primary=False)


def populate_event_ids(apps, schema_editor):
    PlanEvent = apps.get_model("notification_hub", "NotificationPlanEvent")
    for event in PlanEvent.objects.filter(event_id="").only("id").iterator():
        event.event_id = uuid4().hex
        event.save(update_fields=["event_id"])


class Migration(migrations.Migration):
    dependencies = [("notification_hub", "0002_notificationpreferenceprofile_enable_habit_reminders")]

    operations = [
        migrations.AddField(model_name="notificationdevice", name="assignment_version", field=models.PositiveBigIntegerField(default=1)),
        migrations.AddField(model_name="notificationdevice", name="is_active", field=models.BooleanField(db_index=True, default=True)),
        migrations.AddField(model_name="notificationdevice", name="notifications_enabled_systemwide", field=models.BooleanField(default=False)),
        migrations.AddField(model_name="notificationdevice", name="permission_checked_at", field=models.DateTimeField(blank=True, null=True)),
        migrations.AddField(model_name="notificationdevice", name="permission_status", field=models.CharField(blank=True, default="unavailable", max_length=24)),
        migrations.AddField(model_name="notificationdevice", name="revoked_at", field=models.DateTimeField(blank=True, null=True)),
        migrations.AddField(model_name="notificationplan", name="acknowledged_at", field=models.DateTimeField(blank=True, null=True)),
        migrations.AddField(model_name="notificationplan", name="presented_at", field=models.DateTimeField(blank=True, null=True)),
        migrations.AddField(model_name="notificationplan", name="revision", field=models.PositiveIntegerField(default=1)),
        migrations.AddField(model_name="notificationplan", name="source_event_id", field=models.CharField(blank=True, default="", max_length=120)),
        migrations.AddField(model_name="notificationplan", name="source_event_type", field=models.CharField(blank=True, default="", max_length=80)),
        migrations.AlterField(model_name="notificationplan", name="status", field=models.CharField(choices=[("pending", "Pending"), ("planned", "Planned"), ("scheduled_local", "Scheduled locally"), ("presented_in_app", "Presented in app"), ("delivery_failed", "Delivery failed"), ("acknowledged", "Acknowledged"), ("dismissed", "Dismissed"), ("suppressed_by_policy", "Suppressed by policy"), ("cancelled", "Cancelled"), ("expired", "Expired"), ("delivered", "Delivered")], db_index=True, default="planned", max_length=24)),
        migrations.AddField(
            model_name="notificationplanevent",
            name="event_id",
            field=models.CharField(blank=True, default="", max_length=96),
        ),
        migrations.AddField(model_name="notificationplanevent", name="failure_code", field=models.CharField(blank=True, default="", max_length=80)),
        migrations.AddField(model_name="notificationplanevent", name="plan_revision", field=models.PositiveIntegerField(default=1)),
        migrations.AddField(model_name="notificationplanevent", name="suppression_reason", field=models.CharField(blank=True, default="", max_length=120)),
        migrations.AlterField(model_name="notificationplanevent", name="event_type", field=models.CharField(choices=[("scheduled_local", "Scheduled locally"), ("presented_in_app", "Presented in app"), ("delivery_failed", "Delivery failed"), ("acknowledged", "Acknowledged"), ("foreground_suppressed", "Foreground suppressed"), ("opened", "Opened"), ("dismissed", "Dismissed"), ("expired", "Expired"), ("suppressed_by_policy", "Suppressed by policy"), ("delivered", "Delivered"), ("schedule_failed", "Schedule failed"), ("cancelled_local", "Cancelled locally"), ("cancelled", "Cancelled")], db_index=True, max_length=32)),
        migrations.RunPython(normalize_legacy_states, migrations.RunPython.noop),
        migrations.RunPython(populate_event_ids, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="notificationplanevent",
            name="event_id",
            field=models.CharField(
                db_index=True,
                default=notification_hub.models._event_id,
                max_length=96,
                unique=True,
            ),
        ),
        migrations.AddConstraint(model_name="notificationdevice", constraint=models.UniqueConstraint(condition=models.Q(("is_active", True), ("is_primary", True), ("revoked_at__isnull", True)), fields=("user",), name="unique_active_primary_notification_device")),
    ]
