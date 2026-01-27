from rest_framework import status
from rest_framework.test import APITestCase

from core.models import StepLog
from test_utils.helpers import auth_client_for_user, create_user_with_profile


class StepsTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="stepsuser", height=175, weight=70)
        self.client_auth = auth_client_for_user(self.user)

    def test_upsert_same_day_single_record(self):
        r1 = self.client_auth.post("/api/steps/", {"steps_count": 1000, "distance_km": 1.0}, format="json")
        self.assertIn(r1.status_code, (status.HTTP_200_OK, status.HTTP_201_CREATED))
        r2 = self.client_auth.post("/api/steps/", {"steps_count": 2000, "distance_km": 1.5}, format="json")
        self.assertIn(r2.status_code, (status.HTTP_200_OK, status.HTTP_201_CREATED))

        qs = StepLog.objects.filter(user=self.user)
        self.assertEqual(qs.count(), 1)
        self.assertEqual(qs.first().steps_count, 2000)

    def test_unique_per_user_date(self):
        other = create_user_with_profile(username="other", height=180, weight=75)
        client_other = auth_client_for_user(other)

        self.client_auth.post("/api/steps/", {"steps_count": 500, "distance_km": 0.4}, format="json")
        client_other.post("/api/steps/", {"steps_count": 800, "distance_km": 0.6}, format="json")

        self.assertEqual(StepLog.objects.filter(user=self.user).count(), 1)
        self.assertEqual(StepLog.objects.filter(user=other).count(), 1)

    def test_distance_autocalculated_when_missing(self):
        res = self.client_auth.post("/api/steps/", {"steps_count": 2000}, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertIn("distance_km", res.data)
        self.assertGreater(float(res.data["distance_km"]), 0)
