from __future__ import annotations

from datetime import date
import json
import logging
import time

from core.models import UnifiedHealthState
from core.repositories.health_state_repository import HealthStateRepository
from core.services.chronic.condition_integration_coordinator import ConditionIntegrationCoordinator
from core.services.constraints import ConstraintRecomputeDispatcher
from core.services.orchestration.health_state_projection_service import HealthStateProjectionService
from core.services.orchestration.notification_decision_service import NotificationDecisionService
from core.services.orchestration.notification_dispatcher import NotificationDispatcher
from core.services.orchestration.tracker_dependency_map import TrackerDependencyMap


logger = logging.getLogger("vitamate.performance")


class HealthStateOrchestrator:
    def __init__(
        self,
        *,
        projection_service: HealthStateProjectionService | None = None,
        condition_integration: ConditionIntegrationCoordinator | None = None,
        notification_decision_service: NotificationDecisionService | None = None,
        notification_dispatcher: NotificationDispatcher | None = None,
    ):
        self._projection_service = projection_service or HealthStateProjectionService()
        self._condition_integration = condition_integration or ConditionIntegrationCoordinator()
        self._notification_decision_service = (
            notification_decision_service or NotificationDecisionService()
        )
        self._notification_dispatcher = notification_dispatcher or NotificationDispatcher()

    def handle_event(self, *, user, trigger_type: str, payload=None, synchronous: bool = True):
        started = time.perf_counter()
        payload = dict(payload or {})
        today = payload.get("today")
        if not isinstance(today, date):
            today = date.today()

        plan = self.recompute_impacted_domains(
            user=user,
            trigger_type=trigger_type,
            payload=payload,
            today=today,
        )
        run = HealthStateRepository.create_computation_run(
            user=user,
            trigger_type=trigger_type,
            trigger_reference=str(payload.get("trigger_reference") or ""),
            affected_domains=list(plan.affected_trackers),
            metadata={
                "event_dates": [str(item) for item in plan.event_dates],
                "reason": plan.reason,
                "synchronous": synchronous,
            },
        )
        try:
            self._apply_impacted_domain_recomputes(
                user=user,
                trigger_type=trigger_type,
                payload=payload,
                plan=plan,
            )

            deltas = []
            if plan.recompute_daily:
                for state_date in plan.event_dates:
                    delta = self._rebuild_window(
                        user=user,
                        state_date=state_date,
                        window_kind=UnifiedHealthState.WINDOW_DAILY,
                        trigger_type=trigger_type,
                        payload=payload,
                        affected_trackers=plan.affected_trackers,
                        reason=plan.reason,
                        computation_run=run,
                    )
                    if delta is not None:
                        deltas.append(delta)

            if plan.recompute_current:
                delta = self._rebuild_window(
                    user=user,
                    state_date=today,
                    window_kind=UnifiedHealthState.WINDOW_CURRENT,
                    trigger_type=trigger_type,
                    payload=payload,
                    affected_trackers=plan.affected_trackers,
                    reason=plan.reason,
                    computation_run=run,
                )
                if delta is not None:
                    deltas.append(delta)

            HealthStateRepository.complete_computation_run(
                run,
                affected_domains=list(plan.affected_trackers),
            )
            duration_ms = round((time.perf_counter() - started) * 1000, 2)
            logger.info(
                json.dumps(
                    {
                        "event": "health_state_recompute",
                        "user_id": user.id,
                        "trigger_type": trigger_type,
                        "run_id": run.id,
                        "status": "completed",
                        "duration_ms": duration_ms,
                        "affected_domains": list(plan.affected_trackers),
                    }
                )
            )
            return {
                "run": run,
                "deltas": deltas,
            }
        except Exception as exc:
            HealthStateRepository.fail_computation_run(
                run,
                error_message=str(exc),
                affected_domains=list(plan.affected_trackers),
            )
            duration_ms = round((time.perf_counter() - started) * 1000, 2)
            logger.info(
                json.dumps(
                    {
                        "event": "health_state_recompute",
                        "user_id": user.id,
                        "trigger_type": trigger_type,
                        "run_id": run.id,
                        "status": "failed",
                        "duration_ms": duration_ms,
                        "affected_domains": list(plan.affected_trackers),
                        "error": str(exc),
                    }
                )
            )
            return {
                "run": run,
                "error": str(exc),
            }

    def recompute_impacted_domains(self, *, user, trigger_type: str, payload=None, today: date | None = None):
        del user  # reserved for future user-specific dependency logic
        return TrackerDependencyMap.build_plan(
            trigger_type=trigger_type,
            payload=payload,
            today=today or date.today(),
        )

    def build_state_delta(
        self,
        *,
        user,
        affected_domains,
        reason: str,
        trigger_type: str,
        trigger_reference: str,
        state_date: date,
        window_kind: str,
        previous_state=None,
        new_state=None,
    ) -> dict:
        del user
        previous_metrics = self._flatten_metrics(previous_state.progress_summary if previous_state else {})
        new_metrics = self._flatten_metrics(new_state.progress_summary if new_state else {})
        previous_warnings = self._warning_map(previous_state.warnings if previous_state else [])
        new_warnings = self._warning_map(new_state.warnings if new_state else [])

        warnings_added = [value for key, value in new_warnings.items() if key not in previous_warnings]
        warnings_resolved = [value for key, value in previous_warnings.items() if key not in new_warnings]
        achievements_added = self._achievements_added(
            before=previous_metrics,
            after=new_metrics,
        )

        delta_payload = {
            "state_date": state_date,
            "window_kind": window_kind,
            "trigger_type": trigger_type,
            "trigger_reference": trigger_reference,
            "reason": reason,
            "changed_trackers": list(affected_domains or []),
            "metrics_before": previous_metrics,
            "metrics_after": new_metrics,
            "warnings_added": warnings_added,
            "warnings_resolved": warnings_resolved,
            "achievements_added": achievements_added,
        }
        delta_payload["notification_candidates"] = self._notification_decision_service.decide(
            delta_payload=delta_payload,
        )
        return delta_payload

    def persist_state(self, *, user, state_block: dict, delta_block: dict | None = None):
        trigger_metadata = dict(state_block.get("trigger_metadata") or {})
        if delta_block is not None:
            trigger_metadata["delta_preview"] = {
                "changed_trackers": list(delta_block.get("changed_trackers") or []),
                "warning_count": len(delta_block.get("warnings_added") or []),
            }
        return HealthStateRepository.upsert_state(
            user=user,
            state_date=state_block["state_date"],
            window_kind=state_block["window_kind"],
            affected_trackers=state_block.get("affected_trackers") or [],
            tracker_snapshots=state_block.get("tracker_snapshots") or [],
            progress_summary=state_block.get("progress_summary") or {},
            active_targets=state_block.get("active_targets") or [],
            active_constraints=state_block.get("active_constraints") or {},
            warnings=state_block.get("warnings") or [],
            medication_summary=state_block.get("medication_summary") or {},
            trigger_metadata=trigger_metadata,
        )

    def _apply_impacted_domain_recomputes(self, *, user, trigger_type: str, payload: dict, plan) -> None:
        if plan.sync_active_conditions:
            for state_date in plan.event_dates:
                self._condition_integration.sync_all_for_user(user=user, on_date=state_date)

        if plan.recompute_constraints and plan.constraint_trigger_type:
            ConstraintRecomputeDispatcher.dispatch_for_user(
                user=user,
                trigger_type=plan.constraint_trigger_type,
                trigger_reference=str(payload.get("trigger_reference") or payload.get("source_id") or ""),
                tracker_type=plan.constraint_tracker_type,
            )

    def _rebuild_window(
        self,
        *,
        user,
        state_date: date,
        window_kind: str,
        trigger_type: str,
        payload: dict,
        affected_trackers,
        reason: str,
        computation_run,
    ):
        previous_state = HealthStateRepository.get_state(
            user=user,
            state_date=state_date,
            window_kind=window_kind,
        )
        state_block = self._projection_service.build_projection(
            user=user,
            state_date=state_date,
            window_kind=window_kind,
            affected_trackers=affected_trackers,
            trigger_metadata={
                "trigger_type": trigger_type,
                "trigger_reference": str(payload.get("trigger_reference") or ""),
                "event_dates": [str(item) for item in payload.get("event_dates") or [state_date]],
            },
        )
        if state_block is None:
            return None

        persisted_state = self.persist_state(user=user, state_block=state_block)
        delta_payload = self.build_state_delta(
            user=user,
            affected_domains=affected_trackers,
            reason=reason,
            trigger_type=trigger_type,
            trigger_reference=str(payload.get("trigger_reference") or ""),
            state_date=state_date,
            window_kind=window_kind,
            previous_state=previous_state,
            new_state=persisted_state,
        )
        dispatched = self._notification_dispatcher.dispatch_candidates(
            user=user,
            candidates=delta_payload.get("notification_candidates") or [],
        )
        delta_payload["notification_candidates"] = dispatched
        return HealthStateRepository.create_delta(
            user=user,
            state_date=state_date,
            window_kind=window_kind,
            trigger_type=trigger_type,
            trigger_reference=str(payload.get("trigger_reference") or ""),
            reason=reason,
            changed_trackers=delta_payload.get("changed_trackers") or [],
            metrics_before=delta_payload.get("metrics_before") or {},
            metrics_after=delta_payload.get("metrics_after") or {},
            warnings_added=delta_payload.get("warnings_added") or [],
            warnings_resolved=delta_payload.get("warnings_resolved") or [],
            achievements_added=delta_payload.get("achievements_added") or [],
            notification_candidates=delta_payload.get("notification_candidates") or [],
            computation_run=computation_run,
        )

    @staticmethod
    def _flatten_metrics(summary: dict) -> dict:
        main = dict(summary.get("summary") or {})
        hydration = dict(summary.get("hydration") or {})
        sleep = dict(summary.get("sleep") or {})
        activity = dict(summary.get("activity") or {})
        medications = dict(summary.get("medications") or {})
        chronic = dict(summary.get("chronic_conditions") or {})
        return {
            "calories_consumed": int(main.get("calories_consumed") or 0),
            "calories_remaining": int(main.get("calories_remaining") or 0),
            "water_current": float(hydration.get("current") or 0),
            "water_target": float(hydration.get("target") or 0),
            "steps": int(activity.get("steps") or 0),
            "steps_target": int(activity.get("steps_target") or 0),
            "burn_current": int(main.get("calories_burned") or 0),
            "burn_target": int(main.get("burn_target") or 0),
            "sleep_logged_hours": float(sleep.get("logged_hours_today") or 0),
            "sleep_target_hours": float(sleep.get("recommended_sleep_hours") or 0),
            "medication_adherence_percent": float(medications.get("adherence_7d") or 0),
            "medication_overdue_today": int(medications.get("overdue_today") or 0),
            "condition_adherence_percent": float(chronic.get("adherence_percent") or 0),
            "warning_count": len(summary.get("active_warnings") or []),
        }

    @staticmethod
    def _warning_map(warnings: list[dict]) -> dict[str, dict]:
        items = {}
        for warning in warnings or []:
            key = ":".join(
                [
                    str(warning.get("source") or ""),
                    str(warning.get("condition_id") or ""),
                    str(warning.get("code") or ""),
                    str(warning.get("message") or ""),
                ]
            )
            items[key] = dict(warning)
        return items

    @staticmethod
    def _achievements_added(*, before: dict, after: dict) -> list[dict]:
        achievements: list[dict] = []
        progress_keys = [
            ("hydration_goal_reached", "hydration", after.get("water_current"), after.get("water_target"), before.get("water_current"), before.get("water_target")),
            ("steps_goal_reached", "steps", after.get("steps"), after.get("steps_target"), before.get("steps"), before.get("steps_target")),
            ("sleep_goal_reached", "sleep", after.get("sleep_logged_hours"), after.get("sleep_target_hours"), before.get("sleep_logged_hours"), before.get("sleep_target_hours")),
            ("burn_goal_reached", "activity", after.get("burn_current"), after.get("burn_target"), before.get("burn_current"), before.get("burn_target")),
        ]
        for code, tracker, current_after, target_after, current_before, target_before in progress_keys:
            after_progress = HealthStateOrchestrator._progress_ratio(current_after, target_after)
            before_progress = HealthStateOrchestrator._progress_ratio(current_before, target_before)
            if before_progress < 1 <= after_progress:
                achievements.append({"code": code, "tracker": tracker})
        return achievements

    @staticmethod
    def _progress_ratio(current, target) -> float:
        try:
            current = float(current or 0)
            target = float(target or 0)
        except (TypeError, ValueError):
            return 0
        if target <= 0:
            return 0
        return current / target
