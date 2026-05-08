from rest_framework import status
from rest_framework.test import APITestCase

from core.models import ActivityLog
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

    def test_live_session_lifecycle_supports_pause_edit_resume_and_partial_finish(self):
        start = self.client_auth.post(
            "/api/activity/sessions/",
            {
                "exercise": self.exercise.id,
                "target_duration_seconds": 1800,
                "intensity": "moderate",
                "source": "live",
            },
            format="json",
        )
        self.assertEqual(start.status_code, status.HTTP_201_CREATED)
        self.assertEqual(start.data["status"], "running")
        self.assertGreater(start.data["estimated_calories"], 0)
        session_id = start.data["id"]

        active = self.client_auth.get("/api/activity/sessions/active/")
        self.assertEqual(active.status_code, status.HTTP_200_OK)
        self.assertEqual(active.data["id"], session_id)

        pause = self.client_auth.patch(
            f"/api/activity/sessions/{session_id}/pause/",
            {},
            format="json",
        )
        self.assertEqual(pause.status_code, status.HTTP_200_OK)
        self.assertEqual(pause.data["status"], "paused")

        edit = self.client_auth.patch(
            f"/api/activity/sessions/{session_id}/edit/",
            {"target_duration_seconds": 2400, "intensity": "intense"},
            format="json",
        )
        self.assertEqual(edit.status_code, status.HTTP_200_OK)
        self.assertEqual(edit.data["target_duration_seconds"], 2400)
        self.assertEqual(edit.data["intensity"], "intense")

        resume = self.client_auth.patch(
            f"/api/activity/sessions/{session_id}/resume/",
            {},
            format="json",
        )
        self.assertEqual(resume.status_code, status.HTTP_200_OK)
        self.assertEqual(resume.data["status"], "running")

        finish = self.client_auth.post(
            f"/api/activity/sessions/{session_id}/finish/",
            {"save_partial": True},
            format="json",
        )
        self.assertEqual(finish.status_code, status.HTTP_200_OK)
        self.assertEqual(finish.data["status"], "completed")
        self.assertEqual(ActivityLog.objects.filter(user=self.user).count(), 1)

        active_after = self.client_auth.get("/api/activity/sessions/active/")
        self.assertEqual(active_after.status_code, status.HTTP_200_OK)
        self.assertIsNone(active_after.data)

    def test_live_session_can_be_cancelled_without_creating_activity_log(self):
        start = self.client_auth.post(
            "/api/activity/sessions/",
            {
                "exercise": self.exercise.id,
                "target_duration_seconds": 1500,
                "intensity": "light",
                "source": "live",
            },
            format="json",
        )
        session_id = start.data["id"]

        cancel = self.client_auth.post(
            f"/api/activity/sessions/{session_id}/cancel/",
            {},
            format="json",
        )
        self.assertEqual(cancel.status_code, status.HTTP_200_OK)
        self.assertEqual(cancel.data["status"], "cancelled")
        self.assertEqual(ActivityLog.objects.filter(user=self.user).count(), 0)

    def test_live_session_requires_partial_flag_when_finishing_early(self):
        start = self.client_auth.post(
            "/api/activity/sessions/",
            {
                "exercise": self.exercise.id,
                "target_duration_seconds": 1800,
                "intensity": "moderate",
                "source": "live",
            },
            format="json",
        )

        finish = self.client_auth.post(
            f"/api/activity/sessions/{start.data['id']}/finish/",
            {"save_partial": False},
            format="json",
        )
        self.assertEqual(finish.status_code, status.HTTP_400_BAD_REQUEST)
