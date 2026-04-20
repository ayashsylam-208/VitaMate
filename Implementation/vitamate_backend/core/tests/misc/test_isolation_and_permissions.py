from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APITestCase

from test_utils.helpers import auth_client_for_user, create_user_with_profile


class PermissionsTests(APITestCase):
    protected_endpoints = [
        "/api/meals/",
        "/api/water/",
        "/api/steps/",
        "/api/sleep/",
        "/api/activities/",
        "/api/dashboard/",
        "/api/history/",
        "/api/condition-types/",
        "/api/user-conditions/",
        "/api/condition-medications/",
        "/api/condition-medication-schedules/",
        "/api/health-indicators/",
    ]

    def test_protected_endpoints_require_auth(self):
        for path in self.protected_endpoints:
            res = self.client.get(path)
            self.assertIn(
                res.status_code,
                (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN),
                msg=f"Path {path} should be protected",
            )

    def test_cross_user_isolation_for_water_logs(self):
        user_a = create_user_with_profile(username="userA")
        user_b = create_user_with_profile(username="userB")

        client_a = auth_client_for_user(user_a)
        client_b = auth_client_for_user(user_b)

        res_a = client_a.post("/api/water/", {"amount_liter": 1.0}, format="json")
        self.assertEqual(res_a.status_code, status.HTTP_201_CREATED)

        res_b = client_b.get("/api/water/")
        self.assertEqual(res_b.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res_b.data), 0, "User B should not see User A water logs")

    def test_cross_user_isolation_for_chronic_conditions(self):
        user_a = create_user_with_profile(username="conditionUserA")
        user_b = create_user_with_profile(username="conditionUserB")

        client_a = auth_client_for_user(user_a)
        client_b = auth_client_for_user(user_b)

        condition_type_res = client_a.get("/api/condition-types/")
        self.assertEqual(condition_type_res.status_code, status.HTTP_200_OK)
        diabetes_id = next(
            item["id"] for item in condition_type_res.data if item["code"] == "diabetes"
        )

        create_res = client_a.post(
            "/api/user-conditions/",
            {
                "condition_type": diabetes_id,
                "status": "active",
                "severity_code": "diabetes_managed",
            },
            format="json",
        )
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)

        res_b = client_b.get("/api/user-conditions/")
        self.assertEqual(res_b.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res_b.data), 0, "User B should not see User A conditions")
