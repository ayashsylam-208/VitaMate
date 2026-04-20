from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0011_chronic_conditions_v1_schema"),
    ]

    operations = [
        migrations.AddField(
            model_name="waterlog",
            name="beverage_name",
            field=models.CharField(blank=True, default="Water", max_length=100),
        ),
        migrations.AddField(
            model_name="waterlog",
            name="beverage_type",
            field=models.CharField(
                choices=[
                    ("water", "Water"),
                    ("tea", "Tea"),
                    ("coffee", "Coffee"),
                    ("juice", "Juice"),
                    ("smoothie", "Smoothie"),
                    ("other", "Other"),
                ],
                default="water",
                max_length=30,
            ),
        ),
    ]
