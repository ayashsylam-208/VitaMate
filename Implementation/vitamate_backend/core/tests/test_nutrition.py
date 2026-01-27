from rest_framework import status
from rest_framework.test import APITestCase

from core.models import MealLog
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
