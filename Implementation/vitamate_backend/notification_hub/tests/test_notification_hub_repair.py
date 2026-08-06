from datetime import datetime, timedelta
from unittest.mock import patch
from zoneinfo import ZoneInfo

from django.contrib.auth.models import User
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APIClient

from core.models import UnifiedHealthState
from gamification.models import MotivationExperienceEvent
from notification_hub.models import NotificationDevice, NotificationPlan, NotificationPlanEvent
from notification_hub.services.compilers import CelebrationIntentCompiler, CompiledPlan
from notification_hub.services.device_registry_service import DeviceRegistryService
from notification_hub.services.planner import NotificationHubPlanner


class NotificationHubRepairTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="hub-repair", password="Pass123!")
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def _register(self, installation_id: str, *, authorized: bool = True):
        return self.client.post(
            reverse("notification-hub-device-register"),
            {
                "installation_id": installation_id,
                "platform": "android",
                "timezone": "UTC",
                "notifications_authorized": authorized,
                "notifications_enabled_systemwide": authorized,
                "permission_status": "authorized" if authorized else "denied",
                "exact_alarm_authorized": authorized,
                "checked_at": timezone.now().isoformat(),
            },
            format="json",
        )

    @staticmethod
    def _motivation_row(*, suffix: str, priority: int = 70, title: str = "Nudge"):
        now = timezone.now()
        return CompiledPlan(
            kind=NotificationPlan.KIND_INTENT,
            category=NotificationPlan.CATEGORY_MOTIVATION,
            type=f"nudge_{suffix}",
            priority=priority,
            title=title,
            body="One action remains.",
            route="/water",
            dedupe_key=f"motivation:test:{suffix}",
            source_domain="motivation",
            source_ref="hydration_goal",
            deliver_at=now + timedelta(minutes=5),
            expire_at=now + timedelta(hours=1),
            foreground_behavior="in_app_only",
        )

    def test_non_primary_sync_returns_no_plans_and_switch_revokes_old_delivery(self):
        self.assertEqual(self._register("first").status_code, 200)
        second = self._register("second")
        self.assertEqual(second.status_code, 200)
        self.assertFalse(second.data["is_primary"])

        response = self.client.post(
            reverse("notification-hub-sync"),
            {
                "installation_id": "second",
                "last_known_plan_ids": ["stale-local"],
                "foreground_state": "background",
                "timezone": "UTC",
            },
            format="json",
        )
        payload = response.data["data"]
        self.assertFalse(payload["delivery_enabled"])
        self.assertEqual(payload["reason"], "not_primary_device")
        self.assertEqual(payload["plans"], [])
        self.assertTrue(payload["cancel_all_local_plans"])
        self.assertEqual(payload["cancel_plan_ids"], ["stale-local"])

        switched = self.client.post(
            reverse("notification-hub-primary-device"),
            {"installation_id": "second"},
            format="json",
        )
        self.assertEqual(switched.status_code, 200)
        self.assertTrue(switched.data["is_primary"])
        self.assertFalse(NotificationDevice.objects.get(user=self.user, installation_id="first").is_primary)
        self.assertTrue(NotificationDevice.objects.get(user=self.user, installation_id="second").is_primary)

    def test_permission_denied_keeps_foreground_health_event_but_disables_local_delivery(self):
        self._register("denied", authorized=False)
        UnifiedHealthState.objects.create(
            user=self.user,
            state_date=timezone.localdate(),
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
            warnings=[
                {
                    "code": "critical-test",
                    "level": "critical",
                    "title": "Review health reading",
                    "message": "A health reading needs attention.",
                }
            ],
        )
        response = self.client.post(
            reverse("notification-hub-sync"),
            {
                "installation_id": "denied",
                "foreground_state": "foreground",
                "timezone": "UTC",
                "permission_snapshot": {
                    "notifications_authorized": False,
                    "notifications_enabled_systemwide": False,
                    "permission_status": "denied",
                    "checked_at": timezone.now().isoformat(),
                },
            },
            format="json",
        )
        payload = response.data["data"]
        self.assertFalse(payload["delivery_enabled"])
        self.assertEqual(payload["reason"], "notifications_unavailable")
        self.assertEqual(payload["plans"], [])
        self.assertIn(
            "health_warning",
            {event["type"] for event in payload["in_app_events"]},
        )

    def test_presented_health_warning_is_not_reissued_on_each_sync(self):
        self._register("health-once")
        state = UnifiedHealthState.objects.create(
            user=self.user,
            state_date=timezone.localdate(),
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
            warnings=[
                {
                    "code": "high_blood_pressure_risk",
                    "level": "high",
                    "message": "Risk flag detected: high blood pressure risk",
                    "condition_label": "Hypertension",
                }
            ],
        )
        sync_url = reverse("notification-hub-sync")
        sync_body = {
            "installation_id": "health-once",
            "foreground_state": "foreground",
            "timezone": "UTC",
        }

        first = self.client.post(sync_url, sync_body, format="json")
        self.assertEqual(first.status_code, 200)
        event = first.data["data"]["in_app_events"][0]
        self.assertEqual(event["route"], "/chronic-conditions")
        self.assertTrue(event["payload"]["allow_acknowledge"])

        report = self.client.post(
            reverse("notification-hub-report"),
            {
                "installation_id": "health-once",
                "events": [
                    {
                        "event_id": "health-presented-once",
                        "plan_id": event["plan_id"],
                        "revision": event["revision"],
                        "outcome": NotificationPlanEvent.EVENT_PRESENTED_IN_APP,
                    }
                ],
            },
            format="json",
        )
        self.assertEqual(report.status_code, 200)

        second = self.client.post(sync_url, sync_body, format="json")
        self.assertEqual(second.status_code, 200)
        self.assertEqual(second.data["data"]["in_app_events"], [])
        plan = NotificationPlan.objects.get(plan_id=event["plan_id"])
        self.assertEqual(plan.revision, event["revision"])
        self.assertEqual(plan.status, NotificationPlan.STATUS_PRESENTED_IN_APP)

        state.warnings = [
            {
                "code": "high_blood_pressure_risk",
                "level": "critical",
                "message": "Blood pressure risk increased and needs prompt review.",
                "condition_label": "Hypertension",
            }
        ]
        state.save(update_fields=["warnings", "updated_at"])
        changed = self.client.post(sync_url, sync_body, format="json")
        self.assertEqual(changed.status_code, 200)
        changed_event = changed.data["data"]["in_app_events"][0]
        self.assertEqual(changed_event["plan_id"], event["plan_id"])
        self.assertEqual(changed_event["revision"], event["revision"] + 1)

    def test_stale_reading_warning_is_not_presented_as_a_current_health_alert(self):
        self._register("stale-health")
        UnifiedHealthState.objects.create(
            user=self.user,
            state_date=timezone.localdate(),
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
            warnings=[
                {
                    "source": "condition_alert",
                    "code": "high_blood_pressure_risk",
                    "level": "high",
                    "message": "Risk flag detected: high blood pressure risk",
                    "created_at": (timezone.now() - timedelta(days=2)).isoformat(),
                }
            ],
        )
        response = self.client.post(
            reverse("notification-hub-sync"),
            {
                "installation_id": "stale-health",
                "foreground_state": "foreground",
                "timezone": "UTC",
            },
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["data"]["in_app_events"], [])

    @patch.object(NotificationHubPlanner, "_compiled_plans")
    def test_same_sync_motivation_candidates_are_capped_and_ranked(self, compiled_mock):
        self._register("quota")
        compiled_mock.return_value = [
            self._motivation_row(suffix="low", priority=60),
            self._motivation_row(suffix="highest", priority=90),
            self._motivation_row(suffix="middle", priority=80),
            self._motivation_row(suffix="last", priority=50),
        ]
        response = self.client.post(
            reverse("notification-hub-sync"),
            {
                "installation_id": "quota",
                "foreground_state": "background",
                "timezone": "UTC",
            },
            format="json",
        )
        plans = response.data["data"]["plans"]
        self.assertEqual(len(plans), 2)
        self.assertEqual(
            {plan["type"] for plan in plans},
            {"nudge_highest", "nudge_middle"},
        )

    def test_routine_proximity_uses_context_and_exact_ninety_minute_window(self):
        device = DeviceRegistryService.register_device(
            user=self.user,
            installation_id="proximity",
            platform="android",
            timezone_name="UTC",
            locale="",
            app_version="",
            notifications_authorized=True,
            exact_alarm_authorized=True,
            permission_status="authorized",
            notifications_enabled_systemwide=True,
        )
        base = datetime(2026, 8, 5, 12, 0, tzinfo=ZoneInfo("UTC"))
        routine = CompiledPlan(
            kind=NotificationPlan.KIND_RULE,
            category=NotificationPlan.CATEGORY_ROUTINE,
            type="water_interval",
            priority=60,
            title="Water",
            body="Drink water",
            route="/water",
            dedupe_key="routine-water",
            source_domain="hydration",
            source_ref="profile",
            deliver_at=base,
        )
        for minutes, expected in ((30, True), (90, True), (91, False)):
            candidate = self._motivation_row(suffix=str(minutes))
            candidate = CompiledPlan(
                **{
                    **candidate.__dict__,
                    "deliver_at": base + timedelta(minutes=minutes),
                }
            )
            self.assertEqual(
                NotificationHubPlanner._suppressed_by_routine_window(
                    candidate=candidate,
                    routine_plans=[routine],
                    device=device,
                ),
                expected,
            )

        different = CompiledPlan(
            **{
                **self._motivation_row(suffix="different").__dict__,
                "source_ref": "sleep_goal",
                "route": "/water",
                "deliver_at": base + timedelta(minutes=30),
            }
        )
        self.assertFalse(
            NotificationHubPlanner._suppressed_by_routine_window(
                candidate=different,
                routine_plans=[routine],
                device=device,
            )
        )

    @patch.object(NotificationHubPlanner, "_compiled_plans")
    def test_plan_revision_changes_only_when_semantic_payload_changes(self, compiled_mock):
        self._register("revision")
        compiled_mock.return_value = [self._motivation_row(suffix="revision", title="First")]
        url = reverse("notification-hub-sync")
        body = {"installation_id": "revision", "foreground_state": "background", "timezone": "UTC"}
        first = self.client.post(url, body, format="json").data["data"]["plans"][0]
        second = self.client.post(url, body, format="json").data["data"]["plans"][0]
        self.assertEqual(first["revision"], 1)
        self.assertEqual(second["revision"], 1)

        compiled_mock.return_value = [self._motivation_row(suffix="revision", title="Changed")]
        third = self.client.post(url, body, format="json").data["data"]["plans"][0]
        self.assertEqual(third["revision"], 2)

    def test_report_is_idempotent_and_rejects_invalid_transition(self):
        self._register("reports")
        device = NotificationDevice.objects.get(user=self.user, installation_id="reports")
        plan = NotificationPlan.objects.create(
            user=self.user,
            device=device,
            type="routine_test",
            title="Routine",
            dedupe_key="routine-report",
        )
        url = reverse("notification-hub-report")
        event = {
            "event_id": "schedule-once",
            "plan_id": plan.plan_id,
            "revision": 1,
            "outcome": "scheduled_local",
        }
        first = self.client.post(url, {"installation_id": "reports", "events": [event]}, format="json")
        second = self.client.post(url, {"installation_id": "reports", "events": [event]}, format="json")
        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(NotificationPlanEvent.objects.filter(event_id="schedule-once").count(), 1)
        self.assertTrue(second.data["data"]["recorded_events"][0]["duplicate"])

        invalid_plan = NotificationPlan.objects.create(
            user=self.user,
            device=device,
            type="invalid",
            title="Invalid",
            dedupe_key="invalid-report",
        )
        invalid = self.client.post(
            url,
            {
                "installation_id": "reports",
                "events": [
                    {
                        "event_id": "invalid-ack",
                        "plan_id": invalid_plan.plan_id,
                        "revision": 1,
                        "outcome": "acknowledged",
                    }
                ],
            },
            format="json",
        )
        self.assertEqual(invalid.status_code, 400)

    def test_expired_celebration_is_not_compiled(self):
        MotivationExperienceEvent.objects.create(
            user=self.user,
            event_type=MotivationExperienceEvent.TYPE_LEVEL_UP,
            title="Old level",
            dedupe_key="expired-celebration",
            created_at=timezone.now() - timedelta(hours=13),
        )
        self.assertEqual(CelebrationIntentCompiler.compile(user=self.user, preferences=None), [])
