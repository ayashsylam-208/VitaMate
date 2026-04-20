# Generated manually to extend the chronic-condition schema without rewriting earlier migrations.

import django.db.models.deletion
import django.utils.timezone
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0005_seed_chronic_condition_catalog"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name="conditionmedication",
            name="created_at",
            field=models.DateTimeField(auto_now_add=True, default=django.utils.timezone.now),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="dosage_amount",
            field=models.CharField(blank=True, max_length=40),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="dosage_unit",
            field=models.CharField(blank=True, max_length=40),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="end_date",
            field=models.DateField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="recurrence_pattern",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="relation_to_meal",
            field=models.CharField(
                choices=[
                    ("before_meal", "Before meal"),
                    ("with_meal", "With meal"),
                    ("after_meal", "After meal"),
                    ("anytime", "Anytime"),
                ],
                default="anytime",
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="reminder_enabled",
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="reminder_lead_minutes",
            field=models.PositiveSmallIntegerField(default=15),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="scientific_name",
            field=models.CharField(blank=True, max_length=100),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="start_date",
            field=models.DateField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="updated_at",
            field=models.DateTimeField(auto_now=True, default=django.utils.timezone.now),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name="conditionmedicationlog",
            name="created_at",
            field=models.DateTimeField(auto_now_add=True, default=django.utils.timezone.now),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name="conditionmedicationlog",
            name="points_applied",
            field=models.IntegerField(default=0),
        ),
        migrations.AddField(
            model_name="conditionmedicationlog",
            name="scheduled_for",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="conditionmedicationlog",
            name="skip_reason",
            field=models.CharField(blank=True, max_length=255),
        ),
        migrations.AddField(
            model_name="conditionmedicationschedule",
            name="recurrence_days",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="healthrestriction",
            name="effective_date",
            field=models.DateField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="healthrestriction",
            name="is_default",
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name="healthrestriction",
            name="notes",
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name="healthrestriction",
            name="source_label",
            field=models.CharField(blank=True, max_length=255),
        ),
        migrations.AddField(
            model_name="healthrestriction",
            name="source_version",
            field=models.CharField(blank=True, max_length=50),
        ),
        migrations.AddField(
            model_name="healthtarget",
            name="priority",
            field=models.PositiveSmallIntegerField(default=3),
        ),
        migrations.AddField(
            model_name="healthtarget",
            name="source_type",
            field=models.CharField(
                choices=[
                    ("computed_condition_rule", "Computed condition rule"),
                    ("physician_override", "Physician override"),
                    ("user_custom", "User custom"),
                ],
                default="computed_condition_rule",
                max_length=30,
            ),
        ),
        migrations.AlterField(
            model_name="usercondition",
            name="diagnosis_date",
            field=models.DateField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="usercondition",
            name="created_at",
            field=models.DateTimeField(auto_now_add=True, default=django.utils.timezone.now),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name="usercondition",
            name="is_active",
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name="usercondition",
            name="updated_at",
            field=models.DateTimeField(auto_now=True, default=django.utils.timezone.now),
            preserve_default=False,
        ),
        migrations.AlterField(
            model_name="usercondition",
            name="status",
            field=models.CharField(
                choices=[
                    ("active", "Active"),
                    ("controlled", "Controlled"),
                    ("needs_attention", "Needs attention"),
                    ("inactive", "Inactive"),
                ],
                default="active",
                max_length=20,
            ),
        ),
        migrations.AddConstraint(
            model_name="usercondition",
            constraint=models.UniqueConstraint(
                condition=models.Q(is_active=True),
                fields=("user", "condition_type"),
                name="unique_active_condition_per_user_type",
            ),
        ),
        migrations.CreateModel(
            name="ConditionRuleProfile",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("severity_code", models.CharField(blank=True, max_length=50)),
                ("rule_key", models.CharField(max_length=80)),
                ("rule_value", models.CharField(max_length=120)),
                ("rule_unit", models.CharField(blank=True, max_length=40)),
                ("source_label", models.CharField(blank=True, max_length=255)),
                ("source_version", models.CharField(blank=True, max_length=50)),
                ("effective_date", models.DateField(blank=True, null=True)),
                ("notes", models.TextField(blank=True)),
                ("is_default", models.BooleanField(default=True)),
                (
                    "condition_type",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="rule_profiles",
                        to="core.conditiontype",
                    ),
                ),
            ],
            options={
                "ordering": ("condition_type__name", "severity_code", "rule_key"),
            },
        ),
        migrations.CreateModel(
            name="ConditionPointsAudit",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                (
                    "event_type",
                    models.CharField(
                        choices=[
                            ("medication", "Medication"),
                            ("restriction", "Restriction"),
                            ("streak", "Streak"),
                            ("system", "System"),
                        ],
                        max_length=20,
                    ),
                ),
                ("points_delta", models.IntegerField()),
                ("reason", models.CharField(max_length=255)),
                ("explanation", models.TextField(blank=True)),
                ("metadata", models.JSONField(blank=True, default=dict)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "medication_log",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="points_audit",
                        to="core.conditionmedicationlog",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="condition_points_audit",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                (
                    "user_condition",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="points_audit",
                        to="core.usercondition",
                    ),
                ),
            ],
            options={
                "ordering": ("-created_at", "-id"),
            },
        ),
    ]
