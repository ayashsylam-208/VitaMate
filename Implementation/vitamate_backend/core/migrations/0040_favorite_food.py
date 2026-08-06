from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0039_integration_outbox_event"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="FavoriteFood",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("food_item", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="favorited_by", to="core.fooditem")),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="favorite_foods", to=settings.AUTH_USER_MODEL)),
            ],
            options={"ordering": ("-created_at", "-id")},
        ),
        migrations.AddConstraint(
            model_name="favoritefood",
            constraint=models.UniqueConstraint(fields=("user", "food_item"), name="unique_user_favorite_food"),
        ),
        migrations.AddIndex(
            model_name="favoritefood",
            index=models.Index(fields=["user", "created_at"], name="favorite_food_user_created_idx"),
        ),
    ]
