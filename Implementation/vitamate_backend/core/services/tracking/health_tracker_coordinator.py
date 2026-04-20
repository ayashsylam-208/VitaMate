from __future__ import annotations

from datetime import date, timedelta

from core.services.orchestration.health_state_projection_service import (
    HealthStateProjectionService,
)
from core.services.orchestration.health_state_read_service import HealthStateReadService


class HealthTrackerCoordinator:
    """
    Read-side facade for dashboard/history payloads.

    Materialized unified health state is the primary source. When a snapshot is
    missing, the coordinator falls back to a read-only projection without
    triggering sync, constraint recompute, or notification side effects.
    """

    def __init__(
        self,
        *,
        state_reader: HealthStateReadService | None = None,
        projection_service: HealthStateProjectionService | None = None,
    ):
        self._state_reader = state_reader or HealthStateReadService()
        self._projection_service = projection_service or HealthStateProjectionService()
        self._latest_snapshots = []

    @property
    def latest_snapshots(self):
        return tuple(self._latest_snapshots)

    def build_dashboard(self, *, user, today: date | None = None) -> dict | None:
        today = today or date.today()
        state = self._state_reader.get_current_state(user=user, state_date=today)
        if state is not None:
            self._latest_snapshots = list(state.tracker_snapshots or [])
            return self._dashboard_payload(
                progress_summary=state.progress_summary,
                active_constraints=state.active_constraints,
                warnings=state.warnings,
                state_version=state.version,
                last_computed_at=state.last_computed_at,
                impacted_trackers=state.affected_trackers,
            )

        fallback = self._projection_service.build_projection(
            user=user,
            state_date=today,
            window_kind="current",
            trigger_metadata={"source": "dashboard_read_fallback"},
        )
        if fallback is None:
            return None

        self._latest_snapshots = list(fallback.get("tracker_snapshots") or [])
        return self._dashboard_payload(
            progress_summary=fallback.get("progress_summary"),
            active_constraints=fallback.get("active_constraints"),
            warnings=fallback.get("warnings"),
            state_version=None,
            last_computed_at=None,
            impacted_trackers=fallback.get("affected_trackers"),
        )

    def build_history(self, *, user, today: date | None = None, days: int = 7) -> list[dict] | None:
        today = today or date.today()
        start = today - timedelta(days=max(days - 1, 0))
        state_by_date = {
            item.state_date: item
            for item in self._state_reader.list_daily_states(
                user=user,
                start_date=start,
                end_date=today,
            )
        }

        history = []
        for offset in range(days):
            state_date = start + timedelta(days=offset)
            state = state_by_date.get(state_date)
            if state is not None:
                entry = dict(state.progress_summary.get("history_entry") or {})
                if entry:
                    history.append(entry)
                    continue

            fallback = self._projection_service.build_projection(
                user=user,
                state_date=state_date,
                window_kind="daily",
                trigger_metadata={"source": "history_read_fallback"},
            )
            if fallback is None:
                return None
            history.append(dict(fallback.get("progress_summary", {}).get("history_entry") or {}))

        return history

    @staticmethod
    def _dashboard_payload(
        *,
        progress_summary: dict | None,
        active_constraints: dict | None,
        warnings: list[dict] | None,
        state_version,
        last_computed_at,
        impacted_trackers,
    ) -> dict:
        progress_summary = dict(progress_summary or {})
        payload = {
            "summary": dict(progress_summary.get("summary") or {}),
            "hydration": dict(progress_summary.get("hydration") or {}),
            "sleep": dict(progress_summary.get("sleep") or {}),
            "activity": dict(progress_summary.get("activity") or {}),
            "gamification": dict(progress_summary.get("gamification") or {}),
            "chronic_conditions": dict(progress_summary.get("chronic_conditions") or {}),
            "medications": dict(progress_summary.get("medications") or {}),
            "active_constraints": dict(active_constraints or {}),
        }

        if warnings:
            payload["active_warnings"] = list(warnings)
        elif progress_summary.get("active_warnings"):
            payload["active_warnings"] = list(progress_summary.get("active_warnings") or [])
        if impacted_trackers:
            payload["impacted_trackers"] = list(impacted_trackers)
        elif progress_summary.get("impacted_trackers"):
            payload["impacted_trackers"] = list(progress_summary.get("impacted_trackers") or [])
        if state_version is not None:
            payload["state_version"] = int(state_version)
        if last_computed_at is not None:
            payload["last_computed_at"] = last_computed_at.isoformat()
        return payload
