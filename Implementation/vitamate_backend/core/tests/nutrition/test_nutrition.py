from rest_framework import status
from rest_framework.test import APITestCase

from core.models import (
    FoodCategory,
    FoodItem,
    FoodItemAlias,
    MealLog,
    NutritionFacts,
    NutritionServingOption,
    WaterLog,
)
from gamification.models import PointsTransaction, UserScore
from test_utils.helpers import auth_client_for_user, create_food_item, create_user_with_profile


class NutritionTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="mealuser")
        self.client_auth = auth_client_for_user(self.user)

    def test_food_and_meal_log_calories_reflected_in_dashboard(self):
        food_res = self.client_auth.post(
            "/api/foods/",
            {"name": "Pasta", "calories_100g": 200},
            format="json",
        )
        self.assertIn(food_res.status_code, (status.HTTP_200_OK, status.HTTP_201_CREATED))
        food_id = food_res.data["id"]
        self.assertTrue(
            FoodItemAlias.objects.filter(food_item_id=food_id, normalized_alias="pasta").exists()
        )

        meal_res = self.client_auth.post(
            "/api/meals/",
            {"food": food_id, "meal_type": "lunch", "quantity_grams": 150},
            format="json",
        )
        self.assertEqual(meal_res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(MealLog.objects.filter(user=self.user).count(), 1)
        self.assertEqual(meal_res.data["total_calories"], 300)

        dash = self.client_auth.get("/api/dashboard/")
        self.assertEqual(dash.status_code, status.HTTP_200_OK)
        summary = dash.data["summary"]
        self.assertEqual(summary["calories_consumed"], 300)

    def test_beverage_logging_by_ml_stores_snapshot(self):
        food_res = self.client_auth.post(
            "/api/foods/",
            {
                "name": "Black Coffee",
                "item_type": "beverage",
                "category": "Coffee",
                "default_serving_size": 250,
                "default_serving_unit": "ml",
                "density_g_per_ml": 1.0,
                "nutrition_facts": {
                    "basis_type": "per_100ml",
                    "basis_value": 100,
                    "serving_size": 250,
                    "serving_unit": "ml",
                    "calories_kcal": 2,
                    "caffeine_mg": 40,
                    "water_g": 98,
                },
                "serving_options": [
                    {
                        "name": "Cup 250ml",
                        "amount": 1,
                        "unit": "serving",
                        "grams_equivalent": 250,
                        "milliliters_equivalent": 250,
                        "is_default": True,
                    },
                    {
                        "name": "Bottle 500ml",
                        "amount": 1,
                        "unit": "serving",
                        "grams_equivalent": 500,
                        "milliliters_equivalent": 500,
                        "is_default": False,
                    }
                ],
            },
            format="json",
        )
        self.assertEqual(food_res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(len(food_res.data["serving_options"]), 2)

        meal_res = self.client_auth.post(
            "/api/meals/",
            {
                "food": food_res.data["id"],
                "meal_type": "drink",
                "quantity": 250,
                "unit": "ml",
            },
            format="json",
        )
        self.assertEqual(meal_res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(meal_res.data["total_calories"], 5)
        self.assertEqual(meal_res.data["milliliters_consumed"], 250)
        self.assertEqual(meal_res.data["grams_consumed"], 250)
        self.assertEqual(meal_res.data["snapshot_caffeine_mg"], 100)
        self.assertEqual(meal_res.data["snapshot_water_g"], 245)

        hydration_log = WaterLog.objects.get(linked_meal_log_id=meal_res.data["id"])
        self.assertEqual(hydration_log.food_item.name, "Black Coffee")
        self.assertAlmostEqual(hydration_log.amount_liter, 0.25)

        dash = self.client_auth.get("/api/dashboard/")
        self.assertEqual(dash.status_code, status.HTTP_200_OK)
        self.assertEqual(dash.data["summary"]["caffeine_mg"], 100)
        self.assertAlmostEqual(float(dash.data["hydration"]["current"]), 0.245, places=3)
        self.assertFalse(
            PointsTransaction.objects.filter(user=self.user, rule_code="MEAL_LOGGED").exists()
        )

    def test_nutrition_snapshot_does_not_change_when_facts_change(self):
        coffee = FoodItem.objects.create(
            name="Espresso",
            item_type=FoodItem.TYPE_BEVERAGE,
            density_g_per_ml=1.0,
            calories_100g=4,
        )
        NutritionFacts.objects.create(
            food_item=coffee,
            basis_type=NutritionFacts.BASIS_PER_100ML,
            basis_value=100,
            calories_kcal=4,
            caffeine_mg=80,
        )
        NutritionServingOption.objects.create(
            food_item=coffee,
            name="Shot 30ml",
            amount=1,
            unit="serving",
            grams_equivalent=30,
            milliliters_equivalent=30,
            is_default=True,
        )

        meal_res = self.client_auth.post(
            "/api/meals/",
            {"food": coffee.id, "meal_type": "drink", "quantity": 30, "unit": "ml"},
            format="json",
        )
        self.assertEqual(meal_res.status_code, status.HTTP_201_CREATED)
        log = MealLog.objects.get(id=meal_res.data["id"])
        self.assertEqual(log.snapshot_caffeine_mg, 24)

        facts = coffee.nutrition_facts
        facts.caffeine_mg = 200
        facts.save()

        log.refresh_from_db()
        self.assertEqual(log.snapshot_caffeine_mg, 24)

    def test_patch_meal_log_keeps_meal_type_and_updates_amount(self):
        food = create_food_item(name="Rice", calories_100g=130)

        create_res = self.client_auth.post(
            "/api/meals/",
            {"food": food.id, "meal_type": "lunch", "quantity_grams": 100},
            format="json",
        )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)

        meal_id = create_res.data["id"]
        patch_res = self.client_auth.patch(
            f"/api/meals/{meal_id}/",
            {"quantity_grams": 200},
            format="json",
        )
        self.assertEqual(patch_res.status_code, status.HTTP_200_OK)

        meal = MealLog.objects.get(id=meal_id)
        self.assertEqual(meal.meal_type, "lunch")
        self.assertEqual(meal.quantity_grams, 200)
        self.assertEqual(patch_res.data["total_calories"], 260)

    def test_updating_drink_meal_updates_linked_hydration_progress(self):
        drink = FoodItem.objects.create(
            name="Orange Juice",
            item_type=FoodItem.TYPE_BEVERAGE,
            category="Juice",
            default_serving_size=250,
            default_serving_unit="ml",
            density_g_per_ml=1.0,
            is_hydration_trackable=True,
        )
        NutritionFacts.objects.create(
            food_item=drink,
            basis_type=NutritionFacts.BASIS_PER_100ML,
            basis_value=100,
            serving_size=100,
            serving_unit="ml",
            calories_kcal=45,
            carbohydrates_g=11,
            sugars_g=10,
            water_g=85,
        )

        create_res = self.client_auth.post(
            "/api/meals/",
            {"food": drink.id, "meal_type": "drink", "quantity": 200, "unit": "ml"},
            format="json",
        )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)

        meal_id = create_res.data["id"]
        water_log = WaterLog.objects.get(linked_meal_log_id=meal_id)
        self.assertAlmostEqual(water_log.amount_liter, 0.2)

        patch_res = self.client_auth.patch(
            f"/api/meals/{meal_id}/",
            {"quantity": 300, "unit": "ml"},
            format="json",
        )
        self.assertEqual(patch_res.status_code, status.HTTP_200_OK)

        water_log.refresh_from_db()
        self.assertAlmostEqual(water_log.amount_liter, 0.3)
        self.assertAlmostEqual(water_log.linked_meal_log.snapshot_water_g, 255.0)

        dash = self.client_auth.get("/api/dashboard/")
        self.assertEqual(dash.status_code, status.HTTP_200_OK)
        self.assertAlmostEqual(float(dash.data["hydration"]["current"]), 0.255, places=3)

    def test_deleting_drink_meal_deletes_linked_hydration_log(self):
        drink = FoodItem.objects.create(
            name="Sparkling Water",
            item_type=FoodItem.TYPE_BEVERAGE,
            category="Water",
            default_serving_size=250,
            default_serving_unit="ml",
            density_g_per_ml=1.0,
            is_hydration_trackable=True,
        )
        NutritionFacts.objects.create(
            food_item=drink,
            basis_type=NutritionFacts.BASIS_PER_100ML,
            basis_value=100,
            serving_size=100,
            serving_unit="ml",
            water_g=100,
        )

        create_res = self.client_auth.post(
            "/api/meals/",
            {"food": drink.id, "meal_type": "drink", "quantity": 250, "unit": "ml"},
            format="json",
        )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
        meal_id = create_res.data["id"]
        self.assertTrue(WaterLog.objects.filter(linked_meal_log_id=meal_id).exists())

        delete_res = self.client_auth.delete(f"/api/meals/{meal_id}/")
        self.assertEqual(delete_res.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(MealLog.objects.filter(id=meal_id).exists())
        self.assertFalse(WaterLog.objects.filter(linked_meal_log_id=meal_id).exists())

    def test_drink_meals_do_not_count_as_real_meals_or_unlock_three_meal_mission(self):
        drink = FoodItem.objects.create(
            name="Mint Tea",
            item_type=FoodItem.TYPE_BEVERAGE,
            category="Tea",
            default_serving_size=250,
            default_serving_unit="ml",
            density_g_per_ml=1.0,
            is_hydration_trackable=True,
        )
        NutritionFacts.objects.create(
            food_item=drink,
            basis_type=NutritionFacts.BASIS_PER_100ML,
            basis_value=100,
            serving_size=100,
            serving_unit="ml",
            calories_kcal=2,
            water_g=100,
        )

        for _ in range(3):
            res = self.client_auth.post(
                "/api/meals/",
                {"food": drink.id, "meal_type": "drink", "quantity": 250, "unit": "ml"},
                format="json",
            )
            self.assertEqual(res.status_code, status.HTTP_201_CREATED)

        score = UserScore.objects.get(user=self.user)
        self.assertEqual(score.total_points, 9)
        self.assertFalse(
            PointsTransaction.objects.filter(user=self.user, rule_code="MEAL_LOGGED").exists()
        )
        self.assertFalse(
            PointsTransaction.objects.filter(user=self.user, rule_code="MEALS_LOGGED_3").exists()
        )

        missions = self.client_auth.get("/api/motivation/missions/")
        self.assertEqual(missions.status_code, status.HTTP_200_OK)
        nutrition_mission = next(
            item for item in missions.data["data"]["missions"] if item["mission_type"] == "nutrition_meals"
        )
        self.assertNotEqual(nutrition_mission["status"], "completed")
        self.assertEqual(nutrition_mission["current_value"], 0.0)

    def test_gain_goal_awards_points_when_calories_exceed_target(self):
        profile = self.user.userprofile
        profile.goal = "gain"
        profile.daily_calorie_target = 2000
        profile.save(update_fields=["goal", "daily_calorie_target"])
        food = create_food_item(name="Mass Bowl", calories_100g=900)

        res = self.client_auth.post(
            "/api/meals/",
            {"food": food.id, "meal_type": "lunch", "quantity_grams": 250},
            format="json",
        )

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        tx = PointsTransaction.objects.get(
            user=self.user,
            rule_code="NUTRITION_CALORIE_ALIGNMENT",
            source_id="calorie_alignment",
        )
        self.assertEqual(tx.points, 15)
        self.assertEqual(tx.metadata["profile_goal"], "gain")
        self.assertEqual(tx.metadata["calorie_alignment_status"], "surplus_for_gain")

    def test_loss_goal_deducts_points_when_calories_exceed_target(self):
        profile = self.user.userprofile
        profile.goal = "lose"
        profile.daily_calorie_target = 2000
        profile.save(update_fields=["goal", "daily_calorie_target"])
        food = create_food_item(name="Over Target Meal", calories_100g=900)

        res = self.client_auth.post(
            "/api/meals/",
            {"food": food.id, "meal_type": "dinner", "quantity_grams": 250},
            format="json",
        )

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        tx = PointsTransaction.objects.get(
            user=self.user,
            rule_code="NUTRITION_CALORIE_ALIGNMENT",
            source_id="calorie_alignment",
        )
        self.assertEqual(tx.points, -10)
        self.assertEqual(tx.event_type, PointsTransaction.EVENT_CORRECTION)
        self.assertEqual(tx.metadata["profile_goal"], "lose")
        self.assertEqual(tx.metadata["calorie_alignment_status"], "over_loss_target")

    def test_food_search_uses_alias_category_and_filters(self):
        coffee_category = FoodCategory.objects.get(code="coffee")
        coffee = FoodItem.objects.create(
            name="Black Coffee",
            item_type=FoodItem.TYPE_DRINK,
            primary_category=coffee_category,
            category="Coffee",
            density_g_per_ml=1.0,
            contains_caffeine=True,
            is_hydration_trackable=True,
            is_verified=True,
            search_priority=10,
        )
        NutritionFacts.objects.create(
            food_item=coffee,
            basis_type=NutritionFacts.BASIS_PER_100ML,
            basis_value=100,
            basis_amount=100,
            basis_unit="ml",
            calories_kcal=2,
            caffeine_mg=40,
        )
        FoodItemAlias.objects.create(
            food_item=coffee,
            alias="Americano",
            alias_type=FoodItemAlias.TYPE_COMMON_NAME,
            is_primary=False,
        )

        search_res = self.client_auth.get(
            "/api/foods/search/",
            {
                "q": "americano",
                "item_type": "drink",
                "category": "coffee",
                "contains_caffeine": "true",
                "limit": "5",
            },
        )
        self.assertEqual(search_res.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(search_res.data), 1)
        self.assertEqual(search_res.data[0]["id"], coffee.id)

        autocomplete_res = self.client_auth.get(
            "/api/foods/autocomplete/",
            {"q": "black", "limit": "1"},
        )
        self.assertEqual(autocomplete_res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(autocomplete_res.data), 1)
        self.assertEqual(autocomplete_res.data[0]["id"], coffee.id)
        self.assertEqual(autocomplete_res.data[0]["primary_category"]["code"], "coffee")
