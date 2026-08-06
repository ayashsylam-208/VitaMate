from datetime import date, timedelta
from unittest.mock import patch

from django.db import transaction
from django.test import TestCase, TransactionTestCase
from django.utils import timezone

from core.models import (
    HealthStateComputationRun,
    HealthStateDelta,
    UnifiedHealthState,
)
from core.services.orchestration.health_state_event_publisher import HealthStateEventPublisher
from core.services.orchestration.health_state_orchestrator import (
    HealthStateOrchestrator,
    HealthStateUpdateError,
)
from core.services.orchestration.tracker_dependency_map import (
    HealthStateTriggers,
    TrackerDependencyMap,
)
from core.services.tracking.health_tracker_coordinator import HealthTrackerCoordinator
from test_utils.helpers import auth_client_for_user, create_food_item, create_user_with_profile


class HealthTrackerCoordinatorReadTests(TestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="state_read_user")
        self.coordinator = HealthTrackerCoordinator()

    def _dashboard_progress(self, *, calories_target=2100, calories_consumed=480):
        return {
            "summary": {
                "calories_target": calories_target,
                "base_calories_target": 2000,
                "calories_consumed": calories_consumed,
                "calories_remaining": calories_target - calories_consumed,
                "calories_burned": 220,
                "burn_target": 350,
                "base_burn_target": 300,
                "protein_g": 30.0,
                "carbs_g": 40.0,
                "fat_g": 10.0,
                "sugars_g": 5.0,
                "added_sugars_g": 2.0,
                "fiber_g": 7.0,
                "caffeine_mg": 0.0,
            },
            "hydration": {
                "target": 2.3,
                "base_target": 2.0,
                "current": 1.2,
                "adjusted_target": 2.3,
            },
            "sleep": {
                "target_bed_time": "22:00:00",
                "target_wake_time": "06:00:00",
                "recommended_sleep_hours": 8.0,
                "logged_hours_today": 7.0,
                "progress_percent": 88,
            },
            "activity": {
                "steps": 3200,
                "steps_target": 8000,
                "base_steps_target": 7000,
                "distance_km": 2.4,
                "steps_burned": 128,
                "steps_burn_rate": 53.3,
                "exercise_intensity_mode": "moderate",
            },
            "gamification": {
                "points": 42,
                "level": 2,
            },
            "chronic_conditions": {
                "count": 0,
                "labels": [],
                "adherence_percent": 0,
                "active_medications_today": 0,
                "pending_doses_today": 0,
                "applied_summaries": [],
                "disclaimer": "",
            },
            "medications": {
                "active_medications": 0,
                "today_total_doses": 0,
                "taken_today": 0,
                "pending_today": 0,
                "missed_today": 0,
                "overdue_today": 0,
                "next_due": None,
                "adherence_7d": 100.0,
            },
        }

    def _create_state(self, *, state_date: date, window_kind: str, progress_summary: dict, version: int = 1):
        return UnifiedHealthState.objects.create(
            user=self.user,
            state_date=state_date,
            window_kind=window_kind,
            version=version,
            last_computed_at=timezone.now(),
            affected_trackers=["nutrition", "hydration"],
            tracker_snapshots=[{"tracker_id": "nutrition"}, {"tracker_id": "hydration"}],
            progress_summary=progress_summary,
            active_targets=[],
            active_constraints={"nutrition": []},
            warnings=[{"source": "condition_alert", "code": "x", "message": "warning"}],
            medication_summary=progress_summary.get("medications") or {},
            trigger_metadata={"reason": "test"},
        )

    def test_dashboard_prefers_materialized_state_without_side_effects(self):
        self._create_state(
            state_date=timezone.localdate(),
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
            progress_summary=self._dashboard_progress(calories_target=2550, calories_consumed=620),
            version=3,
        )

        with patch(
            "core.services.chronic.condition_integration_coordinator.ConditionIntegrationCoordinator.sync_all_for_user"
        ) as sync_mock, patch(
            "core.services.constraints.constraint_recompute_dispatcher.ConstraintRecomputeDispatcher.dispatch_for_user"
        ) as recompute_mock, patch(
            "core.services.tracking.health_tracker_coordinator.HealthStateProjectionService.build_projection"
        ) as projection_mock:
            payload = self.coordinator.build_dashboard(
                user=self.user,
                today=timezone.localdate(),
            )

        self.assertEqual(payload["summary"]["calories_target"], 2550)
        self.assertEqual(payload["summary"]["calories_consumed"], 620)
        self.assertEqual(payload["state_version"], 3)
        self.assertIn("active_warnings", payload)
        self.assertEqual(len(self.coordinator.latest_snapshots), 2)
        sync_mock.assert_not_called()
        recompute_mock.assert_not_called()
        projection_mock.assert_not_called()

    def test_history_reads_materialized_daily_snapshots_first(self):
        today = timezone.localdate()
        start = today - timedelta(days=6)
        for offset in range(7):
            day = start + timedelta(days=offset)
            self._create_state(
                state_date=day,
                window_kind=UnifiedHealthState.WINDOW_DAILY,
                progress_summary={
                    "history_entry": {
                        "date": str(day),
                        "water_current": float(offset),
                        "water_target": 2.0,
                        "steps": offset * 100,
                        "steps_target": 8000,
                        "distance_km": 0,
                        "steps_burned": 0,
                        "steps_burn_rate": 0,
                        "calories_in": 0,
                        "calories_target": 2000,
                        "calories_burned": 0,
                        "sleep_hours": 0,
                        "sleep_target": 8.0,
                        "exercise_minutes": 0,
                        "points_estimate": 0,
                        "burn_target": 300,
                        "burn_current": 0,
                    }
                },
            )

        with patch(
            "core.services.tracking.health_tracker_coordinator.HealthStateProjectionService.build_projection"
        ) as projection_mock:
            history = self.coordinator.build_history(user=self.user, today=today, days=7)

        self.assertEqual(len(history), 7)
        self.assertEqual(history[0]["date"], str(start))
        self.assertEqual(history[0]["water_current"], 0.0)
        self.assertEqual(history[-1]["water_current"], 6.0)
        projection_mock.assert_not_called()

    def test_dashboard_bootstrap_persists_snapshot_when_missing(self):
        with patch(
            "core.services.orchestration.health_state_orchestrator.NotificationHubRefreshService.refresh_user"
        ):
            payload = self.coordinator.build_dashboard(
                user=self.user,
                today=timezone.localdate(),
            )

        self.assertIsNotNone(payload)
        self.assertTrue(
            UnifiedHealthState.objects.filter(
                user=self.user,
                state_date=timezone.localdate(),
                window_kind=UnifiedHealthState.WINDOW_CURRENT,
            ).exists()
        )
        self.assertIn("state_version", payload)

    def test_history_missing_snapshots_are_not_fabricated(self):
        today = timezone.localdate()

        with patch(
            "core.services.tracking.health_tracker_coordinator.HealthStateProjectionService.build_history_entry",
        ) as history_entry_mock, patch(
            "core.services.tracking.health_tracker_coordinator.HealthStateProjectionService.build_projection"
        ) as projection_mock:
            history = self.coordinator.build_history(user=self.user, today=today, days=7)

        self.assertEqual(history, [])
        history_entry_mock.assert_not_called()
        projection_mock.assert_not_called()


