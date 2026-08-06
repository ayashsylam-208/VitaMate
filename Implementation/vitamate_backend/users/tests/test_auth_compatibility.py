from datetime import date

from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from test_utils.helpers import auth_client_for_user, create_user_with_profile


class AuthCompatibilityTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.register_url = "/api/auth/register/"
        self.login_url = "/api/auth/login/"

    def test_register_creates_hashed_password(self):
        payload = {
            "username": "testuser",
            "password": "Secret123!",
            "email": "test@example.com",
            "first_name": "Test",
            "last_name": "User",
        }

        res = self.client.post(self.register_url, payload, format="json")

        self.assertEqual(res.status_code, 201)
        user = User.objects.get(username=payload["username"])
        self.assertNotEqual(user.password, payload["password"])
        self.assertTrue(user.check_password(payload["password"]))

    def test_register_rejects_duplicate_email_case_insensitive(self):
        create_user_with_profile(username="firstuser", email="dup@example.com")

        res = self.client.post(
            self.register_url,
            {
                "username": "seconduser",
                "password": "Secret123!",
                "email": " DUP@example.com ",
                "first_name": "Second",
                "last_name": "User",
            },
            format="json",
        )

        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_login_returns_tokens(self):
        User.objects.create_user(
            username="loginuser",
            password="Secret123!",
            email="login@example.com",
        )

        res = self.client.post(
            self.login_url,
            {"username": "loginuser", "password": "Secret123!"},
            format="json",
        )

        self.assertEqual(res.status_code, 200)
        self.assertIn("access", res.data)
        self.assertIn("refresh", res.data)

    def test_me_update_profile_accepts_age(self):
        user = create_user_with_profile(username="ageuser", weight=70, height=170)
        client = auth_client_for_user(user)
        target_age = 25
        res = client.patch(
            "/api/auth/me/",
            {"age": target_age, "weight": 75},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        self.assertEqual(user.userprofile.weight, 75)
        self.assertEqual(user.userprofile.birth_date.year, date.today().year - target_age)

    def test_me_update_profile_accepts_birth_date(self):
        user = create_user_with_profile(username="birthdateuser", weight=70, height=170)
        client = auth_client_for_user(user)
        res = client.patch(
            "/api/auth/me/",
            {"birth_date": "1999-08-21"},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        self.assertEqual(str(user.userprofile.birth_date), "1999-08-21")

    def test_me_update_accepts_manual_daily_water_target(self):
        user = create_user_with_profile(username="manualwater", weight=70, height=170)
        client = auth_client_for_user(user)

        res = client.patch(
            "/api/auth/me/",
            {"daily_water_target": 3.1},
            format="json",
        )

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        user.userprofile.refresh_from_db()
        self.assertEqual(user.userprofile.daily_water_target, 3.1)
        self.assertEqual(user.userprofile.manual_daily_water_target, 3.1)

    def test_me_update_accepts_gender_and_stages_email_verification(self):
        user = create_user_with_profile(username="genderemail", email="old@example.com")
        client = auth_client_for_user(user)

        res = client.patch(
            "/api/auth/me/",
            {"gender": "O", "email": "  NEW@example.COM  "},
            format="json",
        )

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        user.userprofile.refresh_from_db()
        self.assertEqual(user.email, "old@example.com")
        self.assertEqual(user.userprofile.gender, "O")
        self.assertTrue(user.userprofile.gender_confirmed)
        self.assertEqual(user.userprofile.pending_email, "new@example.com")
        self.assertFalse(user.userprofile.email_verified)
