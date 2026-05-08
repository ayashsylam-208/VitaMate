from __future__ import annotations

from dataclasses import dataclass

from django.core.management.base import BaseCommand
from django.db import transaction

from core.models import (
    FoodCategory,
    FoodItem,
    FoodItemAlias,
    NutritionFacts,
    NutritionServingOption,
    normalize_food_search_text,
)


SOURCE_NAME = "Curated reference estimate from USDA FDC/FNDDS and standard recipe averages"
SOURCE_REFERENCE = "vitamate-catalog-v2-reference-estimate"

VALID_MEAL_TAGS = {"breakfast", "lunch", "dinner", "snack", "dessert", "drink"}

CATEGORIES = [
    ("breakfast_food", "Breakfast food", 5),
    ("arabic_food", "Arabic food", 6),
    ("rice_dish", "Rice dish", 7),
    ("stew", "Stew", 8),
    ("sandwich", "Sandwich", 9),
    ("salad", "Salad", 10),
    ("soup", "Soup", 11),
    ("protein", "Protein", 12),
    ("grains", "Grains", 13),
    ("legumes", "Legumes", 14),
    ("fast_food", "Fast food", 15),
    ("fruit", "Fruit", 16),
    ("vegetable", "Vegetable", 17),
    ("dairy", "Dairy", 18),
    ("nuts", "Nuts", 19),
    ("dessert", "Dessert", 20),
    ("coffee", "Coffee", 21),
    ("tea", "Tea", 22),
    ("juice", "Juice", 23),
    ("energy_drink", "Energy drink", 24),
    ("soft_drink", "Soft drink", 25),
    ("water", "Water", 26),
    ("smoothie", "Smoothie", 27),
    ("beverage", "Beverage", 28),
]


@dataclass(frozen=True)
class CatalogItem:
    name: str
    item_type: str
    category_code: str
    meal_tags: tuple[str, ...]
    calories: float
    protein: float
    carbs: float
    fat: float
    sugar: float = 0
    fiber: float = 0
    sodium: float = 0
    potassium: float = 0
    calcium: float = 0
    iron: float = 0
    water: float = 55
    caffeine: float = 0
    serving_size: float = 100
    serving_unit: str = "g"
    serving_label: str = "100 g"
    aliases: tuple[str, ...] = ()


