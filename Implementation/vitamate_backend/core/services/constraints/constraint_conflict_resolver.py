from __future__ import annotations

from collections import defaultdict
from dataclasses import replace

from core.models import ResolvedTrackerConstraint
from core.services.constraints.constraint_source_collector import ConstraintCandidate


class ConstraintConflictResolver:
    """
    Resolves candidates into execution-ready constraints.

    Policy:
    - Source priority is explicit and safety-first.
    - Same metric + same rule keeps the highest-priority candidate.
    - Equal-priority max rules choose the stricter lower max.
    - Equal-priority min rules choose the stricter higher min.
    - Target rules can be capped by an active max or raised by an active min.
    """

    SOURCE_PRIORITY = {
        ResolvedTrackerConstraint.SOURCE_PHYSICIAN_OVERRIDE: 100,
        ResolvedTrackerConstraint.SOURCE_SAFETY_CRITICAL_CONDITION_RULE: 90,
        ResolvedTrackerConstraint.SOURCE_DYNAMIC_CONDITION_STATE: 80,
        ResolvedTrackerConstraint.SOURCE_CONDITION_NUTRIENT_RULE: 70,
        ResolvedTrackerConstraint.SOURCE_USER_CUSTOM_TARGET: 60,
        ResolvedTrackerConstraint.SOURCE_PROFILE_DERIVED_DEFAULT: 40,
        ResolvedTrackerConstraint.SOURCE_GENERAL_RECOMMENDATION: 20,
    }

    @classmethod
    def resolve(cls, candidates: list[ConstraintCandidate]) -> list[ConstraintCandidate]:
        selected: list[ConstraintCandidate] = []
        grouped: dict[tuple[str, str, str, str], list[ConstraintCandidate]] = defaultdict(list)
        for candidate in candidates:
            grouped[cls._rule_group_key(candidate)].append(candidate)

        for group_candidates in grouped.values():
            winner = cls._select_winner(group_candidates)
            selected.append(cls._with_resolution_payload(winner=winner, group_candidates=group_candidates))

        return cls._apply_metric_level_safety_caps(selected)

    @staticmethod
    def _rule_group_key(candidate: ConstraintCandidate) -> tuple[str, str, str, str]:
        return (
            candidate.tracker_type,
            candidate.metric_key,
            candidate.rule_type,
            candidate.unit,
        )

    @classmethod
    def _select_winner(cls, candidates: list[ConstraintCandidate]) -> ConstraintCandidate:
        if len(candidates) == 1:
            return candidates[0]

        def sort_key(candidate: ConstraintCandidate):
            source_priority = cls.SOURCE_PRIORITY.get(candidate.source_type, 0)
            candidate_priority = max(source_priority, int(candidate.priority or 0))
            max_strictness = 0
            min_strictness = 0
            if candidate.rule_type in {
                ResolvedTrackerConstraint.RULE_MAX,
                ResolvedTrackerConstraint.RULE_AVOID,
                ResolvedTrackerConstraint.RULE_RANGE,
            } and candidate.max_value is not None:
                max_strictness = -float(candidate.max_value)
            if candidate.rule_type in {
                ResolvedTrackerConstraint.RULE_MIN,
                ResolvedTrackerConstraint.RULE_RANGE,
            } and candidate.min_value is not None:
                min_strictness = float(candidate.min_value)
            blocking = 1 if candidate.is_blocking else 0
            return (candidate_priority, blocking, max_strictness, min_strictness)

        return sorted(candidates, key=sort_key, reverse=True)[0]

    @classmethod
    def _with_resolution_payload(
        cls,
        *,
        winner: ConstraintCandidate,
        group_candidates: list[ConstraintCandidate],
    ) -> ConstraintCandidate:
        superseded = [
            candidate
            for candidate in group_candidates
            if candidate is not winner
        ]
        if not superseded:
            return winner
        payload = dict(winner.explanation_payload or {})
        payload["resolution_policy"] = "highest_priority_then_most_restrictive"
        payload["priority_order"] = list(cls.SOURCE_PRIORITY.keys())
        payload["superseded_candidates"] = [
            {
                "source_type": candidate.source_type,
                "source_model": candidate.source_model,
                "source_object_id": candidate.source_object_id,
                "priority": candidate.priority,
                "min_value": candidate.min_value,
                "max_value": candidate.max_value,
                "target_value": candidate.target_value,
                "warning_value": candidate.warning_value,
                "reason_summary": candidate.reason_summary,
            }
            for candidate in superseded
        ]
        reason = winner.reason_summary or "Resolved by priority."
        if superseded:
            reason = f"{reason} Lower-priority candidates were superseded."
        return replace(winner, explanation_payload=payload, reason_summary=reason)

    @classmethod
    def _apply_metric_level_safety_caps(
        cls,
        selected: list[ConstraintCandidate],
    ) -> list[ConstraintCandidate]:
        by_metric: dict[tuple[str, str, str], list[ConstraintCandidate]] = defaultdict(list)
        for candidate in selected:
            by_metric[(candidate.tracker_type, candidate.metric_key, candidate.unit)].append(candidate)

        adjusted: list[ConstraintCandidate] = []
        for candidates in by_metric.values():
            max_candidate = cls._most_restrictive_max(candidates)
            min_candidate = cls._most_restrictive_min(candidates)
            for candidate in candidates:
                if candidate.rule_type != ResolvedTrackerConstraint.RULE_TARGET:
                    adjusted.append(candidate)
                    continue
                adjusted.append(
                    cls._cap_target_if_needed(
                        target_candidate=candidate,
                        max_candidate=max_candidate,
                        min_candidate=min_candidate,
                    )
                )
        return adjusted

    @classmethod
    def _most_restrictive_max(
        cls,
        candidates: list[ConstraintCandidate],
    ) -> ConstraintCandidate | None:
        max_candidates = [
            candidate
            for candidate in candidates
            if candidate.max_value is not None
            and candidate.rule_type
            in {
                ResolvedTrackerConstraint.RULE_MAX,
                ResolvedTrackerConstraint.RULE_AVOID,
                ResolvedTrackerConstraint.RULE_RANGE,
            }
        ]
        if not max_candidates:
            return None
        return sorted(
            max_candidates,
            key=lambda item: (
                cls.SOURCE_PRIORITY.get(item.source_type, 0),
                -float(item.max_value),
            ),
            reverse=True,
        )[0]

    @classmethod
    def _most_restrictive_min(
        cls,
        candidates: list[ConstraintCandidate],
    ) -> ConstraintCandidate | None:
        min_candidates = [
            candidate
            for candidate in candidates
            if candidate.min_value is not None
            and candidate.rule_type
            in {
                ResolvedTrackerConstraint.RULE_MIN,
                ResolvedTrackerConstraint.RULE_RANGE,
            }
        ]
        if not min_candidates:
            return None
        return sorted(
            min_candidates,
            key=lambda item: (
                cls.SOURCE_PRIORITY.get(item.source_type, 0),
                float(item.min_value),
            ),
            reverse=True,
        )[0]

    @staticmethod
    def _cap_target_if_needed(
        *,
        target_candidate: ConstraintCandidate,
        max_candidate: ConstraintCandidate | None,
        min_candidate: ConstraintCandidate | None,
    ) -> ConstraintCandidate:
        target_value = target_candidate.target_value
        if target_value is None:
            return target_candidate

        if (
            max_candidate is not None
            and max_candidate.max_value is not None
            and max_candidate.priority >= target_candidate.priority
            and target_value > max_candidate.max_value
        ):
            payload = dict(max_candidate.explanation_payload or {})
            payload["merged_from_target"] = target_candidate.hash_payload()
            payload["resolution_policy"] = "target_capped_by_safety_max"
            return replace(
                max_candidate,
                rule_type=ResolvedTrackerConstraint.RULE_TARGET,
                min_value=None,
                max_value=None,
                target_value=float(max_candidate.max_value),
                warning_value=None,
                reason_summary=(
                    f"Effective target capped at {max_candidate.max_value} {max_candidate.unit} "
                    f"because a higher-priority safety maximum applies."
                ),
                explanation_payload=payload,
            )

        if (
            min_candidate is not None
            and min_candidate.min_value is not None
            and min_candidate.priority >= target_candidate.priority
            and target_value < min_candidate.min_value
        ):
            payload = dict(min_candidate.explanation_payload or {})
            payload["merged_from_target"] = target_candidate.hash_payload()
            payload["resolution_policy"] = "target_raised_by_safety_min"
            return replace(
                min_candidate,
                rule_type=ResolvedTrackerConstraint.RULE_TARGET,
                min_value=None,
                max_value=None,
                target_value=float(min_candidate.min_value),
                warning_value=None,
                reason_summary=(
                    f"Effective target raised to {min_candidate.min_value} {min_candidate.unit} "
                    f"because a higher-priority minimum applies."
                ),
                explanation_payload=payload,
            )

        return target_candidate
