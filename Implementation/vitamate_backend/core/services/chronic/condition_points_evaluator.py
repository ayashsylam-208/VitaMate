from __future__ import annotations

from datetime import date, timedelta

from django.utils import timezone

from core.models import (
    ConditionDailyEvaluation,
    HealthIndicatorRecord,
    ConditionMedicationLog,
    ConditionPointsAudit,
    UserCondition,
)
from gamification.models import PointsTransaction
from gamification.services.points_service import PointsService


class ConditionPointsEvaluator:
    """Centralizes chronic-condition points and audit trail updates."""

    MEDICATION_POINTS = {
        ConditionMedicationLog.STATUS_TAKEN: 3,
        ConditionMedicationLog.STATUS_TAKEN_ON_TIME: 3,
        ConditionMedicationLog.STATUS_TAKEN_LATE: 1,
        ConditionMedicationLog.STATUS_MISSED: -2,
        ConditionMedicationLog.STATUS_SNOOZED: 0,
        ConditionMedicationLog.STATUS_SKIPPED: 0,
    }
    RESTRICTION_REWARD = 5
    RESTRICTION_PENALTY = -3
    MEDICATION_STREAK_REWARD = 2
    CONDITION_STREAK_REWARD = 4
    READING_REWARD = 5
    READING_CRITICAL_REWARD = 1

    @staticmethod
    def _apply_points(
        *,
        user,
        points_delta: int,
        source_id: str,
        rule_code: str,
        event_date: date | None = None,
    ) -> None:
        if points_delta == 0:
            return
        safe_date = event_date or timezone.localdate()
        PointsService.apply_delta(
            user,
            points=points_delta,
            rule_code=rule_code,
            source_type=PointsTransaction.SOURCE_CHRONIC,
            source_id=source_id,
            event_date=safe_date,
            idempotency_key=(
                f"chronic:{user.id}:{rule_code}:{source_id}:"
                f"{safe_date.isoformat()}:{points_delta}"
            ),
        )

    @staticmethod
    def _audit(
        *,
        user_condition: UserCondition,
        event_type: str,
        points_delta: int,
        reason: str,
        explanation: str,
        medication_log: ConditionMedicationLog | None = None,
        metadata: dict | None = None,
    ) -> None:
        ConditionPointsAudit.objects.create(
            user=user_condition.user,
            user_condition=user_condition,
            medication_log=medication_log,
            event_type=event_type,
            points_delta=points_delta,
            reason=reason,
            explanation=explanation,
            metadata=metadata or {},
        )

    @classmethod
    def medication_points_for_status(
        cls,
        *,
        status: str,
        skip_reason: str = "",
    ) -> int:
        if status == ConditionMedicationLog.STATUS_SKIPPED and not skip_reason.strip():
            return -1
        return cls.MEDICATION_POINTS.get(status, 0)

    @classmethod
    def apply_medication_log_points(
        cls,
        *,
        log: ConditionMedicationLog,
        user_condition: UserCondition,
    ) -> int:
        desired_points = cls.medication_points_for_status(
            status=log.status,
            skip_reason=log.skip_reason,
        )
        points_diff = desired_points - log.points_applied
        if points_diff == 0:
            return 0

        cls._apply_points(
            user=user_condition.user,
            points_delta=points_diff,
            source_id=f"log:{log.id}",
            rule_code=f"CHRONIC_MEDICATION_{str(log.status).upper()}",
            event_date=log.scheduled_date,
        )
        log.points_applied = desired_points
        log.save(update_fields=["points_applied"])

        cls._audit(
            user_condition=user_condition,
            medication_log=log,
            event_type=ConditionPointsAudit.EVENT_MEDICATION,
            points_delta=points_diff,
            reason=f"Medication status updated to {log.status}",
            explanation=(
                "Medication adherence points are based on whether the dose was taken on time, "
                "taken late, missed, or skipped with a valid reason."
            ),
            metadata={
                "status": log.status,
                "skip_reason": log.skip_reason,
                "scheduled_date": str(log.scheduled_date),
            },
        )
        return points_diff

    @classmethod
    def desired_daily_restriction_points(cls, *, adherence_percent: float) -> int:
        if adherence_percent >= 80:
            return cls.RESTRICTION_REWARD
        if adherence_percent < 50:
            return cls.RESTRICTION_PENALTY
        return 0

    @classmethod
    def apply_daily_evaluation_points(
        cls,
        *,
        user_condition: UserCondition,
        evaluation: ConditionDailyEvaluation,
        adherence_percent: float,
        target_results: list[dict],
    ) -> int:
        desired_points_delta = cls.desired_daily_restriction_points(
            adherence_percent=adherence_percent
        )
        points_diff = desired_points_delta - evaluation.points_delta
        if points_diff:
            cls._apply_points(
                user=user_condition.user,
                points_delta=points_diff,
                source_id=f"evaluation:{evaluation.id}",
                rule_code=f"CHRONIC_RESTRICTION_{desired_points_delta}",
                event_date=evaluation.evaluation_date,
            )
            cls._audit(
                user_condition=user_condition,
                event_type=ConditionPointsAudit.EVENT_RESTRICTION,
                points_delta=points_diff,
                reason="Daily chronic-condition adherence recalculated",
                explanation=(
                    "Behavior-based chronic-condition points use the daily percentage of in-range "
                    "condition targets. This avoids over-penalizing users when data is missing."
                ),
                metadata={
                    "evaluation_date": str(evaluation.evaluation_date),
                    "restriction_adherence_percent": adherence_percent,
                    "target_count": len(target_results),
                },
            )
        return desired_points_delta

    @classmethod
    def apply_streak_bonus(
        cls,
        *,
        user_condition: UserCondition,
        on_date: date,
    ) -> int:
        total_awarded = 0
        med_streak = 0
        lifestyle_streak = 0

        evaluations = list(
            user_condition.daily_evaluations.order_by("-evaluation_date").values_list(
                "evaluation_date",
                "medication_adherence_percent",
                "restriction_adherence_percent",
            )
        )
        cursor = on_date
        for eval_date, med_percent, restriction_percent in evaluations:
            if eval_date != cursor:
                break
            if med_percent >= 100:
                med_streak += 1
            else:
                med_streak = 0
            if restriction_percent >= 80:
                lifestyle_streak += 1
            else:
                lifestyle_streak = 0
            cursor = cursor - timedelta(days=1)

        milestones: list[tuple[str, int, int, str]] = []
        if med_streak >= 3 and med_streak % 3 == 0:
            milestones.append(
                (
                    "medication_completion",
                    cls.MEDICATION_STREAK_REWARD,
                    med_streak,
                    "Medication completion streak reached a new milestone.",
                )
            )
        if lifestyle_streak >= 7 and lifestyle_streak % 7 == 0:
            milestones.append(
                (
                    "condition_adherence",
                    cls.CONDITION_STREAK_REWARD,
                    lifestyle_streak,
                    "Condition-safe behavior streak reached a weekly milestone.",
                )
            )

        for milestone_key, reward, streak_length, message in milestones:
            already_awarded = ConditionPointsAudit.objects.filter(
                user=user_condition.user,
                user_condition=user_condition,
                event_type=ConditionPointsAudit.EVENT_STREAK,
                metadata__milestone=milestone_key,
                metadata__date=str(on_date),
            ).exists()
            if already_awarded:
                continue
            cls._apply_points(
                user=user_condition.user,
                points_delta=reward,
                source_id=f"streak:{milestone_key}:{on_date.isoformat()}",
                rule_code=f"CHRONIC_STREAK_{milestone_key.upper()}",
                event_date=on_date,
            )
            cls._audit(
                user_condition=user_condition,
                event_type=ConditionPointsAudit.EVENT_STREAK,
                points_delta=reward,
                reason=message,
                explanation=(
                    "Streak bonuses reward repeated healthy behavior for chronic-condition care "
                    "without dominating the base daily points system."
                ),
                metadata={
                    "milestone": milestone_key,
                    "streak_length": streak_length,
                    "date": str(on_date),
                },
            )
            total_awarded += reward

        return total_awarded

    @classmethod
    def apply_reading_points(
        cls,
        *,
        user_condition: UserCondition,
        record: HealthIndicatorRecord,
        evaluation: dict,
    ) -> int:
        risk_level = str(evaluation.get("risk_level") or "").strip().lower()
        desired_points = cls.READING_CRITICAL_REWARD if risk_level == "critical" else cls.READING_REWARD
        cls._apply_points(
            user=user_condition.user,
            points_delta=desired_points,
            source_id=f"reading:{record.id}",
            rule_code="CHRONIC_READING_LOGGED",
            event_date=record.recorded_at.date(),
        )
        cls._audit(
            user_condition=user_condition,
            event_type=ConditionPointsAudit.EVENT_SYSTEM,
            points_delta=desired_points,
            reason=f"Logged {record.indicator_type or record.indicator_name} reading",
            explanation=(
                "Reading points encourage consistent self-monitoring while still reducing the reward when "
                "the workflow flags a critical reading."
            ),
            metadata={
                "indicator_record_id": record.id,
                "indicator_type": record.indicator_type or record.indicator_name,
                "classification": record.classification,
                "risk_level": record.risk_level,
            },
        )
        return desired_points
