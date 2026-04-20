from __future__ import annotations

import hashlib

from core.models import ConstraintResolutionRun, ResolvedTrackerConstraint
from core.services.constraints.constraint_resolution_service import ConstraintResolutionService


class ConstraintRecomputeDispatcher:
    """
    Synchronous dispatcher for now.

    The method shape intentionally leaves room for a future Celery/background path without
    changing callers.
    """

    PARTIAL_TRACKERS_BY_TRIGGER = {
        ConstraintResolutionRun.TRIGGER_HEALTH_INDICATOR_RECORD: ResolvedTrackerConstraint.TRACKER_MONITORING,
        ConstraintResolutionRun.TRIGGER_MEDICATION_PLAN: ResolvedTrackerConstraint.TRACKER_MEDICATION,
        ConstraintResolutionRun.TRIGGER_USER_NUTRIENT_TARGET: ResolvedTrackerConstraint.TRACKER_NUTRITION,
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
    ) -> ConstraintResolutionRun:
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
            # TODO: route this through a task queue once background workers are introduced.
            return ConstraintResolutionRun.objects.create(
                user=user,
                trigger_type=trigger_type,
                trigger_reference=str(trigger_reference or ""),
                input_signature=preflight_signature,
                run_status=ConstraintResolutionRun.STATUS_SKIPPED,
                error_message="Asynchronous recompute is not configured; no background job was queued.",
            )

        if tracker_type:
            return ConstraintResolutionService.recompute_tracker_constraints(
                user_id=user.id,
                tracker_type=tracker_type,
                trigger_type=trigger_type,
                trigger_reference=trigger_reference,
            )
        return ConstraintResolutionService.resolve_for_user(
            user_id=user.id,
            trigger_type=trigger_type,
            trigger_reference=trigger_reference,
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
