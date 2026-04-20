from datetime import timedelta

from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from core.models import SleepLog
from test_utils.helpers import auth_client_for_user, create_user_with_profile


class SleepTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="sleepuser")
        self.client_auth = auth_client_for_user(self.user)

    def test_sleep_duration_computed_and_read_only(self):
        start = timezone.now() - timedelta(hours=8)
        end = timezone.now()
        res = self.client_auth.post(
            "/api/sleep/",
            {
                "start_time": start.isoformat(),
                "end_time": end.isoformat(),
                "quality": "Deep",
                "duration_hours": 0,  # should be ignored
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertIn("duration_hours", res.data)
        self.assertAlmostEqual(float(res.data["duration_hours"]), 8.0, delta=0.2)

        log = SleepLog.objects.get(user=self.user)
        self.assertAlmostEqual(log.duration_hours, 8.0, delta=0.2)
        self.assertNotEqual(float(res.data["duration_hours"]), 0)
