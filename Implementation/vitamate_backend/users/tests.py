from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient


class AuthTests(TestCase):
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
