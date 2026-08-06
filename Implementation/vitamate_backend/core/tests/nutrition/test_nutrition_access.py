from datetime import timedelta

from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from core.models import FoodItem, MealLog, NutritionFacts, NutritionServingOption
from test_utils.helpers import auth_client_for_user, create_food_item, create_user_with_profile


class NutritionCatalogAccessTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="nutrition-reader")
        self.client_auth = auth_client_for_user(self.user)
        self.staff = create_user_with_profile(username="nutrition-admin")
        self.staff.is_staff = True
        self.staff.save(update_fields=["is_staff"])
        self.staff_client = auth_client_for_user(self.staff)
        self.food = create_food_item(name="Catalog Security Food")

    def test_regular_user_can_read_but_cannot_mutate_nutrition_facts(self):
        facts = NutritionFacts.objects.create(food_item=self.food, calories_kcal=42)

        self.assertEqual(
            self.client_auth.get(f"/api/nutrition-facts/{facts.id}/").status_code,
            status.HTTP_200_OK,
        )
        self.assertEqual(
            self.client_auth.patch(
                f"/api/nutrition-facts/{facts.id}/",
                {"calories_kcal": 999},
                format="json",
            ).status_code,
            status.HTTP_403_FORBIDDEN,
        )
        self.assertEqual(
            self.client_auth.delete(f"/api/nutrition-facts/{facts.id}/").status_code,
            status.HTTP_403_FORBIDDEN,
        )
        facts.refresh_from_db()
        self.assertEqual(facts.calories_kcal, 42)

    def test_only_staff_can_create_catalog_facts_and_servings(self):
        regular_food = create_food_item(name="Regular Fact Target")
        self.assertEqual(
            self.client_auth.post(
                "/api/nutrition-facts/",
                {"food_item": regular_food.id, "calories_kcal": 10},
                format="json",
            ).status_code,
            status.HTTP_403_FORBIDDEN,
        )

        staff_food = create_food_item(name="Staff Fact Target")
        facts_response = self.staff_client.post(
            "/api/nutrition-facts/",
            {"food_item": staff_food.id, "calories_kcal": 10},
            format="json",
        )
        self.assertEqual(facts_response.status_code, status.HTTP_201_CREATED)

        regular_serving = self.client_auth.post(
            "/api/nutrition-serving-options/",
            {"food_item": staff_food.id, "name": "Cup", "unit": "serving"},
            format="json",
        )
        self.assertEqual(regular_serving.status_code, status.HTTP_403_FORBIDDEN)
        staff_serving = self.staff_client.post(
            "/api/nutrition-serving-options/",
            {"food_item": staff_food.id, "name": "Cup", "unit": "serving"},
            format="json",
        )
        self.assertEqual(staff_serving.status_code, status.HTTP_201_CREATED)


class MealLogOwnershipAndHistoryTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="meal-owner")
        self.other_user = create_user_with_profile(username="meal-other")
        self.client_auth = auth_client_for_user(self.user)
        self.other_client = auth_client_for_user(self.other_user)
        self.global_food = create_food_item(name="Global Meal Food")
        self.own_food = create_food_item(name="Owner Custom Food", created_by=self.user)
        self.other_food = create_food_item(
            name="Other Custom Food",
            created_by=self.other_user,
        )

    def _create_meal(self, client, food, *, consumed_at=None):
        payload = {
            "food": food.id,
            "meal_type": "lunch",
            "quantity_grams": 100,
        }
        if consumed_at is not None:
            payload["consumed_at"] = consumed_at.isoformat()
        return client.post("/api/meals/", payload, format="json")

    def test_user_can_log_global_and_own_food_but_not_another_users_food(self):
        self.assertEqual(
            self._create_meal(self.client_auth, self.global_food).status_code,
            status.HTTP_201_CREATED,
        )
        self.assertEqual(
            self._create_meal(self.client_auth, self.own_food).status_code,
            status.HTTP_201_CREATED,
        )
        rejected = self._create_meal(self.client_auth, self.other_food)
        self.assertEqual(rejected.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("food", rejected.data)

    def test_meal_detail_is_owner_scoped(self):
        response = self._create_meal(self.other_client, self.other_food)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        meal_id = response.data["id"]

        self.assertEqual(
            self.client_auth.get(f"/api/meals/{meal_id}/").status_code,
            status.HTTP_404_NOT_FOUND,
        )
        self.assertEqual(
            self.client_auth.patch(
                f"/api/meals/{meal_id}/",
                {"quantity_grams": 200},
                format="json",
            ).status_code,
            status.HTTP_404_NOT_FOUND,
        )
        self.assertEqual(
            self.client_auth.delete(f"/api/meals/{meal_id}/").status_code,
            status.HTTP_404_NOT_FOUND,
        )
        self.assertTrue(MealLog.objects.filter(id=meal_id).exists())

    def test_old_meal_can_be_retrieved_updated_deleted_and_listed_by_date(self):
        consumed_at = timezone.now() - timedelta(days=3)
        response = self._create_meal(
            self.client_auth,
            self.own_food,
            consumed_at=consumed_at,
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        meal_id = response.data["id"]
        meal_date = timezone.localtime(consumed_at).date()

        self.assertEqual(
            self.client_auth.get(f"/api/meals/{meal_id}/").status_code,
            status.HTTP_200_OK,
        )
        update = self.client_auth.patch(
            f"/api/meals/{meal_id}/",
            {"quantity_grams": 150},
            format="json",
        )
        self.assertEqual(update.status_code, status.HTTP_200_OK)

        history = self.client_auth.get("/api/meals/", {"date": meal_date.isoformat()})
        self.assertEqual(history.status_code, status.HTTP_200_OK)
        self.assertEqual([row["id"] for row in history.data], [meal_id])
        self.assertEqual(
            self.client_auth.get("/api/meals/", {"date": "not-a-date"}).status_code,
            status.HTTP_400_BAD_REQUEST,
        )

        self.assertEqual(
            self.client_auth.delete(f"/api/meals/{meal_id}/").status_code,
            status.HTTP_204_NO_CONTENT,
        )
        self.assertFalse(MealLog.objects.filter(id=meal_id).exists())
