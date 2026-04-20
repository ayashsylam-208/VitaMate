from datetime import time

from django.test import TestCase

from test_utils.helpers import create_user_with_profile
from users.services.profile_metrics_calculator import ProfileMetricsCalculator


class ProfileMetricsCalculatorTests(TestCase):
    def test_calculates_daily_targets_and_bedtime(self):
        user = create_user_with_profile(
            username="metricsuser",
            weight=82,
            height=182,
            activity_level=1.55,
        )
        profile = user.userprofile
        profile.goal = "lose"
        profile.recommended_sleep_hours = 7.5
        profile.target_wake_time = time(7, 0)

        metrics = ProfileMetricsCalculator.calculate(profile)

        self.assertGreater(metrics.daily_calorie_target, 0)
        self.assertGreater(metrics.daily_water_target, 0)
        self.assertGreaterEqual(metrics.daily_step_goal, 5000)
        self.assertGreater(metrics.daily_burn_goal, 0)
        self.assertEqual(metrics.target_bed_time, time(23, 30))

    def test_apply_updates_profile_fields(self):
        user = create_user_with_profile(username="metricsapply")
        profile = user.userprofile
        profile.weight = 90
        profile.height = 180
        profile.goal = "gain"

        ProfileMetricsCalculator.apply(profile, persist=True)
        profile.refresh_from_db()

        self.assertGreater(profile.daily_calorie_target, 0)
        self.assertGreater(profile.daily_water_target, 0)
        self.assertGreater(profile.daily_step_goal, 0)
        self.assertGreater(profile.daily_burn_goal, 0)
        self.assertGreater(profile.bmi, 0)
