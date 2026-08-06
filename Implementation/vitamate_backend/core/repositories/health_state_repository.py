from datetime import date, datetime, time

from django.db import transaction
from django.utils import timezone

from core.models import (
    HealthStateComputationRun,
    HealthStateDelta,
    UnifiedHealthState,
)


class HealthStateRepository:
    @staticmethod
    def _json_ready(value):
        if isinstance(value, dict):
            return {str(key): HealthStateRepository._json_ready(item) for key, item in value.items()}
        if isinstance(value, (list, tuple, set)):
            return [HealthStateRepository._json_ready(item) for item in value]
        if isinstance(value, (datetime, date, time)):
            return value.isoformat()
        return value

    @staticmethod
    def get_state(*, user, state_date, window_kind: str):
        return UnifiedHealthState.objects.filter(
            user=user,
            state_date=state_date,
            window_kind=window_kind,
        ).first()

    @staticmethod
    def list_states(*, user, start_date, end_date, window_kind: str):
        return UnifiedHealthState.objects.filter(
            user=user,
            state_date__gte=start_date,
            state_date__lte=end_date,
            window_kind=window_kind,
        ).order_by("state_date")

    @staticmethod
    def upsert_state(
        *,
        user,
        state_date,
        window_kind: str,
        affected_trackers,
        tracker_snapshots,
        progress_summary,
        active_targets,
        active_constraints,
        warnings,
        medication_summary,
        trigger_metadata,
    ):
        state = HealthStateRepository.get_state(
            user=user,
            state_date=state_date,
            window_kind=window_kind,
        )
        now = timezone.now()
        if state is None:
            return UnifiedHealthState.objects.create(
                user=user,
                state_date=state_date,
                window_kind=window_kind,
                version=1,
                last_computed_at=now,
                affected_trackers=HealthStateRepository._json_ready(affected_trackers or []),
                tracker_snapshots=HealthStateRepository._json_ready(tracker_snapshots or []),
                progress_summary=HealthStateRepository._json_ready(progress_summary or {}),
                active_targets=HealthStateRepository._json_ready(active_targets or []),
                active_constraints=HealthStateRepository._json_ready(active_constraints or {}),
                warnings=HealthStateRepository._json_ready(warnings or []),
                medication_summary=HealthStateRepository._json_ready(medication_summary or {}),
                trigger_metadata=HealthStateRepository._json_ready(trigger_metadata or {}),
            )

        state.version += 1
        state.last_computed_at = now
        state.affected_trackers = HealthStateRepository._json_ready(affected_trackers or [])
        state.tracker_snapshots = HealthStateRepository._json_ready(tracker_snapshots or [])
        state.progress_summary = HealthStateRepository._json_ready(progress_summary or {})
        state.active_targets = HealthStateRepository._json_ready(active_targets or [])
        state.active_constraints = HealthStateRepository._json_ready(active_constraints or {})
        state.warnings = HealthStateRepository._json_ready(warnings or [])
        state.medication_summary = HealthStateRepository._json_ready(medication_summary or {})
        state.trigger_metadata = HealthStateRepository._json_ready(trigger_metadata or {})
        state.save(
            update_fields=[
                "version",
                "last_computed_at",
                "affected_trackers",
                "tracker_snapshots",
                "progress_summary",
                "active_targets",
                "active_constraints",
                "warnings",
                "medication_summary",
                "trigger_metadata",
                "updated_at",
            ]
        )
        return state

    @staticmethod
    @transaction.atomic
    def begin_computation_run(
        *,
        user,
        trigger_type: str,
        trigger_reference: str = "",
        affected_domains=None,
        sync_mode: str = HealthStateComputationRun.SYNC_MODE_SYNC,
        correlation_id: str = "",
        idempotency_key: str | None = None,
        metadata=None,
    ):
        defaults = {
            "user": user,
            "trigger_type": trigger_type,
            "trigger_reference": str(trigger_reference or ""),
            "affected_domains": list(affected_domains or []),
            "sync_mode": sync_mode,
            "correlation_id": str(correlation_id or ""),
            "metadata": HealthStateRepository._json_ready(metadata or {}),
        }
        if not idempotency_key:
            return HealthStateComputationRun.objects.create(**defaults), False

        run, created = HealthStateComputationRun.objects.select_for_update().get_or_create(
            idempotency_key=str(idempotency_key),
            defaults=defaults,
        )
        if created:
            return run, False
        if run.run_status != HealthStateComputationRun.STATUS_FAILED:
            return run, True

        run.run_status = HealthStateComputationRun.STATUS_RUNNING
        run.retry_count += 1
        run.error_message = ""
        run.error_code = ""
        run.failed_at = None
        run.completed_at = None
        run.started_at = timezone.now()
        run.correlation_id = str(correlation_id or run.correlation_id)
        run.affected_domains = list(affected_domains or [])
        run.metadata = HealthStateRepository._json_ready(metadata or {})
        run.save(
            update_fields=[
                "run_status",
                "retry_count",
                "error_message",
                "error_code",
                "failed_at",
                "completed_at",
                "started_at",
                "correlation_id",
                "affected_domains",
                "metadata",
            ]
        )
        return run, False

    @staticmethod
    def complete_computation_run(run, *, affected_domains=None):
        run.run_status = HealthStateComputationRun.STATUS_COMPLETED
        run.completed_at = timezone.now()
        run.failed_at = None
        run.error_code = ""
        if affected_domains is not None:
            run.affected_domains = list(affected_domains)
        run.save(
            update_fields=[
                "run_status",
                "completed_at",
                "failed_at",
                "error_code",
                "affected_domains",
            ]
        )
        return run

    @staticmethod
    def fail_computation_run(
        run,
        *,
        error_message: str,
        error_code: str = "",
        affected_domains=None,
    ):
        run.run_status = HealthStateComputationRun.STATUS_FAILED
        run.completed_at = timezone.now()
        run.failed_at = run.completed_at
        run.error_message = str(error_message or "")
        run.error_code = str(error_code or "")[:80]
        if affected_domains is not None:
            run.affected_domains = list(affected_domains)
        run.save(
            update_fields=[
                "run_status",
                "completed_at",
                "failed_at",
                "error_message",
                "error_code",
                "affected_domains",
            ]
        )
        return run

    @staticmethod
    def create_delta(
        *,
        user,
        state_date,
        window_kind: str,
        trigger_type: str,
        trigger_reference: str = "",
        reason: str = "",
        changed_trackers=None,
        metrics_before=None,
        metrics_after=None,
        warnings_added=None,
        warnings_resolved=None,
        achievements_added=None,
        computation_run=None,
    ):
        return HealthStateDelta.objects.create(
            user=user,
            state_date=state_date,
            window_kind=window_kind,
            trigger_type=trigger_type,
            trigger_reference=str(trigger_reference or ""),
            reason=reason or "",
            changed_trackers=HealthStateRepository._json_ready(changed_trackers or []),
            metrics_before=HealthStateRepository._json_ready(metrics_before or {}),
            metrics_after=HealthStateRepository._json_ready(metrics_after or {}),
            warnings_added=HealthStateRepository._json_ready(warnings_added or []),
            warnings_resolved=HealthStateRepository._json_ready(warnings_resolved or []),
            achievements_added=HealthStateRepository._json_ready(achievements_added or []),
            computation_run=computation_run,
        )
