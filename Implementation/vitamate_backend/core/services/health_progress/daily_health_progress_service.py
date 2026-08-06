from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Any

from django.db.models import Sum
from django.utils import timezone

from core.models import (
    ConditionMedication,
    MealLog,
    SleepLog,
    UnhealthyHabit,
    UnhealthyHabitLog,
    WaterLog,
)
from core.services.constraints import EffectiveConstraintReader
from core.services.health_progress.movement_evaluator import MovementEvaluator
from core.services.medication_adherence_service import MedicationAdherenceService


STATUS_NOT_LOGGED = "not_logged"
STATUS_NOT_STARTED = "not_started"
STATUS_IN_PROGRESS = "in_progress"
STATUS_COMPLETED = "completed"
STATUS_FAILED = "failed"
STATUS_NOT_APPLICABLE = "not_applicable"
STATUS_INSUFFICIENT_DATA = "insufficient_data"


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(round(float(value)))
    except (TypeError, ValueError):
        return default


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _percent(current: float, target: float) -> int:
    if target <= 0:
        return 0
    return int(round(min(max(current / target, 0.0), 1.0) * 100))


@dataclass(frozen=True)
class DomainEvaluation:
    domain: str
    score: int
    status: str
    data_coverage: int
    is_applicable: bool
    is_essential: bool
    weight: float
    target_source: str
    components: list[dict]
    next_action: dict | None = None

    def as_dict(self) -> dict:
        return {
            "domain": self.domain,
            "score": int(max(0, min(self.score, 100))),
            "status": self.status,
            "data_coverage": int(max(0, min(self.data_coverage, 100))),
            "is_applicable": bool(self.is_applicable),
            "is_essential": bool(self.is_essential),
            "weight": float(self.weight),
            "target_source": self.target_source,
            "components": self.components,
            "next_action": self.next_action,
        }


