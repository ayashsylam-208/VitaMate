from datetime import datetime, timedelta

from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from core.models import MealLog, SleepLog, SleepMorningFeedback, SleepPlan
from test_utils.helpers import auth_client_for_user, create_food_item, create_user_with_profile


class SleepCoachTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="sleepcoach")
        self.client_auth = auth_client_for_user(self.user)
        self.food = create_food_item(name="Coffee", calories_100g=5)

    def _aware(self, year, month, day, hour, minute):
        return timezone.make_aware(datetime(year, month, day, hour, minute))

    def _post_plan(self, *, bed=None, wake=None, flexibility=30, questionnaire=None):
        bed = bed or self._aware(2026, 5, 5, 23, 30)
        wake = wake or self._aware(2026, 5, 6, 7, 50)
        return self.client_auth.post(
            "/api/sleep/coach/plans/",
            {
                "planned_bed_time": bed.isoformat(),
                "latest_wake_time": wake.isoformat(),
                "flexibility_minutes": flexibility,
                "questionnaire": questionnaire or {},
            },
            format="json",
        )

    def test_plan_contract_window_and_cross_midnight(self):
        res = self._post_plan()

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue({"data", "meta"}.issubset(res.data.keys()))
        plan = res.data["data"]["plan"]
        self.assertEqual(plan["flexibility_minutes"], 30)
        self.assertIn(plan["primary_negative_factor"], {"none", "low_activity"})
        self.assertIn("recommendation_reason", plan)
        self.assertIn("wake_options", plan)

        window_start = datetime.fromisoformat(plan["wake_window_start"])
        window_end = datetime.fromisoformat(plan["wake_window_end"])
        selected = datetime.fromisoformat(plan["selected_wake_time"])
        self.assertEqual((window_end - window_start).total_seconds(), 30 * 60)
        self.assertLessEqual(window_start, selected)
        self.assertLessEqual(selected, window_end)

    def test_fallback_when_no_cycle_fits_window(self):
        res = self._post_plan(
            bed=self._aware(2026, 5, 5, 23, 0),
            wake=self._aware(2026, 5, 6, 1, 30),
            flexibility=0,
        )

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        option = res.data["data"]["plan"]["wake_options"][0]
        self.assertTrue(option["is_fallback"])
        self.assertIn("not an ideal sleep-cycle match", option["warning"])

    def test_tracker_late_caffeine_becomes_primary_factor(self):
        consumed_at = self._aware(2026, 5, 5, 18, 30)
        MealLog.objects.create(
            user=self.user,
            food=self.food,
            meal_type="drink",
            quantity_grams=100,
            consumed_at=consumed_at,
            snapshot_calories_kcal=5,
            snapshot_fat_g=0,
            snapshot_caffeine_mg=95,
        )

        res = self._post_plan(
            bed=self._aware(2026, 5, 5, 23, 0),
            wake=self._aware(2026, 5, 6, 7, 30),
        )

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        plan = res.data["data"]["plan"]
        self.assertEqual(plan["primary_negative_factor"], "late_caffeine")
        self.assertTrue(plan["tracker_factors"]["late_caffeine"])

    def test_feedback_creates_sleep_log_and_completes_plan(self):
        plan_res = self._post_plan()
        plan_id = plan_res.data["data"]["plan"]["id"]
        start = self._aware(2026, 5, 5, 23, 45)
        end = self._aware(2026, 5, 6, 7, 20)

        res = self.client_auth.post(
            "/api/sleep/coach/feedback/",
            {
                "plan_id": plan_id,
                "quality_rating": 4,
                "wake_feeling": "rested",
                "focus_rating": 4,
                "disruptor": "",
                "actual_sleep_start": start.isoformat(),
                "actual_wake_time": end.isoformat(),
            },
            format="json",
        )

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(SleepLog.objects.filter(user=self.user).count(), 1)
        self.assertEqual(SleepMorningFeedback.objects.filter(user=self.user).count(), 1)
        self.assertEqual(SleepPlan.objects.get(id=plan_id).status, SleepPlan.STATUS_COMPLETED)
        self.assertEqual(res.data["data"]["feedback"]["sleep_log_id"], SleepLog.objects.get(user=self.user).id)

    def test_today_endpoint_returns_learning_summary(self):
        for i in range(7):
            bed = self._aware(2026, 5, 1 + i, 23, 0)
            wake = self._aware(2026, 5, 2 + i, 7, 30)
            plan_res = self._post_plan(bed=bed, wake=wake)
            self.client_auth.post(
                "/api/sleep/coach/feedback/",
                {
                    "plan_id": plan_res.data["data"]["plan"]["id"],
                    "quality_rating": 4,
                    "wake_feeling": "rested",
                    "focus_rating": 4,
                    "actual_sleep_start": bed.isoformat(),
                    "actual_wake_time": (bed + timedelta(hours=7, minutes=30)).isoformat(),
                },
                format="json",
            )

        res = self.client_auth.get("/api/sleep/coach/today/")

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue({"data", "meta"}.issubset(res.data.keys()))
        self.assertGreaterEqual(res.data["data"]["learning_summary"]["sample_size"], 7)
        self.assertIn("latest_tracker_factors", res.data["data"])
