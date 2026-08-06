from datetime import timedelta

from django.test import TestCase
from django.utils import timezone
from rest_framework import status

from core.models import (
    ConditionAlert,
    ConditionDailyEvaluation,
    ConditionPointsAudit,
    ConditionType,
    HealthIndicatorRecord,
    HealthTarget,
    ResolvedTrackerConstraint,
    UnifiedHealthState,
    UserCondition,
)
from core.services.chronic.condition_integration_coordinator import (
    ConditionIntegrationCoordinator,
)
from core.services.constraints import EffectiveConstraintReader
from gamification.repositories.user_score_repository import UserScoreRepository
from test_utils.helpers import auth_client_for_user, create_food_item, create_user_with_profile


class ChronicConditionApiTests(TestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="chronicuser", weight=78, height=172)
        self.client = auth_client_for_user(self.user)
        self.other_user = create_user_with_profile(username="otherchronic", weight=75, height=169)
        self.other_client = auth_client_for_user(self.other_user)

    def _condition_type(self, slug: str) -> ConditionType:
        aliases = {
            "dyslipidemia": ("dyslipidemia", "hyperlipidemia"),
        }
        candidates = aliases.get(slug, (slug,))
        item = (
            ConditionType.objects.filter(slug__in=candidates)
            .order_by("sort_order", "id")
            .first()
            or ConditionType.objects.filter(code__in=candidates).order_by("sort_order", "id").first()
        )
        self.assertIsNotNone(item, f"Missing supported condition type for {slug}")
        return item

    def _severity_code(self, slug: str, *preferred: str) -> str:
        condition_type = self._condition_type(slug)
        options = [option.get("code") for option in condition_type.severity_options or [] if option.get("code")]
        self.assertTrue(options, f"Missing severity options for {slug}")
        for code in preferred:
            if code in options:
                return code
        return options[0]

    def _create_condition(self, slug: str, **extra):
        condition_type = self._condition_type(slug)
        payload = {
            "condition_type": condition_type.id,
            "condition_status": extra.pop("condition_status", "active"),
            "severity": extra.pop("severity", self._severity_code(slug)),
            **extra,
        }
        return self.client.post("/api/chronic/user-conditions/", payload, format="json")

    def test_supported_catalog_returns_three_supported_conditions(self):
        res = self.client.get("/api/chronic/condition-types/supported/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        slugs = [item["slug"] for item in res.data]
        self.assertEqual(slugs, ["diabetes", "hypertension", "dyslipidemia"])
        diabetes = next(item for item in res.data if item["slug"] == "diabetes")
        dyslipidemia = next(item for item in res.data if item["slug"] == "dyslipidemia")
        self.assertEqual(diabetes["code"], "diabetes")
        self.assertEqual(diabetes["name"], "Diabetes / Prediabetes")
        self.assertTrue(diabetes["severity_options"])
        self.assertTrue(diabetes["can_add"])
        self.assertIn("glucose", diabetes["measurement_types"])
        self.assertFalse(dyslipidemia["supports_direct_daily_reading"])

    def test_create_condition_generates_profile_targets_and_evaluation(self):
        res = self._create_condition(
            "diabetes",
            diagnosis_date="2026-04-10",
            notes="Track fasting values in the app.",
            profile_data={"glucose_target": 110, "hba1c_target": 6.5},
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

        body = res.data
        self.assertEqual(body["condition_type"]["slug"], "diabetes")
        self.assertEqual(body["condition_status"], "active")
        self.assertEqual(body["profile_data"]["glucose_target"], 110)
        self.assertTrue(body["summary"])
        self.assertTrue(
            HealthTarget.objects.filter(
                user_condition_id=body["id"],
                source_type=HealthTarget.SOURCE_DYNAMIC_CONDITION,
            ).exists()
        )
        self.assertTrue(
            HealthTarget.objects.filter(
                user_condition_id=body["id"],
                source_type=HealthTarget.SOURCE_DYNAMIC_CONDITION,
                target_key="added_sugars_g",
            ).exists()
        )
        self.assertTrue(
            ConditionDailyEvaluation.objects.filter(user_condition_id=body["id"]).exists()
        )

    def test_compact_condition_list_returns_lightweight_payload(self):
        create_res = self._create_condition(
            "diabetes",
            diagnosis_date="2026-04-10",
            profile_data={"glucose_target": 110},
        )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)

        reading_res = self.client.post(
            f"/api/chronic/user-conditions/{create_res.data['id']}/readings/",
            {
                "indicator_type": "glucose",
                "value": 184,
                "reading_type": "after_meal",
                "recorded_at": timezone.now().isoformat(),
            },
            format="json",
        )
        self.assertEqual(reading_res.status_code, status.HTTP_201_CREATED)

        res = self.client.get("/api/chronic/user-conditions/?view=compact")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data), 1)
        item = res.data[0]
        self.assertEqual(item["view"], "compact")
        self.assertEqual(item["condition_type"]["slug"], "diabetes")
        self.assertEqual(item["summary_subtitle"], "Last glucose reading recorded")
        self.assertEqual(item["summary_status_label"], "High")
        self.assertEqual(item["summary_line"], "184 mg/dL")
        self.assertIn("secondary_summary_line", item)
        self.assertIn("evaluation_status", item)
        self.assertIn("latest_reading", item)
        self.assertIn("open_alerts_count", item)
        self.assertIn("summary", item)
        self.assertIn("evaluation", item)
        self.assertIn("targets", item)
        self.assertTrue(item["targets"])
        self.assertTrue(item["summary"]["targets"])
        self.assertTrue(item["evaluation"]["tracker_impacts"])
        self.assertNotIn("medications", item)
        self.assertNotIn("indicator_records", item)
        self.assertNotIn("alerts", item)

    def test_duplicate_active_condition_is_rejected(self):
        payload = {
            "diagnosis_date": "2025-02-01",
            "condition_status": "active",
            "severity": self._severity_code("diabetes"),
        }
        first = self._create_condition("diabetes", **payload)
        second = self._create_condition("diabetes", **payload)

        self.assertEqual(first.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("condition_type", second.data)

    def test_diabetes_reading_workflow_updates_evaluation_alerts_and_points(self):
        create_res = self._create_condition(
            "diabetes",
            profile_data={"glucose_target": 110, "hba1c_target": 6.5},
        )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
        condition_id = create_res.data["id"]

        score_before, _ = UserScoreRepository.get_or_create_for_user(self.user)
        points_before = score_before.total_points

        reading_res = self.client.post(
            f"/api/chronic/user-conditions/{condition_id}/readings/",
            {
                "indicator_type": "glucose",
                "value": 195,
                "reading_type": "after_meal",
                "recorded_at": timezone.now().isoformat(),
            },
            format="json",
        )
        self.assertEqual(reading_res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(reading_res.data["reading"]["classification"], "high")
        self.assertEqual(reading_res.data["reading"]["risk_level"], "medium")
        self.assertEqual(reading_res.data["evaluation"]["status"], "attention_needed")
        self.assertIn("hyperglycemia_risk", reading_res.data["evaluation"]["risk_flags"])
        self.assertTrue(reading_res.data["alerts"])
        self.assertTrue(reading_res.data["recommendations"])
        self.assertGreater(reading_res.data["points_delta"], 0)

        condition = UserCondition.objects.get(pk=condition_id)
        record = condition.indicator_records.get()
        self.assertEqual(record.classification, "high")
        self.assertEqual(record.risk_level, "medium")
        self.assertTrue(
            ConditionAlert.objects.filter(user_condition=condition, code="hyperglycemia_risk").exists()
        )
        evaluation = ConditionDailyEvaluation.objects.filter(user_condition=condition).latest("evaluation_date")
        self.assertIn("hyperglycemia_risk", evaluation.risk_flags)
        self.assertTrue(
            HealthTarget.objects.filter(
                user_condition=condition,
                source_type=HealthTarget.SOURCE_DYNAMIC_CONDITION,
                target_key="added_sugars_g",
            ).exists()
        )

        score_after, _ = UserScoreRepository.get_or_create_for_user(self.user)
        self.assertGreater(score_after.total_points, points_before)
        self.assertTrue(
            ConditionPointsAudit.objects.filter(
                user_condition=condition,
                event_type=ConditionPointsAudit.EVENT_SYSTEM,
            ).exists()
        )

    def test_hypertension_reading_tightens_sodium_target(self):
        create_res = self._create_condition(
            "hypertension",
            severity=self._severity_code("hypertension", "stage_1", "stage_2"),
            profile_data={"sodium_limit": 1800, "systolic_target": 130, "diastolic_target": 80},
        )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
        condition_id = create_res.data["id"]

        reading_res = self.client.post(
            f"/api/chronic/user-conditions/{condition_id}/readings/",
            {
                "indicator_type": "blood_pressure",
                "systolic": 145,
                "diastolic": 92,
                "pulse": 84,
                "recorded_at": timezone.now().isoformat(),
            },
            format="json",
        )
        self.assertEqual(reading_res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(reading_res.data["reading"]["classification"], "high")
        self.assertIn("high_blood_pressure_risk", reading_res.data["evaluation"]["risk_flags"])
        sodium_target = next(
            target for target in reading_res.data["adjusted_targets"] if target["key"] == "sodium_mg"
        )
        self.assertEqual(sodium_target["tracker"], "nutrition")
        self.assertEqual(sodium_target["value"], 1500)

    def test_dyslipidemia_followup_updates_summary(self):
        create_res = self._create_condition(
            "dyslipidemia",
            severity=self._severity_code("dyslipidemia"),
            profile_data={"hdl_target": 45, "triglyceride_target": 150, "followup_interval_days": 90},
        )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
        condition_id = create_res.data["id"]

        reading_res = self.client.post(
            f"/api/chronic/user-conditions/{condition_id}/readings/",
            {
                "indicator_type": "lipid_panel",
                "hdl": 42,
                "triglycerides": 185,
                "ldl": 130,
                "total_cholesterol": 210,
                "recorded_at": timezone.now().isoformat(),
            },
            format="json",
        )
        self.assertEqual(reading_res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(reading_res.data["recommendations"])

        summary_res = self.client.get(f"/api/chronic/user-conditions/{condition_id}/summary/")
        self.assertEqual(summary_res.status_code, status.HTTP_200_OK)
        self.assertEqual(summary_res.data["condition_id"], condition_id)
        self.assertEqual(summary_res.data["latest_reading"]["indicator_type"], "lipid_panel")
        self.assertTrue(summary_res.data["tracker_impacts"])

    def test_reading_validation_rejects_wrong_indicator_for_condition(self):
        create_res = self._create_condition("hypertension")
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
        condition_id = create_res.data["id"]

        reading_res = self.client.post(
            f"/api/chronic/user-conditions/{condition_id}/readings/",
            {
                "indicator_type": "glucose",
                "value": 120,
                "reading_type": "fasting",
            },
            format="json",
        )
        self.assertEqual(reading_res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("not valid for hypertension", str(reading_res.data["detail"]))

    def test_nested_endpoints_are_ownership_safe(self):
        create_res = self._create_condition("diabetes")
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
        condition_id = create_res.data["id"]

        detail_res = self.other_client.get(f"/api/chronic/user-conditions/{condition_id}/")
        summary_res = self.other_client.get(f"/api/chronic/user-conditions/{condition_id}/summary/")
        readings_res = self.other_client.post(
            f"/api/chronic/user-conditions/{condition_id}/readings/",
            {
                "indicator_type": "glucose",
                "value": 110,
                "reading_type": "fasting",
            },
            format="json",
        )

        self.assertEqual(detail_res.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(summary_res.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(readings_res.status_code, status.HTTP_404_NOT_FOUND)

    def test_legacy_indicator_endpoint_still_logs_records(self):
        create_res = self._create_condition("diabetes")
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
        condition_id = create_res.data["id"]

        indicator_res = self.client.post(
            "/api/health-indicators/",
            {
                "user_condition": condition_id,
                "indicator_name": "fasting_glucose",
                "value": 118,
                "unit": "mg/dL",
            },
            format="json",
        )
        self.assertEqual(indicator_res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(indicator_res.data["indicator_type"], "glucose")
        self.assertEqual(HealthIndicatorRecord.objects.filter(user_condition_id=condition_id).count(), 1)

    def test_dashboard_and_history_keep_reflecting_condition_effects(self):
        diabetes = self._create_condition(
            "diabetes",
            severity=self._severity_code("diabetes", "diabetes_intensive", "diabetes_managed"),
        )
        hypertension = self._create_condition(
            "hypertension",
            severity=self._severity_code("hypertension", "stage_2", "stage_1"),
        )
        self.assertEqual(diabetes.status_code, status.HTTP_201_CREATED)
        self.assertEqual(hypertension.status_code, status.HTTP_201_CREATED)

        salty_food = create_food_item(
            name="Salty Soup",
            calories_100g=50,
            sodium_mg_100g=2000,
            fiber_100g=0,
        )
        self.client.post(
            "/api/meals/",
            {
                "food": salty_food.id,
                "meal_type": "lunch",
                "quantity_grams": 200,
            },
            format="json",
        )

        dashboard = self.client.get("/api/dashboard/")
        history = self.client.get("/api/history/")
        self.assertEqual(dashboard.status_code, status.HTTP_200_OK)
        self.assertEqual(history.status_code, status.HTTP_200_OK)
        self.assertEqual(dashboard.data["chronic_conditions"]["count"], 2)
        self.assertIn("applied_summaries", dashboard.data["chronic_conditions"])
        self.assertIn("history", history.data)
        self.assertIn("condition_adherence_percent", history.data["history"][0])
        self.assertIn("pending_condition_doses", history.data["history"][0])

    def test_medication_actions_still_work_with_new_condition_flow(self):
        schedule_time = (timezone.localtime() - timedelta(minutes=20)).strftime("%H:%M:%S")
        create_res = self.client.post(
            "/api/chronic/user-conditions/",
            {
                "condition_type": self._condition_type("hypertension").id,
                "condition_status": "active",
                "severity": self._severity_code("hypertension", "stage_1", "stage_2"),
                "medications": [
                    {
                        "name": "Losartan",
                        "dosage": "50 mg",
                        "dosage_amount": "1",
                        "dosage_unit": "tablet",
                        "schedules": [{"time_of_day": schedule_time, "recurrence_days": []}],
                    }
                ],
            },
            format="json",
        )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
        schedule_id = create_res.data["medications"][0]["schedules"][0]["id"]

        score_before, _ = UserScoreRepository.get_or_create_for_user(self.user)
        take_res = self.client.post(f"/api/condition-medication-schedules/{schedule_id}/take/")
        self.assertEqual(take_res.status_code, status.HTTP_200_OK)
        self.assertIn(take_res.data["status"], {"taken_on_time", "taken_late"})
        self.assertGreaterEqual(take_res.data["points_applied"], 1)

        score_after, _ = UserScoreRepository.get_or_create_for_user(self.user)
        self.assertGreater(score_after.total_points, score_before.total_points)
        self.assertTrue(ConditionPointsAudit.objects.filter(event_type="medication").exists())

    def test_deactivate_condition_supersedes_constraints_and_preserves_history(self):
        with self.captureOnCommitCallbacks(execute=True):
            create_res = self._create_condition(
                "hypertension",
                severity=self._severity_code("hypertension", "stage_2", "stage_1"),
            )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
        condition = UserCondition.objects.get(pk=create_res.data["id"])
        self.assertTrue(
            ResolvedTrackerConstraint.objects.filter(
                user=self.user,
                source_condition=condition,
                status=ResolvedTrackerConstraint.STATUS_ACTIVE,
            ).exists()
        )
        state_before = UnifiedHealthState.objects.get(
            user=self.user,
            state_date=timezone.localdate(),
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
        )

        with self.captureOnCommitCallbacks(execute=True):
            deactivate_res = self.client.post(
                f"/api/chronic/user-conditions/{condition.id}/deactivate/",
                {},
                format="json",
            )

        self.assertEqual(deactivate_res.status_code, status.HTTP_200_OK)
        condition.refresh_from_db()
        self.assertFalse(condition.is_active)
        self.assertTrue(UserCondition.objects.filter(pk=condition.id).exists())
        self.assertFalse(
            ResolvedTrackerConstraint.objects.filter(
                user=self.user,
                source_condition=condition,
                status=ResolvedTrackerConstraint.STATUS_ACTIVE,
            ).exists()
        )
        self.assertTrue(
            ResolvedTrackerConstraint.objects.filter(
                user=self.user,
                source_condition=condition,
                status=ResolvedTrackerConstraint.STATUS_SUPERSEDED,
            ).exists()
        )
        state_after = UnifiedHealthState.objects.get(
            user=self.user,
            state_date=timezone.localdate(),
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
        )
        self.assertGreater(state_after.version, state_before.version)

    def test_condition_integration_facade_reads_materialized_targets(self):
        with self.captureOnCommitCallbacks(execute=True):
            create_res = self._create_condition(
                "hypertension",
                severity=self._severity_code("hypertension", "stage_2", "stage_1"),
            )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)

        facade = ConditionIntegrationCoordinator().effective_constraints(
            user=self.user,
            profile=self.user.userprofile,
            on_date=timezone.localdate(),
        )
        sodium = EffectiveConstraintReader.get_effective_constraint(
            user=self.user,
            tracker_type="nutrition",
            constraint_key="sodium_mg",
            default_value=None,
            default_unit="mg",
        )

        self.assertEqual(facade.sodium_limit_mg, sodium.value)
