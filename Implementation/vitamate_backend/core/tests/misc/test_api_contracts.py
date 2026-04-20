from datetime import date, timedelta

from django.contrib.auth.models import User
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from core.models import StepLog, WaterLog
from core.services.steps_service import StepsService
from test_utils.helpers import (
    auth_client_for_user,
    create_exercise,
    create_food_item,
    create_user_with_profile,
)


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

        self.assertEqual(StepLog.objects.filter(user=user, date=date.today()).count(), 1)
        log = StepLog.objects.get(user=user, date=date.today())
        self.assertEqual(log.steps_count, 2000)


class ApiContractTests(TestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="contractuser")
        self.client_auth = auth_client_for_user(self.user)
        self.exercise = create_exercise(name="Run", met_value=8.0)
        self.food = create_food_item(name="Rice", calories_100g=150)

    def test_auth_me_contract(self):
        res = self.client_auth.get("/api/auth/me/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        expected_keys = {
            "username",
            "first_name",
            "last_name",
            "email",
            "weight",
            "height",
            "activity_level",
            "goal",
            "daily_step_goal",
            "gender",
            "birth_date",
            "recommended_sleep_hours",
            "target_wake_time",
            "target_bed_time",
            "enable_sleep_improvement",
            "preferred_activity_type",
            "enable_activity_reminders",
            "activity_reminder_interval_hours",
            "enable_water_reminders",
            "water_reminder_interval_minutes",
        }
        self.assertTrue(expected_keys.issubset(set(res.data.keys())))

    def test_dashboard_contract(self):
        self.client_auth.post("/api/water/", {"amount_liter": 0.5}, format="json")
        self.client_auth.post("/api/steps/", {"steps_count": 1500, "distance_km": 1.1}, format="json")
        self.client_auth.post(
            "/api/activities/",
            {"exercise": self.exercise.id, "duration_minutes": 20},
            format="json",
        )
        self.client_auth.post(
            "/api/meals/",
            {"food": self.food.id, "meal_type": "lunch", "quantity_grams": 100},
            format="json",
        )

        res = self.client_auth.get("/api/dashboard/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        self.assertTrue({"summary", "hydration", "sleep", "activity", "gamification"}.issubset(res.data.keys()))
        self.assertTrue(
            {
                "calories_target",
                "calories_consumed",
                "calories_remaining",
                "calories_burned",
                "burn_target",
            }.issubset(res.data["summary"].keys())
        )
        self.assertTrue({"target", "current", "adjusted_target"}.issubset(res.data["hydration"].keys()))
        self.assertTrue(
            {
                "target_bed_time",
                "target_wake_time",
                "recommended_sleep_hours",
                "logged_hours_today",
                "progress_percent",
            }.issubset(res.data["sleep"].keys())
        )
        self.assertTrue(
            {
                "steps",
                "steps_target",
                "distance_km",
                "steps_burned",
                "steps_burn_rate",
            }.issubset(res.data["activity"].keys())
        )
        self.assertTrue({"points", "level"}.issubset(res.data["gamification"].keys()))

    def test_history_contract(self):
        res = self.client_auth.get("/api/history/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("history", res.data)
        self.assertEqual(len(res.data["history"]), 7)

        item = res.data["history"][0]
        expected_keys = {
            "date",
            "water_current",
            "water_target",
            "steps",
            "steps_target",
            "distance_km",
            "steps_burned",
            "steps_burn_rate",
            "calories_in",
            "calories_target",
            "calories_burned",
            "sleep_hours",
            "sleep_target",
            "exercise_minutes",
            "points_estimate",
            "burn_target",
            "burn_current",
        }
        self.assertTrue(expected_keys.issubset(set(item.keys())))

    def test_water_post_contract(self):
        res = self.client_auth.post("/api/water/", {"amount_liter": 0.25}, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue({"id", "amount_liter", "date"}.issubset(set(res.data.keys())))

    def test_steps_post_contract(self):
        res = self.client_auth.post("/api/steps/", {"steps_count": 2000}, format="json")
        self.assertIn(res.status_code, (status.HTTP_200_OK, status.HTTP_201_CREATED))
        self.assertTrue(
            {
                "id",
                "steps_count",
                "distance_km",
                "date",
                "calories_burned",
                "burn_rate_kcal_per_km",
            }.issubset(set(res.data.keys()))
        )

    def test_sleep_post_contract(self):
        start = timezone.now() - timedelta(hours=7)
        end = timezone.now()
        res = self.client_auth.post(
            "/api/sleep/",
            {
                "start_time": start.isoformat(),
                "end_time": end.isoformat(),
                "quality": "Deep",
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(
            {
                "id",
                "start_time",
                "end_time",
                "quality",
                "date",
                "duration_hours",
                "points_earned",
            }.issubset(set(res.data.keys()))
        )

    def test_activity_post_contract(self):
        res = self.client_auth.post(
            "/api/activities/",
            {"exercise": self.exercise.id, "duration_minutes": 25},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(
            {
                "id",
                "exercise",
                "exercise_name",
                "duration_minutes",
                "date",
                "calories_burned",
            }.issubset(set(res.data.keys()))
        )

    def test_meal_post_contract(self):
        res = self.client_auth.post(
            "/api/meals/",
            {"food": self.food.id, "meal_type": "breakfast", "quantity_grams": 110},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(
            {
                "id",
                "food",
                "food_name",
                "meal_type",
                "quantity_grams",
                "date",
                "total_calories",
            }.issubset(set(res.data.keys()))
        )


class DashboardCoordinatorTests(TestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="flaguser")
        self.client_auth = auth_client_for_user(self.user)
        self.exercise = create_exercise(name="Cycle", met_value=6.5)
        self.food = create_food_item(name="Oats", calories_100g=370)

        self.client_auth.post("/api/water/", {"amount_liter": 0.75}, format="json")
        self.client_auth.post("/api/steps/", {"steps_count": 3200, "distance_km": 2.4}, format="json")
        self.client_auth.post(
            "/api/activities/",
            {"exercise": self.exercise.id, "duration_minutes": 35},
            format="json",
        )
        self.client_auth.post(
            "/api/meals/",
            {"food": self.food.id, "meal_type": "lunch", "quantity_grams": 120},
            format="json",
        )
        start = timezone.now() - timedelta(hours=7, minutes=30)
        end = timezone.now()
        self.client_auth.post(
            "/api/sleep/",
            {"start_time": start.isoformat(), "end_time": end.isoformat(), "quality": "Deep"},
            format="json",
        )

    def test_dashboard_payload_includes_condition_summary_contract(self):
        res = self.client_auth.get("/api/dashboard/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("chronic_conditions", res.data)
        self.assertTrue(
            {
                "count",
                "labels",
                "adherence_percent",
                "active_medications_today",
                "pending_doses_today",
                "applied_summaries",
                "disclaimer",
            }.issubset(res.data["chronic_conditions"].keys())
        )

    def test_history_payload_includes_condition_context(self):
        res = self.client_auth.get("/api/history/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        item = res.data["history"][0]
        self.assertIn("condition_adherence_percent", item)
        self.assertIn("pending_condition_doses", item)
