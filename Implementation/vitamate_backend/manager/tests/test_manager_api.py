import os
import shutil
import tempfile

from django.test import override_settings
from django.urls import reverse
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APIClient
from rest_framework.test import APITestCase

from manager.models import AccountDeletionRequest, HealthGoalOverride, PrivacyExportRequest
from test_utils.helpers import create_user_with_profile


class ManagerApiTests(APITestCase):
    def setUp(self):
        self.user = create_user_with_profile(
            username="manager-user",
            email="manager@example.com",
            weight=74,
            height=171,
        )
        self.client.force_authenticate(self.user)
        self.media_root = tempfile.mkdtemp()
        self.media_override = override_settings(
            MEDIA_ROOT=self.media_root,
            MEDIA_URL="/media/",
        )
        self.media_override.enable()
        self.addCleanup(self.media_override.disable)
        self.addCleanup(lambda: shutil.rmtree(self.media_root, ignore_errors=True))

    def test_overview_returns_manager_contract(self):
        response = self.client.get(reverse("manager-overview"))

        self.assertEqual(response.status_code, 200)
        data = response.data["data"]
        self.assertEqual(data["user"]["username"], self.user.username)
        self.assertIn("my_day", data)
        self.assertIn("motivation", data)
        self.assertEqual(len(data["quick_actions"]), 4)
        self.assertIn("medical", data)
        self.assertIn("privacy", data)

    def test_profile_name_patch_updates_manager_overview(self):
        update = self.client.patch(
            "/api/auth/me/",
            {"first_name": "Updated", "last_name": "Manager"},
            format="json",
        )
        self.assertEqual(update.status_code, 200)

        overview = self.client.get(reverse("manager-overview"))

        self.assertEqual(overview.status_code, 200)
        self.assertEqual(overview.data["data"]["user"]["first_name"], "Updated")
        self.assertEqual(overview.data["data"]["user"]["last_name"], "Manager")
        self.assertEqual(overview.data["data"]["user"]["full_name"], "Updated Manager")

    def test_avatar_upload_rejects_non_image(self):
        upload = SimpleUploadedFile(
            "avatar.txt",
            b"not an image",
            content_type="text/plain",
        )

        response = self.client.post(
            reverse("manager-avatar"),
            {"avatar": upload},
            format="multipart",
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("avatar", response.data)

    def test_avatar_upload_and_delete_updates_profile(self):
        upload = SimpleUploadedFile(
            "avatar.png",
            b"\x89PNG\r\n\x1a\n" + b"0" * 64,
            content_type="image/png",
        )

        response = self.client.post(
            reverse("manager-avatar"),
            {"avatar": upload},
            format="multipart",
        )

        self.assertEqual(response.status_code, 200)
        avatar_url = response.data["data"]["avatar_url"]
        self.assertTrue(avatar_url.startswith("/media/avatars/user_"))
        self.user.userprofile.refresh_from_db()
        self.assertEqual(self.user.userprofile.avatar_url, avatar_url)
        stored_path = os.path.join(self.media_root, avatar_url.replace("/media/", ""))
        self.assertTrue(os.path.exists(stored_path))

        delete_response = self.client.delete(reverse("manager-avatar"))

        self.assertEqual(delete_response.status_code, 200)
        self.user.userprofile.refresh_from_db()
        self.assertEqual(self.user.userprofile.avatar_url, "")
        self.assertFalse(os.path.exists(stored_path))

    def test_change_password_validates_and_updates_credentials(self):
        self.user.set_password("OldPass123!")
        self.user.save(update_fields=["password"])

        wrong_current = self.client.post(
            reverse("manager-change-password"),
            {
                "current_password": "WrongPass123!",
                "new_password": "NewPass123!",
                "new_password_confirm": "NewPass123!",
            },
            format="json",
        )
        self.assertEqual(wrong_current.status_code, 400)
        self.assertIn("current_password", wrong_current.data)

        mismatch = self.client.post(
            reverse("manager-change-password"),
            {
                "current_password": "OldPass123!",
                "new_password": "NewPass123!",
                "new_password_confirm": "Different123!",
            },
            format="json",
        )
        self.assertEqual(mismatch.status_code, 400)
        self.assertIn("new_password_confirm", mismatch.data)

        weak = self.client.post(
            reverse("manager-change-password"),
            {
                "current_password": "OldPass123!",
                "new_password": "123",
                "new_password_confirm": "123",
            },
            format="json",
        )
        self.assertEqual(weak.status_code, 400)

        response = self.client.post(
            reverse("manager-change-password"),
            {
                "current_password": "OldPass123!",
                "new_password": "NewStrongPass123!",
                "new_password_confirm": "NewStrongPass123!",
            },
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertFalse(self.user.check_password("OldPass123!"))
        self.assertTrue(self.user.check_password("NewStrongPass123!"))

        login_client = APIClient()
        old_login = login_client.post(
            reverse("token_obtain_pair"),
            {"username": self.user.username, "password": "OldPass123!"},
            format="json",
        )
        self.assertEqual(old_login.status_code, 401)
        new_login = login_client.post(
            reverse("token_obtain_pair"),
            {"username": self.user.username, "password": "NewStrongPass123!"},
            format="json",
        )
        self.assertEqual(new_login.status_code, 200)

    def test_goals_support_custom_override_and_reset(self):
        response = self.client.get(reverse("manager-goals"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data["data"]["goals"]), 7)

        patch = self.client.patch(
            reverse("manager-goal-detail", kwargs={"key": "steps"}),
            {"custom_value": 9000},
            format="json",
        )
        self.assertEqual(patch.status_code, 200)
        self.assertEqual(patch.data["data"]["goal"]["custom_value"], 9000.0)
        self.assertEqual(
            HealthGoalOverride.objects.get(user=self.user, key="steps").custom_value,
            9000,
        )

        reset = self.client.post(reverse("manager-goals-reset"))
        self.assertEqual(reset.status_code, 200)
        self.assertFalse(HealthGoalOverride.objects.filter(user=self.user).exists())

    def test_privacy_export_and_deletion_requests(self):
        export_response = self.client.post(reverse("manager-privacy-export"))
        self.assertEqual(export_response.status_code, 200)
        self.assertEqual(PrivacyExportRequest.objects.filter(user=self.user).count(), 1)

        deletion_response = self.client.post(
            reverse("manager-account-deletion"),
            {"reason": "testing"},
            format="json",
        )
        self.assertEqual(deletion_response.status_code, 200)
        self.assertTrue(
            AccountDeletionRequest.objects.filter(
                user=self.user,
                status=AccountDeletionRequest.STATUS_REQUESTED,
            ).exists()
        )

        cancel_response = self.client.delete(reverse("manager-account-deletion"))
        self.assertEqual(cancel_response.status_code, 200)
        self.assertFalse(
            AccountDeletionRequest.objects.filter(
                user=self.user,
                status=AccountDeletionRequest.STATUS_REQUESTED,
            ).exists()
        )