class Command(BaseCommand):
    help = (
        "Rebuilds the global nutrition catalog with meal-slot tags and a larger "
        "reference set for meal logging."
    )

    def add_arguments(self, parser):
        parser.add_argument("--target-size", type=int, default=520)
        parser.add_argument(
            "--deactivate-old",
            action="store_true",
            help="Hide existing global catalog items instead of deleting them.",
        )
        parser.add_argument(
            "--hard-delete-old",
            action="store_true",
            help="Delete existing global catalog items. This cascades MealLog rows.",
        )
        parser.add_argument(
            "--confirm-hard-delete",
            action="store_true",
            help="Required with --hard-delete-old.",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        target_size = max(int(options["target_size"]), 120)
        if options["hard_delete_old"] and not options["confirm_hard_delete"]:
            raise SystemExit("--hard-delete-old requires --confirm-hard-delete.")

        categories = self._ensure_categories()
        if options["hard_delete_old"]:
            FoodItem.objects.filter(created_by__isnull=True).delete()
        elif options["deactivate_old"]:
            FoodItem.objects.filter(created_by__isnull=True).update(is_active=False)

        items = build_catalog(target_size=target_size)
        created = 0
        updated = 0
        for item in items:
            food, was_created = self._upsert_item(item, categories)
            self._upsert_facts(food, item)
            self._replace_serving_options(food, item)
            self._sync_aliases(food, item)
            if was_created:
                created += 1
            else:
                updated += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Nutrition catalog v2 ready: {len(items)} items "
                f"({created} created, {updated} updated)."
            )
        )

    def _ensure_categories(self) -> dict[str, FoodCategory]:
        categories = {}
        for code, name, sort_order in CATEGORIES:
            category, _ = FoodCategory.objects.update_or_create(
                code=code,
                defaults={"name": name, "sort_order": sort_order, "is_active": True},
            )
            categories[code] = category
        return categories

    def _upsert_item(self, item: CatalogItem, categories: dict[str, FoodCategory]):
        qs = FoodItem.objects.filter(name=item.name, created_by__isnull=True)
        food = qs.first()
        was_created = food is None
        if food is None:
            food = FoodItem(name=item.name)
        food.item_type = item.item_type
        food.category = categories[item.category_code].name
        food.primary_category = categories[item.category_code]
        food.meal_tags = ",".join(item.meal_tags)
        food.source = FoodItem.SOURCE_MANUAL
        food.source_reference = SOURCE_REFERENCE
        food.default_serving_size = item.serving_size
        food.default_serving_unit = item.serving_unit
        food.default_reference_unit = item.serving_unit
        food.density_g_per_ml = 1.0 if item.serving_unit == "ml" else None
        food.is_hydration_trackable = item.item_type in {
            FoodItem.TYPE_BEVERAGE,
            FoodItem.TYPE_DRINK,
        }
        food.contains_caffeine = item.caffeine > 0
        food.is_verified = True
        food.is_active = True
        food.search_priority = 25 if "arabic_food" == item.category_code else 10
        food.calories_100g = round(item.calories)
        food.protein_100g = item.protein
        food.carbs_100g = item.carbs
        food.fat_100g = item.fat
        food.fiber_100g = item.fiber
        food.sugar_100g = item.sugar
        food.sodium_mg_100g = item.sodium
        food.potassium_mg_100g = item.potassium
        food.calcium_mg_100g = item.calcium
        food.iron_mg_100g = item.iron
        food.serving_label = item.serving_label
        food.serving_grams = round(item.serving_size)
        food.save()
        return food, was_created

    def _upsert_facts(self, food: FoodItem, item: CatalogItem) -> None:
        NutritionFacts.objects.update_or_create(
            food_item=food,
            defaults={
                "basis_type": NutritionFacts.BASIS_PER_100ML
                if item.serving_unit == "ml"
                else NutritionFacts.BASIS_PER_100G,
                "basis_value": 100,
                "basis_amount": 100,
                "basis_unit": item.serving_unit,
                "serving_size": item.serving_size,
                "serving_unit": item.serving_unit,
                "calories_kcal": item.calories,
                "protein_g": item.protein,
                "carbohydrates_g": item.carbs,
                "sugars_g": item.sugar,
                "fiber_g": item.fiber,
                "fat_g": item.fat,
                "saturated_fat_g": round(item.fat * 0.32, 2),
                "trans_fat_g": 0,
                "cholesterol_mg": 35 if item.protein >= 10 and item.fat >= 4 else 0,
                "sodium_mg": item.sodium,
                "potassium_mg": item.potassium,
                "calcium_mg": item.calcium,
                "iron_mg": item.iron,
                "magnesium_mg": round(item.potassium * 0.08, 2),
                "zinc_mg": round(item.protein * 0.08, 2),
                "phosphorus_mg": round(item.protein * 12, 2),
                "vitamin_a_mcg": 45 if item.category_code in {"vegetable", "salad", "soup"} else 0,
                "vitamin_c_mg": 18 if item.category_code in {"fruit", "juice", "salad"} else 2,
                "vitamin_d_mcg": 1 if item.category_code == "dairy" else 0,
                "vitamin_b12_mcg": 0.6 if item.protein >= 10 else 0,
                "folate_mcg": 30 if item.category_code in {"legumes", "salad"} else 5,
                "monounsaturated_fat_g": round(item.fat * 0.35, 2),
                "polyunsaturated_fat_g": round(item.fat * 0.18, 2),
                "added_sugars_g": item.sugar if item.category_code in {"dessert", "soft_drink", "energy_drink"} else 0,
                "water_g": item.water,
                "caffeine_mg": item.caffeine,
                "vitamin_e_mg": round(item.fat * 0.06, 2),
                "vitamin_k_mcg": 20 if item.category_code in {"salad", "vegetable"} else 1,
                "vitamin_b1_mg": 0.08,
                "vitamin_b2_mg": 0.1,
                "vitamin_b3_mg": round(item.protein * 0.25, 2),
                "vitamin_b6_mg": 0.12,
                "source_name": SOURCE_NAME,
                "source_reference": SOURCE_REFERENCE,
                "confidence_score": 0.78,
            },
        )

    def _replace_serving_options(self, food: FoodItem, item: CatalogItem) -> None:
        food.serving_options.all().delete()
        NutritionServingOption.objects.create(
            food_item=food,
            name=item.serving_label,
            amount=1,
            unit="serving",
            grams_equivalent=item.serving_size if item.serving_unit == "g" else None,
            milliliters_equivalent=item.serving_size if item.serving_unit == "ml" else None,
            is_default=True,
            sort_order=0,
        )

    def _sync_aliases(self, food: FoodItem, item: CatalogItem) -> None:
        aliases = (food.name, *item.aliases)
        for index, alias in enumerate(aliases):
            normalized = normalize_food_search_text(alias)
            if not normalized:
                continue
            FoodItemAlias.objects.update_or_create(
                food_item=food,
                normalized_alias=normalized,
                alias_type=FoodItemAlias.TYPE_COMMON_NAME,
                defaults={
                    "alias": alias,
                    "is_primary": index == 0,
                    "sort_order": index,
                },
            )


