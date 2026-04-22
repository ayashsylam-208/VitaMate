"""
Locust load test for VitaMate backend.

Run example (dashboard):
  set LOCUST_SCENARIO=dashboard
  locust -f loadtest/locustfile.py --host=http://127.0.0.1:8000 --users 20 --spawn-rate 5

Run example (history):
  set LOCUST_SCENARIO=history
  locust -f loadtest/locustfile.py --host=http://127.0.0.1:8000 --users 20 --spawn-rate 5

Metrics (avg, p95, failures) are available in Locust UI/CSV exports.
The script expects a seeded fixed user pool such as locust0..locust39.
"""

import os
import threading

from locust import HttpUser, between, task
from locust.exception import StopUser


class _UserPool:
    """Thread-safe sequential assignment of seeded test users."""

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
    SUPPORTED_SCENARIOS = {
        "dashboard": "/api/dashboard/",
        "history": "/api/history/",
    }

    def on_start(self):
        self.scenario = (os.getenv("LOCUST_SCENARIO", "dashboard") or "dashboard").strip().lower()
        if self.scenario not in self.SUPPORTED_SCENARIOS:
            raise StopUser(f"Unsupported LOCUST_SCENARIO '{self.scenario}'.")

        base = os.getenv("LOCUST_USERNAME_BASE", "locust")
        pool_size = int(os.getenv("LOCUST_USER_POOL", "40"))
        self.password = os.getenv("LOCUST_PASSWORD", "Pass123!")
        self.username = _UserPool.next_username(base, pool_size)

        res = self.client.post(
            "/api/auth/login/",
            json={"username": self.username, "password": self.password},
            name="/api/auth/login/",
        )
        if res.status_code != 200:
            raise StopUser(
                f"Login failed for '{self.username}'. Seed the performance dataset before running Locust."
            )

        payload = res.json()
        token = payload.get("access")
        if not token:
            raise StopUser(f"JWT access token missing for '{self.username}'.")

        self.client.headers.update({"Authorization": f"Bearer {token}"})
        profile_res = self.client.get("/api/auth/me/", name="/api/auth/me/")
        if profile_res.status_code != 200:
            raise StopUser(f"Profile load failed for '{self.username}'.")

    @task
    def read_primary_endpoint(self):
        endpoint = self.SUPPORTED_SCENARIOS[self.scenario]
        self.client.get(endpoint, name=endpoint)
