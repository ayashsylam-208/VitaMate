from __future__ import annotations

import hashlib
import json

from django.contrib.auth import get_user_model

from core.models import ConstraintResolutionRun, ResolvedTrackerConstraint
from core.services.constraints.constraint_conflict_resolver import ConstraintConflictResolver
from core.services.constraints.constraint_materializer import ConstraintMaterializer
from core.services.constraints.constraint_source_collector import ConstraintSourceCollector


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
    ) -> ConstraintResolutionRun:
        user = get_user_model().objects.get(pk=user_id)
        candidates = ConstraintSourceCollector.collect_for_user(
            user=user,
            tracker_type=tracker_type,
        )
        resolved = ConstraintConflictResolver.resolve(candidates)
        input_signature = cls.input_signature(
            user_id=user.id,
            trigger_type=trigger_type,
            trigger_reference=trigger_reference,
            tracker_type=tracker_type,
            candidates=resolved,
        )
        return ConstraintMaterializer.materialize(
            user=user,
            constraints=resolved,
            trigger_type=trigger_type,
            trigger_reference=trigger_reference,
            input_signature=input_signature,
            tracker_type=tracker_type,
        )

    @classmethod
    def recompute_tracker_constraints(
        cls,
        *,
        user_id: int,
        tracker_type: str,
        trigger_type: str = ConstraintResolutionRun.TRIGGER_MANUAL,
        trigger_reference: str = "",
    ) -> ConstraintResolutionRun:
        return cls.resolve_for_user(
            user_id=user_id,
            tracker_type=tracker_type,
            trigger_type=trigger_type,
            trigger_reference=trigger_reference,
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
