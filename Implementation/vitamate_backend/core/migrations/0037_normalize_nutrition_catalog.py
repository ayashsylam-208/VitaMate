from django.db import migrations
from django.db.models import Count


NUTRIENT_FIELDS = (
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
)


def _merge_global_duplicates(apps):
    FoodItem = apps.get_model("core", "FoodItem")
    FoodItemAlias = apps.get_model("core", "FoodItemAlias")
    ItemNutrientValue = apps.get_model("core", "ItemNutrientValue")
    MealLog = apps.get_model("core", "MealLog")
    MealLogComponent = apps.get_model("core", "MealLogComponent")
    NutritionFacts = apps.get_model("core", "NutritionFacts")
    NutritionServingOption = apps.get_model("core", "NutritionServingOption")
    WaterLog = apps.get_model("core", "WaterLog")

    duplicate_names = (
        FoodItem.objects.filter(created_by_id__isnull=True)
        .exclude(normalized_name="")
        .values("normalized_name")
        .annotate(total=Count("id"))
        .filter(total__gt=1)
    )
    for row in duplicate_names:
        items = list(
            FoodItem.objects.filter(
                created_by_id__isnull=True,
                normalized_name=row["normalized_name"],
            ).order_by("-is_active", "-is_verified", "id")
        )
        canonical = items[0]
        for duplicate in items[1:]:
            MealLog.objects.filter(food_id=duplicate.id).update(food_id=canonical.id)
            MealLogComponent.objects.filter(food_item_id=duplicate.id).update(
                food_item_id=canonical.id
            )
            WaterLog.objects.filter(food_item_id=duplicate.id).update(
                food_item_id=canonical.id
            )
            WaterLog.objects.filter(drink_item_id=duplicate.id).update(
                drink_item_id=canonical.id
            )

            duplicate_facts = NutritionFacts.objects.filter(food_item_id=duplicate.id).first()
            canonical_facts = NutritionFacts.objects.filter(food_item_id=canonical.id).first()
            if duplicate_facts is not None and canonical_facts is None:
                duplicate_facts.food_item_id = canonical.id
                duplicate_facts.save(update_fields=["food_item"])
            elif duplicate_facts is not None:
                duplicate_facts.delete()

            for alias in FoodItemAlias.objects.filter(food_item_id=duplicate.id):
                FoodItemAlias.objects.get_or_create(
                    food_item_id=canonical.id,
                    normalized_alias=alias.normalized_alias,
                    alias_type=alias.alias_type,
                    defaults={
                        "alias": alias.alias,
                        "is_primary": alias.is_primary,
                        "sort_order": alias.sort_order,
                    },
                )
            FoodItemAlias.objects.filter(food_item_id=duplicate.id).delete()

            for value in ItemNutrientValue.objects.filter(item_id=duplicate.id):
                ItemNutrientValue.objects.get_or_create(
                    item_id=canonical.id,
                    nutrient_id=value.nutrient_id,
                    basis_amount=value.basis_amount,
                    basis_unit=value.basis_unit,
                    defaults={"amount": value.amount},
                )
            ItemNutrientValue.objects.filter(item_id=duplicate.id).delete()
            NutritionServingOption.objects.filter(food_item_id=duplicate.id).update(
                food_item_id=canonical.id
            )
            duplicate.delete()


def _ensure_facts(apps):
    FoodItem = apps.get_model("core", "FoodItem")
    NutritionFacts = apps.get_model("core", "NutritionFacts")
    for food in FoodItem.objects.filter(nutrition_facts__isnull=True).iterator(chunk_size=500):
        is_ml = food.default_reference_unit == "ml" or food.default_serving_unit == "ml"
        NutritionFacts.objects.create(
            food_item_id=food.id,
            basis_type="per_100ml" if is_ml else "per_100g",
            basis_value=100,
            basis_amount=100,
            basis_unit="ml" if is_ml else "g",
            serving_size=max(float(food.default_serving_size or 100), 0.001),
            serving_unit=food.default_serving_unit or ("ml" if is_ml else "g"),
            calories_kcal=max(float(food.calories_100g or 0), 0),
            protein_g=max(float(food.protein_100g or 0), 0),
            carbohydrates_g=max(float(food.carbs_100g or 0), 0),
            sugars_g=max(float(food.sugar_100g or 0), 0),
            fiber_g=max(float(food.fiber_100g or 0), 0),
            fat_g=max(float(food.fat_100g or 0), 0),
            saturated_fat_g=max(float(food.saturated_fat_100g or 0), 0),
            trans_fat_g=max(float(food.trans_fat_100g or 0), 0),
            cholesterol_mg=max(float(food.cholesterol_mg_100g or 0), 0),
            sodium_mg=max(float(food.sodium_mg_100g or 0), 0),
            potassium_mg=max(float(food.potassium_mg_100g or 0), 0),
            vitamin_c_mg=max(float(food.vitamin_c_mg_100g or 0), 0),
            source_name=food.source or "legacy_backfill",
            source_reference=food.source_reference or "",
        )


def _normalize_facts_and_servings(apps):
    NutritionFacts = apps.get_model("core", "NutritionFacts")
    NutritionServingOption = apps.get_model("core", "NutritionServingOption")

    for facts in NutritionFacts.objects.all().iterator(chunk_size=500):
        facts.basis_value = max(float(facts.basis_value or 100), 0.001)
        facts.basis_amount = max(float(facts.basis_amount or facts.basis_value), 0.001)
        facts.serving_size = max(float(facts.serving_size or 100), 0.001)
        expected_unit = {
            "per_100g": "g",
            "per_100ml": "ml",
            "per_serving": "serving",
        }.get(facts.basis_type, "g")
        facts.basis_unit = expected_unit
        for field in NUTRIENT_FIELDS:
            setattr(facts, field, max(float(getattr(facts, field, 0) or 0), 0))
        if facts.confidence_score is not None:
            facts.confidence_score = min(max(float(facts.confidence_score), 0), 1)
        facts.save()

    food_ids = NutritionServingOption.objects.values_list("food_item_id", flat=True).distinct()
    for food_id in food_ids.iterator(chunk_size=500):
        options = NutritionServingOption.objects.filter(food_item_id=food_id).order_by(
            "sort_order", "id"
        )
        default = options.filter(is_default=True).first()
        if default is not None:
            options.filter(is_default=True).exclude(id=default.id).update(is_default=False)
        for option in options:
            option.amount = max(float(option.amount or 1), 0.001)
            if option.grams_equivalent is not None:
                option.grams_equivalent = max(float(option.grams_equivalent), 0)
            if option.milliliters_equivalent is not None:
                option.milliliters_equivalent = max(
                    float(option.milliliters_equivalent), 0
                )
            option.save()


def normalize_catalog(apps, schema_editor):
    _merge_global_duplicates(apps)
    _ensure_facts(apps)
    _normalize_facts_and_servings(apps)


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0036_backfill_meal_log_components"),
    ]

    operations = [
        migrations.RunPython(normalize_catalog, migrations.RunPython.noop),
    ]
