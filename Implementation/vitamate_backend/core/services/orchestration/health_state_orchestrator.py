from __future__ import annotations

from datetime import date
from dataclasses import asdict, dataclass
import json
import logging
import time
import uuid

from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone

from core.models import UnifiedHealthState
from core.repositories.health_state_repository import HealthStateRepository
from core.services.chronic.condition_integration_coordinator import ConditionIntegrationCoordinator
from core.services.constraints import ConstraintRecomputeDispatcher
from core.services.orchestration.health_state_projection_service import HealthStateProjectionService
from core.services.orchestration.tracker_dependency_map import TrackerDependencyMap
from notification_hub.services import NotificationHubRefreshService


logger = logging.getLogger("vitamate.performance")


@dataclass(frozen=True, slots=True)
class HealthStateUpdateResult:
    correlation_id: str
    run_id: int
    constraints_updated: bool
    state_updated: bool
    state_version: int | None
    affected_trackers: list[str]
    warnings: list[str]
    delta_ids: list[int]

    def as_dict(self) -> dict:
        return asdict(self)


class HealthStateUpdateError(RuntimeError):
    def __init__(self, *, correlation_id: str, run_id: int, cause: Exception):
        self.correlation_id = correlation_id
        self.run_id = run_id
        super().__init__(
            f"Health-state update failed (correlation_id={correlation_id}, run_id={run_id})."
        )
        self.__cause__ = cause


class HealthStateOrchestrator:
    def __init__(
        self,
        *,
        projection_service: HealthStateProjectionService | None = None,
        condition_integration: ConditionIntegrationCoordinator | None = None,
    ):
        self._projection_service = projection_service or HealthStateProjectionService()
        self._condition_integration = condition_integration or ConditionIntegrationCoordinator()

    def handle_event(self, *, user, trigger_type: str, payload=None, synchronous: bool = True):
        started = time.perf_counter()
        payload = dict(payload or {})
        correlation_id = str(payload.get("correlation_id") or uuid.uuid4().hex)
        payload["correlation_id"] = correlation_id
        payload.setdefault(
            "idempotency_key",
            f"health-state:{user.id}:{trigger_type}:{correlation_id}",
        )
        today = payload.get("today")
        if not isinstance(today, date):
            today = timezone.localdate()

        plan = self.recompute_impacted_domains(
            user=user,
            trigger_type=trigger_type,
            payload=payload,
            today=today,
        )
        run, duplicate_event = HealthStateRepository.begin_computation_run(
            user=user,
            trigger_type=trigger_type,
            trigger_reference=str(payload.get("trigger_reference") or ""),
            affected_domains=list(plan.affected_trackers),
            correlation_id=correlation_id,
            idempotency_key=str(payload["idempotency_key"]),
            metadata={
                "event_dates": [str(item) for item in plan.event_dates],
                "reason": plan.reason,
                "synchronous": synchronous,
                "correlation_id": correlation_id,
                "idempotency_key": payload["idempotency_key"],
            },
        )
        if duplicate_event:
            current_state = HealthStateRepository.get_state(
                user=user,
                state_date=today,
                window_kind=UnifiedHealthState.WINDOW_CURRENT,
            )
            logger.info(
                json.dumps(
                    {
                        "event": "health_state_duplicate_suppressed",
                        "user_id": user.id,
                        "run_id": run.id,
                        "correlation_id": run.correlation_id or correlation_id,
                        "trigger_type": trigger_type,
                        "state_version": current_state.version if current_state else None,
                    }
                )
            )
            return HealthStateUpdateResult(
                correlation_id=run.correlation_id or correlation_id,
                run_id=run.id,
                constraints_updated=False,
                state_updated=False,
                state_version=current_state.version if current_state else None,
                affected_trackers=list(run.affected_domains or plan.affected_trackers),
                warnings=["duplicate_event_skipped"],
                delta_ids=[],
            ).as_dict()
        try:
            with transaction.atomic():
                get_user_model().objects.select_for_update().only("pk").get(pk=user.pk)
                constraint_runs = self._apply_impacted_domain_recomputes(
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
                        "correlation_id": correlation_id,
                        "status": "completed",
                        "duration_ms": duration_ms,
                        "affected_domains": list(plan.affected_trackers),
                    }
                )
            )
            current_state = HealthStateRepository.get_state(
                user=user,
                state_date=today,
                window_kind=UnifiedHealthState.WINDOW_CURRENT,
            )
            result = HealthStateUpdateResult(
                correlation_id=correlation_id,
                run_id=run.id,
                constraints_updated=any(
                    item.total_constraints_generated or item.total_constraints_superseded
                    for item in constraint_runs
                ),
                state_updated=bool(deltas),
                state_version=current_state.version if current_state else None,
                affected_trackers=list(plan.affected_trackers),
                warnings=[],
                delta_ids=[item.id for item in deltas],
            )
            try:
                NotificationHubRefreshService.refresh_user(user=user)
            except Exception as notification_exc:
                logger.warning(
                    json.dumps(
                        {
                            "event": "notification_hub_refresh_failed",
                            "user_id": user.id,
                            "correlation_id": correlation_id,
                            "health_state_run_id": run.id,
                            "error_type": notification_exc.__class__.__name__,
                        }
                    )
                )
            return result.as_dict()
        except Exception as exc:
            HealthStateRepository.fail_computation_run(
                run,
                error_message=str(exc),
                error_code=exc.__class__.__name__,
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
                        "correlation_id": correlation_id,
                        "status": "failed",
                        "duration_ms": duration_ms,
                        "affected_domains": list(plan.affected_trackers),
                        "error": str(exc),
                    }
                )
            )
            raise HealthStateUpdateError(
                correlation_id=correlation_id,
                run_id=run.id,
                cause=exc,
            ) from exc

    def recompute_impacted_domains(self, *, user, trigger_type: str, payload=None, today: date | None = None):
        del user  # reserved for future user-specific dependency logic
        return TrackerDependencyMap.build_plan(
            trigger_type=trigger_type,
            payload=payload,
            today=today or timezone.localdate(),
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

    def _apply_impacted_domain_recomputes(self, *, user, trigger_type: str, payload: dict, plan) -> list:
        if plan.sync_active_conditions:
            for state_date in plan.event_dates:
                self._condition_integration.sync_all_for_user(user=user, on_date=state_date)

        constraint_runs = []
        if plan.recompute_constraints and plan.constraint_trigger_type:
            tracker_types = plan.constraint_tracker_types or (plan.constraint_tracker_type,)
            tracker_types = tuple(dict.fromkeys(tracker_types))
            for tracker_type in tracker_types:
                suffix = tracker_type or "all"
                constraint_runs.append(ConstraintRecomputeDispatcher.dispatch_for_user(
                    user=user,
                    trigger_type=plan.constraint_trigger_type,
                    trigger_reference=str(payload.get("trigger_reference") or payload.get("source_id") or ""),
                    tracker_type=tracker_type,
                    correlation_id=str(payload.get("correlation_id") or ""),
                    idempotency_key=(
                        f"{payload.get('idempotency_key')}:{suffix}"
                        if payload.get("idempotency_key")
                        else None
                    ),
                    metadata={"health_state_trigger": trigger_type},
                ))
        return constraint_runs

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