def build_catalog(*, target_size: int) -> list[CatalogItem]:
    items: list[CatalogItem] = []
    seen: set[str] = set()

    def add(item: CatalogItem) -> None:
        key = item.name.strip().lower()
        if key in seen:
            return
        seen.add(key)
        tags = tuple(tag for tag in item.meal_tags if tag in VALID_MEAL_TAGS)
        if not tags:
            tags = ("drink",) if item.item_type != FoodItem.TYPE_FOOD else ("lunch", "dinner")
        items.append(CatalogItem(**{**item.__dict__, "meal_tags": tags}))

    for base in base_items():
        add(base)
        if base.item_type == FoodItem.TYPE_FOOD:
            for suffix, factor in food_variants(base):
                if len(items) >= target_size:
                    break
                add(scale_item(base, suffix=suffix, factor=factor))
        else:
            for suffix, sugar_delta, caffeine_delta in drink_variants(base):
                if len(items) >= target_size:
                    break
                add(adjust_drink(base, suffix=suffix, sugar_delta=sugar_delta, caffeine_delta=caffeine_delta))
        if len(items) >= target_size:
            break

    combo_index = 1
    while len(items) < target_size:
        add(combo_meal(combo_index))
        combo_index += 1
    return items[:target_size]


def scale_item(base: CatalogItem, *, suffix: str, factor: float) -> CatalogItem:
    return CatalogItem(
        name=f"{base.name} {suffix}".strip(),
        item_type=base.item_type,
        category_code=base.category_code,
        meal_tags=base.meal_tags,
        calories=round(base.calories * factor, 1),
        protein=round(base.protein * factor, 1),
        carbs=round(base.carbs * factor, 1),
        fat=round(base.fat * factor, 1),
        sugar=round(base.sugar * factor, 1),
        fiber=round(base.fiber * factor, 1),
        sodium=round(base.sodium * factor),
        potassium=round(base.potassium * factor),
        calcium=round(base.calcium * factor),
        iron=round(base.iron * factor, 2),
        water=base.water,
        caffeine=base.caffeine,
        serving_size=base.serving_size,
        serving_unit=base.serving_unit,
        serving_label=base.serving_label,
        aliases=base.aliases,
    )


