from __future__ import annotations

import json
import os
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from ai_meals.models import (
    AIIngredientMapping,
    MealAnalysisCandidate,
    MealAnalysisComponent,
    MealAnalysisSession,
)
from core.models import (
    FoodItem,
    FoodItemAlias,
    NutritionFacts,
    NutritionServingOption,
    normalize_food_search_text,
)


PROVIDER = "vitamate_ai"
SOURCE_REFERENCE = "vitamate-ai-runtime:nutrition_database:mvp_v1"
SOURCE_NAME = "VitaMate AI packaged nutrition reference"


class Command(BaseCommand):
    help = "Synchronize the packaged AI ingredient nutrition catalog into Django."

    def add_arguments(self, parser):
        parser.add_argument(
            "--package-root",
            help="Extracted VitaMate AI runtime root.",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        package_root = self._package_root(options.get("package_root"))
        vocab_root = package_root / "src" / "vitamate_ai_package" / "vocab"
        nutrition_payload = self._read_json(vocab_root / "nutrition_database.json")
        ingredient_payload = self._read_json(vocab_root / "ingredient_catalog.json")
        nutrition_items = nutrition_payload.get("items")
        ingredients = ingredient_payload.get("ingredients")
        if not isinstance(nutrition_items, list) or not nutrition_items:
            raise CommandError("nutrition_database.json has no items.")
        if not isinstance(ingredients, list) or not ingredients:
            raise CommandError("ingredient_catalog.json has no ingredients.")

        category_by_food_key = self._categories_by_food_key(ingredients)
        foods_by_key = {}
        foods_created = 0
        for item in nutrition_items:
            food, created = self._upsert_food(
                item=item,
                category=category_by_food_key.get(item.get("canonical_name"), "AI ingredient"),
            )
            foods_by_key[item["canonical_name"]] = food
            foods_created += int(created)

        mappings_created = 0
        repaired_candidates = 0
        repaired_components = 0
        for ingredient in ingredients:
            ingredient_id = str(ingredient.get("ingredient_id") or "").strip()
            label = str(ingredient.get("display_name_en") or "").strip()
            food_key = str((ingredient.get("nutrition_ref") or {}).get("food_key") or "").strip()
            food = foods_by_key.get(food_key)
            if not ingredient_id or not label or food is None:
                continue
            mapping, created = AIIngredientMapping.objects.update_or_create(
                provider=PROVIDER,
                provider_id=ingredient_id,
                defaults={
                    "provider_label": label,
                    "aliases": ingredient.get("aliases") or [],
                    "food_item": food,
                    "mapping_confidence": 1,
                    "is_active": True,
                },
            )
            mappings_created += int(created)
            active_sessions = {
                MealAnalysisSession.STATUS_REVIEW,
                MealAnalysisSession.STATUS_NEEDS_INPUT,
            }
            repaired_candidates += MealAnalysisCandidate.objects.filter(
                session__status__in=active_sessions,
                provider_id=mapping.provider_id,
                mapped_food_item__isnull=True,
            ).update(mapped_food_item=food)
            repaired_components += MealAnalysisComponent.objects.filter(
                session__status__in=active_sessions,
                provider_id=mapping.provider_id,
                mapped_food_item__isnull=True,
            ).update(mapped_food_item=food)

        self.stdout.write(
            self.style.SUCCESS(
                "AI nutrition catalog synchronized: "
                f"{len(foods_by_key)} foods ({foods_created} created), "
                f"{AIIngredientMapping.objects.filter(provider=PROVIDER, is_active=True).count()} "
                f"active mappings ({mappings_created} created), "
                f"{repaired_candidates} pending candidates and "
                f"{repaired_components} pending components repaired."
            )
        )

    @staticmethod
    def _package_root(value):
        configured = value or os.getenv("VITAMATE_AI_PACKAGE_ROOT")
        root = Path(configured) if configured else Path(settings.BASE_DIR).parent / ".local" / "vitamate_ai_runtime"
        root = root.expanduser().resolve()
        if not root.is_dir():
            raise CommandError(f"AI package root does not exist: {root}")
        return root

    @staticmethod
    def _read_json(path):
        if not path.is_file():
            raise CommandError(f"Required AI catalog file is missing: {path}")
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise CommandError(f"Could not read AI catalog file: {path}") from exc

    @staticmethod
    def _categories_by_food_key(ingredients):
        categories = {}
        for ingredient in ingredients:
            food_key = str((ingredient.get("nutrition_ref") or {}).get("food_key") or "").strip()
            category = str(ingredient.get("category") or "").strip().replace("_", " ")
            if food_key and category:
                categories.setdefault(food_key, category.title())
        return categories

    def _upsert_food(self, *, item, category):
        canonical_name = str(item.get("canonical_name") or "").strip()
        nutrients = item.get("nutrients_per_100g") or {}
        if not canonical_name or not isinstance(nutrients, dict):
            raise CommandError("AI nutrition item is missing its canonical name or nutrients.")
        normalized_name = normalize_food_search_text(canonical_name)
        food, created = FoodItem.objects.update_or_create(
            created_by=None,
            normalized_name=normalized_name,
            defaults={
                "name": canonical_name,
                "item_type": FoodItem.TYPE_FOOD,
                "category": category,
                "meal_tags": "breakfast,lunch,dinner,snack",
                "source": FoodItem.SOURCE_AI,
                "source_reference": SOURCE_REFERENCE,
                "default_serving_size": 100,
                "default_serving_unit": "g",
                "default_reference_unit": "g",
                "is_verified": True,
                "is_active": True,
                "search_priority": 100,
                "calories_100g": round(self._number(nutrients, "calories_kcal")),
                "protein_100g": self._number(nutrients, "protein_g"),
                "carbs_100g": self._number(nutrients, "carbohydrates_g"),
                "fat_100g": self._number(nutrients, "fat_g"),
                "fiber_100g": self._number(nutrients, "fiber_g"),
                "sugar_100g": self._number(nutrients, "sugars_g"),
                "sodium_mg_100g": self._number(nutrients, "sodium_mg"),
                "potassium_mg_100g": self._number(nutrients, "potassium_mg"),
                "vitamin_c_mg_100g": self._number(nutrients, "vitamin_c_mg"),
                "serving_label": "100 g",
                "serving_grams": 100,
            },
        )
        NutritionFacts.objects.update_or_create(
            food_item=food,
            defaults={
                "basis_type": NutritionFacts.BASIS_PER_100G,
                "basis_value": 100,
                "basis_amount": 100,
                "basis_unit": "g",
                "serving_size": 100,
                "serving_unit": "g",
                "calories_kcal": self._number(nutrients, "calories_kcal"),
                "protein_g": self._number(nutrients, "protein_g"),
                "carbohydrates_g": self._number(nutrients, "carbohydrates_g"),
                "sugars_g": self._number(nutrients, "sugars_g"),
                "fiber_g": self._number(nutrients, "fiber_g"),
                "fat_g": self._number(nutrients, "fat_g"),
                "sodium_mg": self._number(nutrients, "sodium_mg"),
                "potassium_mg": self._number(nutrients, "potassium_mg"),
                "calcium_mg": self._number(nutrients, "calcium_mg"),
                "iron_mg": self._number(nutrients, "iron_mg"),
                "vitamin_a_mcg": self._number(nutrients, "vitamin_a_mcg"),
                "vitamin_c_mg": self._number(nutrients, "vitamin_c_mg"),
                "vitamin_b12_mcg": self._number(nutrients, "b12_mcg"),
                "folate_mcg": self._number(nutrients, "b9_mcg"),
                "vitamin_b1_mg": self._number(nutrients, "b1_mg"),
                "vitamin_b2_mg": self._number(nutrients, "b2_mg"),
                "vitamin_b3_mg": self._number(nutrients, "b3_mg"),
                "vitamin_b6_mg": self._number(nutrients, "b6_mg"),
                "source_name": SOURCE_NAME,
                "source_reference": SOURCE_REFERENCE,
                "confidence_score": 0.8,
            },
        )
        NutritionServingOption.objects.filter(
            food_item=food,
            is_default=True,
        ).exclude(name="100 g").update(is_default=False)
        NutritionServingOption.objects.update_or_create(
            food_item=food,
            name="100 g",
            defaults={
                "amount": 1,
                "unit": "serving",
                "grams_equivalent": 100,
                "milliliters_equivalent": None,
                "is_default": True,
                "sort_order": 0,
            },
        )
        aliases = [canonical_name, *(item.get("aliases") or [])]
        food.aliases = list(dict.fromkeys(str(alias).strip() for alias in aliases if str(alias).strip()))
        food.save(update_fields=("aliases", "updated_at"))
        for index, alias in enumerate(food.aliases):
            FoodItemAlias.objects.update_or_create(
                food_item=food,
                normalized_alias=normalize_food_search_text(alias),
                alias_type=FoodItemAlias.TYPE_COMMON_NAME,
                defaults={
                    "alias": alias,
                    "is_primary": index == 0,
                    "sort_order": index,
                },
            )
        return food, created

    @staticmethod
    def _number(values, key):
        try:
            return max(float(values.get(key) or 0), 0)
        except (TypeError, ValueError):
            return 0