class DailyHealthProgressService:
    SCORE_VERSION = "daily-health-v1"
    REQUIRED_MEALS = 3

    DOMAIN_PRIORITY = {
        "medication": 0,
        "nutrition": 1,
        "hydration": 2,
        "movement": 3,
        "sleep": 4,
        "habits": 5,
    }

    @classmethod
    def evaluate(cls, *, user, target_date: date | None = None) -> dict:
        target_date = target_date or timezone.localdate()
        profile = getattr(user, "userprofile", None)
        domains = [
            cls._nutrition(user=user, profile=profile, target_date=target_date),
            cls._hydration(user=user, profile=profile, target_date=target_date),
            cls._movement(user=user, profile=profile, target_date=target_date),
            cls._sleep(user=user, profile=profile, target_date=target_date),
            cls._medication(user=user, target_date=target_date),
            cls._habits(user=user, target_date=target_date),
        ]
        applicable = [domain for domain in domains if domain.is_applicable]
        weighted_total = sum(domain.score * domain.weight for domain in applicable)
        total_weight = sum(domain.weight for domain in applicable)
        progress = int(round(weighted_total / total_weight)) if total_weight > 0 else 0

        essential = [
            domain
            for domain in domains
            if domain.is_applicable and domain.is_essential
        ]
        completed_essential = [
            domain for domain in essential if domain.status == STATUS_COMPLETED
        ]
        coverage = (
            int(round(sum(domain.data_coverage for domain in essential) / len(essential)))
            if essential
            else 100
        )
        has_critical_overdue = any(
            domain.domain == "medication" and domain.status == STATUS_FAILED
            for domain in essential
        )
        has_missing_essential = any(
            domain.status in {STATUS_NOT_LOGGED, STATUS_NOT_STARTED, STATUS_INSUFFICIENT_DATA}
            for domain in essential
        )
        daily_complete = (
            bool(essential)
            and len(completed_essential) == len(essential)
            and coverage >= 80
            and not has_critical_overdue
            and not has_missing_essential
        )

        if daily_complete:
            completion_status = STATUS_COMPLETED
        elif not any(domain.data_coverage > 0 for domain in essential):
            completion_status = STATUS_NOT_STARTED
        elif coverage < 80 and has_missing_essential:
            completion_status = STATUS_INSUFFICIENT_DATA
        else:
            completion_status = STATUS_IN_PROGRESS

        focus = cls._focus(domains=domains, daily_complete=daily_complete)
        daily_health = {
            "date": target_date.isoformat(),
            "score_version": cls.SCORE_VERSION,
            "progress_percent": progress,
            "score": progress,
            "coverage_percent": coverage,
            "completion_status": completion_status,
            "daily_complete": daily_complete,
            "completed_essential": len(completed_essential),
            "total_essential": len(essential),
            "critical_overdue": has_critical_overdue,
            "message": cls._message(
                daily_complete=daily_complete,
                completion_status=completion_status,
                focus=focus,
            ),
        }
        return {
            "daily_health": daily_health,
            "domains": [domain.as_dict() for domain in domains],
            "focus": focus,
        }

    @classmethod
    def _nutrition(cls, *, user, profile, target_date: date) -> DomainEvaluation:
        meals = list(
            MealLog.objects.filter(user=user, date=target_date)
            .exclude(meal_type=MealLog.BEVERAGE_DRINK if hasattr(MealLog, "BEVERAGE_DRINK") else "drink")
            .only("snapshot_calories_kcal", "quantity_grams", "meal_type", "food")
        )
        meal_count = len(meals)
        calories = sum(getattr(meal, "total_calories", 0) for meal in meals)
        profile_target = _safe_int(getattr(profile, "daily_calorie_target", 0), 2000)
        if profile_target <= 0:
            profile_target = 2000
        effective_target = EffectiveConstraintReader.get_effective_constraint(
            user=user,
            tracker_type="nutrition",
            constraint_key="calories_kcal",
            default_value=profile_target,
            default_unit="kcal",
            default_source="profile_fallback",
        )
        calorie_target = _safe_int(effective_target.value, profile_target)
        meal_progress = _percent(meal_count, cls.REQUIRED_MEALS)
        calorie_progress = _percent(calories, calorie_target)
        score = int(round((meal_progress * 0.7) + (calorie_progress * 0.3)))
        if meal_count <= 0:
            status = STATUS_NOT_LOGGED
            next_action = {
                "title": "Log your first meal",
                "subtitle": "Nutrition is essential before the day can be complete.",
                "route": "/meals",
            }
        elif meal_count >= cls.REQUIRED_MEALS:
            status = STATUS_COMPLETED
            next_action = None
        else:
            status = STATUS_IN_PROGRESS
            remaining = cls.REQUIRED_MEALS - meal_count
            next_action = {
                "title": "Complete today's meals",
                "subtitle": f"{remaining} meal{'s' if remaining != 1 else ''} left for nutrition coverage.",
                "route": "/meals",
            }
        return DomainEvaluation(
            domain="nutrition",
            score=score,
            status=status,
            data_coverage=meal_progress,
            is_applicable=True,
            is_essential=True,
            weight=1.2,
            target_source=effective_target.source_type,
            components=[
                {
                    "key": "meals",
                    "label": "Meals logged",
                    "current": meal_count,
                    "target": cls.REQUIRED_MEALS,
                    "unit": "meals",
                    "progress_percent": meal_progress,
                },
                {
                    "key": "calories",
                    "label": "Calories",
                    "current": calories,
                    "target": calorie_target,
                    "unit": "kcal",
                    "progress_percent": calorie_progress,
                },
            ],
            next_action=next_action,
        )

    @classmethod
    def _hydration(cls, *, user, profile, target_date: date) -> DomainEvaluation:
        current_liters = _safe_float(
            WaterLog.objects.filter(user=user, date=target_date)
            .aggregate(total=Sum("amount_liter"))
            .get("total")
        )
        profile_target = _safe_float(getattr(profile, "daily_water_target", 0), 2.5)
        if profile_target <= 0:
            profile_target = 2.5
        effective_target = EffectiveConstraintReader.get_effective_constraint(
            user=user,
            tracker_type="hydration",
            constraint_key="daily_water_liters",
            default_value=profile_target,
            default_unit="liters",
            default_source="profile_fallback",
        )
        target_liters = _safe_float(effective_target.value, profile_target)
        progress = _percent(current_liters, target_liters)
        if current_liters <= 0:
            status = STATUS_NOT_LOGGED
            next_action = {
                "title": "Log your first water intake",
                "subtitle": "Hydration progress starts with one glass.",
                "route": "/water",
            }
        elif progress >= 100:
            status = STATUS_COMPLETED
            next_action = None
        else:
            status = STATUS_IN_PROGRESS
            remaining_ml = max(int(round((target_liters - current_liters) * 1000)), 0)
            next_action = {
                "title": "Keep hydration moving",
                "subtitle": f"{remaining_ml} ml left for today's water goal.",
                "route": "/water",
            }
        return DomainEvaluation(
            domain="hydration",
            score=progress,
            status=status,
            data_coverage=100 if current_liters > 0 else 0,
            is_applicable=True,
            is_essential=True,
            weight=1.0,
            target_source=effective_target.source_type,
            components=[
                {
                    "key": "water",
                    "label": "Water",
                    "current": round(current_liters, 2),
                    "target": round(target_liters, 2),
                    "unit": "L",
                    "progress_percent": progress,
                }
            ],
            next_action=next_action,
        )

    @classmethod
    def _movement(cls, *, user, profile, target_date: date) -> DomainEvaluation:
        movement = MovementEvaluator.evaluate(user=user, target_date=target_date)
        movement_target_sources = dict(movement.get("target_sources") or {})
        steps_component = dict(movement["components"]["steps"])
        exercise_component = dict(movement["components"]["exercise"])
        steps = _safe_int(steps_component.get("current"))
        step_target = _safe_int(steps_component.get("target"))
        activity_minutes = _safe_int(exercise_component.get("current"))
        minute_target = _safe_int(exercise_component.get("target"))
        active_calories = dict(movement.get("active_calories") or {})
        activity_burn = _safe_int(active_calories.get("value"))
        burn_target = _safe_int(active_calories.get("target"))
        burn_progress = _safe_int(active_calories.get("percent"))
        score = _safe_int(movement.get("score"))
        is_complete = bool(movement.get("is_complete"))
        has_data = steps > 0 or activity_minutes > 0 or activity_burn > 0

        if movement.get("status") == STATUS_NOT_APPLICABLE:
            status = STATUS_NOT_APPLICABLE
            next_action = None
            is_applicable = False
            is_essential = False
        elif not has_data:
            status = STATUS_NOT_LOGGED
            next_action = {
                "title": "Add movement today",
                "subtitle": "Steps or one short activity session can move this goal.",
                "route": "/activities",
            }
            is_applicable = True
            is_essential = True
        elif is_complete:
            status = STATUS_COMPLETED
            next_action = None
            is_applicable = True
            is_essential = True
        else:
            status = STATUS_IN_PROGRESS
            next_action = movement.get("next_action") or {
                "title": "One more movement push",
                "subtitle": "A short walk or workout can close today's movement goal.",
                "route": "/activities",
            }
            is_applicable = True
            is_essential = True
        return DomainEvaluation(
            domain="movement",
            score=score,
            status=status,
            data_coverage=_safe_int(movement.get("coverage"), 100 if has_data else 0),
            is_applicable=is_applicable,
            is_essential=is_essential,
            weight=1.0,
            target_source=(
                movement_target_sources.get("steps")
                or movement_target_sources.get("active_burn")
                or "profile_fallback"
            ),
            components=[
                {
                    "key": "steps",
                    "label": "Steps",
                    "current": steps,
                    "target": step_target,
                    "unit": "steps",
                    "progress_percent": _safe_int(steps_component.get("progress_percent")),
                    "required": bool(steps_component.get("required")),
                    "status": steps_component.get("status"),
                },
                {
                    "key": "activity_minutes",
                    "label": "Activity minutes",
                    "current": activity_minutes,
                    "target": minute_target,
                    "unit": "min",
                    "progress_percent": _safe_int(exercise_component.get("progress_percent")),
                    "required": bool(exercise_component.get("required")),
                    "status": exercise_component.get("status"),
                },
                {
                    "key": "active_burn",
                    "label": "Active burn",
                    "current": activity_burn,
                    "target": burn_target,
                    "unit": "kcal",
                    "progress_percent": burn_progress,
                    "required": False,
                    "status": STATUS_COMPLETED if burn_progress >= 100 else STATUS_IN_PROGRESS,
                },
            ],
            next_action=next_action,
        )

    @classmethod
    def _sleep(cls, *, user, profile, target_date: date) -> DomainEvaluation:
        logs = list(SleepLog.objects.filter(user=user, date=target_date))
        current_hours = round(sum(_safe_float(log.duration_hours) for log in logs), 2)
        profile_target = _safe_float(getattr(profile, "recommended_sleep_hours", 0), 8.0)
        if profile_target <= 0:
            profile_target = 8.0
        effective_target = EffectiveConstraintReader.get_effective_constraint(
            user=user,
            tracker_type="sleep",
            constraint_key="sleep_hours",
            default_value=profile_target,
            default_unit="hours",
            default_source="profile_fallback",
        )
        target_hours = _safe_float(effective_target.value, profile_target)
        progress = _percent(current_hours, target_hours)
        if current_hours <= 0:
            status = STATUS_NOT_LOGGED
            next_action = {
                "title": "Log last night's sleep",
                "subtitle": "Sleep data is part of the daily health picture.",
                "route": "/sleep",
            }
        elif progress >= 100:
            status = STATUS_COMPLETED
            next_action = None
        else:
            status = STATUS_IN_PROGRESS
            next_action = {
                "title": "Improve sleep coverage",
                "subtitle": f"{round(max(target_hours - current_hours, 0), 1)} h left against your target.",
                "route": "/sleep",
            }
        return DomainEvaluation(
            domain="sleep",
            score=progress,
            status=status,
            data_coverage=100 if current_hours > 0 else 0,
            is_applicable=True,
            is_essential=True,
            weight=1.0,
            target_source=effective_target.source_type,
            components=[
                {
                    "key": "sleep",
                    "label": "Sleep",
                    "current": current_hours,
                    "target": round(target_hours, 2),
                    "unit": "h",
                    "progress_percent": progress,
                }
            ],
            next_action=next_action,
        )

    @classmethod
    def _medication(cls, *, user, target_date: date) -> DomainEvaluation:
        counts = MedicationAdherenceService.counts_for_day(
            user=user,
            target_date=target_date,
        )
        total = _safe_int(counts.get("today_total_doses"))
        taken = _safe_int(counts.get("taken_today"))
        pending = _safe_int(counts.get("pending_today"))
        missed = _safe_int(counts.get("missed_today"))
        overdue = _safe_int(counts.get("overdue_today"))
        active_schedule_exists = (
            ConditionMedication.objects.filter(user=user, is_active=True, is_prn=False)
            .filter(schedules__is_active=True)
            .distinct()
            .exists()
        )
        is_applicable = active_schedule_exists or total > 0
        if not is_applicable:
            return DomainEvaluation(
                domain="medication",
                score=0,
                status=STATUS_NOT_APPLICABLE,
                data_coverage=100,
                is_applicable=False,
                is_essential=False,
                weight=1.3,
                target_source="medication_plan",
                components=[],
                next_action=None,
            )

        score = _percent(taken, total) if total > 0 else 0
        if total <= 0:
            status = STATUS_NOT_LOGGED
            next_action = {
                "title": "Review medication schedule",
                "subtitle": "A medication plan exists but no dose is generated for today.",
                "route": "/medications",
            }
        elif missed > 0 or overdue > 0:
            status = STATUS_FAILED
            next_action = {
                "title": "Resolve overdue medication",
                "subtitle": "Medication adherence is a health-critical task.",
                "route": "/medications",
            }
        elif taken >= total:
            status = STATUS_COMPLETED
            next_action = None
        elif pending > 0:
            status = STATUS_IN_PROGRESS
            next_action = {
                "title": "Take pending medication",
                "subtitle": f"{pending} dose{'s' if pending != 1 else ''} still pending today.",
                "route": "/medications",
            }
        else:
            status = STATUS_IN_PROGRESS
            next_action = {
                "title": "Update medication status",
                "subtitle": "Confirm today's medication plan.",
                "route": "/medications",
            }
        return DomainEvaluation(
            domain="medication",
            score=score,
            status=status,
            data_coverage=100 if total > 0 else 0,
            is_applicable=True,
            is_essential=True,
            weight=1.3,
            target_source="medication_plan",
            components=[
                {
                    "key": "doses",
                    "label": "Medication doses",
                    "current": taken,
                    "target": total,
                    "unit": "doses",
                    "progress_percent": score,
                },
                {
                    "key": "pending",
                    "label": "Pending",
                    "current": pending,
                    "target": total,
                    "unit": "doses",
                    "progress_percent": _percent(total - pending, total) if total else 0,
                },
            ],
            next_action=next_action,
        )

    @classmethod
    def _habits(cls, *, user, target_date: date) -> DomainEvaluation:
        from core.services.habits import HabitEvaluationService

        summary = HabitEvaluationService.evaluate_user(
            user=user,
            target_date=target_date,
        )
        evaluations = [
            item for item in summary.get("evaluations", []) if item.get("is_applicable")
        ]
        if not evaluations:
            return DomainEvaluation(
                domain="habits",
                score=0,
                status=STATUS_NOT_APPLICABLE,
                data_coverage=100,
                is_applicable=False,
                is_essential=False,
                weight=0.5,
                target_source="habit_plan",
                components=[],
                next_action=None,
            )
        relapse_count = sum(
            1
            for item in evaluations
            if item.get("status") in {STATUS_FAILED, "relapse", "limit_exceeded"}
        )
        missing_count = sum(1 for item in evaluations if item.get("status") == STATUS_NOT_LOGGED)
        completed_count = sum(1 for item in evaluations if item.get("is_complete"))
        if relapse_count > 0:
            status = STATUS_FAILED
            score = 0
            next_action = {
                "title": "Review habit plan",
                "subtitle": "A relapse or over-limit event was logged today.",
                "route": "/habits",
            }
        elif missing_count > 0:
            status = STATUS_NOT_LOGGED
            score = int(summary.get("score") or 0)
            next_action = {
                "title": "Check in on habit plans",
                "subtitle": "No-log days are not counted as confirmed success.",
                "route": "/habits",
            }
        elif completed_count == len(evaluations):
            status = STATUS_COMPLETED
            score = int(summary.get("score") or 100)
            next_action = None
        else:
            status = STATUS_IN_PROGRESS
            score = int(summary.get("score") or 0)
            next_action = {
                "title": "Continue habit plan",
                "subtitle": "One habit plan still needs attention today.",
                "route": "/habits",
            }
        return DomainEvaluation(
            domain="habits",
            score=score,
            status=status,
            data_coverage=0 if missing_count == len(evaluations) else 100,
            is_applicable=True,
            is_essential=False,
            weight=0.5,
            target_source="habit_plan",
            components=[
                {
                    "key": "active_habits",
                    "label": "Active habit plans",
                    "current": len(evaluations),
                    "target": len(evaluations),
                    "unit": "plans",
                    "progress_percent": 100,
                },
                {
                    "key": "confirmed",
                    "label": "Explicit check-ins",
                    "current": len(evaluations) - missing_count,
                    "target": len(evaluations),
                    "unit": "plans",
                    "progress_percent": _percent(len(evaluations) - missing_count, len(evaluations)),
                },
                {
                    "key": "relapses",
                    "label": "Relapses",
                    "current": relapse_count,
                    "target": 0,
                    "unit": "events",
                    "progress_percent": 100 if relapse_count == 0 else 0,
                },
            ],
            next_action=next_action,
        )

    @classmethod
    def _focus(cls, *, domains: list[DomainEvaluation], daily_complete: bool) -> dict:
        if daily_complete:
            return {
                "kind": "daily_complete",
                "domain": "",
                "title": "Daily health plan complete",
                "subtitle": "All essential applicable goals are complete.",
                "route": "/progress",
                "progress_percent": 100,
            }
        candidates = [
            domain
            for domain in domains
            if domain.is_applicable
            and domain.is_essential
            and domain.status != STATUS_COMPLETED
            and domain.next_action
        ]
        candidates.sort(key=lambda domain: cls.DOMAIN_PRIORITY.get(domain.domain, 99))
        if not candidates:
            return {
                "kind": "daily_progress",
                "domain": "",
                "title": "Keep your health data current",
                "subtitle": "Open a tracker to update today's progress.",
                "route": "/progress",
                "progress_percent": 0,
            }
        domain = candidates[0]
        action = domain.next_action or {}
        return {
            "kind": "domain_action",
            "domain": domain.domain,
            "title": str(action.get("title") or "Continue today's goal"),
            "subtitle": str(action.get("subtitle") or ""),
            "route": str(action.get("route") or "/progress"),
            "progress_percent": domain.score,
        }

    @staticmethod
    def _message(*, daily_complete: bool, completion_status: str, focus: dict) -> str:
        if daily_complete:
            return "Daily health plan complete."
        if completion_status == STATUS_NOT_STARTED:
            return "Start with one essential tracker to build today's health progress."
        if completion_status == STATUS_INSUFFICIENT_DATA:
            return str(focus.get("subtitle") or "Essential data is still missing.")
        return str(focus.get("subtitle") or "Continue the next essential tracker.")
