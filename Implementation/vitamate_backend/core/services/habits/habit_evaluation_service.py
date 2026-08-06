from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta

from django.utils import timezone

from core.models import UnhealthyHabit, UnhealthyHabitLog


STATUS_NOT_LOGGED = "not_logged"
STATUS_IN_PROGRESS = "in_progress"
STATUS_WITHIN_PLAN = "within_plan"
STATUS_WITHIN_PLAN_SLEEP_RISK = "within_plan_with_sleep_risk"
STATUS_APPROACHING_LIMIT = "approaching_limit"
STATUS_LIMIT_REACHED = "limit_reached"
STATUS_LIMIT_EXCEEDED = "limit_exceeded"
STATUS_CONFIRMED_ABSTINENT = "confirmed_abstinent"
STATUS_RELAPSE = "relapse"
STATUS_PAUSED = "paused"
STATUS_NOT_APPLICABLE = "not_applicable"
STATUS_INSUFFICIENT_DATA = "insufficient_data"


@dataclass(frozen=True)
class HabitEvaluation:
    habit_id: int | None
    date: date
    habit_type: str
    strategy: str
    status: str
    score: int
    is_complete: bool
    is_applicable: bool
    is_required: bool
    data_coverage: float
    current: float
    target: float | None
    remaining: float | None
    confirmed: bool
    cutoff_status: str
    next_action: dict
    feedback: dict
    in_app_events: list[dict]

    def as_dict(self) -> dict:
        return {
            "habit_id": self.habit_id,
            "date": self.date.isoformat(),
            "habit_type": self.habit_type,
            "strategy": self.strategy,
            "status": self.status,
            "score": self.score,
            "is_complete": self.is_complete,
            "is_applicable": self.is_applicable,
            "is_required": self.is_required,
            "data_coverage": self.data_coverage,
            "current": self.current,
            "target": self.target,
            "remaining": self.remaining,
            "confirmed": self.confirmed,
            "cutoff_status": self.cutoff_status,
            "next_action": self.next_action,
            "feedback": self.feedback,
            "in_app_events": self.in_app_events,
        }


