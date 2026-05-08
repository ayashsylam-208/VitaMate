from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0021_meallog_serving_label_snapshot"),
    ]

    operations = [
        migrations.AddField(
            model_name="conditionmedication",
            name="supplement_nutrient",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="supplement_medication_plans",
                to="core.nutrient",
            ),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="supplement_nutrient_amount",
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="conditionmedication",
            name="supplement_nutrient_unit",
            field=models.CharField(blank=True, max_length=30),
        ),
        migrations.AddField(
            model_name="usernutrienttarget",
            name="linked_medication",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="linked_nutrient_targets",
                to="core.conditionmedication",
            ),
        ),
        migrations.AddField(
            model_name="usernutrienttarget",
            name="note",
            field=models.TextField(blank=True),
        ),
    ]
