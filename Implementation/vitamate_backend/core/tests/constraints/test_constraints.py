from django.test import TestCase
from rest_framework import status

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
        self.assertEqual(recompute_res.data["run"]["run_status"], ConstraintResolutionRun.STATUS_COMPLETED)

    def _create_hydration_max_condition(self, *, max_liters: float) -> UserCondition:
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
            unit="liters",
            max_allowed_value=max_liters,
            is_scored=True,
            guidance="Fluid intake capped by active condition.",
        )
        return UserCondition.objects.create(
            user=self.user,
            condition_type=condition_type,
            status=UserCondition.STATUS_ACTIVE,
            severity_code="moderate",
            is_active=True,
        )
