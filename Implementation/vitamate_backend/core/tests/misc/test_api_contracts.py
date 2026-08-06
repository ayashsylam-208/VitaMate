from datetime import date, timedelta
from decimal import Decimal

from django.contrib.auth.models import User
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from core.models import (
    ConditionMedication,
    ConditionMedicationLog,
    NutritionFacts,
    StepLog,
    UnifiedHealthState,
    WaterLog,
)
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
        log1 = WaterLog.objects.create(user=self.user1, amount_liter=1.0)
        log2 = WaterLog.objects.create(user=self.user2, amount_liter=2.0)
        WaterLog.objects.filter(id=log1.id).update(date=timezone.localdate())
        WaterLog.objects.filter(id=log2.id).update(date=timezone.localdate())

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
            StepLog.objects.filter(user=user, date=timezone.localdate()).count(),
            1,
        )
        log = StepLog.objects.get(user=user, date=timezone.localdate())
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
            "activity_reminder_time",
            "activity_reminder_days",
            "inactive_reminder_enabled",
            "inactive_reminder_hours",
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

    def test_home_overview_contract(self):
        res = self.client_auth.get("/api/home/overview/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue({"data", "meta"}.issubset(res.data.keys()))
        self.assertTrue(
            {
                "points",
                "level",
                "daily_points",
                "today_steps",
                "step_target",
                "activity_burned_kcal",
                "activity_minutes",
                "burn_target_kcal",
                "water_ml",
                "sleep_minutes",
                "calories",
                "missions_completed",
                "missions_total",
                "current_streak",
                "level_name",
                "chronic_conditions",
                "conditions_center",
                "daily_health",
                "domains",
                "focus",
                "xp",
                "streaks",
            }.issubset(res.data["data"].keys())
        )
        self.assertTrue(
            {
                "progress_percent",
                "coverage_percent",
                "completion_status",
                "daily_complete",
                "score_version",
            }.issubset(res.data["data"]["daily_health"].keys())
        )
        self.assertTrue(
            {"is_stale", "computed_at", "snapshot_version", "request_id"}.issubset(
                res.data["meta"].keys()
            )
        )

    def test_progress_endpoints_contract(self):
        overview = self.client_auth.get("/api/progress/overview/")
        self.assertEqual(overview.status_code, status.HTTP_200_OK)
        self.assertTrue({"data", "meta"}.issubset(overview.data.keys()))
        self.assertTrue(
            {
                "summary",
                "hydration",
                "sleep",
                "activity",
                "gamification",
                "chronic_conditions",
                "medications",
            }.issubset(overview.data["data"].keys())
        )
        self.assertTrue(
            {
                "overall_score",
                "points",
                "level",
                "weekly_consistency",
                "tracker_cards",
                "timeline_7d",
                "insight",
            }.issubset(overview.data["data"].keys())
        )

        history = self.client_auth.get("/api/progress/history/")
        self.assertEqual(history.status_code, status.HTTP_200_OK)
        self.assertTrue({"data", "meta"}.issubset(history.data.keys()))
        self.assertIn("history", history.data["data"])
        self.assertEqual(len(history.data["data"]["history"]), 7)

        detail = self.client_auth.get("/api/progress/details/nutrition/?range_days=14")
        self.assertEqual(detail.status_code, status.HTTP_200_OK)
        self.assertTrue({"data", "meta"}.issubset(detail.data.keys()))
        self.assertTrue(
            {
                "tracker",
                "title",
                "score",
                "status",
                "range_days",
                "summary_cards",
                "metrics",
                "trend",
                "sections",
                "insight",
            }.issubset(detail.data["data"].keys())
        )
        self.assertEqual(detail.data["data"]["tracker"], "nutrition")
        self.assertEqual(detail.data["data"]["range_days"], 14)
        tracker_codes = {
            item.get("code")
            for item in overview.data["data"].get("tracker_cards", [])
        }
        self.assertIn("motivation", tracker_codes)
        self.assertIn("activity", tracker_codes)
        self.assertNotIn("steps", tracker_codes)

    def test_progress_overview_uses_projection_when_snapshot_missing(self):
        profile = self.user.userprofile
        profile.daily_calorie_target = 2150
        profile.daily_water_target = 2.4
        profile.daily_step_goal = 8500
        profile.daily_burn_goal = 420
        profile.recommended_sleep_hours = 7.5
        profile.save(
            update_fields=[
                "daily_calorie_target",
                "daily_water_target",
                "daily_step_goal",
                "daily_burn_goal",
                "recommended_sleep_hours",
            ]
        )

        res = self.client_auth.get("/api/progress/overview/")

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["data"]["summary"]["calories_target"], 2150)
        self.assertEqual(res.data["data"]["summary"]["burn_target"], 420)
        self.assertEqual(res.data["data"]["hydration"]["target"], 2.4)
        self.assertEqual(res.data["data"]["sleep"]["recommended_sleep_hours"], 7.5)
        self.assertEqual(res.data["data"]["activity"]["steps_target"], 8500)

    def test_feature_summary_endpoints_contract(self):
        endpoints = {
            "/api/nutrition/summary/": {
                "target_calories",
                "consumed_calories",
                "burned_calories",
                "remaining_calories",
                "points",
            },
            "/api/nutrition/micronutrients/": {
                "date",
                "items",
                "disclaimer",
            },
            "/api/hydration/summary/": {
                "target_ml",
                "consumed_ml",
                "remaining_ml",
                "progress_percent",
            },
            "/api/sleep/summary/": {
                "goal_hours",
                "logged_hours_today",
                "progress_percent",
                "sleep_points",
            },
            "/api/steps/summary/": {
                "target_steps",
                "steps_today",
                "remaining_steps",
                "extra_steps",
                "steps_progress_percent",
                "distance_km",
                "calories_burned",
                "burn_rate_kcal_per_km",
                "points",
            },
            "/api/activity/summary/": {
                "burn_target",
                "burn_current",
                "exercise_minutes",
                "points_estimate",
                "today_summary",
                "weekly_summary",
                "active_session",
                "suggestions",
            },
            "/api/medications/overview/": {
                "medications",
                "today_plan",
                "overall_adherence",
                "snapshot_summary",
            },
            "/api/chronic/overview/": {
                "conditions",
                "today_doses",
                "summary",
            },
        }

        for endpoint, expected_keys in endpoints.items():
            with self.subTest(endpoint=endpoint):
                res = self.client_auth.get(endpoint)
                self.assertEqual(res.status_code, status.HTTP_200_OK)
                self.assertTrue({"data", "meta"}.issubset(res.data.keys()))
                self.assertTrue(expected_keys.issubset(res.data["data"].keys()))

    def test_motivation_endpoints_contract(self):
        overview = self.client_auth.get("/api/motivation/overview/")
        self.assertEqual(overview.status_code, status.HTTP_200_OK)
        self.assertTrue({"data", "meta"}.issubset(overview.data.keys()))
        self.assertTrue(
            {
                "daily_points",
                "total_points",
                "level",
                "level_name",
                "missions_completed",
                "missions_total",
                "current_streak",
                "longest_streak",
                "insight",
            }.issubset(overview.data["data"].keys())
        )

        missions = self.client_auth.get("/api/motivation/missions/")
        self.assertEqual(missions.status_code, status.HTTP_200_OK)
        self.assertTrue({"data", "meta"}.issubset(missions.data.keys()))
        mission_items = missions.data["data"].get("missions", [])
        self.assertIsInstance(mission_items, list)
        if mission_items:
            first_id = mission_items[0]["id"]
            refresh = self.client_auth.post(
                f"/api/motivation/missions/{first_id}/refresh/",
                {},
                format="json",
            )
            self.assertEqual(refresh.status_code, status.HTTP_200_OK)
            self.assertTrue({"data", "meta"}.issubset(refresh.data.keys()))

        points = self.client_auth.get("/api/motivation/points/?range_days=14")
        self.assertEqual(points.status_code, status.HTTP_200_OK)
        self.assertTrue({"data", "meta"}.issubset(points.data.keys()))
        self.assertIn("days", points.data["data"])
        self.assertIn("transactions", points.data["data"])

        badges = self.client_auth.get("/api/motivation/badges/")
        self.assertEqual(badges.status_code, status.HTTP_200_OK)
        self.assertTrue({"data", "meta"}.issubset(badges.data.keys()))
        self.assertIn("badges", badges.data["data"])

        feed = self.client_auth.get("/api/motivation/feed/")
        self.assertEqual(feed.status_code, status.HTTP_200_OK)
        self.assertTrue({"data", "meta"}.issubset(feed.data.keys()))
        self.assertTrue(
            {
                "summary",
                "focus",
                "celebrations",
                "updated_at",
            }.issubset(feed.data["data"].keys())
        )

        ack = self.client_auth.post(
            "/api/motivation/celebrations/ack/",
            {"ids": []},
            format="json",
        )
        self.assertEqual(ack.status_code, status.HTTP_200_OK)
        self.assertIn("acknowledged_ids", ack.data["data"])

    def test_nutrition_summary_uses_profile_calorie_target_when_snapshot_missing(self):
        self.user.userprofile.daily_calorie_target = 2150
        self.user.userprofile.save(update_fields=["daily_calorie_target"])

        res = self.client_auth.get("/api/nutrition/summary/")

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["data"]["target_calories"], 2150)
        state = UnifiedHealthState.objects.get(
            user=self.user,
            state_date=timezone.localdate(),
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
        )
        self.assertEqual(
            res.data["data"]["active_target_calories"],
            state.progress_summary["summary"]["calories_target"],
        )

    def test_nutrition_summary_tracks_live_meal_changes(self):
        create_res = self.client_auth.post(
            "/api/meals/",
            {"food": self.food.id, "meal_type": "lunch", "quantity_grams": 100},
            format="json",
        )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)

        summary_res = self.client_auth.get("/api/nutrition/summary/")
        self.assertEqual(summary_res.status_code, status.HTTP_200_OK)
        self.assertEqual(summary_res.data["data"]["consumed_calories"], 150)

        meal_id = create_res.data["id"]
        update_res = self.client_auth.patch(
            f"/api/meals/{meal_id}/",
            {"quantity_grams": 200},
            format="json",
        )
        self.assertEqual(update_res.status_code, status.HTTP_200_OK)

        summary_res = self.client_auth.get("/api/nutrition/summary/")
        self.assertEqual(summary_res.data["data"]["consumed_calories"], 300)

        delete_res = self.client_auth.delete(f"/api/meals/{meal_id}/")
        self.assertEqual(delete_res.status_code, status.HTTP_204_NO_CONTENT)

        summary_res = self.client_auth.get("/api/nutrition/summary/")
        self.assertEqual(summary_res.data["data"]["consumed_calories"], 0)

    def test_activity_and_steps_summaries_use_projection_when_snapshot_missing(self):
        profile = self.user.userprofile
        profile.daily_step_goal = 9000
        profile.daily_burn_goal = 450
        profile.save(update_fields=["daily_step_goal", "daily_burn_goal"])

        self.client_auth.post(
            "/api/steps/",
            {"steps_count": 2500, "distance_km": 1.8},
            format="json",
        )
        self.client_auth.post(
            "/api/activities/",
            {"exercise": self.exercise.id, "duration_minutes": 20},
            format="json",
        )

        steps_res = self.client_auth.get("/api/steps/summary/")
        activity_res = self.client_auth.get("/api/activity/summary/")

        self.assertEqual(steps_res.status_code, status.HTTP_200_OK)
        self.assertEqual(steps_res.data["data"]["target_steps"], 9000)
        self.assertEqual(steps_res.data["data"]["steps_today"], 2500)
        self.assertEqual(steps_res.data["data"]["extra_steps"], 0)
        self.assertGreater(steps_res.data["data"]["calories_burned"], 0)

        self.assertEqual(activity_res.status_code, status.HTTP_200_OK)
        self.assertEqual(activity_res.data["data"]["burn_target"], 450)
        self.assertEqual(activity_res.data["data"]["exercise_minutes"], 20)
        self.assertGreater(activity_res.data["data"]["burn_current"], 0)
        self.assertGreater(activity_res.data["data"]["points_estimate"], 0)

        home_res = self.client_auth.get("/api/home/overview/")
        progress_res = self.client_auth.get("/api/progress/overview/")

        self.assertEqual(home_res.status_code, status.HTTP_200_OK)
        self.assertGreater(home_res.data["data"]["points"], 0)
        self.assertGreaterEqual(home_res.data["data"]["level"], 1)
        self.assertGreater(home_res.data["data"]["daily_points"], 0)
        self.assertEqual(home_res.data["data"]["today_steps"], 2500)
        self.assertEqual(home_res.data["data"]["step_target"], 9000)
        self.assertEqual(home_res.data["data"]["activity_minutes"], 20)
        self.assertGreater(home_res.data["data"]["activity_burned_kcal"], 0)
        self.assertEqual(home_res.data["data"]["burn_target_kcal"], 450)

        self.assertEqual(progress_res.status_code, status.HTTP_200_OK)
        self.assertGreater(
            progress_res.data["data"]["summary"]["calories_burned"],
            0,
        )
        self.assertEqual(progress_res.data["data"]["activity"]["steps"], 2500)

    def test_steps_summary_reports_steps_over_goal_from_direct_log(self):
        profile = self.user.userprofile
        profile.daily_step_goal = 8000
        profile.save(update_fields=["daily_step_goal"])

        self.client_auth.post(
            "/api/steps/",
            {"steps_count": 8250, "distance_km": 6.1},
            format="json",
        )

        res = self.client_auth.get("/api/steps/summary/")

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["data"]["target_steps"], 8000)
        self.assertEqual(res.data["data"]["steps_today"], 8250)
        self.assertEqual(res.data["data"]["remaining_steps"], 0)
        self.assertEqual(res.data["data"]["extra_steps"], 250)
        self.assertGreaterEqual(res.data["data"]["steps_progress_percent"], 103)

    def test_activity_session_endpoints_contract(self):
        start = self.client_auth.post(
            "/api/activity/sessions/",
            {
                "exercise": self.exercise.id,
                "target_duration_seconds": 1800,
                "intensity": "moderate",
                "source": "live",
            },
            format="json",
        )

        self.assertEqual(start.status_code, status.HTTP_201_CREATED)
        self.assertTrue(
            {
                "id",
                "exercise",
                "exercise_name",
                "exercise_icon_key",
                "status",
                "source",
                "intensity",
                "target_duration_seconds",
                "actual_duration_seconds",
                "remaining_duration_seconds",
                "progress_percent",
                "estimated_calories",
                "calories_burned",
                "started_at",
                "total_paused_seconds",
            }.issubset(set(start.data.keys()))
        )

        session_id = start.data["id"]
        active = self.client_auth.get("/api/activity/sessions/active/")
        self.assertEqual(active.status_code, status.HTTP_200_OK)
        self.assertEqual(active.data["id"], session_id)

        pause = self.client_auth.patch(
            f"/api/activity/sessions/{session_id}/pause/",
            {},
            format="json",
        )
        self.assertEqual(pause.status_code, status.HTTP_200_OK)
        self.assertEqual(pause.data["status"], "paused")

        resume = self.client_auth.patch(
            f"/api/activity/sessions/{session_id}/resume/",
            {},
            format="json",
        )
        self.assertEqual(resume.status_code, status.HTTP_200_OK)
        self.assertEqual(resume.data["status"], "running")

        edit = self.client_auth.patch(
            f"/api/activity/sessions/{session_id}/edit/",
            {"target_duration_seconds": 2100, "intensity": "intense"},
            format="json",
        )
        self.assertEqual(edit.status_code, status.HTTP_200_OK)
        self.assertEqual(edit.data["target_duration_seconds"], 2100)
        self.assertEqual(edit.data["intensity"], "intense")

        finish = self.client_auth.post(
            f"/api/activity/sessions/{session_id}/finish/",
            {"save_partial": True},
            format="json",
        )
        self.assertEqual(finish.status_code, status.HTTP_200_OK)
        self.assertEqual(finish.data["status"], "completed")

        no_active = self.client_auth.get("/api/activity/sessions/active/")
        self.assertEqual(no_active.status_code, status.HTTP_200_OK)
        self.assertIsNone(no_active.data)

    def test_micronutrient_overview_uses_meal_snapshots(self):
        NutritionFacts.objects.create(
            food_item=self.food,
            basis_type="per_100g",
            basis_amount=100,
            basis_unit="g",
            calcium_mg=120,
            iron_mg=2,
            vitamin_d_mcg=3,
        )
        self.client_auth.post(
            "/api/meals/",
            {"food": self.food.id, "meal_type": "lunch", "quantity_grams": 200},
            format="json",
        )

        res = self.client_auth.get("/api/nutrition/micronutrients/")

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue({"data", "meta"}.issubset(res.data.keys()))
        items = {item["code"]: item for item in res.data["data"]["items"]}
        self.assertIn("calcium_mg", items)
        self.assertIn("vitamin_d_mcg", items)
        self.assertEqual(items["calcium_mg"]["food_consumed"], 240.0)
        self.assertEqual(items["vitamin_d_mcg"]["food_consumed"], 6.0)
        self.assertEqual(items["calcium_mg"]["supplement_consumed"], 0.0)

    def test_micronutrient_target_can_create_linked_supplement_plan(self):
        target_res = self.client_auth.post(
            "/api/nutrition/micronutrients/targets/",
            {
                "nutrient_code": "vitamin_d_mcg",
                "target_value": 20,
                "note": "Low vitamin D",
                "create_medication_plan": True,
                "supplement_name": "Vitamin D",
                "supplement_amount": 25,
                "supplement_unit": "mcg",
                "schedule_time": "08:30",
            },
            format="json",
        )

        self.assertEqual(target_res.status_code, status.HTTP_201_CREATED)
        items = {item["code"]: item for item in target_res.data["data"]["items"]}
        vitamin_d = items["vitamin_d_mcg"]
        self.assertTrue(vitamin_d["deficiency_tracked"])
        self.assertIsNotNone(vitamin_d["linked_medication"])

        medication_id = vitamin_d["linked_medication"]["id"]
        ConditionMedicationLog.objects.create(
            medication_id=medication_id,
            scheduled_date=timezone.localdate(),
            status=ConditionMedicationLog.STATUS_TAKEN,
            dose_taken_amount=Decimal("25"),
        )

        overview = self.client_auth.get("/api/nutrition/micronutrients/")

        self.assertEqual(overview.status_code, status.HTTP_200_OK)
        items = {item["code"]: item for item in overview.data["data"]["items"]}
        self.assertEqual(items["vitamin_d_mcg"]["food_consumed"], 0.0)
        self.assertEqual(items["vitamin_d_mcg"]["supplement_consumed"], 25.0)

    def test_micronutrient_target_can_create_medication_from_name_without_numeric_dose(self):
        target_res = self.client_auth.post(
            "/api/nutrition/micronutrients/targets/",
            {
                "nutrient_code": "vitamin_d_mcg",
                "lab_value": 18,
                "current_medication_name": "Vitamin D drops",
                "current_medication_dose": "1000 IU daily",
                "create_medication_plan": True,
                "schedule_time": "09:00",
            },
            format="json",
        )

        self.assertEqual(target_res.status_code, status.HTTP_201_CREATED)
        items = {item["code"]: item for item in target_res.data["data"]["items"]}
        vitamin_d = items["vitamin_d_mcg"]
        self.assertTrue(vitamin_d["deficiency_tracked"])
        self.assertIsNotNone(vitamin_d["linked_medication"])
        self.assertEqual(
            vitamin_d["linked_medication"]["display_name"],
            "Vitamin D drops",
        )

        medication = ConditionMedication.objects.get(
            id=vitamin_d["linked_medication"]["id"],
        )
        self.assertEqual(medication.display_name, "Vitamin D drops")
        self.assertEqual(medication.dosage, "1000 IU daily")
        self.assertEqual(medication.supplement_nutrient.code, "vitamin_d_mcg")

        overview = self.client_auth.get("/api/medications/overview/")
        medication_names = [
            item["display_name"] for item in overview.data["data"]["medications"]
        ]
        self.assertIn("Vitamin D drops", medication_names)

    def test_micronutrient_target_accepts_lab_context_and_suggests_daily_target(self):
        target_res = self.client_auth.post(
            "/api/nutrition/micronutrients/targets/",
            {
                "nutrient_code": "vitamin_d_mcg",
                "lab_value": 18,
                "current_medication_name": "Vitamin D drops",
                "current_medication_dose": "1000 IU daily",
            },
            format="json",
        )

        self.assertEqual(target_res.status_code, status.HTTP_201_CREATED)
        items = {item["code"]: item for item in target_res.data["data"]["items"]}
        vitamin_d = items["vitamin_d_mcg"]
        self.assertTrue(vitamin_d["deficiency_tracked"])
        self.assertEqual(vitamin_d["target_value"], 18.75)
        self.assertEqual(vitamin_d["target_source"], "user_custom_target")
        self.assertIsNotNone(vitamin_d["constraint_id"])
        self.assertEqual(vitamin_d["lab_context"]["value"], 18.0)
        self.assertEqual(vitamin_d["lab_context"]["reference_min"], 30.0)
        self.assertEqual(vitamin_d["lab_context"]["reference_max"], 100.0)
        self.assertEqual(
            vitamin_d["lab_context"]["calculation_basis"],
            "lab_below_range",
        )
        self.assertEqual(
            vitamin_d["lab_context"]["improvement_plan"]["status"],
            "build_up",
        )
        self.assertEqual(
            vitamin_d["lab_context"]["current_medication_name"],
            "Vitamin D drops",
        )
        state = UnifiedHealthState.objects.get(
            user=self.user,
            state_date=timezone.localdate(),
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
        )
        self.assertTrue(
            any(
                row.get("metric_key") == "vitamin_d_mcg"
                for row in state.active_constraints.get("micronutrient", [])
            )
        )

    def test_micronutrient_lab_above_range_creates_mineral_limit(self):
        target_res = self.client_auth.post(
            "/api/nutrition/micronutrients/targets/",
            {
                "nutrient_code": "sodium_mg",
                "lab_value": 150,
            },
            format="json",
        )

        self.assertEqual(target_res.status_code, status.HTTP_201_CREATED)
        items = {item["code"]: item for item in target_res.data["data"]["items"]}
        sodium = items["sodium_mg"]
        self.assertTrue(sodium["deficiency_tracked"])
        self.assertEqual(sodium["target_value"], 1200.0)
        self.assertEqual(sodium["max_value"], 1200.0)
        self.assertEqual(
            sodium["lab_context"]["calculation_basis"],
            "lab_above_range",
        )

    def test_micronutrient_sodium_below_range_creates_goal_and_medication(self):
        target_res = self.client_auth.post(
            "/api/nutrition/micronutrients/targets/",
            {
                "nutrient_code": "sodium_mg",
                "lab_value": 100,
                "current_medication_name": "Sodium supplement",
                "create_medication_plan": True,
                "supplement_name": "Sodium supplement",
                "supplement_amount": 2,
                "supplement_unit": "mg",
                "schedule_time": "09:00",
            },
            format="json",
        )

        self.assertEqual(target_res.status_code, status.HTTP_201_CREATED)
        items = {item["code"]: item for item in target_res.data["data"]["items"]}
        sodium = items["sodium_mg"]
        self.assertTrue(sodium["deficiency_tracked"])
        self.assertEqual(sodium["target_value"], 1875.0)
        self.assertEqual(sodium["min_value"], 1875.0)
        self.assertIsNotNone(sodium["linked_medication"])
        self.assertEqual(
            sodium["linked_medication"]["display_name"],
            "Sodium supplement",
        )

        overview = self.client_auth.get("/api/medications/overview/")
        medication_names = [
            item["display_name"] for item in overview.data["data"]["medications"]
        ]
        self.assertIn("Sodium supplement", medication_names)

    def test_chronic_guidance_overview_contract(self):
        res = self.client_auth.get("/api/chronic/overview/?view=guidance")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue({"data", "meta"}.issubset(res.data.keys()))
        self.assertTrue({"conditions", "summary"}.issubset(res.data["data"].keys()))
        self.assertNotIn("today_doses", res.data["data"])

    def test_read_model_endpoints_include_debug_headers(self):
        res = self.client_auth.get("/api/home/overview/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("X-VitaMate-Request-Id", res.headers)
        self.assertIn("X-VitaMate-Latency-Ms", res.headers)
        self.assertIn("X-VitaMate-Db-Queries", res.headers)
        self.assertIn("X-VitaMate-Response-Bytes", res.headers)

    def test_openapi_schema_endpoint_is_available(self):
        res = self.client_auth.get("/api/schema/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("openapi", res.data)

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
