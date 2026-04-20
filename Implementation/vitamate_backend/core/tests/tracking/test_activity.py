from rest_framework import status
from rest_framework.test import APITestCase

from test_utils.helpers import auth_client_for_user, create_exercise, create_user_with_profile


class ActivityTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(username="activityuser", weight=70)
        self.client_auth = auth_client_for_user(self.user)
        self.exercise = create_exercise(name="Run", met_value=8.0)

    def test_activity_calories_computed_from_met(self):
        res = self.client_auth.post(
            "/api/activities/",
            {"exercise": self.exercise.id, "duration_minutes": 30},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertIn("calories_burned", res.data)
        # Expected: (MET * 3.5 * weight / 200) * minutes = (8*3.5*70/200)*30 = 294
        self.assertAlmostEqual(int(res.data["calories_burned"]), 294, delta=2)
