from django.db import migrations, models


def normalize_user_emails(apps, schema_editor):
    User = apps.get_model("auth", "User")
    seen = set()
    for user in User.objects.order_by("id"):
        email = (user.email or "").strip().lower()
        if email:
            base = email
            if email in seen and "@" in email:
                local, domain = email.split("@", 1)
                email = f"{local}+dup{user.id}@{domain}"
            elif email in seen:
                email = f"{email}+dup{user.id}"
            seen.add(email)
        if user.email != email:
            user.email = email
            user.save(update_fields=["email"])


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0006_userprofile_enable_motivation_reminders"),
    ]

    operations = [
        migrations.AddField(
            model_name="userprofile",
            name="avatar_url",
            field=models.URLField(blank=True, default=""),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="email_verified",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="gender_confirmed",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="pending_email",
            field=models.EmailField(blank=True, default="", max_length=254),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="preferred_language",
            field=models.CharField(default="English", max_length=40),
        ),
        migrations.AddField(
            model_name="userprofile",
            name="region",
            field=models.CharField(default="Romania", max_length=80),
        ),
        migrations.AlterField(
            model_name="userprofile",
            name="gender",
            field=models.CharField(choices=[("F", "Female"), ("M", "Male"), ("O", "Other")], max_length=1),
        ),
        migrations.RunPython(normalize_user_emails, migrations.RunPython.noop),
        migrations.RunSQL(
            sql=(
                "CREATE UNIQUE INDEX IF NOT EXISTS unique_auth_user_email_ci_nonblank "
                "ON auth_user (LOWER(email)) WHERE email <> '';"
            ),
            reverse_sql="DROP INDEX IF EXISTS unique_auth_user_email_ci_nonblank;",
        ),
    ]
