from __future__ import annotations

import hashlib
import uuid

from core.models import ConstraintResolutionRun, ResolvedTrackerConstraint
from core.services.constraints.constraint_resolution_service import ConstraintResolutionService
from core.tasks import dispatch_constraint_recompute


class ConstraintRecomputeDispatcher:
    """
    Synchronous dispatcher for now.

    The method shape intentionally leaves room for a future Celery/background path without
    changing callers.
    """

    PARTIAL_TRACKERS_BY_TRIGGER = {
        ConstraintResolutionRun.TRIGGER_HEALTH_INDICATOR_RECORD: ResolvedTrackerConstraint.TRACKER_MONITORING,
        ConstraintResolutionRun.TRIGGER_MEDICATION_PLAN: ResolvedTrackerConstraint.TRACKER_MEDICATION,
    }

    @classmethod
    def dispatch_for_user(
        cls,
        *,
        user,
        trigger_type: str = ConstraintResolutionRun.TRIGGER_MANUAL,
        trigger_reference: str = "",
        tracker_type: str | None = None,
        synchronous: bool = True,
        correlation_id: str = "",
        idempotency_key: str | None = None,
        metadata: dict | None = None,
        sync_mode: str | None = None,
    ) -> ConstraintResolutionRun:
        correlation_id = str(correlation_id or uuid.uuid4().hex)
        tracker_type = tracker_type or cls.PARTIAL_TRACKERS_BY_TRIGGER.get(trigger_type)
        preflight_signature = cls._preflight_signature(
            user_id=user.id,
            trigger_type=trigger_type,
            trigger_reference=trigger_reference,
            tracker_type=tracker_type,
        )
        existing_run = ConstraintResolutionRun.objects.filter(
            user=user,
            run_status=ConstraintResolutionRun.STATUS_RUNNING,
            input_signature=preflight_signature,
        ).order_by("-started_at").first()
        if existing_run is not None:
            return existing_run

        if not synchronous:
            run = cls._queued_run(
                user=user,
                trigger_type=trigger_type,
                trigger_reference=trigger_reference,
                preflight_signature=preflight_signature,
                tracker_type=tracker_type,
                correlation_id=correlation_id,
                idempotency_key=idempotency_key,
                metadata=metadata,
            )
            if run.run_status in {
                ConstraintResolutionRun.STATUS_SUCCEEDED,
                ConstraintResolutionRun.STATUS_SKIPPED,
            }:
                return run
            dispatch_constraint_recompute(
                user_id=user.id,
                trigger_type=trigger_type,
                trigger_reference=trigger_reference,
                tracker_type=tracker_type,
                run_id=run.id,
                correlation_id=correlation_id,
                idempotency_key=idempotency_key,
            )
            run.refresh_from_db()
            return run

        if tracker_type:
            return ConstraintResolutionService.recompute_tracker_constraints(
                user_id=user.id,
                tracker_type=tracker_type,
                trigger_type=trigger_type,
                trigger_reference=trigger_reference,
                correlation_id=correlation_id,
                idempotency_key=idempotency_key,
                sync_mode=sync_mode or ConstraintResolutionRun.SYNC_MODE_SYNCHRONOUS,
                metadata=metadata,
            )
        return ConstraintResolutionService.resolve_for_user(
            user_id=user.id,
            trigger_type=trigger_type,
            trigger_reference=trigger_reference,
            correlation_id=correlation_id,
            idempotency_key=idempotency_key,
            sync_mode=sync_mode or ConstraintResolutionRun.SYNC_MODE_SYNCHRONOUS,
            metadata=metadata,
        )

    @staticmethod
    def _queued_run(
        *,
        user,
        trigger_type,
        trigger_reference,
        preflight_signature,
        tracker_type,
        correlation_id,
        idempotency_key,
        metadata,
    ) -> ConstraintResolutionRun:
        if idempotency_key:
            existing = ConstraintResolutionRun.objects.filter(idempotency_key=idempotency_key).first()
            if existing is not None:
                return existing
        return ConstraintResolutionRun.objects.create(
            user=user,
            trigger_type=trigger_type,
            trigger_reference=str(trigger_reference or ""),
            input_signature=preflight_signature,
            run_status=ConstraintResolutionRun.STATUS_PENDING,
            sync_mode=ConstraintResolutionRun.SYNC_MODE_QUEUED,
            correlation_id=correlation_id,
            idempotency_key=idempotency_key or None,
            affected_trackers=[tracker_type] if tracker_type else [],
            metadata={"queued_via": "task_dispatch", **dict(metadata or {})},
        )

    @staticmethod
    def _preflight_signature(
        *,
        user_id: int,
        trigger_type: str,
        trigger_reference: str = "",
        tracker_type: str | None = None,
    ) -> str:
        raw = f"{user_id}:{trigger_type}:{trigger_reference or ''}:{tracker_type or 'all'}"
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()
