from datetime import date, datetime, time

from django.utils import timezone

from core.models import (
    HealthStateComputationRun,
    HealthStateDelta,
    NotificationDispatchRecord,
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
    def create_computation_run(
        *,
        user,
        trigger_type: str,
        trigger_reference: str = "",
        affected_domains=None,
        sync_mode: str = HealthStateComputationRun.SYNC_MODE_SYNC,
        metadata=None,
    ):
        return HealthStateComputationRun.objects.create(
            user=user,
            trigger_type=trigger_type,
            trigger_reference=str(trigger_reference or ""),
            affected_domains=list(affected_domains or []),
            sync_mode=sync_mode,
            metadata=HealthStateRepository._json_ready(metadata or {}),
        )

    @staticmethod
    def complete_computation_run(run, *, affected_domains=None):
        run.run_status = HealthStateComputationRun.STATUS_COMPLETED
        run.completed_at = timezone.now()
        if affected_domains is not None:
            run.affected_domains = list(affected_domains)
        run.save(update_fields=["run_status", "completed_at", "affected_domains"])
        return run

    @staticmethod
    def fail_computation_run(run, *, error_message: str, affected_domains=None):
        run.run_status = HealthStateComputationRun.STATUS_FAILED
        run.completed_at = timezone.now()
        run.error_message = str(error_message or "")
        if affected_domains is not None:
            run.affected_domains = list(affected_domains)
        run.save(
            update_fields=[
                "run_status",
                "completed_at",
                "error_message",
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
        notification_candidates=None,
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
            notification_candidates=HealthStateRepository._json_ready(notification_candidates or []),
            computation_run=computation_run,
        )


class NotificationDispatchRepository:
    @staticmethod
    def latest_by_dedupe_key(*, user, dedupe_key: str):
        return NotificationDispatchRecord.objects.filter(
            user=user,
            dedupe_key=dedupe_key,
        ).order_by("-updated_at", "-id").first()

    @staticmethod
    def create_record(
        *,
        user,
        notification_type: str,
        channel: str,
        priority: int,
        dedupe_key: str,
        payload,
        status: str,
        cooldown_until=None,
        last_dispatched_at=None,
    ):
        return NotificationDispatchRecord.objects.create(
            user=user,
            notification_type=notification_type,
            channel=channel or "",
            priority=priority,
            dedupe_key=dedupe_key,
            payload=HealthStateRepository._json_ready(payload or {}),
            status=status,
            cooldown_until=cooldown_until,
            last_dispatched_at=last_dispatched_at,
        )
