# Performance Baseline Notes

This file captures the pre-optimization baseline for:

- `GET /api/dashboard/`
- `GET /api/history/`

## Environment

- Date: `2026-04-22`
- Backend host: `http://127.0.0.1:8000`
- Database: `Postgres` via default backend development settings
- Dataset profile: `representative`
- Seed command:
  - `python manage.py seed_performance_dataset --profile representative --reset`
- Locust scenario mode:
  - `LOCUST_SCENARIO=dashboard`
  - `LOCUST_SCENARIO=history`
- User pool: `locust0` .. `locust39`

## Official Commands

From `Implementation/vitamate_backend`:

```powershell
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py seed_performance_dataset --profile representative --reset
.\.venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

Dashboard run:

```powershell
$env:LOCUST_SCENARIO="dashboard"
locust -f loadtest/locustfile.py --host=http://127.0.0.1:8000 --users 20 --spawn-rate 5 --run-time 2m --headless --csv=..\\docs\\performance\\before\\dashboard --only-summary
```

History run:

```powershell
$env:LOCUST_SCENARIO="history"
locust -f loadtest/locustfile.py --host=http://127.0.0.1:8000 --users 20 --spawn-rate 5 --run-time 2m --headless --csv=..\\docs\\performance\\before\\history --only-summary
```

## Baseline Table

| Endpoint | Users | Spawn rate | Run time | Avg ms | P95 ms | Max ms | RPS | Failures |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `/api/dashboard/` | 20 | 5 | 2m | 355.85 | 720 | 1203.86 | 8.40 | 0 |
| `/api/history/` | 20 | 5 | 2m | 5261.65 | 6400 | 6876.79 | 2.68 | 0 |

## Initial Bottleneck Notes

- Dashboard: stable under the baseline profile, but still slower than desirable for a primary home-screen read. The current baseline sits at 355.85 ms average and 720 ms at P95.
- History: dominant bottleneck in the current baseline. Average latency is about 5.26s with P95 at 6.4s, which is far above dashboard latency under the same load profile.
- Does fallback appear dominant: likely yes for `history`, based on the large gap between `dashboard` and `history` under the same seed dataset. This is an inference from the measurements, not yet query-count proof.
- Any failures or instability: none in the successful baseline runs. The only earlier failure was harness-related because the seeded user pool was smaller than the Locust pool; that mismatch was corrected by reseeding the full 40-user pool before the official runs.

## Artifact Paths

- `docs/performance/before/dashboard_stats.csv`
- `docs/performance/before/dashboard_failures.csv`
- `docs/performance/before/dashboard_exceptions.csv`
- `docs/performance/before/history_stats.csv`
- `docs/performance/before/history_failures.csv`
- `docs/performance/before/history_exceptions.csv`
