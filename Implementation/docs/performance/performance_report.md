# Performance Report

## Summary

- Optimization target:
  - `GET /api/dashboard/`
  - `GET /api/history/`
- Dataset profile: `representative`
- Evidence mode: `CSV + Notes`

## Before vs After

| Endpoint | Metric | Before | After | Delta |
| --- | --- | --- | --- | --- |
| `/api/dashboard/` | Avg ms | 355.85 | 142.82 | -213.03 ms |
| `/api/dashboard/` | P95 ms | 720 | 240 | -480 ms |
| `/api/dashboard/` | RPS | 8.40 | 9.12 | +0.72 |
| `/api/dashboard/` | Failures | 0 | 0 | 0 |
| `/api/history/` | Avg ms | 5261.65 | 817.39 | -4444.26 ms |
| `/api/history/` | P95 ms | 6400 | 1500 | -4900 ms |
| `/api/history/` | RPS | 2.68 | 7.02 | +4.34 |
| `/api/history/` | Failures | 0 | 0 | 0 |

## Bottlenecks

- Fallback path cost: confirmed main bottleneck for `history`. The old path built a full projection for each day and then used only `history_entry`.
- Constraint reuse cost: dashboard/history were repeatedly loading active constraints and recomputing effective numeric targets within the same request path.
- Medication summary query cost: day counts were computed through repeated queryset `.count()` calls and condition dose counts rebuilt the same daily plan twice.
- Activity/profile read amplification: `history` fallback rebuilt warnings, targets, snapshots, and dashboard-only structures that were never returned by `/api/history/`.

## Changes Applied

- Added a lightweight `build_history_entry()` path in the projection service so `history` fallback now computes only the fields returned by `/api/history/`.
- Reused an active-constraint bundle inside the projection request path instead of querying active constraints separately for each numeric target.
- Added shared condition context preparation so active conditions, rule profiles, and target maps are prepared once and reused across daily history entries.
- Reworked medication day counting to use a single pass over daily logs instead of multiple filtered `.count()` queries.
- Replaced duplicate medication dose-list rebuilds with a shared `today_dose_counts()` path.
- Removed N+1-style reads in condition adherence/target resolution by batching daily evaluations and condition rule profile loading.

## Interpretation

- What improved: both endpoints improved, but `history` improved the most. Average latency dropped from 5261.65 ms to 817.39 ms, and throughput rose from 2.68 RPS to 7.02 RPS.
- Why it improved: the main gain came from stopping full daily projection builds for history fallback and reducing repeated queries for constraints, conditions, and medication summary calculations.
- Remaining limits: `history` is still slower than `dashboard`, which suggests there is still value in query-count instrumentation and deeper optimization around daily log aggregation and snapshot coverage.

## Artifacts

- `docs/performance/before/`
- `docs/performance/after/`
- `docs/performance/baseline_notes.md`
- `docs/performance/before/dashboard_stats.csv`
- `docs/performance/before/history_stats.csv`
- `docs/performance/after/dashboard_stats.csv`
- `docs/performance/after/history_stats.csv`
