from __future__ import annotations

from datetime import date, timedelta

from django.db import transaction
from django.db.models import Sum

from core.models import ActivityLog, StepLog, WaterLog
from gamification.models import PointsTransaction, UserScore
from gamification.services.motivation_service import MotivationService
from gamification.services.points_service import PointsService


class ReconciliationService:
    @classmethod
    def _water_day(cls, *, user, target_date: date) -> None:
        actual_ids = {
            str(item)
            for item in WaterLog.objects.filter(user=user, date=target_date).values_list("id", flat=True)
        }
        recorded_ids = set(
            filter(
                None,
                PointsTransaction.objects.filter(
                    user=user,
                    source_type=PointsTransaction.SOURCE_HYDRATION,
                    rule_code="WATER_LOGGED",
                    event_date=target_date,
                ).values_list("source_id", flat=True),
            )
        )
        for source_id in sorted(actual_ids | recorded_ids):
            PointsService.sync_source_rule_total(
                user,
                source_type=PointsTransaction.SOURCE_HYDRATION,
                source_id=source_id,
                rule_code="WATER_LOGGED",
                desired_points=3 if source_id in actual_ids else 0,
                event_date=target_date,
                reason="Reconciled hydration points for the day.",
                metadata={"reconciled_by": "ReconciliationService"},
            )

    @classmethod
    def _nutrition_day(cls, *, user, target_date: date) -> None:
        PointsService.sync_nutrition_day_points(
            user,
            event_date=target_date,
        )

    @classmethod
    def _activity_day(cls, *, user, target_date: date) -> None:
        actual_ids = {
            str(item)
            for item in ActivityLog.objects.filter(user=user, date=target_date).values_list("id", flat=True)
        }
        recorded_ids = set(
            filter(
                None,
                PointsTransaction.objects.filter(
                    user=user,
                    source_type=PointsTransaction.SOURCE_ACTIVITY,
                    rule_code="ACTIVITY_SESSION_COMPLETED",
                    event_date=target_date,
                ).values_list("source_id", flat=True),
            )
        )
        for source_id in sorted(actual_ids | recorded_ids):
            PointsService.sync_source_rule_total(
                user,
                source_type=PointsTransaction.SOURCE_ACTIVITY,
                source_id=source_id,
                rule_code="ACTIVITY_SESSION_COMPLETED",
                desired_points=10 if source_id in actual_ids else 0,
                event_date=target_date,
                reason="Reconciled activity completion points for the day.",
                metadata={"reconciled_by": "ReconciliationService"},
            )

    @classmethod
    def _steps_day(cls, *, user, target_date: date) -> None:
        step_log = StepLog.objects.filter(user=user, date=target_date).first()
        PointsService.award_steps_points(
            user,
            step_log.steps_count if step_log is not None else 0,
            source_id=step_log.id if step_log is not None else "",
            event_date=target_date,
        )

    @classmethod
    @transaction.atomic
    def reconcile_user_day(cls, *, user, target_date: date) -> dict:
        before_transactions = PointsTransaction.objects.filter(user=user, event_date=target_date).count()
        before_points = (
            PointsTransaction.objects.filter(user=user, event_date=target_date)
            .aggregate(total=Sum("points"))
            .get("total")
            or 0
        )
        cls._water_day(user=user, target_date=target_date)
        cls._nutrition_day(user=user, target_date=target_date)
        cls._activity_day(user=user, target_date=target_date)
        cls._steps_day(user=user, target_date=target_date)
        MotivationService.refresh_daily(user=user, target_date=target_date)
        score = UserScore.rebuild_for_user(user=user)
        after_transactions = PointsTransaction.objects.filter(user=user, event_date=target_date).count()
        return {
            "user_id": user.id,
            "date": target_date.isoformat(),
            "transactions_before": before_transactions,
            "transactions_after": after_transactions,
            "transactions_created": max(after_transactions - before_transactions, 0),
            "total_points": int(score.total_points or 0),
            "level": int(score.level or 1),
            "points_before": int(before_points),
        }

    @classmethod
    def reconcile_user_range(cls, *, user, start_date: date, end_date: date) -> list[dict]:
        if end_date < start_date:
            start_date, end_date = end_date, start_date
        results = []
        cursor = start_date
        while cursor <= end_date:
            results.append(cls.reconcile_user_day(user=user, target_date=cursor))
            cursor += timedelta(days=1)
        return results
