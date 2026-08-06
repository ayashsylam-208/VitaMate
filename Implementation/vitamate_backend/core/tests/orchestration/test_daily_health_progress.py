from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from core.models import ActivityLog, Exercise, FoodItem, MealLog, StepLog, WaterLog
from core.services.health_progress import DailyHealthProgressService
from gamification.models import PointsTransaction
from gamification.services.points_service import PointsService
from test_utils.helpers import auth_client_for_user, create_user_with_profile


class DailyHealthProgressTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="dailyhealth")
        self.profile = self.user.userprofile
        self.profile.daily_water_target = 2.0
        self.profile.daily_step_goal = 6000
        self.profile.daily_burn_goal = 250
        self.profile.daily_calorie_target = 2000
        self.profile.recommended_sleep_hours = 8
        self.profile.save()
        self.today = timezone.localdate()

    def test_points_do_not_change_daily_health_progress(self):
        before = DailyHealthProgressService.evaluate(user=self.user, target_date=self.today)

        PointsService.apply_delta(
            self.user,
            points=80,
            rule_code="MANUAL_DELTA",
            source_type=PointsTransaction.SOURCE_SYSTEM,
            source_id="test",
            reason="test points",
            event_date=self.today,
        )

        after = DailyHealthProgressService.evaluate(user=self.user, target_date=self.today)

        self.assertEqual(
            before["daily_health"]["progress_percent"],
            after["daily_health"]["progress_percent"],
        )
        self.assertFalse(after["daily_health"]["daily_complete"])

    def test_hydration_and_activity_do_not_complete_day_without_nutrition(self):
        WaterLog.objects.create(user=self.user, amount_liter=2.0)
        StepLog.objects.update_or_create(
            user=self.user,
            date=self.today,
            defaults={"steps_count": 7000},
        )
        exercise = Exercise.objects.create(name="Walk", met_value=4.0)
        ActivityLog.objects.create(
            user=self.user,
            exercise=exercise,
            duration_minutes=30,
        )

        payload = DailyHealthProgressService.evaluate(user=self.user, target_date=self.today)
        nutrition = next(
            domain for domain in payload["domains"] if domain["domain"] == "nutrition"
        )

        self.assertEqual(nutrition["status"], "not_logged")
        self.assertFalse(payload["daily_health"]["daily_complete"])
        self.assertEqual(payload["focus"]["domain"], "nutrition")

    def test_three_meals_are_required_for_nutrition_completion(self):
        food = FoodItem.objects.create(name="Meal", calories_100g=500)
        MealLog.objects.create(
            user=self.user,
            food=food,
            meal_type="breakfast",
            quantity_grams=100,
            snapshot_calories_kcal=500,
        )

        payload = DailyHealthProgressService.evaluate(user=self.user, target_date=self.today)
        nutrition = next(
            domain for domain in payload["domains"] if domain["domain"] == "nutrition"
        )

        self.assertEqual(nutrition["status"], "in_progress")
        self.assertLess(nutrition["score"], 100)
        self.assertFalse(payload["daily_health"]["daily_complete"])

    def test_required_steps_complete_without_exercise_does_not_complete_movement(self):
        StepLog.objects.update_or_create(
            user=self.user,
            date=self.today,
            defaults={"steps_count": 7000, "sensor_steps": 7000},
        )

        payload = DailyHealthProgressService.evaluate(user=self.user, target_date=self.today)
        movement = next(
            domain for domain in payload["domains"] if domain["domain"] == "movement"
        )
        exercise = next(
            component for component in movement["components"] if component["key"] == "activity_minutes"
        )

        self.assertEqual(exercise["status"], "not_started")
        self.assertTrue(exercise["required"])
        self.assertEqual(movement["status"], "in_progress")
        self.assertLess(movement["score"], 100)

    def test_no_medication_plan_is_not_applicable(self):
        payload = DailyHealthProgressService.evaluate(user=self.user, target_date=self.today)
        medication = next(
            domain for domain in payload["domains"] if domain["domain"] == "medication"
        )

        self.assertEqual(medication["status"], "not_applicable")
        self.assertFalse(medication["is_applicable"])
        self.assertFalse(medication["is_essential"])

    def test_home_overview_exposes_daily_health_contract(self):
        client = auth_client_for_user(self.user)

        res = client.get("/api/home/overview/")

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.data["data"]
        self.assertIn("daily_health", data)
        self.assertIn("domains", data)
        self.assertIn("focus", data)
        self.assertIn("xp", data)
        self.assertFalse(data["daily_health"]["daily_complete"])
        self.assertEqual(data["xp"]["daily_points"], data["daily_points"])
