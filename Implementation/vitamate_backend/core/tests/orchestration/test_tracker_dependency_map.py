from datetime import date

from django.test import SimpleTestCase

from core.services.orchestration.tracker_dependency_map import (
    HealthStateTriggers,
    TrackerDependencyMap,
)


class TrackerDependencyMapTests(SimpleTestCase):
    def test_micronutrient_target_change_recomputes_nutrition_and_micronutrients(self):
        plan = TrackerDependencyMap.build_plan(
            trigger_type=HealthStateTriggers.USER_NUTRIENT_TARGET_CHANGED,
            payload={},
            today=date(2026, 8, 4),
        )

        self.assertEqual(plan.affected_trackers, ("nutrition", "micronutrient"))
        self.assertEqual(plan.constraint_tracker_types, ("nutrition", "micronutrient"))
        self.assertTrue(plan.recompute_constraints)
        self.assertTrue(plan.recompute_current)

    def test_dependency_map_contains_only_known_unique_trackers(self):
        self.assertEqual(TrackerDependencyMap.validate(), [])

    def test_unknown_event_does_not_silently_claim_recompute(self):
        with self.assertRaisesMessage(ValueError, "Unknown health-state trigger"):
            TrackerDependencyMap.build_plan(
                trigger_type="unknown_event",
                payload={},
                today=date(2026, 8, 4),
            )
