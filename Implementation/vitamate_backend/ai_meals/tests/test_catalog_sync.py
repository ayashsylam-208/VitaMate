import json
from pathlib import Path
from tempfile import TemporaryDirectory

from django.core.management import call_command
from django.test import TestCase

from ai_meals.models import AIIngredientMapping
from core.models import FoodItem, NutritionFacts


class SyncAINutritionCatalogTests(TestCase):
    def test_sync_creates_canonical_food_facts_and_provider_mapping(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            vocab = root / "src" / "vitamate_ai_package" / "vocab"
            vocab.mkdir(parents=True)
            (vocab / "nutrition_database.json").write_text(
                json.dumps(
                    {
                        "items": [
                            {
                                "canonical_name": "rice",
                                "aliases": ["white rice cooked"],
                                "nutrients_per_100g": {
                                    "calories_kcal": 130,
                                    "carbohydrates_g": 28.2,
                                    "protein_g": 2.7,
                                    "fat_g": 0.3,
                                },
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )
            (vocab / "ingredient_catalog.json").write_text(
                json.dumps(
                    {
                        "ingredients": [
                            {
                                "ingredient_id": "sushi_rice",
                                "display_name_en": "sushi rice",
                                "aliases": ["sushi rice"],
                                "nutrition_ref": {"food_key": "rice"},
                                "category": "grain",
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )

            call_command("sync_ai_nutrition_catalog", package_root=str(root))
            call_command("sync_ai_nutrition_catalog", package_root=str(root))

        food = FoodItem.objects.get(normalized_name="rice", created_by__isnull=True)
        facts = NutritionFacts.objects.get(food_item=food)
        mapping = AIIngredientMapping.objects.get(
            provider="vitamate_ai",
            provider_id="sushi_rice",
        )
        self.assertEqual(facts.calories_kcal, 130)
        self.assertEqual(facts.carbohydrates_g, 28.2)
        self.assertEqual(mapping.food_item, food)
        self.assertEqual(FoodItem.objects.filter(normalized_name="rice").count(), 1)
