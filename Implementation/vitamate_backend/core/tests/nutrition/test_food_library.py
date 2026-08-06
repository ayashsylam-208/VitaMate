from datetime import timedelta

from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from core.models import FavoriteFood, MealLog
from test_utils.helpers import create_food_item, create_user_with_profile


class FoodLibraryApiTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="food-library-user")
        self.other = create_user_with_profile(username="food-library-other")
        self.client.force_authenticate(self.user)
        self.apple = create_food_item(name="Library Apple")
        self.rice = create_food_item(name="Library Rice")
        self.private_food = create_food_item(
            name="Private Recipe",
            created_by=self.other,
        )

    def test_favorites_are_persisted_and_owner_scoped(self):
        response = self.client.post(
            f"/api/foods/{self.apple.id}/favorite/",
            {"is_favorite": True},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["is_favorite"])
        self.assertEqual(FavoriteFood.objects.filter(user=self.user).count(), 1)

        favorites = self.client.get("/api/foods/favorites/")
        self.assertEqual(favorites.status_code, status.HTTP_200_OK)
        self.assertEqual([item["id"] for item in favorites.data], [self.apple.id])

        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get("/api/foods/favorites/").data, [])

    def test_user_cannot_favorite_another_users_private_food(self):
        response = self.client.post(
            f"/api/foods/{self.private_food.id}/favorite/",
            {"is_favorite": True},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_recent_foods_are_ordered_by_last_use(self):
        now = timezone.now()
        MealLog.objects.create(
            user=self.user,
            food=self.apple,
            meal_type="snack",
            consumed_at=now - timedelta(hours=2),
        )
        MealLog.objects.create(
            user=self.user,
            food=self.rice,
            meal_type="lunch",
            consumed_at=now,
        )

        response = self.client.get("/api/foods/recent/?limit=10")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            [item["id"] for item in response.data],
            [self.rice.id, self.apple.id],
        )

    def test_autocomplete_supports_stable_offset_pagination(self):
        first = self.client.get(
            "/api/foods/autocomplete/",
            {"q": "Library", "limit": 1, "offset": 0},
        )
        second = self.client.get(
            "/api/foods/autocomplete/",
            {"q": "Library", "limit": 1, "offset": 1},
        )

        self.assertEqual(first.status_code, status.HTTP_200_OK)
        self.assertEqual(second.status_code, status.HTTP_200_OK)
        self.assertEqual(len(first.data), 1)
        self.assertEqual(len(second.data), 1)
        self.assertEqual(
            {first.data[0]["id"], second.data[0]["id"]},
            {self.apple.id, self.rice.id},
        )
