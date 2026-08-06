from decimal import Decimal

from django.db import migrations


SNAPSHOT_FIELDS = (
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


def backfill_components(apps, schema_editor):
    MealLog = apps.get_model("core", "MealLog")
    MealLogComponent = apps.get_model("core", "MealLogComponent")
    pending = []

    queryset = MealLog.objects.filter(food_id__isnull=False).iterator(chunk_size=500)
    for meal in queryset:
        quantity = float(meal.quantity or meal.quantity_grams or 0)
        grams = float(meal.grams_consumed or meal.quantity_grams or 0)
        milliliters = float(meal.milliliters_consumed or 0)
        if grams <= 0 and milliliters <= 0:
            grams = max(quantity, 0.001)
        quantity = max(quantity, 0.001)
        snapshot = {
            field: float(getattr(meal, f"snapshot_{field}", 0) or 0)
            for field in SNAPSHOT_FIELDS
        }
        food_name = meal.food.name
        pending.append(
            MealLogComponent(
                meal_log_id=meal.id,
                food_item_id=meal.food_id,
                display_name_snapshot=food_name,
                quantity_value=Decimal(str(quantity)),
                quantity_unit=meal.unit or "g",
                resolved_grams=Decimal(str(grams)) if grams > 0 else None,
                resolved_milliliters=(
                    Decimal(str(milliliters)) if milliliters > 0 else None
                ),
                nutrition_snapshot=snapshot,
                source_label=food_name,
                is_user_confirmed=True,
                sort_order=0,
            )
        )
        meal.display_name = food_name
        meal.save(update_fields=["display_name"])
        if len(pending) >= 500:
            MealLogComponent.objects.bulk_create(pending, ignore_conflicts=True)
            pending = []

    if pending:
        MealLogComponent.objects.bulk_create(pending, ignore_conflicts=True)


def reverse_backfill(apps, schema_editor):
    MealLogComponent = apps.get_model("core", "MealLogComponent")
    MealLogComponent.objects.all().delete()


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0035_meal_log_components"),
    ]

    operations = [
        migrations.RunPython(backfill_components, reverse_backfill),
    ]
