from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0022_micronutrient_tracking"),
    ]

    operations = [
        migrations.AddField(
            model_name="usernutrienttarget",
            name="calculation_basis",
            field=models.CharField(blank=True, max_length=40),
        ),
        migrations.AddField(
            model_name="usernutrienttarget",
            name="clinician_recommended_value",
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="usernutrienttarget",
            name="current_medication_dose",
            field=models.CharField(blank=True, max_length=80),
        ),
        migrations.AddField(
            model_name="usernutrienttarget",
            name="current_medication_name",
            field=models.CharField(blank=True, max_length=120),
        ),
        migrations.AddField(
            model_name="usernutrienttarget",
            name="lab_reference_max",
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="usernutrienttarget",
            name="lab_reference_min",
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="usernutrienttarget",
            name="lab_test_date",
            field=models.DateField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="usernutrienttarget",
            name="lab_test_name",
            field=models.CharField(blank=True, max_length=120),
        ),
        migrations.AddField(
            model_name="usernutrienttarget",
            name="lab_unit",
            field=models.CharField(blank=True, max_length=30),
        ),
        migrations.AddField(
            model_name="usernutrienttarget",
            name="lab_value",
            field=models.FloatField(blank=True, null=True),
        ),
    ]
