from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("ai_meals", "0001_initial")]

    operations = [
        migrations.AddField(
            model_name="mealanalysissession",
            name="analysis_key",
            field=models.CharField(blank=True, default="", max_length=120),
        ),
        migrations.AddConstraint(
            model_name="mealanalysissession",
            constraint=models.UniqueConstraint(
                condition=~models.Q(analysis_key=""),
                fields=("user", "analysis_key"),
                name="unique_user_ai_analysis_key",
            ),
        ),
    ]
