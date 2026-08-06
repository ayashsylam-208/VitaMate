from django.test import TestCase

from core.models import WaterLog
from gamification.models import PointsTransaction, UserScore
from gamification.services.reconciliation_service import ReconciliationService
from test_utils.helpers import create_user_with_profile


class ReconciliationServiceTests(TestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="reconcile_user")

    def test_reconciliation_fixes_stale_water_points_and_is_idempotent(self):
        from core.services.water_service import WaterService

        log = WaterService.log_water(self.user, amount_liter=0.5)
        score = UserScore.objects.get(user=self.user)
        self.assertEqual(score.total_points, 3)

        WaterLog.objects.filter(id=log.id).delete()
        score.refresh_from_db()
        self.assertEqual(score.total_points, 3)

        result = ReconciliationService.reconcile_user_day(
            user=self.user,
            target_date=log.date,
        )
        score.refresh_from_db()
        self.assertEqual(score.total_points, 0)
        self.assertGreaterEqual(result["transactions_created"], 1)
        self.assertEqual(
            PointsTransaction.objects.filter(
                user=self.user,
                source_type=PointsTransaction.SOURCE_HYDRATION,
                rule_code="WATER_LOGGED",
            ).count(),
            2,
        )

        tx_count = PointsTransaction.objects.filter(user=self.user).count()
        ReconciliationService.reconcile_user_day(user=self.user, target_date=log.date)
        self.assertEqual(PointsTransaction.objects.filter(user=self.user).count(), tx_count)