class HealthStateWriteFlowTests(TestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="state_write_user")
        self.client_auth = auth_client_for_user(self.user)
        self.food = create_food_item(name="State Rice", calories_100g=160)

    def test_meal_log_creates_current_and_daily_unified_state_after_commit(self):
        with self.captureOnCommitCallbacks(execute=True) as callbacks:
            response = self.client_auth.post(
                "/api/meals/",
                {
                    "food": self.food.id,
                    "meal_type": "lunch",
                    "quantity_grams": 120,
                },
                format="json",
            )

        self.assertEqual(response.status_code, 201)
        self.assertGreaterEqual(len(callbacks), 1)
        current_state = UnifiedHealthState.objects.filter(
            user=self.user,
            state_date=timezone.localdate(),
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
        ).first()
        daily_state = UnifiedHealthState.objects.filter(
            user=self.user,
            state_date=timezone.localdate(),
            window_kind=UnifiedHealthState.WINDOW_DAILY,
        ).first()
        run = HealthStateComputationRun.objects.filter(user=self.user).order_by("-id").first()

        self.assertIsNotNone(current_state)
        self.assertIsNotNone(daily_state)
        self.assertIsNotNone(run)
        self.assertEqual(run.run_status, HealthStateComputationRun.STATUS_COMPLETED)
        self.assertGreater(current_state.progress_summary["summary"]["calories_consumed"], 0)
        self.assertTrue(
            HealthStateDelta.objects.filter(
                user=self.user,
                trigger_type=HealthStateTriggers.MEAL_LOGGED,
            ).exists()
        )

        run_count = HealthStateComputationRun.objects.filter(user=self.user).count()
        delta_count = HealthStateDelta.objects.filter(user=self.user).count()
        duplicate_result = HealthStateOrchestrator().handle_event(
            user=self.user,
            trigger_type=HealthStateTriggers.MEAL_LOGGED,
            payload={
                "trigger_reference": run.trigger_reference,
                "correlation_id": run.correlation_id,
                "idempotency_key": run.idempotency_key,
            },
            synchronous=True,
        )
        self.assertEqual(duplicate_result["run_id"], run.id)
        self.assertEqual(duplicate_result["warnings"], ["duplicate_event_skipped"])
        self.assertEqual(HealthStateComputationRun.objects.filter(user=self.user).count(), run_count)
        self.assertEqual(HealthStateDelta.objects.filter(user=self.user).count(), delta_count)

    def test_failed_recompute_rolls_back_state_and_retries_same_run(self):
        payload = {
            "trigger_reference": "retryable-meal-event",
            "idempotency_key": f"health-state-retry-test:{self.user.id}",
            "event_dates": [timezone.localdate()],
            "today": timezone.localdate(),
        }
        with patch(
            "core.services.orchestration.health_state_projection_service."
            "HealthStateProjectionService.build_projection",
            side_effect=RuntimeError("projection failed"),
        ):
            with self.assertRaises(HealthStateUpdateError):
                HealthStateOrchestrator().handle_event(
                    user=self.user,
                    trigger_type=HealthStateTriggers.MEAL_LOGGED,
                    payload=payload,
                    synchronous=True,
                )

        run = HealthStateComputationRun.objects.get(
            idempotency_key=payload["idempotency_key"]
        )
        self.assertEqual(run.run_status, HealthStateComputationRun.STATUS_FAILED)
        self.assertEqual(run.error_code, "RuntimeError")
        self.assertFalse(UnifiedHealthState.objects.filter(user=self.user).exists())
        self.assertFalse(HealthStateDelta.objects.filter(user=self.user).exists())

        result = HealthStateOrchestrator().handle_event(
            user=self.user,
            trigger_type=HealthStateTriggers.MEAL_LOGGED,
            payload=payload,
            synchronous=True,
        )
        run.refresh_from_db()
        self.assertEqual(result["run_id"], run.id)
        self.assertEqual(run.run_status, HealthStateComputationRun.STATUS_COMPLETED)
        self.assertEqual(run.retry_count, 1)
        self.assertTrue(UnifiedHealthState.objects.filter(user=self.user).exists())


