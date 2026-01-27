from django.test import TestCase

from gamification.models import UserScore
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

    def test_deduct_points_not_below_zero(self):
        PointsService.add_points(self.user, 10)
        PointsService.deduct_points(self.user, 50)
        score = UserScore.objects.get(user=self.user)
        self.assertEqual(score.total_points, 0)

    def test_meal_penalty_when_over_target(self):
        # target calorie default from profile.calculate_metrics
        PointsService.apply_meal_points(self.user, calories_in=5000, target=2000)
        score = UserScore.objects.get(user=self.user)
        self.assertLessEqual(score.total_points, 0)
