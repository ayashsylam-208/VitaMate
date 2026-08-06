from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from django.contrib.auth import get_user_model
from django.db import close_old_connections
from django.test import TestCase, TransactionTestCase
from rest_framework.exceptions import ValidationError

from core.models import FoodItem, MealLog, MealLogComponent
from core.services.nutrition.meal_finalization_service import MealFinalizationService
from test_utils.helpers import create_food_item, create_user_with_profile


class MealFinalizationServiceTests(TestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="meal-finalizer")
        self.rice = create_food_item(
            name="Finalizer Rice",
            calories_100g=130,
            carbs_100g=28,
        )
        self.chicken = create_food_item(
            name="Finalizer Chicken",
            calories_100g=200,
            protein_100g=30,
            carbs_100g=0,
        )

    def test_composite_meal_aggregates_snapshots_and_persists_components(self):
        meal = MealFinalizationService.finalize(
            user=self.user,
            meal_type="lunch",
            display_name="Chicken rice bowl",
            components=[
                {
                    "food": self.rice,
                    "quantity_grams": 150,
                    "confidence_score": 0.9,
                    "source_label": "rice",
                },
                {
                    "food": self.chicken,
                    "quantity_grams": 100,
                    "confidence_score": 0.8,
                    "source_label": "chicken",
                },
            ],
            source=MealLog.SOURCE_AI,
            finalization_key="analysis:test-composite",
            reward_owner_domain="test",
            sync_hydration=False,
            publish_event=False,
        )

        self.assertTrue(meal.is_composite)
        self.assertIsNone(meal.food_id)
        self.assertEqual(meal.display_name, "Chicken rice bowl")
        self.assertEqual(meal.total_calories, 395)
        self.assertEqual(meal.components.count(), 2)
        self.assertEqual(
            list(meal.components.values_list("display_name_snapshot", flat=True)),
            ["Finalizer Rice", "Finalizer Chicken"],
        )
        self.assertAlmostEqual(float(meal.snapshot_protein_g), 45)
        self.assertAlmostEqual(float(meal.snapshot_carbohydrates_g), 42)

    def test_finalization_key_is_idempotent(self):
        payload = {
            "user": self.user,
            "meal_type": "lunch",
            "components": [{"food": self.rice, "quantity_grams": 100}],
            "finalization_key": "analysis:same-request",
            "reward_owner_domain": "test",
            "sync_hydration": False,
            "publish_event": False,
        }
        first = MealFinalizationService.finalize(**payload)
        second = MealFinalizationService.finalize(**payload)

        self.assertEqual(second.id, first.id)
        self.assertEqual(MealLog.objects.filter(user=self.user).count(), 1)
        self.assertEqual(MealLogComponent.objects.filter(meal_log=first).count(), 1)

    def test_component_cannot_use_another_users_custom_food(self):
        other = create_user_with_profile(username="meal-finalizer-other")
        private_food = create_food_item(name="Private AI Food", created_by=other)

        with self.assertRaises(ValidationError):
            MealFinalizationService.finalize(
                user=self.user,
                meal_type="lunch",
                components=[{"food": private_food, "quantity_grams": 100}],
                reward_owner_domain="test",
                sync_hydration=False,
                publish_event=False,
            )


class MealFinalizationConcurrencyTests(TransactionTestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="meal-finalizer-concurrent")
        self.food = create_food_item(
            name="Concurrent Finalizer Rice",
            calories_100g=130,
            carbs_100g=28,
        )

    def test_concurrent_retries_create_one_meal(self):
        barrier = Barrier(2)

        def finalize_once():
            close_old_connections()
            try:
                user = get_user_model().objects.get(id=self.user.id)
                food = FoodItem.objects.get(id=self.food.id)
                barrier.wait(timeout=10)
                meal = MealFinalizationService.finalize(
                    user=user,
                    meal_type="lunch",
                    components=[{"food": food, "quantity_grams": 100}],
                    finalization_key="analysis:concurrent-request",
                    reward_owner_domain="test",
                    sync_hydration=False,
                    publish_event=False,
                )
                return meal.id
            finally:
                close_old_connections()

        with ThreadPoolExecutor(max_workers=2) as executor:
            meal_ids = list(executor.map(lambda _: finalize_once(), range(2)))

        self.assertEqual(len(set(meal_ids)), 1)
        self.assertEqual(MealLog.objects.filter(user=self.user).count(), 1)
        self.assertEqual(
            MealLogComponent.objects.filter(meal_log__user=self.user).count(),
            1,
        )
