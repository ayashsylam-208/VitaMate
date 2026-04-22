from django.contrib.auth.models import User
from django.core.management import call_command, CommandError
from django.test import TestCase

from core.models import (
    ActivityLog,
    ConditionMedication,
    ConditionMedicationLog,
    SleepLog,
    StepLog,
    UnifiedHealthState,
    UserCondition,
    WaterLog,
    MealLog,
)
from test_utils.helpers import create_food_item, create_user_with_profile


class SeedPerformanceDatasetCommandTests(TestCase):
    def test_command_creates_representative_dataset_for_seeded_pool(self):
        call_command(
            "seed_performance_dataset",
            profile="representative",
            reset=True,
            user_count=2,
            days=3,
        )

        for username in ("locust0", "locust1"):
            user = User.objects.get(username=username)
            self.assertTrue(user.check_password("Pass123!"))
            self.assertIsNotNone(user.userprofile)

            self.assertGreater(MealLog.objects.filter(user=user).count(), 0)
            self.assertGreater(WaterLog.objects.filter(user=user).count(), 0)
            self.assertGreater(StepLog.objects.filter(user=user).count(), 0)
            self.assertGreater(SleepLog.objects.filter(user=user).count(), 0)
            self.assertGreater(ActivityLog.objects.filter(user=user).count(), 0)
            self.assertGreater(ConditionMedication.objects.filter(user=user).count(), 0)
            self.assertGreater(ConditionMedicationLog.objects.filter(medication__user=user).count(), 0)
            self.assertGreater(UserCondition.objects.filter(user=user).count(), 0)
            self.assertFalse(UnifiedHealthState.objects.filter(user=user).exists())

    def test_reset_replaces_existing_user_state(self):
        user = create_user_with_profile(username="locust0")
        StepLog.objects.create(user=user, steps_count=800)
        WaterLog.objects.create(user=user, amount_liter=0.3)
        MealLog.objects.create(
            user=user,
            food=create_food_item(name="Old Meal"),
            meal_type="lunch",
            quantity_grams=120,
        )
        UnifiedHealthState.objects.create(
            user=user,
            state_date=user.userprofile.birth_date,
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
        )

        call_command(
            "seed_performance_dataset",
            profile="representative",
            reset=True,
            user_count=1,
            days=2,
        )

        user = User.objects.get(username="locust0")
        self.assertGreater(MealLog.objects.filter(user=user).count(), 0)
        self.assertGreater(WaterLog.objects.filter(user=user).count(), 0)
        self.assertGreater(StepLog.objects.filter(user=user).count(), 0)
        self.assertFalse(UnifiedHealthState.objects.filter(user=user).exists())

    def test_unknown_profile_is_rejected(self):
        with self.assertRaises(CommandError):
            call_command("seed_performance_dataset", profile="unknown")
