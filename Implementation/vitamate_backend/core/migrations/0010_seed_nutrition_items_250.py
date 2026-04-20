import json
from pathlib import Path

from django.db import migrations


def seed_nutrition_items(apps, schema_editor):
    FoodItem = apps.get_model("core", "FoodItem")
    NutritionFacts = apps.get_model("core", "NutritionFacts")
    NutritionServingOption = apps.get_model("core", "NutritionServingOption")

    seed_path = Path(__file__).resolve().parent.parent / "data" / "nutrition_seed_250.json"
    items = json.loads(seed_path.read_text(encoding="utf-8"))

    for item in items:
        facts_data = item.pop("nutrition_facts")
        serving_options = item.pop("serving_options")

        food_defaults = {
            **item,
            "calories_100g": round(facts_data.get("calories_kcal") or 0),
            "protein_100g": facts_data.get("protein_g") or 0,
            "carbs_100g": facts_data.get("carbohydrates_g") or 0,
            "fat_100g": facts_data.get("fat_g") or 0,
            "fiber_100g": facts_data.get("fiber_g") or 0,
            "sugar_100g": facts_data.get("sugars_g") or 0,
            "sodium_mg_100g": facts_data.get("sodium_mg") or 0,
            "saturated_fat_100g": facts_data.get("saturated_fat_g") or 0,
            "trans_fat_100g": facts_data.get("trans_fat_g") or 0,
            "potassium_mg_100g": facts_data.get("potassium_mg") or 0,
            "cholesterol_mg_100g": facts_data.get("cholesterol_mg") or 0,
            "vitamin_c_mg_100g": facts_data.get("vitamin_c_mg") or 0,
        }
        food, created = FoodItem.objects.get_or_create(
            name=item["name"],
            defaults=food_defaults,
        )
        if not created:
            for field, value in food_defaults.items():
                if field != "name":
                    setattr(food, field, value)
            food.save()

        NutritionFacts.objects.update_or_create(
            food_item=food,
            defaults=facts_data,
        )

        for option in serving_options:
            defaults = option.copy()
            name = defaults.pop("name")
            NutritionServingOption.objects.update_or_create(
                food_item=food,
                name=name,
                defaults=defaults,
            )


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0009_nutritionfacts_nutritionservingoption_and_more"),
    ]

    operations = [
        migrations.RunPython(seed_nutrition_items, migrations.RunPython.noop),
    ]
