from django.db import migrations, models


MEAL_KEYWORDS = {
    "breakfast": [
        "breakfast",
        "oat",
        "egg",
        "omelette",
        "omelet",
        "labneh",
        "foul",
        "ful",
        "manakish",
        "zaatar",
        "pancake",
        "yogurt",
        "milk",
    ],
    "lunch": [
        "rice",
        "kabsa",
        "maqluba",
        "mansaf",
        "chicken",
        "beef",
        "fish",
        "stew",
        "pasta",
        "lunch",
        "meat",
        "lentil",
    ],
    "dinner": [
        "soup",
        "salad",
        "sandwich",
        "shawarma",
        "kebab",
        "grilled",
        "dinner",
        "fish",
        "chicken",
        "tuna",
        "hummus",
    ],
    "snack": [
        "snack",
        "fruit",
        "nuts",
        "cracker",
        "chips",
        "yogurt",
        "apple",
        "banana",
    ],
    "dessert": [
        "dessert",
        "cake",
        "cookie",
        "ice cream",
        "chocolate",
        "baklava",
        "knafeh",
        "maamoul",
        "pudding",
        "sweet",
    ],
}


def backfill_meal_tags(apps, schema_editor):
    FoodItem = apps.get_model("core", "FoodItem")
    for item in FoodItem.objects.all().iterator():
        if item.item_type in {"beverage", "drink"}:
            item.meal_tags = "drink"
            item.save(update_fields=["meal_tags"])
            continue

        haystack = " ".join(
            part
            for part in [
                item.name or "",
                item.category or "",
                getattr(item.primary_category, "name", "") if item.primary_category_id else "",
                getattr(item.primary_category, "code", "") if item.primary_category_id else "",
            ]
            if part
        ).lower()
        tags = []
        for tag, keywords in MEAL_KEYWORDS.items():
            if any(keyword in haystack for keyword in keywords):
                tags.append(tag)
        if not tags:
            tags = ["lunch", "dinner"]
        item.meal_tags = ",".join(dict.fromkeys(tags))
        item.save(update_fields=["meal_tags"])


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0027_unhealthyhabit_unhealthyhabitbaseline_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="fooditem",
            name="meal_tags",
            field=models.CharField(
                blank=True,
                db_index=True,
                default="",
                help_text="Comma-separated meal slots such as breakfast,lunch,dinner,snack,dessert,drink.",
                max_length=140,
            ),
        ),
        migrations.RunPython(backfill_meal_tags, migrations.RunPython.noop),
    ]
