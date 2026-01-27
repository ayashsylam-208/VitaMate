from datetime import date

from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient

from core.models import StepLog, WaterLog
from core.services.steps_service import StepsService


class ApiAccessTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.login_url = "/api/auth/login/"
        self.user1 = User.objects.create_user(username="user1", password="Pass123!")
        self.user2 = User.objects.create_user(username="user2", password="Pass123!")

    def _auth_client(self, username, password):
        client = APIClient()
        res = client.post(
            self.login_url,
            {"username": username, "password": password},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        token = res.data["access"]
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
        return client

    def test_protected_endpoint_requires_auth(self):
        res = self.client.get("/api/water/")
        self.assertIn(res.status_code, (401, 403))

    def test_user_isolation_on_water_logs(self):
        WaterLog.objects.create(user=self.user1, amount_liter=1.0)
        WaterLog.objects.create(user=self.user2, amount_liter=2.0)

        client = self._auth_client("user1", "Pass123!")
        res = client.get("/api/water/")

        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 1)
        self.assertEqual(res.data[0]["amount_liter"], 1.0)


class StepsServiceTests(TestCase):
    def test_steps_upsert_keeps_single_daily_record(self):
        user = User.objects.create_user(username="stepsuser", password="Pass123!")

        StepsService.log_steps(user=user, steps_count=1000, distance_km=0)
        StepsService.log_steps(user=user, steps_count=2000, distance_km=0)

        self.assertEqual(
            StepLog.objects.filter(user=user, date=date.today()).count(), 1
        )
        log = StepLog.objects.get(user=user, date=date.today())
        self.assertEqual(log.steps_count, 2000)
