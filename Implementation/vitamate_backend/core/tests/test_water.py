from rest_framework import status
from rest_framework.test import APITestCase

from core.models import WaterLog
from gamification.models import UserScore
from test_utils.helpers import auth_client_for_user, create_user_with_profile


class WaterTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="wateruser")
        self.client_auth = auth_client_for_user(self.user)

    def test_create_water_log_and_persist(self):
        res = self.client_auth.post("/api/water/", {"amount_liter": 0.5}, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(WaterLog.objects.filter(user=self.user).count(), 1)
        self.assertEqual(float(res.data["amount_liter"]), 0.5)

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
