from datetime import timedelta
from unittest.mock import patch
from zoneinfo import ZoneInfo

from django.db.models import Count
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from core.models import (
    ConditionMedication,
    ConditionMedicationLog,
    ConditionType,
    Medicine,
    UserCondition,
)
from core.services.condition_medication_service import ConditionMedicationService
from test_utils.helpers import auth_client_for_user, create_user_with_profile


class UnifiedMedicationApiTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="meduser")
        self.client_auth = auth_client_for_user(self.user)
        self.other_user = create_user_with_profile(username="medother")
        self.other_client = auth_client_for_user(self.other_user)

    def _future_time(self, timezone_name="UTC"):
        return (timezone.now().astimezone(ZoneInfo(timezone_name)) + timedelta(minutes=30)).strftime("%H:%M")

    def _condition(self):
        condition_type = (
            ConditionType.objects.filter(slug="diabetes").first()
            or ConditionType.objects.create(
                code="diabetes",
                slug="diabetes",
                name="Diabetes",
                is_supported=True,
                severity_options=[{"code": "diabetes_managed"}],
            )
        )
        return UserCondition.objects.create(
            user=self.user,
            condition_type=condition_type,
            status=UserCondition.STATUS_ACTIVE,
            severity_code="diabetes_managed",
            is_active=True,
        )

    def _create_manual_medication(self):
        return self.client_auth.post(
            "/api/medications/",
            {
                "display_name": "Vitamin D",
                "source_type": "manual",
                "dose_amount": "1000",
                "dose_unit": "IU",
                "form": "capsule",
                "instructions": "With breakfast",
                "start_date": str(timezone.localdate()),
                "timezone": "Asia/Damascus",
                "schedules": [
                    {
                        "schedule_type": "daily",
                        "time": self._future_time("Asia/Damascus"),
                        "meal_relation": "with_food",
                    }
                ],
            },
            format="json",
        )

    def test_create_manual_medication_generates_pending_dose_and_reminder_sync(self):
        res = self._create_manual_medication()
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        medication = ConditionMedication.objects.get(user=self.user)
        self.assertEqual(medication.source_type, ConditionMedication.SOURCE_MANUAL)
        self.assertIsNone(medication.user_condition)
        self.assertTrue(
            ConditionMedicationLog.objects.filter(
                medication=medication,
                status=ConditionMedicationLog.STATUS_PENDING,
            ).exists()
        )
        self.assertTrue(res.data["reminder_sync"]["items"])

    def test_create_condition_medication_uses_same_plan_model(self):
        condition = self._condition()
        res = self.client_auth.post(
            "/api/medications/",
            {
                "display_name": "Metformin",
                "source_type": "condition",
                "user_condition_id": condition.id,
                "dose_amount": "500",
                "dose_unit": "mg",
                "form": "tablet",
                "start_date": str(timezone.localdate()),
                "schedules": [{"schedule_type": "daily", "time": self._future_time()}],
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        medication = ConditionMedication.objects.get(user=self.user, display_name="Metformin")
        self.assertEqual(medication.source_type, ConditionMedication.SOURCE_CONDITION)
        self.assertEqual(medication.user_condition, condition)
        self.assertIsNotNone(medication.medicine)
        self.assertEqual(medication.medicine.name, "Metformin")

        list_res = self.client_auth.get("/api/medications/")
        self.assertEqual(list_res.status_code, status.HTTP_200_OK)
        self.assertEqual([item["id"] for item in list_res.data], [medication.id])

    def test_chronic_medication_endpoint_syncs_legacy_medicine_mirror(self):
        condition = self._condition()
        create_res = self.client_auth.post(
            "/api/condition-medications/",
            {
                "user_condition": condition.id,
                "name": "Amlodipine",
                "dosage": "5 mg",
                "dosage_amount": "5",
                "dosage_unit": "mg",
                "relation_to_meal": "after_meal",
                "schedules": [
                    {
                        "time_of_day": self._future_time(),
                        "recurrence_days": [],
                    }
                ],
            },
            format="json",
        )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED, create_res.data)
        medication = ConditionMedication.objects.get(user=self.user, name="Amlodipine")
        self.assertEqual(medication.user_condition, condition)
        self.assertEqual(medication.source_type, ConditionMedication.SOURCE_CONDITION)
        self.assertIsNotNone(medication.medicine)
        self.assertEqual(Medicine.objects.filter(user=self.user, name="Amlodipine").count(), 1)

        general_res = self.client_auth.get("/api/medications/")
        self.assertEqual(general_res.status_code, status.HTTP_200_OK)
        self.assertEqual([item["id"] for item in general_res.data], [medication.id])
        self.assertEqual(general_res.data[0]["medicine_id"], medication.medicine_id)

        update_res = self.client_auth.patch(
            f"/api/condition-medications/{medication.id}/",
            {
                "name": "Amlodipine XR",
                "dosage": "10 mg",
            },
            format="json",
        )
        self.assertEqual(update_res.status_code, status.HTTP_200_OK, update_res.data)
        medication.refresh_from_db()
        medication.medicine.refresh_from_db()
        self.assertEqual(medication.name, "Amlodipine XR")
        self.assertEqual(medication.medicine.name, "Amlodipine XR")
        self.assertEqual(medication.medicine.dosage, "10 mg")

        deactivate_res = self.client_auth.post(f"/api/condition-medications/{medication.id}/deactivate/")
        self.assertEqual(deactivate_res.status_code, status.HTTP_200_OK, deactivate_res.data)
        medication.refresh_from_db()
        medication.medicine.refresh_from_db()
        self.assertFalse(medication.is_active)
        self.assertFalse(medication.medicine.is_active)
        self.assertEqual(self.client_auth.get("/api/medications/").data, [])

    def test_interval_schedule_can_generate_multiple_doses_on_same_day(self):
        res = self.client_auth.post(
            "/api/medications/",
            {
                "display_name": "Antibiotic",
                "source_type": "manual",
                "dose_amount": "1",
                "dose_unit": "tablet",
                "start_date": str(timezone.localdate()),
                "schedules": [
                    {
                        "schedule_type": "interval",
                        "time": "00:00",
                        "interval_hours": 8,
                    }
                ],
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        medication = ConditionMedication.objects.get(user=self.user, display_name="Antibiotic")
        multi_dose_day = (
            ConditionMedicationLog.objects.filter(medication=medication)
            .values("scheduled_date")
            .annotate(total=Count("id"))
            .filter(total__gt=1)
            .exists()
        )
        self.assertTrue(multi_dose_day)

    def test_today_plan_and_dose_actions_update_concrete_log(self):
        create_res = self._create_manual_medication()
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED, create_res.data)

        today_res = self.client_auth.get("/api/medications/today/")
        self.assertEqual(today_res.status_code, status.HTTP_200_OK)
        self.assertTrue(today_res.data)
        log_id = today_res.data[0]["log_id"]

        take_res = self.client_auth.post(
            f"/api/medications/doses/{log_id}/taken/",
            {"taken_at": timezone.now().isoformat(), "dose_taken_amount": "1000"},
            format="json",
        )
        self.assertEqual(take_res.status_code, status.HTTP_200_OK, take_res.data)
        self.assertEqual(take_res.data["status"], "taken")

        second_take = self.client_auth.post(
            f"/api/medications/doses/{log_id}/taken/",
            {"taken_at": timezone.now().isoformat()},
            format="json",
        )
        self.assertEqual(second_take.status_code, status.HTTP_400_BAD_REQUEST)

    def test_snooze_skip_and_adherence_summary(self):
        create_res = self._create_manual_medication()
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED, create_res.data)
        log_id = self.client_auth.get("/api/medications/today/").data[0]["log_id"]

        snooze_until = timezone.now() + timedelta(minutes=15)
        snooze_res = self.client_auth.post(
            f"/api/medications/doses/{log_id}/snooze/",
            {"snoozed_until": snooze_until.isoformat()},
            format="json",
        )
        self.assertEqual(snooze_res.status_code, status.HTTP_200_OK, snooze_res.data)
        self.assertEqual(snooze_res.data["status"], "snoozed")

        skip_res = self.client_auth.post(
            f"/api/medications/doses/{log_id}/skipped/",
            {"reason": "doctor paused for one day"},
            format="json",
        )
        self.assertEqual(skip_res.status_code, status.HTTP_200_OK, skip_res.data)
        self.assertEqual(skip_res.data["status"], "skipped")

        summary_res = self.client_auth.get("/api/medications/adherence-summary/")
        self.assertEqual(summary_res.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(summary_res.data["expected_doses"], 1)
        self.assertEqual(summary_res.data["skipped_doses"], 1)

    def test_dashboard_and_history_include_medication_state(self):
        create_res = self._create_manual_medication()
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED, create_res.data)

        dashboard = self.client_auth.get("/api/dashboard/")
        self.assertEqual(dashboard.status_code, status.HTTP_200_OK)
        self.assertIn("medications", dashboard.data)
        self.assertEqual(dashboard.data["medications"]["active_medications"], 1)

        history = self.client_auth.get("/api/history/")
        self.assertEqual(history.status_code, status.HTTP_200_OK)
        self.assertIn("medication_total_doses", history.data["history"][-1])

    def test_deactivate_removes_pending_doses_from_today_plan(self):
        create_res = self._create_manual_medication()
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED, create_res.data)
        medication_id = create_res.data["medication"]["id"]
        self.assertTrue(self.client_auth.get("/api/medications/today/").data)

        deactivate_res = self.client_auth.post(f"/api/medications/{medication_id}/deactivate/")
        self.assertEqual(deactivate_res.status_code, status.HTTP_200_OK, deactivate_res.data)
        today_res = self.client_auth.get("/api/medications/today/")
        self.assertEqual(today_res.status_code, status.HTTP_200_OK)
        self.assertEqual(today_res.data, [])

    def test_other_user_cannot_access_dose_action(self):
        create_res = self._create_manual_medication()
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED, create_res.data)
        log_id = self.client_auth.get("/api/medications/today/").data[0]["log_id"]

        res = self.other_client.post(
            f"/api/medications/doses/{log_id}/missed/",
            {},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_overdue_condition_schedule_log_generation_avoids_non_atomic_insert(self):
        condition = self._condition()
        medication = ConditionMedication.objects.create(
            user=self.user,
            user_condition=condition,
            source_type=ConditionMedication.SOURCE_CONDITION,
            name="Metformin",
            display_name="Metformin",
            dosage="500 mg",
        )
        schedule = medication.schedules.create(
            time_of_day=(timezone.localtime() - timedelta(hours=3)).time().replace(second=0, microsecond=0)
        )

        with patch(
            "core.services.chronic.condition_medication_service.MedicationRepository.save_dose_log",
            side_effect=AssertionError("legacy insert path should not be used"),
        ):
            ConditionMedicationService.ensure_today_medication_logs(
                user_condition=condition,
                now=timezone.localtime(),
            )

        logs = ConditionMedicationLog.objects.filter(
            schedule=schedule,
            scheduled_date=timezone.localdate(),
        )
        self.assertEqual(logs.count(), 1)
        self.assertEqual(logs.get().status, ConditionMedicationLog.STATUS_MISSED)
