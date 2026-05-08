from datetime import timedelta

from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from core.models import MealLog, UnhealthyHabit, UnhealthyHabitLog, UnhealthyHabitPointEvent
from gamification.models import UserScore
from test_utils.helpers import auth_client_for_user, create_user_with_profile


class UnhealthyHabitTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="habits-user")
        self.client_auth = auth_client_for_user(self.user)

    def _create_setup(self, habit_type="caffeine", daily_limit=300, weekly_limit=None):
        create = self.client_auth.post(
            "/api/habits/unhealthy/",
            {"habit_type": habit_type, "goal_type": "reduce"},
            format="json",
        )
        self.assertEqual(create.status_code, status.HTTP_201_CREATED)
        habit_id = create.data["data"]["habit"]["id"]
        self.client_auth.post(
            f"/api/habits/unhealthy/{habit_id}/baseline/",
            {
                "initial_quantity": 400 if habit_type == "caffeine" else 5,
                "initial_frequency": 400 if habit_type == "caffeine" else 5,
                "unit": "mg" if habit_type == "caffeine" else "meals",
                "common_trigger": "stress",
            },
            format="json",
        )
        self.client_auth.post(
            f"/api/habits/unhealthy/{habit_id}/plan/",
            {
                "goal_type": "reduce",
                "daily_limit": daily_limit,
                "weekly_limit": weekly_limit,
                "cutoff_time": "18:00" if habit_type == "caffeine" else None,
            },
            format="json",
        )
        return habit_id

    def test_overview_contract_returns_three_cards(self):
        res = self.client_auth.get("/api/habits/unhealthy/overview/")

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue({"data", "meta"}.issubset(res.data.keys()))
        self.assertEqual(len(res.data["data"]["habits"]), 3)
        self.assertIn("summary", res.data["data"])

    def test_setup_and_log_caffeine_syncs_to_nutrition_and_awards_points(self):
        habit_id = self._create_setup()

        res = self.client_auth.post(
            f"/api/habits/unhealthy/{habit_id}/logs/",
            {
                "quantity": 1,
                "unit": "mg",
                "caffeine_mg": 120,
                "calories_kcal": 10,
                "food_name": "Habit coffee",
                "trigger": "study",
                "sync_to_tracker": True,
            },
            format="json",
        )

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        log = UnhealthyHabitLog.objects.get(habit_id=habit_id)
        self.assertIsNotNone(log.linked_meal_log)
        self.assertEqual(MealLog.objects.filter(user=self.user).count(), 1)
        self.assertGreater(UserScore.objects.get(user=self.user).total_points, 0)
        self.assertEqual(
            UnhealthyHabitPointEvent.objects.filter(habit_id=habit_id).count(),
            3,
        )

    def test_quit_plan_is_generated_from_baseline_without_manual_limit(self):
        create = self.client_auth.post(
            "/api/habits/unhealthy/",
            {"habit_type": "smoking", "goal_type": "quit"},
            format="json",
        )
        habit_id = create.data["data"]["habit"]["id"]
        self.client_auth.post(
            f"/api/habits/unhealthy/{habit_id}/baseline/",
            {
                "initial_quantity": 10,
                "initial_frequency": 10,
                "unit": "cigarettes",
                "common_trigger": "after meals",
            },
            format="json",
        )

        res = self.client_auth.post(
            f"/api/habits/unhealthy/{habit_id}/plan/",
            {"goal_type": "quit"},
            format="json",
        )

        plan = res.data["data"]["habit"]["plan"]
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(plan["daily_limit"], 8)
        self.assertEqual(plan["target_quantity"], 0)
        self.assertIn("Quit plan", plan["plan_stage"])

    def test_smoking_log_does_not_sync_to_nutrition(self):
        habit_id = self._create_setup(habit_type="smoking", daily_limit=5)

        res = self.client_auth.post(
            f"/api/habits/unhealthy/{habit_id}/logs/",
            {
                "quantity": 1,
                "unit": "cigarettes",
                "trigger": "stress",
                "sync_to_tracker": True,
            },
            format="json",
        )

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        log = UnhealthyHabitLog.objects.get(habit_id=habit_id)
        self.assertIsNone(log.linked_meal_log)
        self.assertEqual(MealLog.objects.filter(user=self.user).count(), 0)

    def test_over_limit_is_relapse_without_point_deduction(self):
        habit_id = self._create_setup(habit_type="smoking", daily_limit=1)
        self.client_auth.post(
            f"/api/habits/unhealthy/{habit_id}/logs/",
            {"quantity": 1, "unit": "cigarettes"},
            format="json",
        )
        before = UserScore.objects.get(user=self.user).total_points

        res = self.client_auth.post(
            f"/api/habits/unhealthy/{habit_id}/logs/",
            {"quantity": 2, "unit": "cigarettes"},
            format="json",
        )

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res.data["data"]["log"]["is_relapse"])
        self.assertGreaterEqual(UserScore.objects.get(user=self.user).total_points, before)

    def test_sleep_coach_reads_habit_late_caffeine(self):
        habit_id = self._create_setup()
        planned_bed = timezone.now().replace(hour=23, minute=0, second=0, microsecond=0)
        self.client_auth.post(
            f"/api/habits/unhealthy/{habit_id}/logs/",
            {
                "logged_at": planned_bed.replace(hour=19).isoformat(),
                "quantity": 1,
                "unit": "mg",
                "caffeine_mg": 100,
            },
            format="json",
        )

        res = self.client_auth.post(
            "/api/sleep/coach/plans/",
            {
                "planned_bed_time": planned_bed.isoformat(),
                "latest_wake_time": (planned_bed + timedelta(hours=8)).isoformat(),
                "flexibility_minutes": 30,
                "questionnaire": {},
            },
            format="json",
        )

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res.data["data"]["plan"]["tracker_factors"]["late_caffeine"])

    def test_pause_habit(self):
        habit_id = self._create_setup(habit_type="fast_food", daily_limit=None, weekly_limit=2)

        res = self.client_auth.post(f"/api/habits/unhealthy/{habit_id}/pause/")

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(UnhealthyHabit.objects.get(id=habit_id).status, "paused")
