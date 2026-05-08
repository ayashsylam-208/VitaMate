from django.db import migrations


OMELETTE_FACTS = {
    "sugars_g": 1.5,
    "fiber_g": 0.8,
    "saturated_fat_g": 3.0,
    "trans_fat_g": 0.0,
    "cholesterol_mg": 260.0,
    "sodium_mg": 270.0,
    "potassium_mg": 170.0,
    "calcium_mg": 65.0,
    "iron_mg": 1.7,
    "magnesium_mg": 15.0,
    "zinc_mg": 1.3,
    "phosphorus_mg": 180.0,
    "vitamin_a_mcg": 160.0,
    "vitamin_c_mg": 4.0,
    "vitamin_d_mcg": 1.3,
    "vitamin_b12_mcg": 0.9,
    "folate_mcg": 45.0,
    "monounsaturated_fat_g": 4.0,
    "polyunsaturated_fat_g": 1.3,
    "added_sugars_g": 0.0,
    "water_g": 74.0,
    "caffeine_mg": 0.0,
    "vitamin_e_mg": 1.1,
    "vitamin_k_mcg": 9.0,
    "vitamin_b1_mg": 0.05,
    "vitamin_b2_mg": 0.35,
    "vitamin_b3_mg": 0.1,
    "vitamin_b6_mg": 0.12,
}

LEGACY_FIELDS = {
    "sugar_100g": OMELETTE_FACTS["sugars_g"],
    "fiber_100g": OMELETTE_FACTS["fiber_g"],
    "sodium_mg_100g": OMELETTE_FACTS["sodium_mg"],
    "saturated_fat_100g": OMELETTE_FACTS["saturated_fat_g"],
    "trans_fat_100g": OMELETTE_FACTS["trans_fat_g"],
    "potassium_mg_100g": OMELETTE_FACTS["potassium_mg"],
    "cholesterol_mg_100g": OMELETTE_FACTS["cholesterol_mg"],
    "vitamin_c_mg_100g": OMELETTE_FACTS["vitamin_c_mg"],
}

SNAPSHOT_FIELDS = [
    "calories_kcal",
    "protein_g",
    "carbohydrates_g",
    "sugars_g",
    "fiber_g",
    "fat_g",
    "saturated_fat_g",
    "trans_fat_g",
    "cholesterol_mg",
    "sodium_mg",
    "potassium_mg",
    "calcium_mg",
    "iron_mg",
    "magnesium_mg",
    "zinc_mg",
    "phosphorus_mg",
    "vitamin_a_mcg",
    "vitamin_c_mg",
    "vitamin_d_mcg",
    "vitamin_b12_mcg",
    "folate_mcg",
    "monounsaturated_fat_g",
    "polyunsaturated_fat_g",
    "added_sugars_g",
    "water_g",
    "caffeine_mg",
    "vitamin_e_mg",
    "vitamin_k_mcg",
    "vitamin_b1_mg",
    "vitamin_b2_mg",
    "vitamin_b3_mg",
    "vitamin_b6_mg",
]


def backfill_omelette_micronutrients(apps, schema_editor):
    FoodItem = apps.get_model("core", "FoodItem")
    NutritionFacts = apps.get_model("core", "NutritionFacts")
    MealLog = apps.get_model("core", "MealLog")

    food = FoodItem.objects.filter(name__iexact="Veggie Omelette").first()
    if food is None:
        return

    for field, value in LEGACY_FIELDS.items():
        setattr(food, field, value)
    food.save(update_fields=list(LEGACY_FIELDS.keys()))

    facts, _ = NutritionFacts.objects.get_or_create(
        food_item=food,
        defaults={
            "basis_type": "per_100g",
            "basis_value": 100,
            "basis_amount": 100,
            "basis_unit": "g",
            "serving_size": food.serving_grams or 100,
            "serving_unit": "g",
            "calories_kcal": food.calories_100g or 0,
            "protein_g": food.protein_100g or 0,
            "carbohydrates_g": food.carbs_100g or 0,
            "fat_g": food.fat_100g or 0,
        },
    )
    for field, value in OMELETTE_FACTS.items():
        setattr(facts, field, value)
    facts.source_name = "VitaMate estimated omelette profile"
    facts.source_reference = "seed:veggie-omelette-micronutrients"
    facts.confidence_score = 0.72
    facts.save(
        update_fields=[
            *OMELETTE_FACTS.keys(),
            "source_name",
            "source_reference",
            "confidence_score",
            "updated_at",
        ]
    )

    per_100g = {
        "calories_kcal": float(food.calories_100g or 0),
        "protein_g": float(food.protein_100g or 0),
        "carbohydrates_g": float(food.carbs_100g or 0),
        "fat_g": float(food.fat_100g or 0),
        **OMELETTE_FACTS,
    }
    for meal in MealLog.objects.filter(food=food):
        grams = meal.grams_consumed or meal.quantity_grams or 0
        if not grams and meal.servings_consumed:
            grams = float(meal.servings_consumed or 0) * float(food.serving_grams or 100)
        factor = float(grams or 0) / 100.0
        update_fields = []
        for field in SNAPSHOT_FIELDS:
            snapshot_field = f"snapshot_{field}"
            setattr(meal, snapshot_field, float(per_100g.get(field, 0) or 0) * factor)
            update_fields.append(snapshot_field)
        meal.save(update_fields=update_fields)


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0024_drop_user_nutrient_target_lab_percent_columns"),
    ]

    operations = [
        migrations.RunPython(
            backfill_omelette_micronutrients,
            reverse_code=migrations.RunPython.noop,
        ),
    ]
