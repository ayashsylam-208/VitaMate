from django.contrib.auth.models import User
from django.core.management import call_command, CommandError
from django.test import TestCase

from core.models import (
    ConditionType,
    MealLog,
    UserCondition,
    WaterLog,
)
from gamification.models import UserScore
from test_utils.helpers import create_food_item, create_user_with_profile


class SeedIntegrationUserCommandTests(TestCase):
    def test_command_creates_reproducible_e2e_user(self):
        call_command("seed_integration_user", scenario="chronic_flow", reset=True)

        user = User.objects.get(username="e2e_chronic")
        self.assertTrue(user.check_password("Pass123!"))
        self.assertIsNotNone(user.userprofile)

        score = UserScore.objects.get(user=user)
        self.assertEqual(score.total_points, 0)
        self.assertEqual(score.level, 1)
        self.assertFalse(UserCondition.objects.filter(user=user).exists())
        self.assertFalse(WaterLog.objects.filter(user=user).exists())
        self.assertFalse(MealLog.objects.filter(user=user).exists())

    def test_reset_clears_existing_user_specific_state(self):
        user = create_user_with_profile(username="e2e_chronic")
        UserScore.objects.update_or_create(
            user=user,
            defaults={"total_points": 250, "level": 3},
        )

        condition_type = ConditionType.objects.filter(slug="hypertension").first()
        self.assertIsNotNone(condition_type)
        UserCondition.objects.create(
            user=user,
            condition_type=condition_type,
            status="active",
            severity_code="stage_1",
        )
        WaterLog.objects.create(user=user, amount_liter=0.4)
        MealLog.objects.create(
            user=user,
            food=create_food_item(name="Reset Meal"),
            meal_type="lunch",
            quantity_grams=120,
        )

        call_command("seed_integration_user", scenario="chronic_flow", reset=True)

        user.refresh_from_db()
        score = UserScore.objects.get(user=user)
        self.assertEqual(score.total_points, 0)
        self.assertEqual(score.level, 1)
        self.assertFalse(UserCondition.objects.filter(user=user).exists())
        self.assertFalse(WaterLog.objects.filter(user=user).exists())
        self.assertFalse(MealLog.objects.filter(user=user).exists())

    def test_unknown_scenario_is_rejected(self):
        with self.assertRaises(CommandError):
            call_command("seed_integration_user", scenario="unknown", reset=True)
