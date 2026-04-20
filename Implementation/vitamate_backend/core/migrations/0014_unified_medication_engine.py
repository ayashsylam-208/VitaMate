from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


def forward_populate_medication_engine(apps, schema_editor):
    ConditionMedication = apps.get_model("core", "ConditionMedication")
    ConditionMedicationSchedule = apps.get_model("core", "ConditionMedicationSchedule")
    ConditionMedicationLog = apps.get_model("core", "ConditionMedicationLog")

    for medication in ConditionMedication.objects.select_related("user_condition"):
        if medication.user_condition_id and not medication.user_id:
            medication.user_id = medication.user_condition.user_id
        if not medication.display_name:
            medication.display_name = medication.name
        if not medication.source_type:
            medication.source_type = "condition" if medication.user_condition_id else "manual"
        medication.save(update_fields=["user", "display_name", "source_type"])

    for schedule in ConditionMedicationSchedule.objects.all():
        changed = []
        if not schedule.days_of_week:
            schedule.days_of_week = schedule.recurrence_days or []
            changed.append("days_of_week")
        if not schedule.meal_relation:
            schedule.meal_relation = "none"
            changed.append("meal_relation")
        if changed:
            schedule.save(update_fields=changed)

    for log in ConditionMedicationLog.objects.select_related("schedule", "schedule__medication"):
        changed = []
        if log.schedule_id and not log.medication_id:
            log.medication_id = log.schedule.medication_id
            changed.append("medication")
        if changed:
            log.save(update_fields=changed)


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("core", "0013_fooditem_created_by_waterlog_links"),
    ]

    operations = [
        migrations.AddField(
            model_name="conditionmedication",
            name="adherence_mode",
            field=models.CharField(
                choices=[("strict", "Strict"), ("flexible", "Flexible")],
                default="strict",
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="display_name",
            field=models.CharField(blank=True, max_length=100),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="form",
            field=models.CharField(blank=True, max_length=40),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="is_prn",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="medicine",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="condition_medication_plans",
                to="core.medicine",
            ),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="source_type",
            field=models.CharField(
                choices=[("manual", "Manual"), ("condition", "Condition")],
                default="condition",
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="timezone",
            field=models.CharField(default="UTC", max_length=64),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="user",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="medication_plans",
                to=settings.AUTH_USER_MODEL,
            ),
        ),
        migrations.AddField(
            model_name="conditionmedicationschedule",
            name="days_of_week",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="conditionmedicationschedule",
            name="grace_period_minutes",
            field=models.PositiveSmallIntegerField(default=60),
        ),
        migrations.AddField(
            model_name="conditionmedicationschedule",
            name="interval_hours",
            field=models.PositiveSmallIntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="conditionmedicationschedule",
            name="is_active",
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name="conditionmedicationschedule",
            name="meal_relation",
            field=models.CharField(
                choices=[
                    ("before_meal", "Before meal"),
                    ("after_meal", "After meal"),
                    ("with_food", "With food"),
                    ("none", "None"),
                ],
                default="none",
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="conditionmedicationschedule",
            name="schedule_type",
            field=models.CharField(
                choices=[
                    ("daily", "Daily"),
                    ("specific_days", "Specific days"),
                    ("interval", "Interval"),
                    ("as_needed", "As needed"),
                ],
                default="daily",
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="conditionmedicationschedule",
            name="snooze_default_minutes",
            field=models.PositiveSmallIntegerField(default=15),
        ),
        migrations.AddField(
            model_name="conditionmedicationlog",
            name="action_source",
            field=models.CharField(
                choices=[("user", "User"), ("system", "System")],
                default="system",
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="conditionmedicationlog",
            name="adherence_credit",
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=5, null=True),
        ),
        migrations.AddField(
            model_name="conditionmedicationlog",
            name="dose_taken_amount",
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=8, null=True),
        ),
        migrations.AddField(
            model_name="conditionmedicationlog",
            name="medication",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="dose_logs",
                to="core.conditionmedication",
            ),
        ),
        migrations.AddField(
            model_name="conditionmedicationlog",
            name="notes",
            field=models.CharField(blank=True, max_length=255),
        ),
        migrations.AddField(
            model_name="conditionmedicationlog",
            name="snoozed_until",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="conditionmedicationlog",
            name="updated_at",
            field=models.DateTimeField(auto_now=True, default=django.utils.timezone.now),
            preserve_default=False,
        ),
        migrations.AlterField(
            model_name="conditionmedication",
            name="user_condition",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="medications",
                to="core.usercondition",
            ),
        ),
        migrations.AlterField(
            model_name="conditionmedicationlog",
            name="schedule",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="logs",
                to="core.conditionmedicationschedule",
            ),
        ),
        migrations.AlterField(
            model_name="conditionmedicationlog",
            name="status",
            field=models.CharField(
                choices=[
                    ("pending", "Pending"),
                    ("taken", "Taken"),
                    ("overdue", "Overdue"),
                    ("snoozed", "Snoozed"),
                    ("taken_on_time", "Taken on time"),
                    ("taken_late", "Taken late"),
                    ("missed", "Missed"),
                    ("skipped", "Skipped"),
                ],
                default="pending",
                max_length=20,
            ),
        ),
        migrations.RunPython(forward_populate_medication_engine, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="conditionmedication",
            name="user",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="medication_plans",
                to=settings.AUTH_USER_MODEL,
            ),
        ),
        migrations.AddConstraint(
            model_name="conditionmedicationschedule",
            constraint=models.UniqueConstraint(
                condition=models.Q(is_active=True),
                fields=("medication", "schedule_type", "time_of_day", "interval_hours"),
                name="unique_active_med_schedule_time",
            ),
        ),
        migrations.AddConstraint(
            model_name="conditionmedicationlog",
            constraint=models.UniqueConstraint(
                fields=("medication", "scheduled_for"),
                name="unique_medication_scheduled_for",
            ),
        ),
    ]