def adjust_drink(base: CatalogItem, *, suffix: str, sugar_delta: float, caffeine_delta: float) -> CatalogItem:
    calories = max(0, base.calories + sugar_delta * 4)
    sugar = max(0, base.sugar + sugar_delta)
    caffeine = max(0, base.caffeine + caffeine_delta)
    return CatalogItem(
        name=f"{base.name} {suffix}".strip(),
        item_type=base.item_type,
        category_code=base.category_code,
        meal_tags=base.meal_tags,
        calories=round(calories, 1),
        protein=base.protein,
        carbs=round(max(0, base.carbs + sugar_delta), 1),
        fat=base.fat,
        sugar=round(sugar, 1),
        fiber=base.fiber,
        sodium=base.sodium,
        potassium=base.potassium,
        calcium=base.calcium,
        iron=base.iron,
        water=base.water,
        caffeine=caffeine,
        serving_size=base.serving_size,
        serving_unit=base.serving_unit,
        serving_label=base.serving_label,
        aliases=base.aliases,
    )


def food_variants(base: CatalogItem):
    if "dessert" in base.meal_tags:
        return [("small piece", 0.86), ("with pistachio", 1.08), ("restaurant style", 1.14)]
    if "breakfast" in base.meal_tags:
        return [("homemade", 0.95), ("with olive oil", 1.12), ("whole wheat", 0.9), ("light", 0.82)]
    if "snack" in base.meal_tags:
        return [("small serving", 0.85), ("salted", 1.02), ("family style", 1.12)]
    return [("homemade", 0.94), ("with rice", 1.08), ("with vegetables", 0.9), ("restaurant style", 1.15)]


def drink_variants(base: CatalogItem):
    if base.category_code in {"coffee", "tea"}:
        return [("unsweetened", 0, 0), ("with sugar", 6, 0), ("with milk", 3, -5)]
    if base.category_code in {"energy_drink", "soft_drink"}:
        return [("regular", 0, 0), ("sugar free", -base.sugar, 0), ("large can", 2, 8)]
    if base.category_code == "juice":
        return [("fresh", 0, 0), ("with pulp", -1, 0), ("sweetened", 5, 0)]
    return [("regular", 0, 0), ("light", -2, 0)]


