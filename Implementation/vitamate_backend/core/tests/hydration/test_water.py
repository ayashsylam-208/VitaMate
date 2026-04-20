from rest_framework import status
from rest_framework.test import APITestCase

from core.models import FoodItem, MealLog, NutritionFacts, WaterLog
from gamification.models import UserScore
from test_utils.helpers import auth_client_for_user, create_user_with_profile


class WaterTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="wateruser")
        self.client_auth = auth_client_for_user(self.user)
        self.other_user = create_user_with_profile(username="waterother")
        self.other_client = auth_client_for_user(self.other_user)

    def _create_beverage(
        self,
        *,
        name,
        category,
        calories=0,
        protein=0,
        carbs=0,
        fat=0,
        sugars=0,
        caffeine=0,
        created_by=None,
    ):
        item = FoodItem.objects.create(
            name=name,
            created_by=created_by,
            item_type=FoodItem.TYPE_BEVERAGE,
            category=category,
            default_serving_size=250,
            default_serving_unit="ml",
            density_g_per_ml=1.0,
        )
        NutritionFacts.objects.create(
            food_item=item,
            basis_type=NutritionFacts.BASIS_PER_100ML,
            basis_value=100,
            serving_size=100,
            serving_unit="ml",
            calories_kcal=calories,
            protein_g=protein,
            carbohydrates_g=carbs,
            fat_g=fat,
            sugars_g=sugars,
            caffeine_mg=caffeine,
        )
        return item

    def test_create_water_log_and_persist(self):
        res = self.client_auth.post("/api/water/", {"amount_ml": 500}, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(WaterLog.objects.filter(user=self.user).count(), 1)
        self.assertEqual(float(res.data["amount_liter"]), 0.5)
        self.assertEqual(int(res.data["amount_ml"]), 500)
        self.assertEqual(res.data["beverage_type"], "water")
        self.assertEqual(res.data["beverage_name"], "Water")
        log = WaterLog.objects.get(user=self.user)
        self.assertIsNotNone(log.food_item)
        self.assertIsNotNone(log.linked_meal_log)
        self.assertEqual(log.linked_meal_log.meal_type, "drink")
        self.assertEqual(log.food_item.name, "Water")
        self.assertEqual(res.data["nutrition_preview"]["calories"], 0.0)

    def test_create_beverage_log_and_persist_metadata_from_legacy_catalog_match(self):
        self._create_beverage(
            name="Green Tea",
            category="Tea",
            calories=1,
            caffeine=12,
        )
        res = self.client_auth.post(
            "/api/water/",
            {
                "amount_ml": 250,
                "beverage_type": "tea",
                "beverage_name": "Green Tea",
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        log = WaterLog.objects.get(user=self.user, beverage_type="tea")
        self.assertEqual(log.beverage_name, "Green Tea")
        self.assertIsNotNone(log.food_item)
        self.assertEqual(log.food_item.name, "Green Tea")
        self.assertAlmostEqual(log.linked_meal_log.snapshot_caffeine_mg, 30.0)

    def test_catalog_beverage_logging_updates_nutrition_and_hydration(self):
        juice = self._create_beverage(
            name="Orange Juice",
            category="Juice",
            calories=45,
            carbs=11,
            sugars=10,
        )
        res = self.client_auth.post(
            "/api/water/",
            {"food_item": juice.id, "amount_ml": 200},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

        log = WaterLog.objects.get(user=self.user)
        self.assertEqual(log.food_item_id, juice.id)
        self.assertEqual(log.linked_meal_log.food_id, juice.id)
        self.assertAlmostEqual(log.linked_meal_log.snapshot_calories_kcal, 90.0)
        self.assertAlmostEqual(log.linked_meal_log.snapshot_carbohydrates_g, 22.0)

        dash = self.client_auth.get("/api/dashboard/")
        self.assertEqual(dash.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(float(dash.data["hydration"]["current"]), 0.2)
        self.assertEqual(dash.data["summary"]["calories_consumed"], 90)

    def test_custom_beverage_reusable_is_private_and_searchable(self):
        res = self.client_auth.post(
            "/api/water/",
            {
                "amount_ml": 330,
                "save_for_reuse": True,
                "custom_beverage": {
                    "name": "Sparkling Mate",
                    "beverage_type": "Energy",
                    "calories_kcal": 18,
                    "carbohydrates_g": 4.5,
                    "sugars_g": 4.0,
                    "caffeine_mg": 10,
                    "sodium_mg": 8,
                },
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

        log = WaterLog.objects.get(user=self.user)
        self.assertIsNotNone(log.food_item)
        self.assertEqual(log.food_item.created_by, self.user)
        self.assertEqual(log.food_item.item_type, FoodItem.TYPE_BEVERAGE)
        self.assertTrue(MealLog.objects.filter(id=log.linked_meal_log_id, meal_type="drink").exists())
        self.assertAlmostEqual(log.linked_meal_log.snapshot_calories_kcal, 59.4)
        self.assertAlmostEqual(log.linked_meal_log.snapshot_caffeine_mg, 33.0)

        foods_res = self.client_auth.get("/api/foods/?item_type=beverage&q=mate")
        self.assertEqual(foods_res.status_code, status.HTTP_200_OK)
        self.assertIn(log.food_item_id, [item["id"] for item in foods_res.data])

        other_res = self.other_client.get("/api/foods/?item_type=beverage&q=mate")
        self.assertEqual(other_res.status_code, status.HTTP_200_OK)
        self.assertNotIn(log.food_item_id, [item["id"] for item in other_res.data])

    def test_patch_water_log_updates_linked_meal_log(self):
        tea = self._create_beverage(name="Black Tea", category="Tea", calories=1, caffeine=20)
        coffee = self._create_beverage(name="Americano", category="Coffee", calories=2, caffeine=40)

        create_res = self.client_auth.post(
            "/api/water/",
            {"food_item": tea.id, "amount_ml": 200},
            format="json",
        )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
        meal_id = create_res.data["linked_meal_log"]
        log_id = create_res.data["id"]

        patch_res = self.client_auth.patch(
            f"/api/water/{log_id}/",
            {"food_item": coffee.id, "amount_ml": 100},
            format="json",
        )
        self.assertEqual(patch_res.status_code, status.HTTP_200_OK)

        log = WaterLog.objects.get(id=log_id)
        self.assertEqual(log.food_item_id, coffee.id)
        self.assertEqual(log.linked_meal_log_id, meal_id)
        self.assertEqual(log.linked_meal_log.food_id, coffee.id)
        self.assertEqual(log.linked_meal_log.milliliters_consumed, 100.0)
        self.assertAlmostEqual(log.linked_meal_log.snapshot_caffeine_mg, 40.0)

    def test_delete_water_log_deletes_linked_meal_log(self):
        coffee = self._create_beverage(name="Latte", category="Coffee", calories=30, caffeine=35)
        create_res = self.client_auth.post(
            "/api/water/",
            {"food_item": coffee.id, "amount_ml": 150},
            format="json",
        )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)

        log_id = create_res.data["id"]
        meal_id = create_res.data["linked_meal_log"]
        delete_res = self.client_auth.delete(f"/api/water/{log_id}/")
        self.assertEqual(delete_res.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(WaterLog.objects.filter(id=log_id).exists())
        self.assertFalse(MealLog.objects.filter(id=meal_id).exists())

    def test_dashboard_hydration_reflects_water(self):
        self.client_auth.post("/api/water/", {"amount_liter": 0.7}, format="json")
        dash = self.client_auth.get("/api/dashboard/")
        self.assertEqual(dash.status_code, status.HTTP_200_OK)
        hydration = dash.data["hydration"]
        self.assertGreaterEqual(float(hydration["current"]), 0.7)

    def test_points_awarded_on_water_log(self):
        self.client_auth.post("/api/water/", {"amount_liter": 0.25}, format="json")
        score = UserScore.objects.get(user=self.user)
        self.assertGreaterEqual(score.total_points, 5)
