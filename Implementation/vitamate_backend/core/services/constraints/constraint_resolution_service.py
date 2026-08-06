from __future__ import annotations

import hashlib
import json
import logging
import time

from django.contrib.auth import get_user_model
from django.utils import timezone

from core.models import ConstraintResolutionRun, ResolvedTrackerConstraint
from core.services.constraints.constraint_conflict_resolver import ConstraintConflictResolver
from core.services.constraints.constraint_candidate_validator import ConstraintCandidateValidator
from core.services.constraints.constraint_materializer import ConstraintMaterializer
from core.services.constraints.constraint_source_collector import ConstraintSourceCollector


logger = logging.getLogger("vitamate.performance")


class ConstraintResolutionService:
    """High-level orchestration service for resolving effective tracker constraints."""

    @classmethod
    def resolve_for_user(
        cls,
        *,
        user_id: int,
        trigger_type: str = ConstraintResolutionRun.TRIGGER_MANUAL,
        trigger_reference: str = "",
        tracker_type: str | None = None,
        run: ConstraintResolutionRun | None = None,
        correlation_id: str = "",
        idempotency_key: str | None = None,
        sync_mode: str = ConstraintResolutionRun.SYNC_MODE_SYNCHRONOUS,
        metadata: dict | None = None,
    ) -> ConstraintResolutionRun:
        started = time.perf_counter()
        user = get_user_model().objects.get(pk=user_id)
        preflight_signature = cls.input_signature(
            user_id=user.id,
            trigger_type=trigger_type,
            trigger_reference=trigger_reference,
            tracker_type=tracker_type,
        )
        run = cls._ensure_run(
            user=user,
            run=run,
            trigger_type=trigger_type,
            trigger_reference=trigger_reference,
            tracker_type=tracker_type,
            input_signature=preflight_signature,
            correlation_id=correlation_id,
            idempotency_key=idempotency_key,
            sync_mode=sync_mode,
            metadata=metadata,
        )
        if run.run_status in {
            ConstraintResolutionRun.STATUS_SUCCEEDED,
            ConstraintResolutionRun.STATUS_SKIPPED,
        }:
            cls._log_result(run=run, duration_ms=(time.perf_counter() - started) * 1000)
            return run

        try:
            candidates = ConstraintSourceCollector.collect_for_user(
                user=user,
                tracker_type=tracker_type,
            )
            ConstraintCandidateValidator.validate_all(candidates)
            resolved = ConstraintConflictResolver.resolve(candidates)
            input_signature = cls.input_signature(
                user_id=user.id,
                trigger_type=trigger_type,
                trigger_reference=trigger_reference,
                tracker_type=tracker_type,
                candidates=resolved,
            )
        except Exception as exc:
            cls._mark_failed(run=run, exc=exc)
            cls._log_result(run=run, duration_ms=(time.perf_counter() - started) * 1000)
            raise
        try:
            run = ConstraintMaterializer.materialize(
                user=user,
                constraints=resolved,
                trigger_type=trigger_type,
                trigger_reference=trigger_reference,
                input_signature=input_signature,
                tracker_type=tracker_type,
                run=run,
                correlation_id=correlation_id,
                idempotency_key=idempotency_key,
                sync_mode=sync_mode,
                metadata=metadata,
            )
        except Exception:
            run.refresh_from_db()
            cls._log_result(run=run, duration_ms=(time.perf_counter() - started) * 1000)
            raise
        cls._log_result(run=run, duration_ms=(time.perf_counter() - started) * 1000)
        return run

    @staticmethod
    def _log_result(*, run: ConstraintResolutionRun, duration_ms: float) -> None:
        logger.info(
            json.dumps(
                {
                    "event": "constraint_recompute",
                    "user_id": run.user_id,
                    "run_id": run.id,
                    "correlation_id": run.correlation_id,
                    "trigger_type": run.trigger_type,
                    "affected_trackers": list(run.affected_trackers or []),
                    "status": run.run_status,
                    "generated": run.total_constraints_generated,
                    "superseded": run.total_constraints_superseded,
                    "retry_count": run.retry_count,
                    "failure_category": run.error_code or "",
                    "duration_ms": round(duration_ms, 2),
                }
            )
        )

    @staticmethod
    def _ensure_run(
        *,
        user,
        run,
        trigger_type,
        trigger_reference,
        tracker_type,
        input_signature,
        correlation_id,
        idempotency_key,
        sync_mode,
        metadata,
    ) -> ConstraintResolutionRun:
        if run is None and idempotency_key:
            run = ConstraintResolutionRun.objects.filter(idempotency_key=idempotency_key).first()
        if run is None:
            return ConstraintResolutionRun.objects.create(
                user=user,
                trigger_type=trigger_type,
                trigger_reference=str(trigger_reference or ""),
                input_signature=input_signature,
                run_status=ConstraintResolutionRun.STATUS_RUNNING,
                sync_mode=sync_mode,
                correlation_id=str(correlation_id or ""),
                idempotency_key=idempotency_key or None,
                metadata=dict(metadata or {}),
                affected_trackers=[tracker_type] if tracker_type else [],
            )
        if run.run_status in {
            ConstraintResolutionRun.STATUS_SUCCEEDED,
            ConstraintResolutionRun.STATUS_SKIPPED,
        }:
            return run
        if run.run_status == ConstraintResolutionRun.STATUS_FAILED:
            run.retry_count += 1
        run.run_status = ConstraintResolutionRun.STATUS_RUNNING
        run.correlation_id = str(correlation_id or run.correlation_id or "")
        run.metadata = {**dict(run.metadata or {}), **dict(metadata or {})}
        run.failed_at = None
        run.completed_at = None
        run.error_code = ""
        run.error_message = ""
        run.save(
            update_fields=[
                "run_status",
                "correlation_id",
                "metadata",
                "retry_count",
                "failed_at",
                "completed_at",
                "error_code",
                "error_message",
            ]
        )
        return run

    @staticmethod
    def _mark_failed(*, run: ConstraintResolutionRun, exc: Exception) -> None:
        failed_at = timezone.now()
        run.run_status = ConstraintResolutionRun.STATUS_FAILED
        run.failed_at = failed_at
        run.completed_at = failed_at
        run.error_code = exc.__class__.__name__
        run.error_message = str(exc)
        run.save(
            update_fields=[
                "run_status",
                "failed_at",
                "completed_at",
                "error_code",
                "error_message",
            ]
        )

    @classmethod
    def recompute_tracker_constraints(
        cls,
        *,
        user_id: int,
        tracker_type: str,
        trigger_type: str = ConstraintResolutionRun.TRIGGER_MANUAL,
        trigger_reference: str = "",
        run: ConstraintResolutionRun | None = None,
        correlation_id: str = "",
        idempotency_key: str | None = None,
        sync_mode: str = ConstraintResolutionRun.SYNC_MODE_SYNCHRONOUS,
        metadata: dict | None = None,
    ) -> ConstraintResolutionRun:
        return cls.resolve_for_user(
            user_id=user_id,
            tracker_type=tracker_type,
            trigger_type=trigger_type,
            trigger_reference=trigger_reference,
            run=run,
            correlation_id=correlation_id,
            idempotency_key=idempotency_key,
            sync_mode=sync_mode,
            metadata=metadata,
        )

    @staticmethod
    def explain_constraint(*, user, constraint_id: int) -> dict:
        constraint = ResolvedTrackerConstraint.objects.get(
            id=constraint_id,
            user=user,
        )
        return {
            "id": constraint.id,
            "tracker_type": constraint.tracker_type,
            "metric_key": constraint.metric_key,
            "rule_type": constraint.rule_type,
            "reason_summary": constraint.reason_summary,
            "explanation_payload": constraint.explanation_payload,
            "source_type": constraint.source_type,
            "version_hash": constraint.version_hash,
        }

    @staticmethod
    def input_signature(
        *,
        user_id: int,
        trigger_type: str,
        trigger_reference: str = "",
        tracker_type: str | None = None,
        candidates=None,
    ) -> str:
        payload = {
            "user_id": user_id,
            "trigger_type": trigger_type,
            "trigger_reference": str(trigger_reference or ""),
            "tracker_type": tracker_type or "all",
            "candidates": [
                candidate.hash_payload()
                for candidate in (candidates or [])
            ],
        }
        raw = json.dumps(payload, sort_keys=True, default=str)
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()