class HealthStateTransactionTests(TransactionTestCase):
    reset_sequences = True

    def test_rolled_back_domain_write_does_not_publish_health_state_event(self):
        user = create_user_with_profile(username="rolled-back-health-state-event")
        with patch(
            "core.services.orchestration.health_state_event_publisher."
            "dispatch_health_state_event"
        ) as dispatch_mock:
            with self.assertRaises(RuntimeError):
                with transaction.atomic():
                    HealthStateEventPublisher.publish_on_commit(
                        user=user,
                        trigger_type=HealthStateTriggers.MEAL_LOGGED,
                        payload={"trigger_reference": "rolled-back"},
                    )
                    raise RuntimeError("force rollback")

        dispatch_mock.assert_not_called()


class DependencyPlanTests(TestCase):
    def test_backdated_medication_adherence_recomputes_current_and_daily(self):
        plan = TrackerDependencyMap.build_plan(
            trigger_type=HealthStateTriggers.MEDICATION_ADHERENCE_CHANGED,
            payload={"event_dates": ["2026-04-10"]},
            today=date(2026, 4, 19),
        )

        self.assertTrue(plan.recompute_daily)
        self.assertTrue(plan.recompute_current)
        self.assertEqual(plan.event_dates, (date(2026, 4, 10),))
