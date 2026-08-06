from datetime import time, timedelta
from zoneinfo import ZoneInfo

from django.contrib.auth.models import User
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APITestCase

from core.models import (
    ConditionMedicationLog,
    UnifiedHealthState,
    UnhealthyHabit,
    UnhealthyHabitReminder,
)
from core.services.constraints import ConstraintResolutionService
from gamification.models import MotivationExperienceEvent
from notification_hub.models import NotificationDevice, NotificationPlan, NotificationPlanEvent
from notification_hub.services.compilers import HydrationRuleCompiler
from users.services.user_profile_service import UserProfileService


class NotificationHubApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="hub-user",
            password="Pass123!",
        )
        self.client.force_authenticate(self.user)
        self.register_url = reverse("notification-hub-device-register")
        self.preferences_url = reverse("notification-hub-preferences")
        self.sync_url = reverse("notification-hub-sync")
        self.report_url = reverse("notification-hub-report")

    def test_register_device_creates_primary_android_device(self):
        response = self.client.post(
            self.register_url,
            {
                "installation_id": "android-main",
                "platform": "android",
                "timezone": "Asia/Damascus",
                "locale": "ar-SY",
                "app_version": "1.4.0",
                "notifications_authorized": True,
                "exact_alarm_authorized": True,
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        device = NotificationDevice.objects.get(
            user=self.user,
            installation_id="android-main",
        )
        self.assertTrue(device.is_primary)
        self.assertTrue(device.notifications_authorized)
        self.assertTrue(device.exact_alarm_authorized)
        self.assertEqual(device.timezone, "Asia/Damascus")
        self.assertEqual(response.data["device_id"], device.id)
        self.assertTrue(response.data["is_primary"])
        self.assertEqual(response.data["channels_version"], 3)
        self.assertEqual(
            response.data["capabilities"],
            {
                "local_delivery": True,
                "exact_alarm_supported": True,
                "in_app_events": True,
            },
        )

    def test_preferences_patch_updates_hub_and_user_profile_state(self):
        response = self.client.patch(
            self.preferences_url,
            {
                "enable_meal_reminders": True,
                "enable_motivation_reminders": False,
                "quiet_hours_enabled": True,
                "quiet_start": "22:00:00",
                "quiet_end": "07:00:00",
                "daily_water_target_ml": 3100,
                "water_reminder_interval_minutes": 90,
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["enable_meal_reminders"])
        self.assertFalse(response.data["enable_motivation_reminders"])
        self.assertTrue(response.data["quiet_hours_enabled"])
        self.assertEqual(response.data["quiet_start"], "22:00:00")
        self.assertEqual(response.data["quiet_end"], "07:00:00")
        self.assertEqual(response.data["daily_water_target_ml"], 3100)
        self.assertEqual(response.data["water_reminder_interval_minutes"], 90)

        user_profile = UserProfileService.ensure_profile(self.user)
        user_profile.refresh_from_db()
        self.assertFalse(user_profile.enable_motivation_reminders)
        self.assertEqual(user_profile.daily_water_target, 3.1)
        self.assertEqual(user_profile.manual_daily_water_target, 3.1)
        self.assertEqual(user_profile.water_reminder_interval_minutes, 90)

    def test_hydration_compiler_uses_unified_state_then_materialized_constraint(self):
        profile = UserProfileService.ensure_profile(self.user)
        profile.daily_water_target = 3.1
        profile.save(update_fields=["daily_water_target"])
        ConstraintResolutionService.resolve_for_user(user_id=self.user.id)
        state = UnifiedHealthState.objects.create(
            user=self.user,
            state_date=timezone.localdate(),
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
            version=4,
            progress_summary={"hydration": {"adjusted_target": 2.7}},
        )

        state_target, state_version, generated_at = HydrationRuleCompiler._active_target_liters(
            user=self.user,
            user_profile=profile,
            today=timezone.localdate(),
        )
        self.assertAlmostEqual(state_target, 2.7)
        self.assertEqual(state_version, 4)
        self.assertIsNotNone(generated_at)

        state.delete()
        constraint_target, state_version, generated_at = (
            HydrationRuleCompiler._active_target_liters(
                user=self.user,
                user_profile=profile,
                today=timezone.localdate(),
            )
        )
        self.assertAlmostEqual(constraint_target, 3.1)
        self.assertIsNone(state_version)
        self.assertIsNone(generated_at)

    def test_sync_auto_registers_device_and_returns_meal_snapshot(self):
        self.client.patch(
            self.preferences_url,
            {
                "enable_routine_reminders": True,
                "enable_meal_reminders": True,
                "enable_water_reminders": False,
                "enable_activity_reminders": False,
                "enable_step_reminders": False,
                "enable_sleep_reminders": False,
                "enable_motivation_reminders": False,
                "enable_medication_reminders": False,
                "enable_health_alerts": False,
            },
            format="json",
        )

        response = self.client.post(
            self.sync_url,
            {
                "installation_id": "android-sync",
                "foreground_state": "background",
                "timezone": "Asia/Damascus",
                "permission_snapshot": {
                    "notifications_authorized": True,
                    "exact_alarm_authorized": True,
                },
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        payload = response.data["data"]
        self.assertEqual(payload["channels_version"], 3)
        self.assertEqual(payload["horizon_hours"], 72)
        self.assertEqual(payload["cancel_plan_ids"], [])
        self.assertEqual(payload["in_app_events"], [])
        self.assertEqual(len(payload["plans"]), 3)
        self.assertEqual(
            {plan["type"] for plan in payload["plans"]},
            {"meal_time"},
        )
        self.assertEqual(
            {plan["status"] for plan in payload["plans"]},
            {NotificationPlan.STATUS_PLANNED},
        )

        device = NotificationDevice.objects.get(
            user=self.user,
            installation_id="android-sync",
        )
        self.assertTrue(device.is_primary)
        self.assertIsNotNone(device.last_sync_at)

    def test_habit_reminders_respect_status_and_independent_toggle(self):
        habit = UnhealthyHabit.objects.create(
            user=self.user,
            habit_type=UnhealthyHabit.TYPE_CAFFEINE,
            title="Caffeine",
            goal_type=UnhealthyHabit.GOAL_REDUCE,
            status=UnhealthyHabit.STATUS_ACTIVE,
        )
        reminder = UnhealthyHabitReminder.objects.create(
            habit=habit,
            time_of_day=time(14, 0),
            message="Check caffeine timing.",
        )
        self.client.patch(
            self.preferences_url,
            {
                "enable_routine_reminders": True,
                "enable_habit_reminders": True,
                "enable_meal_reminders": False,
                "enable_water_reminders": False,
                "enable_activity_reminders": False,
                "enable_step_reminders": False,
                "enable_sleep_reminders": False,
                "enable_motivation_reminders": False,
                "enable_medication_reminders": False,
                "enable_health_alerts": False,
            },
            format="json",
        )

        response = self.client.post(
            self.sync_url,
            {
                "installation_id": "android-habits",
                "foreground_state": "background",
                "timezone": "Asia/Damascus",
                "permission_snapshot": {
                    "notifications_authorized": True,
                    "exact_alarm_authorized": True,
                },
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        plans = response.data["data"]["plans"]
        self.assertEqual(len(plans), 1)
        self.assertEqual(plans[0]["type"], "habit_time")
        self.assertEqual(plans[0]["dedupe_key"], f"routine:habit:{reminder.id}")

        self.client.patch(
            self.preferences_url,
            {"enable_habit_reminders": False},
            format="json",
        )
        disabled = self.client.post(
            self.sync_url,
            {
                "installation_id": "android-habits",
                "foreground_state": "background",
                "timezone": "Asia/Damascus",
            },
            format="json",
        )
        self.assertEqual(disabled.status_code, 200)
        self.assertEqual(disabled.data["data"]["plans"], [])
        self.assertEqual(len(disabled.data["data"]["cancel_plan_ids"]), 1)

        self.client.patch(
            self.preferences_url,
            {"enable_habit_reminders": True},
            format="json",
        )
        habit.status = UnhealthyHabit.STATUS_PAUSED
        habit.save(update_fields=["status", "updated_at"])
        paused = self.client.post(
            self.sync_url,
            {
                "installation_id": "android-habits",
                "foreground_state": "background",
                "timezone": "Asia/Damascus",
            },
            format="json",
        )
        self.assertEqual(paused.status_code, 200)
        self.assertEqual(paused.data["data"]["plans"], [])

    def test_sync_returns_materialized_medication_plans_by_log_id(self):
        self.client.patch(
            self.preferences_url,
            {
                "enable_routine_reminders": True,
                "enable_medication_reminders": True,
                "enable_meal_reminders": False,
                "enable_water_reminders": False,
                "enable_activity_reminders": False,
                "enable_step_reminders": False,
                "enable_sleep_reminders": False,
                "enable_motivation_reminders": False,
                "enable_health_alerts": False,
            },
            format="json",
        )
        future_time = (
            timezone.now().astimezone(ZoneInfo("Asia/Damascus")) + timedelta(minutes=30)
        ).strftime("%H:%M")
        create_response = self.client.post(
            "/api/medications/",
            {
                "display_name": "Vitamin D",
                "source_type": "manual",
                "dose_amount": "1000",
                "dose_unit": "IU",
                "form": "capsule",
                "start_date": str(timezone.localdate()),
                "timezone": "Asia/Damascus",
                "reminder_lead_minutes": 0,
                "schedules": [{"schedule_type": "daily", "time": future_time}],
            },
            format="json",
        )
        self.assertEqual(create_response.status_code, 201, create_response.data)
        log = ConditionMedicationLog.objects.filter(medication__user=self.user).order_by("scheduled_for").first()
        self.assertIsNotNone(log)

        response = self.client.post(
            self.sync_url,
            {
                "installation_id": "android-med",
                "foreground_state": "background",
                "timezone": "Asia/Damascus",
                "permission_snapshot": {
                    "notifications_authorized": True,
                    "exact_alarm_authorized": True,
                },
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        plans = response.data["data"]["plans"]
        self.assertTrue(plans)
        plan = next(item for item in plans if item["payload"].get("log_id") == log.id)
        self.assertEqual(plan["type"], "medication_dose")
        self.assertEqual(plan["payload"]["log_id"], log.id)
        self.assertEqual(plan["schedule_spec"], {})
        self.assertIsNotNone(plan["deliver_at"])
        persisted = NotificationPlan.objects.get(plan_id=plan["plan_id"])
        self.assertEqual(persisted.source_ref, str(log.id))

    def test_sync_does_not_promote_medium_health_guidance_to_red_alert(self):
        self.client.patch(
            self.preferences_url,
            {
                "enable_routine_reminders": False,
                "enable_motivation_reminders": False,
                "enable_health_alerts": True,
                "enable_medication_reminders": False,
            },
            format="json",
        )
        UnifiedHealthState.objects.create(
            user=self.user,
            state_date=timezone.localdate(),
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
            warnings=[
                {
                    "source": "condition_alert",
                    "code": "tighten_heart_healthy_fats",
                    "level": "medium",
                    "message": (
                        "Favor unsaturated fats, fiber-rich meals, and avoid "
                        "trans fat while lipid risk remains elevated."
                    ),
                }
            ],
            medication_summary={},
        )

        response = self.client.post(
            self.sync_url,
            {
                "installation_id": "android-health-guidance",
                "foreground_state": "foreground",
                "timezone": "Asia/Damascus",
                "permission_snapshot": {
                    "notifications_authorized": True,
                    "exact_alarm_authorized": True,
                },
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        payload = response.data["data"]
        self.assertEqual(payload["plans"], [])
        self.assertEqual(payload["in_app_events"], [])

    def test_sync_does_not_promote_medication_overdue_to_foreground_red_alert(self):
        self.client.patch(
            self.preferences_url,
            {
                "enable_routine_reminders": False,
                "enable_motivation_reminders": False,
                "enable_health_alerts": True,
                "enable_medication_reminders": False,
            },
            format="json",
        )
        UnifiedHealthState.objects.create(
            user=self.user,
            state_date=timezone.localdate(),
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
            warnings=[
                {
                    "source": "medication",
                    "code": "medication_overdue",
                    "level": "high",
                    "message": "1 medication doses overdue today.",
                    "count": 1,
                }
            ],
            medication_summary={"overdue_today": 1},
        )

        response = self.client.post(
            self.sync_url,
            {
                "installation_id": "android-med-overdue",
                "foreground_state": "foreground",
                "timezone": "Asia/Damascus",
                "permission_snapshot": {
                    "notifications_authorized": True,
                    "exact_alarm_authorized": True,
                },
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        payload = response.data["data"]
        self.assertEqual(payload["plans"], [])
        self.assertEqual(payload["in_app_events"], [])
        self.assertFalse(
            NotificationPlan.objects.filter(
                user=self.user,
                type="medication_overdue",
            ).exists()
        )

    def test_sync_foreground_promotes_celebration_to_in_app_and_report_updates_status(self):
        register_response = self.client.post(
            self.register_url,
            {
                "installation_id": "android-events",
                "platform": "android",
                "timezone": "Asia/Damascus",
                "locale": "ar-SY",
                "app_version": "1.4.0",
                "notifications_authorized": True,
                "exact_alarm_authorized": True,
            },
            format="json",
        )
        self.assertEqual(register_response.status_code, 200)

        self.client.patch(
            self.preferences_url,
            {
                "enable_routine_reminders": False,
                "enable_motivation_reminders": False,
                "enable_health_alerts": False,
                "enable_medication_reminders": False,
            },
            format="json",
        )
        source_event = MotivationExperienceEvent.objects.create(
            user=self.user,
            event_type=MotivationExperienceEvent.TYPE_LEVEL_UP,
            title="Level up",
            subtitle="You reached level 2.",
            points_delta=25,
            route="/score",
            dedupe_key="test-level-up",
        )

        sync_response = self.client.post(
            self.sync_url,
            {
                "installation_id": "android-events",
                "foreground_state": "foreground",
                "timezone": "Asia/Damascus",
            },
            format="json",
        )

        self.assertEqual(sync_response.status_code, 200)
        payload = sync_response.data["data"]
        self.assertEqual(payload["plans"], [])
        self.assertEqual(len(payload["in_app_events"]), 1)
        in_app_event = payload["in_app_events"][0]
        self.assertEqual(in_app_event["type"], MotivationExperienceEvent.TYPE_LEVEL_UP)
        self.assertEqual(in_app_event["status"], NotificationPlan.STATUS_PLANNED)

        plan = NotificationPlan.objects.get(plan_id=in_app_event["plan_id"])
        self.assertEqual(plan.status, NotificationPlan.STATUS_PLANNED)

        report_response = self.client.post(
            self.report_url,
            {
                "installation_id": "android-events",
                "events": [
                    {
                        "event_id": "present-level-up-once",
                        "plan_id": plan.plan_id,
                        "revision": plan.revision,
                        "outcome": NotificationPlanEvent.EVENT_PRESENTED_IN_APP,
                        "metadata": {"surface": "dialog"},
                    },
                    {
                        "event_id": "ack-level-up-once",
                        "plan_id": plan.plan_id,
                        "revision": plan.revision,
                        "outcome": NotificationPlanEvent.EVENT_ACKNOWLEDGED,
                    }
                ],
            },
            format="json",
        )

        self.assertEqual(report_response.status_code, 200)
        recorded = report_response.data["data"]["recorded_events"]
        self.assertEqual(len(recorded), 2)
        self.assertEqual(
            [item["outcome"] for item in recorded],
            [
                NotificationPlanEvent.EVENT_PRESENTED_IN_APP,
                NotificationPlanEvent.EVENT_ACKNOWLEDGED,
            ],
        )
        plan.refresh_from_db()
        source_event.refresh_from_db()
        self.assertEqual(plan.status, NotificationPlan.STATUS_ACKNOWLEDGED)
        self.assertTrue(source_event.is_acknowledged)
        self.assertTrue(
            NotificationPlanEvent.objects.filter(
                plan=plan,
                event_type=NotificationPlanEvent.EVENT_PRESENTED_IN_APP,
            ).exists()
        )
        repeated = self.client.post(
            self.sync_url,
            {
                "installation_id": "android-events",
                "foreground_state": "foreground",
                "timezone": "Asia/Damascus",
            },
            format="json",
        )
        self.assertEqual(repeated.status_code, 200)
        self.assertEqual(repeated.data["data"]["in_app_events"], [])
