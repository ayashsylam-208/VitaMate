from django.db import migrations, models
import django.db.models.deletion


def backfill_source_sessions(apps, schema_editor):
    ActivityLog = apps.get_model("core", "ActivityLog")
    ActivitySession = apps.get_model("core", "ActivitySession")

    completed_sessions = ActivitySession.objects.filter(
        status="completed",
        ended_at__isnull=False,
        actual_duration_seconds__gt=0,
    ).order_by("id")

    for session in completed_sessions:
        if ActivityLog.objects.filter(source_session=session).exists():
            continue
        duration_minutes = max(1, round((session.actual_duration_seconds or 0) / 60))
        candidates = ActivityLog.objects.filter(
            user_id=session.user_id,
            exercise_id=session.exercise_id,
            source_session__isnull=True,
            date=session.ended_at.date(),
            duration_minutes=duration_minutes,
        ).order_by("id")
        if candidates.count() == 1:
            log = candidates.first()
            log.source_session_id = session.id
            log.save(update_fields=["source_session"])


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0030_remove_healthstatedelta_notification_candidates_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="activitylog",
            name="source_session",
            field=models.OneToOneField(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="final_activity_log",
                to="core.activitysession",
            ),
        ),
        migrations.RunPython(backfill_source_sessions, migrations.RunPython.noop),
    ]
