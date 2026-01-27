"""
Locust load test for VitaMate backend.
Run example (20 users):
  locust -f loadtest/locustfile.py --host=http://127.0.0.1:8000 --users 20 --spawn-rate 5

Metrics (avg, p95, failures) are available in Locust UI/CSV exports.
The script reuses a small user pool to avoid infinite registrations.
"""

import os
import threading
from datetime import datetime, timedelta, timezone

from locust import HttpUser, between, task


class _UserPool:
    """
    Thread-safe sequential assignment of test users to virtual users.
    """

    _lock = threading.Lock()
    _counter = 0

    @classmethod
    def next_username(cls, base: str, pool_size: int) -> str:
        with cls._lock:
            username = f"{base}{cls._counter % pool_size}"
            cls._counter += 1
            return username


class VitaMateUser(HttpUser):
    wait_time = between(1, 3)

    def on_start(self):
        base = os.getenv("LOCUST_USERNAME_BASE", "locust")
        pool_size = int(os.getenv("LOCUST_USER_POOL", "40"))
        self.password = os.getenv("LOCUST_PASSWORD", "Pass123!")
        self.username = _UserPool.next_username(base, pool_size)

        # Register once per username (idempotent: ignore 400 if already exists).
        self.client.post(
            "/api/auth/register/",
            json={
                "username": self.username,
                "password": self.password,
                "email": f"{self.username}@example.com",
                "first_name": "Locust",
                "last_name": "User",
            },
            name="/api/auth/register/",
        )

        # Login to obtain JWT.
        res = self.client.post(
            "/api/auth/login/",
            json={"username": self.username, "password": self.password},
            name="/api/auth/login/",
        )
        if res.status_code == 200 and "access" in res.json():
            token = res.json()["access"]
            self.client.headers.update({"Authorization": f"Bearer {token}"})
            # Ensure profile exists for dashboard by calling /api/auth/me/
            self.client.get("/api/auth/me/", name="/api/auth/me/")

    @task(3)
    def dashboard(self):
        self.client.get("/api/dashboard/", name="/api/dashboard/")

    @task(2)
    def log_water(self):
        self.client.post("/api/water/", json={"amount_liter": 0.25}, name="/api/water/")

    @task(2)
    def log_steps(self):
        self.client.post(
            "/api/steps/",
            json={"steps_count": 1200, "distance_km": 0.9},
            name="/api/steps/",
        )

    @task(1)
    def log_sleep(self):
        end = datetime.now(timezone.utc)
        start = end - timedelta(hours=7)
        self.client.post(
            "/api/sleep/",
            json={
                "start_time": start.isoformat(),
                "end_time": end.isoformat(),
                "quality": "Deep",
            },
            name="/api/sleep/",
        )
