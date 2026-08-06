from django.test import TestCase

from core.services.steps_service import StepsService
from gamification.models import DailyStepPointsAward, MotivationExperienceEvent, PointsTransaction, UserScore
from gamification.services.points_service import PointsService
from test_utils.helpers import create_user_with_profile


class PointsServiceTests(TestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="pointsuser", weight=70)

    def test_award_points_and_level_progression(self):
        PointsService.add_points(self.user, 1200)
        score = UserScore.objects.get(user=self.user)
        self.assertEqual(score.total_points, 1200)
        self.assertEqual(score.level, 2)

    def test_deduct_points_ignored_for_non_allowed_source(self):
        PointsService.add_points(self.user, 10)
        PointsService.deduct_points(self.user, 50)
        score = UserScore.objects.get(user=self.user)
        self.assertEqual(score.total_points, 10)

    def test_negative_points_allowed_for_medication_source(self):
        PointsService.add_points(self.user, 10)
        PointsService.apply_delta(
            self.user,
            points=-5,
            source_type=PointsTransaction.SOURCE_MEDICATION,
            source_id="dose:1",
            rule_code="MEDICATION_MISSED",
        )
        score = UserScore.objects.get(user=self.user)
        self.assertEqual(score.total_points, 5)

    def test_multiple_transactions_keep_userscore_equal_to_ledger(self):
        PointsService.apply_delta(
            self.user,
            points=7,
            source_type=PointsTransaction.SOURCE_SYSTEM,
            source_id="custom:1",
            rule_code="CUSTOM_A",
            idempotency_key="custom-a",
        )
        PointsService.apply_delta(
            self.user,
            points=11,
            source_type=PointsTransaction.SOURCE_SYSTEM,
            source_id="custom:2",
            rule_code="CUSTOM_B",
            idempotency_key="custom-b",
        )
        PointsService.apply_delta(
            self.user,
            points=-3,
            source_type=PointsTransaction.SOURCE_MEDICATION,
            source_id="dose:3",
            rule_code="MEDICATION_ADJUSTMENT",
            idempotency_key="custom-c",
        )

        score = UserScore.objects.get(user=self.user)
        ledger_total = sum(
            int(item.points or 0)
            for item in PointsTransaction.objects.filter(user=self.user)
        )
        self.assertEqual(score.total_points, ledger_total)

        rebuilt = UserScore.rebuild_for_user(user=self.user)
        self.assertEqual(rebuilt.total_points, ledger_total)

    def test_idempotency_prevents_duplicate_transaction(self):
        PointsService.award_rule(
            self.user,
            rule_code="WATER_GOAL_COMPLETED",
            source_type=PointsTransaction.SOURCE_HYDRATION,
            source_id="daily_goal",
            event_date=None,
            idempotency_key="test-key-1",
        )
        PointsService.award_rule(
            self.user,
            rule_code="WATER_GOAL_COMPLETED",
            source_type=PointsTransaction.SOURCE_HYDRATION,
            source_id="daily_goal",
            event_date=None,
            idempotency_key="test-key-1",
        )
        self.assertEqual(PointsTransaction.objects.filter(idempotency_key="test-key-1").count(), 1)

    def test_positive_tracker_points_create_experience_event_and_level_up(self):
        PointsService.award_rule(
            self.user,
            rule_code="MEAL_LOGGED",
            source_type=PointsTransaction.SOURCE_NUTRITION,
            source_id="meal:1",
            idempotency_key="meal-event-1",
        )
        PointsService.add_points(
            self.user,
            995,
            source_type=PointsTransaction.SOURCE_SYSTEM,
            source_id="bootstrap",
        )
        PointsService.award_rule(
            self.user,
            rule_code="WATER_LOGGED",
            source_type=PointsTransaction.SOURCE_HYDRATION,
            source_id="water:1",
            idempotency_key="water-event-1",
        )

        self.assertTrue(
            MotivationExperienceEvent.objects.filter(
                user=self.user,
                event_type=MotivationExperienceEvent.TYPE_POINTS_AWARDED,
                route="/meals",
            ).exists()
        )
        self.assertTrue(
            MotivationExperienceEvent.objects.filter(
                user=self.user,
                event_type=MotivationExperienceEvent.TYPE_LEVEL_UP,
            ).exists()
        )

    def test_step_points_depend_on_final_total_not_upload_pattern(self):
        user_once = create_user_with_profile(username="steps_once")
        user_gradual = create_user_with_profile(username="steps_gradual")
        for user in (user_once, user_gradual):
            user.userprofile.daily_step_goal = 10000
            user.userprofile.save(update_fields=["daily_step_goal"])

        StepsService.log_steps(user=user_once, steps_count=10000, distance_km=0)
        for total in (1000, 3000, 5000, 8000, 10000, 10000):
            StepsService.log_steps(user=user_gradual, steps_count=total, distance_km=0)

        once_points = sum(
            int(item.points or 0)
            for item in PointsTransaction.objects.filter(
                user=user_once,
                source_type=PointsTransaction.SOURCE_STEPS,
            )
        )
        gradual_points = sum(
            int(item.points or 0)
            for item in PointsTransaction.objects.filter(
                user=user_gradual,
                source_type=PointsTransaction.SOURCE_STEPS,
            )
        )

        self.assertEqual(once_points, 25)
        self.assertEqual(gradual_points, 25)
        self.assertEqual(once_points, gradual_points)

        award_once = DailyStepPointsAward.objects.get(user=user_once)
        award_gradual = DailyStepPointsAward.objects.get(user=user_gradual)
        self.assertEqual(award_once.points_awarded, 15)
        self.assertTrue(award_once.goal_bonus_awarded)
        self.assertEqual(award_gradual.points_awarded, 15)
        self.assertTrue(award_gradual.goal_bonus_awarded)