class HabitEvaluationService:
    VERSION = "habit-evaluation-v1"

    @classmethod
    def evaluate_habit(
        cls,
        *,
        habit: UnhealthyHabit,
        target_date: date | None = None,
    ) -> dict:
        target_date = target_date or timezone.localdate()
        if habit.status != UnhealthyHabit.STATUS_ACTIVE:
            return HabitEvaluation(
                habit_id=habit.id,
                date=target_date,
                habit_type=habit.habit_type,
                strategy="paused",
                status=STATUS_NOT_APPLICABLE,
                score=0,
                is_complete=False,
                is_applicable=False,
                is_required=False,
                data_coverage=1.0,
                current=0,
                target=None,
                remaining=None,
                confirmed=False,
                cutoff_status="not_applicable",
                next_action={},
                feedback={
                    "type": "neutral",
                    "message_key": "habit_paused",
                    "message": "This habit plan is paused.",
                },
                in_app_events=[],
            ).as_dict()

        logs = list(habit.logs.filter(log_date=target_date).order_by("logged_at", "id"))
        use_logs = [log for log in logs if cls._is_use_log(log)]
        checkins = [log for log in logs if log.is_abstinence_checkin]
        plan = getattr(habit, "plan", None)
        target = cls._target_for(habit=habit, target_date=target_date)
        strategy = cls._strategy_for(habit=habit, target=target)
        current = cls._current_for(habit=habit, target_date=target_date, use_logs=use_logs)
        confirmed = bool(use_logs or checkins)
        cutoff_status = cls._cutoff_status(habit=habit, logs=use_logs)

        if not confirmed:
            return cls._evaluation(
                habit=habit,
                target_date=target_date,
                strategy=strategy,
                status=STATUS_NOT_LOGGED,
                current=current,
                target=target,
                confirmed=False,
                cutoff_status=cutoff_status,
                next_action=cls._next_action(habit=habit, status=STATUS_NOT_LOGGED),
            ).as_dict()

        if checkins and not use_logs:
            return cls._evaluation(
                habit=habit,
                target_date=target_date,
                strategy=strategy,
                status=STATUS_CONFIRMED_ABSTINENT,
                current=0,
                target=target,
                confirmed=True,
                cutoff_status=cutoff_status,
                next_action={},
            ).as_dict()

        if any(log.is_relapse for log in use_logs):
            status = STATUS_RELAPSE
        elif target is None:
            status = STATUS_INSUFFICIENT_DATA
        elif current > target:
            status = STATUS_LIMIT_EXCEEDED
        elif target > 0 and current == target:
            status = STATUS_LIMIT_REACHED
        elif target > 0 and current >= target * 0.8:
            status = STATUS_APPROACHING_LIMIT
        else:
            status = STATUS_WITHIN_PLAN

        if (
            habit.habit_type == UnhealthyHabit.TYPE_CAFFEINE
            and status == STATUS_WITHIN_PLAN
            and cutoff_status == "after_cutoff"
        ):
            status = STATUS_WITHIN_PLAN_SLEEP_RISK

        return cls._evaluation(
            habit=habit,
            target_date=target_date,
            strategy=strategy,
            status=status,
            current=current,
            target=target,
            confirmed=True,
            cutoff_status=cutoff_status,
            next_action=cls._next_action(habit=habit, status=status),
        ).as_dict()

    @classmethod
    def evaluate_user(cls, *, user, target_date: date | None = None) -> dict:
        target_date = target_date or timezone.localdate()
        habits = list(
            UnhealthyHabit.objects.filter(user=user)
            .select_related("plan", "baseline")
            .prefetch_related("logs")
            .order_by("habit_type", "-created_at", "-id")
        )
        latest_by_type: dict[str, UnhealthyHabit] = {}
        for habit in habits:
            latest_by_type.setdefault(habit.habit_type, habit)

        evaluations = [
            cls.evaluate_habit(habit=habit, target_date=target_date)
            for habit in latest_by_type.values()
        ]
        active = [item for item in evaluations if item["is_applicable"]]
        confirmed = [item for item in active if item["confirmed"]]
        complete = [item for item in active if item["is_complete"]]
        relapses = [
            item
            for item in active
            if item["status"] in {STATUS_RELAPSE, STATUS_LIMIT_EXCEEDED}
        ]
        score = (
            int(round(sum(item["score"] for item in active) / len(active)))
            if active
            else 0
        )
        return {
            "date": target_date.isoformat(),
            "score_version": cls.VERSION,
            "active_count": len(active),
            "confirmed_count": len(confirmed),
            "completed_count": len(complete),
            "relapses_today": len(relapses),
            "score": score,
            "evaluations": evaluations,
        }

    @classmethod
    def _evaluation(
        cls,
        *,
        habit: UnhealthyHabit,
        target_date: date,
        strategy: str,
        status: str,
        current: float,
        target: float | None,
        confirmed: bool,
        cutoff_status: str,
        next_action: dict,
    ) -> HabitEvaluation:
        remaining = None if target is None else max(round(float(target) - float(current), 2), 0)
        is_complete = status in {STATUS_WITHIN_PLAN, STATUS_CONFIRMED_ABSTINENT}
        if habit.habit_type == UnhealthyHabit.TYPE_CAFFEINE and status == STATUS_WITHIN_PLAN_SLEEP_RISK:
            is_complete = True
        score = cls._score(status=status, current=current, target=target)
        feedback = cls._feedback(habit=habit, status=status, cutoff_status=cutoff_status)
        return HabitEvaluation(
            habit_id=habit.id,
            date=target_date,
            habit_type=habit.habit_type,
            strategy=strategy,
            status=status,
            score=score,
            is_complete=is_complete,
            is_applicable=True,
            is_required=True,
            data_coverage=1.0 if confirmed else 0.0,
            current=round(float(current), 2),
            target=round(float(target), 2) if target is not None else None,
            remaining=remaining,
            confirmed=confirmed,
            cutoff_status=cutoff_status,
            next_action=next_action,
            feedback=feedback,
            in_app_events=cls._events(
                habit=habit,
                status=status,
                feedback=feedback,
                cutoff_status=cutoff_status,
            ),
        )

    @staticmethod
    def _is_use_log(log: UnhealthyHabitLog) -> bool:
        if log.is_abstinence_checkin:
            return False
        if log.is_relapse:
            return True
        return float(log.quantity or 0) > 0 or float(log.caffeine_mg or 0) > 0

    @classmethod
    def _current_for(
        cls,
        *,
        habit: UnhealthyHabit,
        target_date: date,
        use_logs: list[UnhealthyHabitLog],
    ) -> float:
        logs = use_logs
        if habit.habit_type == UnhealthyHabit.TYPE_FAST_FOOD:
            plan = getattr(habit, "plan", None)
            if plan and plan.weekly_limit is not None:
                week_start = target_date - timedelta(days=target_date.weekday())
                logs = list(
                    habit.logs.filter(
                        log_date__gte=week_start,
                        log_date__lte=target_date,
                        is_abstinence_checkin=False,
                    )
                )
        return sum(cls._metric_from_log(habit=habit, log=log) for log in logs)

    @staticmethod
    def _metric_from_log(*, habit: UnhealthyHabit, log: UnhealthyHabitLog) -> float:
        if habit.habit_type == UnhealthyHabit.TYPE_CAFFEINE:
            caffeine = float(log.caffeine_mg or 0)
            return caffeine if caffeine > 0 else float(log.quantity or 0)
        return float(log.quantity or 0)

    @classmethod
    def _target_for(cls, *, habit: UnhealthyHabit, target_date: date) -> float | None:
        del target_date
        plan = getattr(habit, "plan", None)
        if plan is None:
            return None
        if habit.goal_type == UnhealthyHabit.GOAL_QUIT:
            return 0.0
        if habit.habit_type == UnhealthyHabit.TYPE_FAST_FOOD:
            if plan.weekly_limit is not None:
                return float(plan.weekly_limit)
            if plan.daily_limit is not None:
                return float(plan.daily_limit)
            return None
        if plan.daily_limit is not None:
            return float(plan.daily_limit)
        if plan.target_quantity is not None:
            return float(plan.target_quantity)
        return None

    @staticmethod
    def _strategy_for(*, habit: UnhealthyHabit, target: float | None) -> str:
        if habit.goal_type == UnhealthyHabit.GOAL_QUIT or target == 0:
            return "abstinence"
        if habit.habit_type == UnhealthyHabit.TYPE_FAST_FOOD:
            plan = getattr(habit, "plan", None)
            if plan and plan.weekly_limit is not None:
                return "weekly_limit"
        if target is not None:
            return "daily_limit"
        return "reduction"

    @staticmethod
    def _cutoff_status(*, habit: UnhealthyHabit, logs: list[UnhealthyHabitLog]) -> str:
        if habit.habit_type != UnhealthyHabit.TYPE_CAFFEINE:
            return "not_applicable"
        plan = getattr(habit, "plan", None)
        cutoff = getattr(plan, "cutoff_time", None)
        if cutoff is None:
            return "no_cutoff"
        for log in logs:
            local_time = timezone.localtime(log.logged_at).time()
            if local_time >= cutoff:
                return "after_cutoff"
        return "before_cutoff"

    @staticmethod
    def _score(*, status: str, current: float, target: float | None) -> int:
        if status == STATUS_NOT_LOGGED:
            return 0
        if status in {STATUS_CONFIRMED_ABSTINENT, STATUS_WITHIN_PLAN, STATUS_WITHIN_PLAN_SLEEP_RISK}:
            return 100 if status == STATUS_CONFIRMED_ABSTINENT else 80
        if status == STATUS_APPROACHING_LIMIT:
            return 65
        if status == STATUS_LIMIT_REACHED:
            return 50
        if status in {STATUS_LIMIT_EXCEEDED, STATUS_RELAPSE}:
            if target is None or target <= 0:
                return 0
            over_ratio = max((current - target) / target, 0)
            return max(0, int(round(40 - (over_ratio * 40))))
        if status == STATUS_INSUFFICIENT_DATA:
            return 20
        return 0

    @staticmethod
    def _next_action(*, habit: UnhealthyHabit, status: str) -> dict:
        route = "/habits"
        if status == STATUS_NOT_LOGGED:
            return {
                "type": "log_or_check_in",
                "title": "Check in on your habit plan",
                "subtitle": "Log use or confirm no-use so today is explicit.",
                "route": route,
            }
        if status == STATUS_APPROACHING_LIMIT:
            return {
                "type": "avoid_limit",
                "title": "Protect the rest of today",
                "subtitle": "You are close to the planned limit.",
                "route": route,
            }
        if status in {STATUS_LIMIT_REACHED, STATUS_LIMIT_EXCEEDED, STATUS_RELAPSE}:
            return {
                "type": "review_trigger",
                "title": "Review the trigger",
                "subtitle": "Use the next choice to get back to the plan.",
                "route": route,
            }
        if habit.habit_type == UnhealthyHabit.TYPE_CAFFEINE and status == STATUS_WITHIN_PLAN_SLEEP_RISK:
            return {
                "type": "avoid_after_cutoff",
                "title": "Avoid more caffeine tonight",
                "subtitle": "This helps protect sleep quality.",
                "route": route,
            }
        return {}

    @staticmethod
    def _feedback(*, habit: UnhealthyHabit, status: str, cutoff_status: str) -> dict:
        if status == STATUS_CONFIRMED_ABSTINENT:
            return {
                "type": "positive",
                "message_key": "habit_abstinence_confirmed",
                "message": "No-use confirmed for today.",
            }
        if status == STATUS_WITHIN_PLAN:
            return {
                "type": "positive",
                "message_key": "habit_within_plan",
                "message": "Logged and still within today's plan.",
            }
        if status == STATUS_WITHIN_PLAN_SLEEP_RISK:
            return {
                "type": "caution",
                "message_key": "late_caffeine",
                "message": "This is within your amount limit, but it is late enough to affect sleep.",
            }
        if status == STATUS_APPROACHING_LIMIT:
            return {
                "type": "caution",
                "message_key": "habit_approaching_limit",
                "message": "You are close to the planned limit.",
            }
        if status == STATUS_LIMIT_REACHED:
            return {
                "type": "caution",
                "message_key": "habit_limit_reached",
                "message": "You reached the planned limit. The next choice matters.",
            }
        if status == STATUS_LIMIT_EXCEEDED:
            return {
                "type": "warning",
                "message_key": "habit_limit_exceeded",
                "message": "You crossed the planned limit. Review the trigger and continue.",
            }
        if status == STATUS_RELAPSE:
            return {
                "type": "warning",
                "message_key": "habit_relapse_logged",
                "message": "Relapse logged. This is data for the next plan adjustment.",
            }
        if status == STATUS_INSUFFICIENT_DATA:
            return {
                "type": "neutral",
                "message_key": "habit_insufficient_data",
                "message": "More detail is needed for an accurate habit evaluation.",
            }
        return {
            "type": "neutral",
            "message_key": "habit_not_logged",
            "message": "Check in explicitly to update today's habit status.",
        }

    @staticmethod
    def _events(
        *,
        habit: UnhealthyHabit,
        status: str,
        feedback: dict,
        cutoff_status: str,
    ) -> list[dict]:
        if status == STATUS_NOT_LOGGED:
            return []
        event_type = str(feedback.get("message_key") or status)
        severity = str(feedback.get("type") or "neutral")
        if status == STATUS_WITHIN_PLAN_SLEEP_RISK:
            event_type = "late_caffeine"
        return [
            {
                "type": event_type,
                "severity": severity,
                "title": HabitEvaluationService._event_title(habit=habit, status=status),
                "body": str(feedback.get("message") or ""),
                "route": "/habits",
                "habit_type": habit.habit_type,
                "status": status,
                "cutoff_status": cutoff_status,
            }
        ]

    @staticmethod
    def _event_title(*, habit: UnhealthyHabit, status: str) -> str:
        label = habit.title or habit.get_habit_type_display()
        if status == STATUS_LIMIT_EXCEEDED:
            return f"{label} plan exceeded"
        if status == STATUS_RELAPSE:
            return f"{label} relapse logged"
        if status == STATUS_WITHIN_PLAN_SLEEP_RISK:
            return "Late caffeine logged"
        if status == STATUS_CONFIRMED_ABSTINENT:
            return f"{label} no-use confirmed"
        return f"{label} updated"
