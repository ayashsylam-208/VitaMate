from __future__ import annotations

import hashlib
import json

from django.db import transaction
from django.utils import timezone

from core.models import (
    ConstraintResolutionRun,
    ConstraintSourceTrace,
    ResolvedTrackerConstraint,
)
from core.services.constraints.constraint_source_collector import ConstraintCandidate


class ConstraintMaterializer:
    """Writes resolved candidates into the materialized execution table."""

    @classmethod
    def materialize(
        cls,
        *,
        user,
        constraints: list[ConstraintCandidate],
        trigger_type: str,
        trigger_reference: str = "",
        input_signature: str,
        tracker_type: str | None = None,
    ) -> ConstraintResolutionRun:
        run = ConstraintResolutionRun.objects.create(
            user=user,
            trigger_type=trigger_type,
            trigger_reference=str(trigger_reference or ""),
            input_signature=input_signature,
            run_status=ConstraintResolutionRun.STATUS_RUNNING,
        )
        try:
            with transaction.atomic():
                now = timezone.now()
                active_query = ResolvedTrackerConstraint.objects.filter(
                    user=user,
                    status=ResolvedTrackerConstraint.STATUS_ACTIVE,
                )
                if tracker_type:
                    active_query = active_query.filter(tracker_type=tracker_type)
                superseded_count = active_query.update(
                    status=ResolvedTrackerConstraint.STATUS_SUPERSEDED,
                    effective_to=now,
                )

                created = []
                for candidate in constraints:
                    resolved = ResolvedTrackerConstraint.objects.create(
                        user=user,
                        tracker_type=candidate.tracker_type,
                        category=candidate.category,
                        metric_key=candidate.metric_key,
                        rule_type=candidate.rule_type,
                        evaluation_mode=candidate.evaluation_mode,
                        unit=candidate.unit,
                        min_value=candidate.min_value,
                        max_value=candidate.max_value,
                        target_value=candidate.target_value,
                        warning_value=candidate.warning_value,
                        priority=max(int(candidate.priority or 0), 0),
                        is_blocking=candidate.is_blocking,
                        is_scored=candidate.is_scored,
                        source_type=candidate.source_type,
                        source_condition=candidate.source_condition,
                        source_restriction=candidate.source_restriction,
                        source_target=candidate.source_target,
                        source_nutrient_rule=candidate.source_nutrient_rule,
                        source_user_nutrient_target=candidate.source_user_nutrient_target,
                        reason_summary=candidate.reason_summary,
                        explanation_payload=candidate.explanation_payload,
                        confidence_score=candidate.confidence_score,
                        effective_from=now,
                        computed_at=now,
                        status=ResolvedTrackerConstraint.STATUS_ACTIVE,
                        version_hash=cls._version_hash(candidate),
                    )
                    cls._write_traces(resolved=resolved, candidate=candidate)
                    created.append(resolved)

                run.total_constraints_generated = len(created)
                run.total_constraints_superseded = superseded_count
                run.run_status = ConstraintResolutionRun.STATUS_COMPLETED
                run.completed_at = timezone.now()
                run.save(
                    update_fields=[
                        "total_constraints_generated",
                        "total_constraints_superseded",
                        "run_status",
                        "completed_at",
                    ]
                )
        except Exception as exc:
            run.run_status = ConstraintResolutionRun.STATUS_FAILED
            run.completed_at = timezone.now()
            run.error_message = str(exc)
            run.save(update_fields=["run_status", "completed_at", "error_message"])
            raise
        return run

    @staticmethod
    def _version_hash(candidate: ConstraintCandidate) -> str:
        raw = json.dumps(candidate.hash_payload(), sort_keys=True, default=str)
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()

    @staticmethod
    def _write_traces(
        *,
        resolved: ResolvedTrackerConstraint,
        candidate: ConstraintCandidate,
    ) -> None:
        selected = candidate.source_trace_payload()
        traces = []
        if selected is not None:
            traces.append(
                ConstraintSourceTrace(
                    resolved_constraint=resolved,
                    source_model=selected["source_model"],
                    source_object_id=str(selected.get("source_object_id") or ""),
                    contribution_type=ConstraintSourceTrace.CONTRIBUTION_SELECTED,
                    priority_score=selected["priority_score"],
                    note=selected["note"],
                )
            )

        for superseded in candidate.explanation_payload.get("superseded_candidates", []):
            if not superseded.get("source_model"):
                continue
            traces.append(
                ConstraintSourceTrace(
                    resolved_constraint=resolved,
                    source_model=superseded["source_model"],
                    source_object_id=str(superseded.get("source_object_id") or ""),
                    contribution_type=ConstraintSourceTrace.CONTRIBUTION_SUPERSEDED,
                    priority_score=int(superseded.get("priority") or 0),
                    note=superseded.get("reason_summary") or "",
                )
            )

        merged = candidate.explanation_payload.get("merged_from_target")
        if merged and merged.get("source_model"):
            traces.append(
                ConstraintSourceTrace(
                    resolved_constraint=resolved,
                    source_model=merged["source_model"],
                    source_object_id=str(merged.get("source_object_id") or ""),
                    contribution_type=ConstraintSourceTrace.CONTRIBUTION_SUPPORTING,
                    priority_score=int(merged.get("priority") or 0),
                    note="Original target adjusted by a higher-priority constraint.",
                )
            )

        if traces:
            ConstraintSourceTrace.objects.bulk_create(traces)
