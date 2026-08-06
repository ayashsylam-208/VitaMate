from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier

from django.db import close_old_connections
from django.db.models import Count
from django.test import TestCase, TransactionTestCase
from django.utils import timezone
from rest_framework import status
from unittest.mock import patch

from core.models import (
    ConstraintResolutionRun,
    ConditionType,
    HealthRestriction,
    ResolvedTrackerConstraint,
    UserCondition,
)
from core.services.constraints import (
    ConstraintReadService,
    ConstraintRecomputeDispatcher,
    ConstraintResolutionService,
    EffectiveConstraintReader,
)
from test_utils.helpers import auth_client_for_user, create_user_with_profile


class ConstraintResolutionTests(TestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="constraint-user", weight=91, height=175)
        self.client = auth_client_for_user(self.user)
        self.profile = self.user.userprofile
        self.profile.daily_water_target = 3.0
        self.profile.daily_calorie_target = 2100
        self.profile.daily_step_goal = 7000
        self.profile.daily_burn_goal = 350
        self.profile.recommended_sleep_hours = 7.5
        self.profile.save(
            update_fields=[
                "daily_water_target",
                "daily_calorie_target",
                "daily_step_goal",
                "daily_burn_goal",
                "recommended_sleep_hours",
            ]
        )
        ResolvedTrackerConstraint.objects.filter(user=self.user).delete()
        ConstraintResolutionRun.objects.filter(user=self.user).delete()

    def test_resolution_materializes_profile_defaults(self):
        run = ConstraintResolutionService.resolve_for_user(user_id=self.user.id)

        self.assertEqual(run.run_status, ConstraintResolutionRun.STATUS_COMPLETED)
        self.assertGreater(run.total_constraints_generated, 0)

        water_constraint = ResolvedTrackerConstraint.objects.get(
            user=self.user,
            status=ResolvedTrackerConstraint.STATUS_ACTIVE,
            tracker_type=ResolvedTrackerConstraint.TRACKER_HYDRATION,
            metric_key="daily_water_liters",
            rule_type=ResolvedTrackerConstraint.RULE_TARGET,
        )
        self.assertEqual(water_constraint.source_type, ResolvedTrackerConstraint.SOURCE_PROFILE_DERIVED_DEFAULT)
        self.assertAlmostEqual(water_constraint.target_value, 3.0)

    def test_conflict_resolution_caps_profile_target_with_condition_max(self):
        self._create_hydration_max_condition(max_liters=2.0)

        ConstraintResolutionService.resolve_for_user(user_id=self.user.id)

        effective_target = ResolvedTrackerConstraint.objects.get(
            user=self.user,
            status=ResolvedTrackerConstraint.STATUS_ACTIVE,
            tracker_type=ResolvedTrackerConstraint.TRACKER_HYDRATION,
            metric_key="daily_water_liters",
            rule_type=ResolvedTrackerConstraint.RULE_TARGET,
        )
        self.assertEqual(
            effective_target.source_type,
            ResolvedTrackerConstraint.SOURCE_SAFETY_CRITICAL_CONDITION_RULE,
        )
        self.assertAlmostEqual(effective_target.target_value, 2.0)
        self.assertEqual(
            effective_target.explanation_payload["resolution_policy"],
            "target_capped_by_safety_max",
        )

        read_value = ConstraintReadService.effective_numeric_value(
            user=self.user,
            tracker_type=ResolvedTrackerConstraint.TRACKER_HYDRATION,
            metric_key="daily_water_liters",
            fallback=3.0,
        )
        self.assertAlmostEqual(read_value, 2.0)

    def test_equivalent_daily_units_are_normalized_before_resolution(self):
        self._create_hydration_max_condition(
            max_liters=2.2,
            unit="liters/day",
        )

        ConstraintResolutionService.resolve_for_user(user_id=self.user.id)
        effective = ResolvedTrackerConstraint.objects.get(
            user=self.user,
            status=ResolvedTrackerConstraint.STATUS_ACTIVE,
            tracker_type=ResolvedTrackerConstraint.TRACKER_HYDRATION,
            metric_key="daily_water_liters",
            rule_type=ResolvedTrackerConstraint.RULE_TARGET,
        )
        self.assertEqual(effective.unit, "liters")
        self.assertAlmostEqual(effective.target_value, 2.2)
        self.assertEqual(effective.explanation_payload["rule_version"], "test-v1")
        self.assertEqual(
            effective.explanation_payload["clinical_source"],
            "Existing test catalog source",
        )

    def test_incompatible_unit_fails_run_instead_of_merging_values(self):
        self._create_hydration_max_condition(max_liters=2000, unit="ml/day")
        with self.assertRaisesRegex(ValueError, "unit must be 'liters'"):
            ConstraintResolutionService.resolve_for_user(user_id=self.user.id)
        run = ConstraintResolutionRun.objects.filter(user=self.user).order_by("-id").first()
        self.assertEqual(run.run_status, ConstraintResolutionRun.STATUS_FAILED)
        self.assertIn("ValidationError", run.error_code)

    def test_recompute_dispatcher_supersedes_previous_constraints(self):
        ConstraintResolutionService.resolve_for_user(user_id=self.user.id)
        self.profile.daily_water_target = 2.7
        self.profile.save(update_fields=["daily_water_target"])

        run = ConstraintRecomputeDispatcher.dispatch_for_user(
            user=self.user,
            trigger_type=ConstraintResolutionRun.TRIGGER_USER_PROFILE,
            trigger_reference=str(self.profile.id),
        )

        self.assertEqual(run.run_status, ConstraintResolutionRun.STATUS_COMPLETED)
        self.assertGreater(run.total_constraints_superseded, 0)
        active_value = ConstraintReadService.effective_numeric_value(
            user=self.user,
            tracker_type=ResolvedTrackerConstraint.TRACKER_HYDRATION,
            metric_key="daily_water_liters",
        )
        self.assertAlmostEqual(active_value, 2.7)
        self.assertTrue(
            ResolvedTrackerConstraint.objects.filter(
                user=self.user,
                status=ResolvedTrackerConstraint.STATUS_SUPERSEDED,
            ).exists()
        )

    def test_tracker_read_service_and_api_return_active_constraints(self):
        ConstraintResolutionService.resolve_for_user(user_id=self.user.id)

        summary = ConstraintReadService.active_summary_for_user(user=self.user)
        self.assertIn(ResolvedTrackerConstraint.TRACKER_HYDRATION, summary)

        res = self.client.get("/api/health/constraints/hydration/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["tracker_type"], "hydration")
        self.assertTrue(res.data["constraints"])

        recompute_res = self.client.post(
            "/api/health/constraints/recompute/",
            {"tracker_type": "hydration"},
            format="json",
        )
        self.assertEqual(recompute_res.status_code, status.HTTP_200_OK)
        self.assertIn(
            recompute_res.data["run"]["run_status"],
            {ConstraintResolutionRun.STATUS_SUCCEEDED, ConstraintResolutionRun.STATUS_SKIPPED},
        )
        self.assertTrue(recompute_res.data["run"]["successful"])

    def test_duplicate_idempotency_key_reuses_successful_run(self):
        first = ConstraintRecomputeDispatcher.dispatch_for_user(
            user=self.user,
            trigger_type=ConstraintResolutionRun.TRIGGER_MANUAL,
            trigger_reference="idempotent-test",
            idempotency_key="constraint-idempotent-test",
            correlation_id="correlation-1",
        )
        second = ConstraintRecomputeDispatcher.dispatch_for_user(
            user=self.user,
            trigger_type=ConstraintResolutionRun.TRIGGER_MANUAL,
            trigger_reference="idempotent-test",
            idempotency_key="constraint-idempotent-test",
            correlation_id="correlation-1",
        )

        self.assertEqual(first.id, second.id)
        self.assertEqual(
            ConstraintResolutionRun.objects.filter(idempotency_key="constraint-idempotent-test").count(),
            1,
        )

    def test_queued_run_reuses_placeholder_and_persists_metadata(self):
        run = ConstraintRecomputeDispatcher.dispatch_for_user(
            user=self.user,
            trigger_type=ConstraintResolutionRun.TRIGGER_MANUAL,
            trigger_reference="queued-test",
            synchronous=False,
            idempotency_key="constraint-queued-test",
            correlation_id="queued-correlation",
            metadata={"source": "test"},
        )

        self.assertEqual(run.sync_mode, ConstraintResolutionRun.SYNC_MODE_QUEUED)
        self.assertEqual(run.correlation_id, "queued-correlation")
        self.assertEqual(run.metadata["source"], "test")
        self.assertIn(
            run.run_status,
            {ConstraintResolutionRun.STATUS_SUCCEEDED, ConstraintResolutionRun.STATUS_SKIPPED},
        )
        self.assertEqual(
            ConstraintResolutionRun.objects.filter(idempotency_key="constraint-queued-test").count(),
            1,
        )

    def test_failed_collection_is_recorded_and_retryable(self):
        with patch(
            "core.services.constraints.constraint_resolution_service.ConstraintSourceCollector.collect_for_user",
            side_effect=RuntimeError("collector failed"),
        ):
            with self.assertRaises(RuntimeError):
                ConstraintRecomputeDispatcher.dispatch_for_user(
                    user=self.user,
                    trigger_type=ConstraintResolutionRun.TRIGGER_MANUAL,
                    trigger_reference="retry-test",
                    idempotency_key="constraint-retry-test",
                    correlation_id="retry-correlation",
                )

        failed = ConstraintResolutionRun.objects.get(idempotency_key="constraint-retry-test")
        self.assertEqual(failed.run_status, ConstraintResolutionRun.STATUS_FAILED)
        self.assertEqual(failed.error_code, "RuntimeError")
        self.assertIsNotNone(failed.failed_at)

        retried = ConstraintRecomputeDispatcher.dispatch_for_user(
            user=self.user,
            trigger_type=ConstraintResolutionRun.TRIGGER_MANUAL,
            trigger_reference="retry-test",
            idempotency_key="constraint-retry-test",
            correlation_id="retry-correlation",
        )
        self.assertEqual(retried.id, failed.id)
        self.assertEqual(retried.retry_count, 1)
        self.assertIn(
            retried.run_status,
            {ConstraintResolutionRun.STATUS_SUCCEEDED, ConstraintResolutionRun.STATUS_SKIPPED},
        )

    def test_effective_reader_enforces_validity_window(self):
        ConstraintResolutionService.resolve_for_user(user_id=self.user.id)
        constraint = ResolvedTrackerConstraint.objects.get(
            user=self.user,
            status=ResolvedTrackerConstraint.STATUS_ACTIVE,
            tracker_type=ResolvedTrackerConstraint.TRACKER_HYDRATION,
            metric_key="daily_water_liters",
            rule_type=ResolvedTrackerConstraint.RULE_TARGET,
        )
        constraint.effective_from = timezone.now() + timedelta(hours=1)
        constraint.save(update_fields=["effective_from"])

        future_result = EffectiveConstraintReader.get_effective_constraint(
            user=self.user,
            tracker_type="hydration",
            constraint_key="daily_water_liters",
            default_value=1.9,
            default_unit="liters",
        )
        self.assertTrue(future_result.defaulted)
        self.assertAlmostEqual(future_result.value, 1.9)

        constraint.effective_from = timezone.now() - timedelta(days=2)
        constraint.effective_to = timezone.now() - timedelta(days=1)
        constraint.save(update_fields=["effective_from", "effective_to"])
        expired_result = EffectiveConstraintReader.get_effective_constraint(
            user=self.user,
            tracker_type="hydration",
            constraint_key="daily_water_liters",
            default_value=2.1,
            default_unit="liters",
        )
        self.assertTrue(expired_result.defaulted)
        self.assertAlmostEqual(expired_result.value, 2.1)

    def test_effective_reader_bulk_resolution_matches_single_reads(self):
        ConstraintResolutionService.resolve_for_user(user_id=self.user.id)
        requests = [
            {
                "tracker_type": "hydration",
                "constraint_key": "daily_water_liters",
                "default_value": 2.0,
                "default_unit": "liters",
            },
            {
                "tracker_type": "nutrition",
                "constraint_key": "calories_kcal",
                "default_value": 1800,
                "default_unit": "kcal",
            },
        ]

        with self.assertNumQueries(1):
            results = EffectiveConstraintReader.get_effective_constraints(
                user=self.user,
                requests=requests,
            )

        self.assertAlmostEqual(results[("hydration", "daily_water_liters")].value, 3.0)
        self.assertAlmostEqual(results[("nutrition", "calories_kcal")].value, 2100)

    def _create_hydration_max_condition(
        self,
        *,
        max_liters: float,
        unit: str = "liters",
    ) -> UserCondition:
        condition_type = ConditionType.objects.create(
            code="fluid_limit_test",
            slug="fluid_limit_test",
            name="Fluid Limit",
            display_name="Fluid Limit",
            is_supported=True,
            severity_options=[{"code": "moderate", "label": "Moderate"}],
        )
        HealthRestriction.objects.create(
            condition_type=condition_type,
            severity_code="moderate",
            restriction_key="daily_water_liters_max",
            title="Daily fluid cap",
            category=HealthRestriction.CATEGORY_HYDRATION,
            metric_key="water_liters",
            evaluation_mode="daily_total",
            unit=unit,
            max_allowed_value=max_liters,
            is_scored=True,
            guidance="Fluid intake capped by active condition.",
            evidence_source="Existing test catalog source",
            source_version="test-v1",
        )
        return UserCondition.objects.create(
            user=self.user,
            condition_type=condition_type,
            status=UserCondition.STATUS_ACTIVE,
            severity_code="moderate",
            is_active=True,
        )


class ConstraintConcurrencyTests(TransactionTestCase):
    reset_sequences = True

    def setUp(self):
        self.user = create_user_with_profile(
            username="constraint-concurrent-user",
            weight=80,
            height=175,
        )

    def test_concurrent_recompute_does_not_create_duplicate_active_scopes(self):
        barrier = Barrier(2)

        def recompute_once(index):
            close_old_connections()
            try:
                barrier.wait(timeout=10)
                run = ConstraintResolutionService.resolve_for_user(
                    user_id=self.user.id,
                    idempotency_key=f"constraint-concurrency:{self.user.id}:{index}",
                    correlation_id=f"constraint-concurrency-{index}",
                )
                return run.run_status
            finally:
                close_old_connections()

        with ThreadPoolExecutor(max_workers=2) as executor:
            statuses = list(executor.map(recompute_once, range(2)))

        self.assertTrue(
            set(statuses).issubset(
                {
                    ConstraintResolutionRun.STATUS_SUCCEEDED,
                    ConstraintResolutionRun.STATUS_SKIPPED,
                }
            )
        )
        duplicate_scopes = (
            ResolvedTrackerConstraint.objects.filter(
                user=self.user,
                status=ResolvedTrackerConstraint.STATUS_ACTIVE,
            )
            .values("tracker_type", "metric_key", "rule_type")
            .annotate(total=Count("id"))
            .filter(total__gt=1)
        )
        self.assertFalse(duplicate_scopes.exists())
