from datetime import date

from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APITestCase

from test_utils.helpers import auth_client_for_user, create_user_with_profile


class AuthTests(APITestCase):
    def test_registration_success(self):
        payload = {
            "username": "newuser",
            "password": "Secret123!",
            "email": "newuser@example.com",
            "first_name": "New",
            "last_name": "User",
        }
        res = self.client.post("/api/auth/register/", payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        user = User.objects.get(username="newuser")
        self.assertTrue(user.check_password(payload["password"]))

    def test_registration_existing_email_fails(self):
        create_user_with_profile(username="user1", email="dup@example.com")
        res = self.client.post(
            "/api/auth/register/",
            {
                "username": "user2",
                "password": "Secret123!",
                "email": "dup@example.com",
                "first_name": "Dup",
                "last_name": "User",
            },
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_me_update_accepts_gender_and_stage_new_email_as_pending(self):
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

    def test_login_success_returns_tokens(self):
        user = create_user_with_profile(username="loginuser", password="Secret123!")
        res = self.client.post(
            "/api/auth/login/",
            {"username": user.username, "password": "Secret123!"},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("access", res.data)
        self.assertIn("refresh", res.data)

    def test_login_wrong_password_fails(self):
        user = create_user_with_profile(username="wrongpass", password="Secret123!")
        res = self.client.post(
            "/api/auth/login/",
            {"username": user.username, "password": "BadPass!"},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_me_returns_profile(self):
        user = create_user_with_profile(username="meuser")
        client = auth_client_for_user(user)
        res = client.get("/api/auth/me/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["username"], user.username)

    def test_me_update_profile(self):
        user = create_user_with_profile(username="upduser", weight=70, height=170)
        client = auth_client_for_user(user)
        # Serializer expects flat fields (UserUpdateSerializer) not nested; adjust accordingly.
        res = client.patch(
            "/api/auth/me/",
            {"weight": 80, "height": 180},
            format="json",
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        self.assertEqual(user.userprofile.weight, 80)
        self.assertEqual(user.userprofile.height, 180)

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