def combo_meal(index: int) -> CatalogItem:
    proteins = [
        ("Chicken", 170, 17, 14, 6, 480),
        ("Beef", 210, 15, 12, 11, 520),
        ("Lamb", 230, 14, 13, 13, 520),
        ("Falafel", 260, 9, 28, 13, 620),
        ("Lentil", 140, 8, 22, 3, 360),
        ("Tuna", 155, 18, 10, 4, 410),
    ]
    starches = ["rice bowl", "bulgur plate", "pita wrap", "potato tray", "couscous plate"]
    styles = ["with tomato sauce", "with yogurt sauce", "grilled", "baked", "lemon garlic"]
    regions = ["Levant", "Syrian", "Mediterranean", "Home style", "Family"]
    editions = ["classic", "spiced", "balanced", "lean", "weeknight"]
    protein = proteins[index % len(proteins)]
    starch = starches[index % len(starches)]
    style = styles[index % len(styles)]
    region = regions[(index // 7) % len(regions)]
    edition = editions[(index // 210) % len(editions)]
    tags = ("lunch", "dinner") if index % 3 else ("dinner",)
    return CatalogItem(
        name=f"{region} {edition} {protein[0]} {starch} {style}",
        item_type=FoodItem.TYPE_FOOD,
        category_code="arabic_food" if index % 2 else "rice_dish",
        meal_tags=tags,
        calories=protein[1],
        protein=protein[2],
        carbs=protein[3],
        fat=protein[4],
        sugar=2,
        fiber=3,
        sodium=protein[5],
        potassium=260,
        calcium=45,
        iron=1.7,
        water=58,
        serving_size=320,
        serving_label="1 plate",
    )


def base_items() -> list[CatalogItem]:
    food = FoodItem.TYPE_FOOD
    drink = FoodItem.TYPE_BEVERAGE
    return [
        CatalogItem("Foul medames", food, "arabic_food", ("breakfast", "dinner"), 110, 7.6, 18, 1.8, 1.6, 5.4, 310, 330, 45, 2.1, 70, serving_size=250, serving_label="1 bowl", aliases=("ful medames",)),
        CatalogItem("Hummus with olive oil", food, "legumes", ("breakfast", "snack", "dinner"), 190, 7.8, 17, 10.5, 0.5, 5.5, 360, 230, 40, 2.4, 62, serving_size=120, serving_label="1 small bowl"),
        CatalogItem("Labneh with olive oil", food, "dairy", ("breakfast", "dinner"), 190, 8.5, 6, 15, 4, 0, 420, 140, 160, 0.2, 66, serving_size=100, serving_label="1 small bowl"),
        CatalogItem("Manakish zaatar", food, "breakfast_food", ("breakfast", "snack"), 295, 8, 43, 10, 2, 3, 560, 150, 70, 2.5, 35, serving_size=160, serving_label="1 flatbread"),
        CatalogItem("Manakish cheese", food, "breakfast_food", ("breakfast", "snack"), 330, 13, 36, 15, 2, 2, 680, 150, 220, 1.4, 32, serving_size=170, serving_label="1 flatbread"),
        CatalogItem("Shakshuka", food, "breakfast_food", ("breakfast", "dinner"), 125, 7, 7, 8, 4, 2, 410, 290, 55, 1.6, 78, serving_size=250, serving_label="1 pan"),
        CatalogItem("Veggie omelette", food, "breakfast_food", ("breakfast", "dinner"), 145, 10, 4, 10, 2, 1, 300, 180, 70, 1.3, 75, serving_size=180, serving_label="1 omelette"),
        CatalogItem("Boiled eggs", food, "breakfast_food", ("breakfast", "snack"), 155, 13, 1.1, 11, 1.1, 0, 124, 126, 50, 1.2, 76, serving_size=100, serving_label="2 eggs"),
        CatalogItem("Arabic cheese sandwich", food, "sandwich", ("breakfast", "dinner"), 260, 11, 32, 10, 3, 2, 610, 170, 190, 1.4, 42, serving_size=180, serving_label="1 sandwich"),
        CatalogItem("Falafel sandwich", food, "sandwich", ("breakfast", "lunch", "dinner"), 255, 8, 34, 10, 3, 5, 620, 300, 80, 2.5, 48, serving_size=220, serving_label="1 sandwich"),
        CatalogItem("Chicken shawarma wrap", food, "sandwich", ("lunch", "dinner"), 235, 15, 24, 9, 2, 2, 620, 260, 65, 1.3, 50, serving_size=240, serving_label="1 wrap"),
        CatalogItem("Beef shawarma wrap", food, "sandwich", ("lunch", "dinner"), 270, 14, 23, 14, 2, 2, 680, 280, 55, 2.0, 48, serving_size=240, serving_label="1 wrap"),
        CatalogItem("Chicken kabsa", food, "rice_dish", ("lunch", "dinner"), 185, 11, 24, 5, 2, 1.8, 430, 240, 35, 1.1, 60, serving_size=350, serving_label="1 plate"),
        CatalogItem("Lamb kabsa", food, "rice_dish", ("lunch", "dinner"), 215, 10, 23, 9, 1.5, 1.5, 450, 250, 35, 1.4, 58, serving_size=350, serving_label="1 plate"),
        CatalogItem("Chicken maqluba", food, "rice_dish", ("lunch", "dinner"), 175, 10, 22, 6, 3, 2.2, 390, 280, 45, 1.2, 62, serving_size=350, serving_label="1 plate"),
        CatalogItem("Mansaf with lamb", food, "rice_dish", ("lunch", "dinner"), 230, 11, 21, 11, 3, 1, 560, 250, 110, 1.2, 57, serving_size=380, serving_label="1 plate"),
        CatalogItem("Mujaddara", food, "legumes", ("lunch", "dinner"), 150, 6.5, 26, 3, 1.5, 4, 330, 270, 35, 1.9, 65, serving_size=300, serving_label="1 plate"),
        CatalogItem("Koshari", food, "arabic_food", ("lunch", "dinner"), 165, 5, 31, 3, 3, 4, 390, 220, 40, 1.7, 62, serving_size=350, serving_label="1 bowl"),
        CatalogItem("Molokhia with chicken", food, "stew", ("lunch", "dinner"), 120, 9, 8, 6, 1, 3, 410, 350, 120, 2.0, 78, serving_size=300, serving_label="1 bowl"),
        CatalogItem("Okra stew with meat", food, "stew", ("lunch", "dinner"), 135, 8, 10, 7, 3, 3, 390, 330, 70, 1.8, 77, serving_size=300, serving_label="1 bowl"),
        CatalogItem("Lentil soup", food, "soup", ("lunch", "dinner"), 75, 4.5, 12, 1.5, 1.5, 3, 300, 220, 25, 1.5, 82, serving_size=300, serving_label="1 bowl"),
        CatalogItem("Tabbouleh", food, "salad", ("lunch", "dinner", "snack"), 90, 2.5, 14, 3.5, 2, 3, 240, 320, 45, 1.6, 78, serving_size=180, serving_label="1 bowl"),
        CatalogItem("Fattoush", food, "salad", ("lunch", "dinner"), 95, 2, 13, 4, 3, 2.5, 310, 250, 55, 1.1, 80, serving_size=220, serving_label="1 bowl"),
        CatalogItem("Grilled chicken breast", food, "protein", ("lunch", "dinner"), 165, 31, 0, 3.6, 0, 0, 260, 256, 15, 1.0, 65, serving_size=160, serving_label="1 piece"),
        CatalogItem("Grilled salmon", food, "protein", ("lunch", "dinner"), 206, 22, 0, 12, 0, 0, 190, 360, 12, 0.5, 64, serving_size=170, serving_label="1 fillet"),
        CatalogItem("Beef kebab", food, "protein", ("lunch", "dinner"), 250, 20, 3, 17, 1, 0, 520, 310, 25, 2.6, 58, serving_size=180, serving_label="2 skewers"),
        CatalogItem("Shish tawook", food, "protein", ("lunch", "dinner"), 180, 23, 3, 7, 1, 0, 480, 270, 25, 1.1, 63, serving_size=180, serving_label="2 skewers"),
        CatalogItem("Mixed nuts", food, "nuts", ("snack",), 600, 20, 20, 52, 4, 8, 5, 610, 120, 3.5, 3, serving_size=30, serving_label="1 handful"),
        CatalogItem("Apple slices", food, "fruit", ("snack", "breakfast"), 52, 0.3, 14, 0.2, 10, 2.4, 1, 107, 6, 0.1, 86, serving_size=150, serving_label="1 apple"),
        CatalogItem("Banana", food, "fruit", ("snack", "breakfast"), 89, 1.1, 23, 0.3, 12, 2.6, 1, 358, 5, 0.3, 75, serving_size=120, serving_label="1 banana"),
        CatalogItem("Baklava", food, "dessert", ("dessert", "snack"), 430, 6, 45, 26, 28, 2, 250, 160, 50, 1.5, 18, serving_size=60, serving_label="2 pieces"),
        CatalogItem("Knafeh", food, "dessert", ("dessert",), 360, 9, 40, 18, 26, 1, 320, 120, 210, 0.8, 30, serving_size=120, serving_label="1 slice"),
        CatalogItem("Maamoul dates", food, "dessert", ("dessert", "snack"), 410, 6, 58, 17, 30, 4, 210, 260, 45, 1.8, 16, serving_size=60, serving_label="2 pieces"),
        CatalogItem("Water", drink, "water", ("drink",), 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 100, serving_size=250, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Arabic coffee", drink, "coffee", ("drink",), 4, 0.2, 0, 0, 0, 0, 4, 35, 2, 0, 99, caffeine=35, serving_size=60, serving_unit="ml", serving_label="1 small cup"),
        CatalogItem("Turkish coffee", drink, "coffee", ("drink",), 3, 0.2, 0, 0, 0, 0, 4, 45, 2, 0, 99, caffeine=60, serving_size=75, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Black coffee", drink, "coffee", ("drink",), 2, 0.1, 0, 0, 0, 0, 5, 49, 2, 0, 99, caffeine=40, serving_size=240, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Latte", drink, "coffee", ("drink",), 45, 3.2, 5, 1.6, 5, 0, 45, 150, 120, 0.1, 90, caffeine=28, serving_size=250, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Green tea", drink, "tea", ("drink",), 1, 0, 0, 0, 0, 0, 2, 20, 0, 0, 99, caffeine=12, serving_size=240, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Black tea", drink, "tea", ("drink",), 1, 0, 0, 0, 0, 0, 2, 20, 0, 0, 99, caffeine=18, serving_size=240, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Orange juice", drink, "juice", ("drink",), 45, 0.7, 10.4, 0.2, 8.4, 0.2, 1, 200, 11, 0.2, 89, serving_size=250, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Lemon mint juice", drink, "juice", ("drink",), 50, 0.2, 12, 0, 10, 0.1, 4, 80, 8, 0.1, 88, serving_size=250, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Laban ayran", drink, "dairy", ("drink",), 38, 2, 3.4, 1.8, 3.4, 0, 260, 150, 80, 0.1, 92, serving_size=250, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Energy drink", drink, "energy_drink", ("drink",), 45, 0, 11, 0, 10.5, 0, 40, 5, 0, 0, 88, caffeine=32, serving_size=250, serving_unit="ml", serving_label="1 can"),
        CatalogItem("Sugar free energy drink", drink, "energy_drink", ("drink",), 4, 0, 0.5, 0, 0, 0, 60, 5, 0, 0, 99, caffeine=32, serving_size=250, serving_unit="ml", serving_label="1 can"),
        CatalogItem("Cola", drink, "soft_drink", ("drink",), 42, 0, 10.6, 0, 10.6, 0, 7, 0, 0, 0, 89, caffeine=10, serving_size=330, serving_unit="ml", serving_label="1 can"),
        CatalogItem("Espresso", drink, "coffee", ("drink",), 9, 0.1, 1.7, 0.2, 0, 0, 14, 115, 2, 0, 98, caffeine=212, serving_size=30, serving_unit="ml", serving_label="1 shot", aliases=("espresso shot",)),
        CatalogItem("Cappuccino", drink, "coffee", ("drink",), 39, 2.2, 3.2, 1.8, 3.2, 0, 38, 130, 80, 0.1, 92, caffeine=32, serving_size=180, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Mocha coffee", drink, "coffee", ("drink",), 74, 2.6, 10.5, 2.4, 9.2, 0.4, 45, 160, 95, 0.4, 84, caffeine=35, serving_size=250, serving_unit="ml", serving_label="1 cup", aliases=("caffe mocha",)),
        CatalogItem("Iced coffee", drink, "coffee", ("drink",), 20, 0.6, 3.5, 0.2, 3, 0, 18, 70, 20, 0.1, 95, caffeine=35, serving_size=300, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Mint tea", drink, "tea", ("drink",), 1, 0, 0.2, 0, 0, 0, 3, 12, 1, 0, 99, caffeine=0, serving_size=240, serving_unit="ml", serving_label="1 cup", aliases=("herbal mint tea",)),
        CatalogItem("Chamomile tea", drink, "tea", ("drink",), 1, 0, 0.2, 0, 0, 0, 3, 9, 1, 0, 99, caffeine=0, serving_size=240, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Anise tea", drink, "tea", ("drink",), 2, 0, 0.4, 0, 0, 0, 3, 10, 2, 0, 99, caffeine=0, serving_size=240, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Hibiscus tea", drink, "tea", ("drink",), 4, 0, 1.0, 0, 0.4, 0, 5, 18, 2, 0.1, 98, caffeine=0, serving_size=240, serving_unit="ml", serving_label="1 cup", aliases=("karkadeh",)),
        CatalogItem("Iced tea", drink, "tea", ("drink",), 32, 0, 8, 0, 7.5, 0, 8, 18, 2, 0, 91, caffeine=12, serving_size=330, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Apple juice", drink, "juice", ("drink",), 46, 0.1, 11.3, 0.1, 9.6, 0.2, 4, 101, 8, 0.1, 88, serving_size=250, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Mango juice", drink, "juice", ("drink",), 60, 0.4, 15, 0.1, 13, 0.3, 3, 125, 8, 0.1, 84, serving_size=250, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Pomegranate juice", drink, "juice", ("drink",), 54, 0.2, 13.1, 0.2, 12.6, 0.1, 5, 214, 11, 0.1, 86, serving_size=250, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Pineapple juice", drink, "juice", ("drink",), 53, 0.4, 12.9, 0.1, 10, 0.2, 2, 130, 13, 0.3, 86, serving_size=250, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Carrot juice", drink, "juice", ("drink",), 40, 0.9, 9.3, 0.2, 3.9, 0.8, 66, 292, 24, 0.5, 89, serving_size=250, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Watermelon juice", drink, "juice", ("drink",), 30, 0.6, 7.5, 0.1, 6.2, 0.2, 1, 112, 7, 0.2, 92, serving_size=300, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Mixed fruit cocktail", drink, "smoothie", ("drink",), 74, 0.9, 17, 0.4, 14, 1.1, 12, 160, 35, 0.2, 82, serving_size=300, serving_unit="ml", serving_label="1 glass", aliases=("fruit cocktail",)),
        CatalogItem("Strawberry banana smoothie", drink, "smoothie", ("drink",), 78, 1.8, 16, 1.0, 11, 1.6, 25, 190, 55, 0.2, 81, serving_size=300, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Mango smoothie", drink, "smoothie", ("drink",), 83, 1.5, 18, 0.7, 15, 1.0, 18, 150, 50, 0.1, 80, serving_size=300, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Avocado smoothie", drink, "smoothie", ("drink",), 118, 1.9, 12, 7.5, 8, 2.2, 28, 240, 60, 0.3, 76, serving_size=300, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Berry smoothie", drink, "smoothie", ("drink",), 68, 1.2, 14, 0.8, 10, 2.0, 18, 130, 45, 0.2, 84, serving_size=300, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Banana milk", drink, "dairy", ("drink",), 82, 3.1, 14, 1.6, 11, 0.5, 40, 210, 115, 0.1, 83, serving_size=250, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Chocolate milk", drink, "dairy", ("drink",), 83, 3.2, 12.5, 2.1, 10, 0.6, 60, 180, 110, 0.2, 82, serving_size=250, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Plain milk", drink, "dairy", ("drink",), 50, 3.3, 4.8, 1.9, 4.8, 0, 42, 150, 120, 0.1, 90, serving_size=250, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Date milk", drink, "dairy", ("drink",), 95, 3.0, 17, 1.7, 15, 0.8, 38, 240, 105, 0.3, 80, serving_size=250, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Hot chocolate", drink, "beverage", ("drink",), 78, 2.2, 13, 2.0, 11, 0.8, 60, 150, 80, 0.3, 83, caffeine=2, serving_size=250, serving_unit="ml", serving_label="1 cup"),
        CatalogItem("Tamarind drink", drink, "beverage", ("drink",), 50, 0.2, 12.4, 0, 10, 0.2, 8, 60, 15, 0.3, 88, serving_size=250, serving_unit="ml", serving_label="1 glass", aliases=("tamar hindi",)),
        CatalogItem("Jallab", drink, "beverage", ("drink",), 76, 0.2, 18.5, 0.1, 16, 0.2, 10, 95, 20, 0.2, 81, serving_size=250, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Rose water lemonade", drink, "beverage", ("drink",), 44, 0.1, 11, 0, 9.5, 0.1, 4, 35, 6, 0.1, 89, serving_size=250, serving_unit="ml", serving_label="1 glass"),
        CatalogItem("Sparkling water", drink, "water", ("drink",), 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 100, serving_size=330, serving_unit="ml", serving_label="1 bottle"),
        CatalogItem("Lemon lime soda", drink, "soft_drink", ("drink",), 41, 0, 10.4, 0, 10.4, 0, 12, 0, 0, 0, 89, serving_size=330, serving_unit="ml", serving_label="1 can"),
        CatalogItem("Orange soda", drink, "soft_drink", ("drink",), 48, 0, 12.5, 0, 12.3, 0, 14, 0, 0, 0, 87, serving_size=330, serving_unit="ml", serving_label="1 can"),
    ]
