from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from datetime import datetime, time, timedelta
from statistics import mean
from typing import Any

from django.db import transaction
from django.utils import timezone

from core.models import ActivityLog, MealLog, SleepMorningFeedback, SleepPlan, StepLog
from core.services.tracking.sleep_service import SleepService


@dataclass(frozen=True)
class SleepCoachRecommendation:
    wake_window_start: datetime
    wake_window_end: datetime
    estimated_sleep_start: datetime
    wake_options: list[dict[str, Any]]
    selected_wake_time: datetime
    recommendation_reason: str
    primary_negative_factor: str
    night_tip: str
    tracker_factors: dict[str, Any]


class SleepCoachService:
    BASE_LATENCY_MINUTES = 20
    CYCLE_MINUTES = 90
    FACTOR_PRIORITY = (
        SleepPlan.FACTOR_LATE_CAFFEINE,
        SleepPlan.FACTOR_LATE_HEAVY_MEAL,
        SleepPlan.FACTOR_HIGH_STRESS,
        SleepPlan.FACTOR_HIGH_SCREEN,
        SleepPlan.FACTOR_LATE_NAP,
        SleepPlan.FACTOR_LATE_INTENSE_EXERCISE,
        SleepPlan.FACTOR_LOW_ACTIVITY,
    )

    @classmethod
    @transaction.atomic
    def create_plan(
        cls,
        *,
        user,
        planned_bed_time: datetime,
        latest_wake_time: datetime,
        flexibility_minutes: int,
        questionnaire: dict[str, Any] | None = None,
    ) -> SleepPlan:
        planned_bed_time = cls._aware(planned_bed_time)
        latest_wake_time = cls._aware(latest_wake_time)
        if latest_wake_time <= planned_bed_time:
            latest_wake_time += timedelta(days=1)
        flexibility_minutes = max(0, min(int(flexibility_minutes or 0), 240))
        questionnaire = questionnaire or {}

        recommendation = cls.build_recommendation(
            user=user,
            planned_bed_time=planned_bed_time,
            latest_wake_time=latest_wake_time,
            flexibility_minutes=flexibility_minutes,
            questionnaire=questionnaire,
        )
        SleepPlan.objects.filter(
            user=user,
            status=SleepPlan.STATUS_ACTIVE,
            selected_wake_time__gte=timezone.now() - timedelta(hours=12),
        ).update(status=SleepPlan.STATUS_CANCELLED)
        return SleepPlan.objects.create(
            user=user,
            plan_date=timezone.localtime(planned_bed_time).date(),
            planned_bed_time=planned_bed_time,
            latest_wake_time=latest_wake_time,
            flexibility_minutes=flexibility_minutes,
            wake_window_start=recommendation.wake_window_start,
            wake_window_end=recommendation.wake_window_end,
            questionnaire=questionnaire,
            tracker_factors=recommendation.tracker_factors,
            estimated_sleep_start=recommendation.estimated_sleep_start,
            wake_options=recommendation.wake_options,
            selected_wake_time=recommendation.selected_wake_time,
            recommendation_reason=recommendation.recommendation_reason,
            primary_negative_factor=recommendation.primary_negative_factor,
            night_tip=recommendation.night_tip,
        )

    @classmethod
    def build_recommendation(
        cls,
        *,
        user,
        planned_bed_time: datetime,
        latest_wake_time: datetime,
        flexibility_minutes: int,
        questionnaire: dict[str, Any],
    ) -> SleepCoachRecommendation:
        tracker_factors = cls.tracker_factors_for_plan(
            user=user,
            planned_bed_time=planned_bed_time,
        )
        factor_flags = cls._factor_flags(questionnaire=questionnaire, tracker_factors=tracker_factors)
        primary = cls._primary_negative_factor(factor_flags)
        latency_minutes = cls.BASE_LATENCY_MINUTES + cls._latency_modifier_minutes(factor_flags)
        estimated_sleep_start = planned_bed_time + timedelta(minutes=latency_minutes)
        wake_window_end = latest_wake_time
        wake_window_start = latest_wake_time - timedelta(minutes=flexibility_minutes)
        cycle_options = cls._cycle_options(
            estimated_sleep_start=estimated_sleep_start,
            window_start=wake_window_start,
            window_end=wake_window_end,
        )
        wake_options = cls._wake_options(
            cycle_options=cycle_options,
            estimated_sleep_start=estimated_sleep_start,
            window_start=wake_window_start,
            window_end=wake_window_end,
        )
        selected = datetime.fromisoformat(wake_options[0]["wake_time"])
        if timezone.is_naive(selected):
            selected = timezone.make_aware(selected)
        reason = cls._recommendation_reason(
            option=wake_options[0],
            primary_factor=primary,
            cycle_match=bool(cycle_options),
        )
        return SleepCoachRecommendation(
            wake_window_start=wake_window_start,
            wake_window_end=wake_window_end,
            estimated_sleep_start=estimated_sleep_start,
            wake_options=wake_options,
            selected_wake_time=selected,
            recommendation_reason=reason,
            primary_negative_factor=primary,
            night_tip=cls._night_tip(primary),
            tracker_factors={**tracker_factors, "factor_flags": factor_flags},
        )

    @classmethod
    def today_payload(cls, *, user) -> dict[str, Any]:
        now = timezone.now()
        plan = (
            SleepPlan.objects.filter(user=user)
            .select_related("morning_feedback")
            .order_by("-planned_bed_time", "-id")
            .first()
        )
        active_plan = plan if plan and plan.status != SleepPlan.STATUS_CANCELLED else None
        feedback_prompt = False
        if active_plan is not None and not hasattr(active_plan, "morning_feedback"):
            selected = active_plan.selected_wake_time or active_plan.latest_wake_time
            feedback_prompt = selected <= now + timedelta(hours=4)
        return {
            "plan": cls.serialize_plan(active_plan) if active_plan else None,
            "feedback_prompt": feedback_prompt,
            "learning_summary": cls.learning_summary(user=user),
            "latest_tracker_factors": cls.tracker_factors_for_plan(
                user=user,
                planned_bed_time=now,
            ),
            "disclaimer": "Smart Wake schedules a local reminder. It is not a guaranteed alarm or medical device.",
        }

    @classmethod
    @transaction.atomic
    def cancel_active_plan(cls, *, user) -> int:
        return SleepPlan.objects.filter(user=user, status=SleepPlan.STATUS_ACTIVE).update(
            status=SleepPlan.STATUS_CANCELLED
        )

    @classmethod
    @transaction.atomic
    def save_feedback(
        cls,
        *,
        user,
        plan_id: int,
        quality_rating: int,
        wake_feeling: str,
        focus_rating: int,
        disruptor: str = "",
        actual_sleep_start: datetime | None = None,
        actual_wake_time: datetime | None = None,
    ) -> SleepMorningFeedback:
        plan = SleepPlan.objects.get(id=plan_id, user=user)
        actual_sleep_start = cls._aware(actual_sleep_start) if actual_sleep_start else None
        actual_wake_time = cls._aware(actual_wake_time) if actual_wake_time else None
        if actual_sleep_start and actual_wake_time and actual_wake_time <= actual_sleep_start:
            actual_wake_time += timedelta(days=1)
        feedback, _ = SleepMorningFeedback.objects.update_or_create(
            user=user,
            plan=plan,
            defaults={
                "quality_rating": quality_rating,
                "wake_feeling": wake_feeling,
                "focus_rating": focus_rating,
                "disruptor": (disruptor or "")[:40],
                "actual_sleep_start": actual_sleep_start,
                "actual_wake_time": actual_wake_time,
            },
        )
        if actual_sleep_start and actual_wake_time:
            quality = cls._sleep_log_quality(quality_rating)
            if feedback.sleep_log_id:
                sleep_log = SleepService.update_sleep_log(
                    feedback.sleep_log,
                    start_time=actual_sleep_start,
                    end_time=actual_wake_time,
                    quality=quality,
                )
            else:
                sleep_log = SleepService.log_sleep(
                    user=user,
                    start_time=actual_sleep_start,
                    end_time=actual_wake_time,
                    quality=quality,
                )
            feedback.sleep_log = sleep_log
            feedback.save(update_fields=["sleep_log", "updated_at"])
        plan.status = SleepPlan.STATUS_COMPLETED
        plan.save(update_fields=["status", "updated_at"])
        return feedback

    @classmethod
    def learning_summary(cls, *, user) -> dict[str, Any]:
        feedbacks = list(
            SleepMorningFeedback.objects.filter(user=user)
            .select_related("plan")
            .order_by("-created_at")[:14]
        )
        if not feedbacks:
            return {
                "sample_size": 0,
                "average_quality": 0,
                "insights": [],
                "best_sleep_duration_range": "",
                "top_negative_factor": SleepPlan.FACTOR_NONE,
            }
        qualities = [item.quality_rating for item in feedbacks]
        factors = [item.plan.primary_negative_factor for item in feedbacks if item.plan.primary_negative_factor]
        top_factor = Counter(factors).most_common(1)[0][0] if factors else SleepPlan.FACTOR_NONE
        durations = []
        for item in feedbacks:
            if item.actual_sleep_start and item.actual_wake_time and item.quality_rating >= 4:
                hours = (item.actual_wake_time - item.actual_sleep_start).total_seconds() / 3600
                if 0 < hours < 16:
                    durations.append(hours)
        insights = []
        if top_factor and top_factor != SleepPlan.FACTOR_NONE:
            insights.append(f"Most repeated sleep pressure recently: {top_factor.replace('_', ' ')}.")
        for factor in (SleepPlan.FACTOR_LATE_CAFFEINE, SleepPlan.FACTOR_LATE_HEAVY_MEAL):
            true_scores = [item.quality_rating for item in feedbacks if item.plan.primary_negative_factor == factor]
            other_scores = [item.quality_rating for item in feedbacks if item.plan.primary_negative_factor != factor]
            if len(true_scores) >= 2 and len(other_scores) >= 2 and mean(true_scores) + 0.5 <= mean(other_scores):
                insights.append(f"{factor.replace('_', ' ').title()} is linked with lower morning ratings.")
        duration_range = ""
        if len(durations) >= 3:
            avg = mean(durations)
            duration_range = f"{max(avg - 0.4, 0):.1f}-{avg + 0.4:.1f} h"
            insights.append(f"Your better mornings cluster around {duration_range} of sleep.")
        return {
            "sample_size": len(feedbacks),
            "average_quality": round(mean(qualities), 1),
            "insights": insights[:3],
            "best_sleep_duration_range": duration_range,
            "top_negative_factor": top_factor or SleepPlan.FACTOR_NONE,
        }

    @classmethod
    def tracker_factors_for_plan(cls, *, user, planned_bed_time: datetime) -> dict[str, Any]:
        planned_bed_time = cls._aware(planned_bed_time)
        local_bed = timezone.localtime(planned_bed_time)
        lookback_start = planned_bed_time - timedelta(hours=12)
        meals = list(
            MealLog.objects.filter(
                user=user,
                consumed_at__gte=lookback_start,
                consumed_at__lte=planned_bed_time,
            )
            .select_related("food")
            .order_by("consumed_at")
        )
        late_caffeine_meals = []
        late_heavy_meals = []
        for meal in meals:
            consumed_at = timezone.localtime(meal.consumed_at) if meal.consumed_at else None
            if consumed_at is None:
                continue
            caffeine_mg = float(meal.snapshot_caffeine_mg or 0)
            hours_before_bed = (planned_bed_time - meal.consumed_at).total_seconds() / 3600
            if caffeine_mg > 0 and (consumed_at.hour >= 14 or hours_before_bed <= 8):
                late_caffeine_meals.append(
                    {
                        "meal_id": meal.id,
                        "food_name": meal.food.name,
                        "caffeine_mg": round(caffeine_mg, 1),
                        "consumed_at": cls._iso(meal.consumed_at),
                    }
                )
            calories = float(meal.snapshot_calories_kcal or meal.total_calories or 0)
            fat = float(meal.snapshot_fat_g or 0)
            if hours_before_bed <= 3 and (calories >= 600 or fat >= 25):
                late_heavy_meals.append(
                    {
                        "meal_id": meal.id,
                        "food_name": meal.food.name,
                        "calories": round(calories),
                        "fat_g": round(fat, 1),
                        "consumed_at": cls._iso(meal.consumed_at),
                    }
                )
        late_smoking_logs = []
        try:
            from core.services.habits import UnhealthyHabitService

            habit_caffeine_logs = UnhealthyHabitService.late_caffeine_logs(
                user=user,
                planned_bed_time=planned_bed_time,
            )
            for item in habit_caffeine_logs:
                late_caffeine_meals.append(item)
            late_smoking_logs = UnhealthyHabitService.late_smoking_logs(
                user=user,
                planned_bed_time=planned_bed_time,
            )
        except Exception:
            late_smoking_logs = []
        activity_date = local_bed.date()
        steps_log = StepLog.objects.filter(user=user, date=activity_date).first()
        activity_minutes = (
            ActivityLog.objects.filter(user=user, date=activity_date)
            .values_list("duration_minutes", flat=True)
        )
        exercise_minutes = sum(int(value or 0) for value in activity_minutes)
        steps_today = int(getattr(steps_log, "steps_count", 0) or 0)
        low_activity = steps_today < 3000 and exercise_minutes < 20
        return {
            "late_caffeine": bool(late_caffeine_meals),
            "late_caffeine_meals": late_caffeine_meals,
            "late_heavy_meal": bool(late_heavy_meals),
            "late_heavy_meals": late_heavy_meals,
            "late_smoking": bool(late_smoking_logs),
            "late_smoking_logs": late_smoking_logs,
            "steps_today": steps_today,
            "exercise_minutes": exercise_minutes,
            "low_activity": low_activity,
        }

    @classmethod
    def serialize_plan(cls, plan: SleepPlan | None) -> dict[str, Any] | None:
        if plan is None:
            return None
        return {
            "id": plan.id,
            "status": plan.status,
            "plan_date": plan.plan_date.isoformat(),
            "planned_bed_time": cls._iso(plan.planned_bed_time),
            "latest_wake_time": cls._iso(plan.latest_wake_time),
            "flexibility_minutes": plan.flexibility_minutes,
            "wake_window_start": cls._iso(plan.wake_window_start),
            "wake_window_end": cls._iso(plan.wake_window_end),
            "questionnaire": plan.questionnaire or {},
            "tracker_factors": plan.tracker_factors or {},
            "estimated_sleep_start": cls._iso(plan.estimated_sleep_start),
            "wake_options": plan.wake_options or [],
            "selected_wake_time": cls._iso(plan.selected_wake_time) if plan.selected_wake_time else None,
            "recommendation_reason": plan.recommendation_reason,
            "primary_negative_factor": plan.primary_negative_factor,
            "night_tip": plan.night_tip,
            "has_feedback": hasattr(plan, "morning_feedback"),
            "disclaimer": "This is a scheduled reminder, not a guaranteed alarm.",
        }

    @classmethod
    def serialize_feedback(cls, feedback: SleepMorningFeedback) -> dict[str, Any]:
        return {
            "id": feedback.id,
            "plan_id": feedback.plan_id,
            "quality_rating": feedback.quality_rating,
            "wake_feeling": feedback.wake_feeling,
            "focus_rating": feedback.focus_rating,
            "disruptor": feedback.disruptor,
            "actual_sleep_start": cls._iso(feedback.actual_sleep_start) if feedback.actual_sleep_start else None,
            "actual_wake_time": cls._iso(feedback.actual_wake_time) if feedback.actual_wake_time else None,
            "sleep_log_id": feedback.sleep_log_id,
        }

    @staticmethod
    def _aware(value: datetime) -> datetime:
        if timezone.is_naive(value):
            return timezone.make_aware(value)
        return value

    @staticmethod
    def _iso(value: datetime) -> str:
        return timezone.localtime(value).isoformat()

    @classmethod
    def _factor_flags(cls, *, questionnaire: dict[str, Any], tracker_factors: dict[str, Any]) -> dict[str, bool]:
        caffeine = str(questionnaire.get("caffeine", "")).lower()
        dinner = str(questionnaire.get("dinner", "")).lower()
        stress = str(questionnaire.get("stress", "")).lower()
        exercise = str(questionnaire.get("exercise", "")).lower()
        nap = str(questionnaire.get("nap", "")).lower()
        screen = str(questionnaire.get("screen", "")).lower()
        return {
            SleepPlan.FACTOR_LATE_CAFFEINE: bool(tracker_factors.get("late_caffeine"))
            or caffeine in {"after_afternoon", "last_4_hours", "late", "high"},
            SleepPlan.FACTOR_LATE_HEAVY_MEAL: bool(tracker_factors.get("late_heavy_meal"))
            or dinner in {"heavy", "late", "heavy_late"},
            SleepPlan.FACTOR_HIGH_STRESS: stress in {"high", "very_high"},
            SleepPlan.FACTOR_HIGH_SCREEN: screen in {"high", "much", "heavy"},
            SleepPlan.FACTOR_LATE_NAP: nap in {"long_late", "late", "long"},
            SleepPlan.FACTOR_LATE_INTENSE_EXERCISE: exercise in {"intense_late", "strong_late"},
            SleepPlan.FACTOR_LOW_ACTIVITY: bool(tracker_factors.get("low_activity")),
        }

    @classmethod
    def _primary_negative_factor(cls, flags: dict[str, bool]) -> str:
        for factor in cls.FACTOR_PRIORITY:
            if flags.get(factor):
                return factor
        return SleepPlan.FACTOR_NONE

    @staticmethod
    def _latency_modifier_minutes(flags: dict[str, bool]) -> int:
        modifiers = {
            SleepPlan.FACTOR_LATE_CAFFEINE: 15,
            SleepPlan.FACTOR_LATE_HEAVY_MEAL: 10,
            SleepPlan.FACTOR_HIGH_STRESS: 15,
            SleepPlan.FACTOR_HIGH_SCREEN: 10,
            SleepPlan.FACTOR_LATE_NAP: 15,
            SleepPlan.FACTOR_LATE_INTENSE_EXERCISE: 10,
            SleepPlan.FACTOR_LOW_ACTIVITY: 5,
        }
        return sum(minutes for factor, minutes in modifiers.items() if flags.get(factor))

    @classmethod
    def _cycle_options(
        cls,
        *,
        estimated_sleep_start: datetime,
        window_start: datetime,
        window_end: datetime,
    ) -> list[dict[str, Any]]:
        options = []
        for cycles in range(3, 8):
            wake_time = estimated_sleep_start + timedelta(minutes=cycles * cls.CYCLE_MINUTES)
            if window_start <= wake_time <= window_end:
                options.append(
                    {
                        "wake_time": cls._iso(wake_time),
                        "cycles": cycles,
                        "sleep_duration_minutes": cycles * cls.CYCLE_MINUTES,
                    }
                )
        return options

    @classmethod
    def _wake_options(
        cls,
        *,
        cycle_options: list[dict[str, Any]],
        estimated_sleep_start: datetime,
        window_start: datetime,
        window_end: datetime,
    ) -> list[dict[str, Any]]:
        if cycle_options:
            cycle_options = sorted(cycle_options, key=lambda item: item["wake_time"])
            recommended = {**cycle_options[-1], "kind": "recommended", "is_recommended": True, "is_fallback": False}
            options = [recommended]
            if len(cycle_options) >= 2:
                options.append({**cycle_options[-2], "kind": "earlier", "is_recommended": False, "is_fallback": False})
            not_preferred = window_end - timedelta(minutes=45)
            if window_start <= not_preferred <= window_end:
                options.append(
                    {
                        "kind": "not_preferred",
                        "wake_time": cls._iso(not_preferred),
                        "cycles": None,
                        "sleep_duration_minutes": round((not_preferred - estimated_sleep_start).total_seconds() / 60),
                        "is_recommended": False,
                        "is_fallback": False,
                    }
                )
            return options[:3]
        duration_minutes = round((window_end - estimated_sleep_start).total_seconds() / 60)
        short_sleep = duration_minutes < 360
        reason = (
            "This is the safest available option within your schedule, not an ideal sleep-cycle match."
            if short_sleep
            else "No full 90-minute cycle ends inside your wake window, so latest wake is the practical fallback."
        )
        return [
            {
                "kind": "recommended",
                "wake_time": cls._iso(window_end),
                "cycles": None,
                "sleep_duration_minutes": duration_minutes,
                "is_recommended": True,
                "is_fallback": True,
                "warning": reason,
            }
        ]

    @staticmethod
    def _recommendation_reason(*, option: dict[str, Any], primary_factor: str, cycle_match: bool) -> str:
        if not cycle_match:
            return option.get("warning") or "No clean sleep-cycle endpoint fits inside your wake window."
        cycles = option.get("cycles")
        factor_text = "" if primary_factor == SleepPlan.FACTOR_NONE else f" while accounting for {primary_factor.replace('_', ' ')}"
        return f"Recommended because it lands near the end of about {cycles} sleep cycles{factor_text}."

    @staticmethod
    def _night_tip(primary: str) -> str:
        tips = {
            SleepPlan.FACTOR_LATE_CAFFEINE: "Tonight, avoid more caffeine and give yourself a short wind-down before bed.",
            SleepPlan.FACTOR_LATE_HEAVY_MEAL: "Keep the rest of the evening light and avoid lying down immediately after eating.",
            SleepPlan.FACTOR_HIGH_STRESS: "Try 10 minutes of calm breathing or journaling before bed.",
            SleepPlan.FACTOR_HIGH_SCREEN: "Put the phone away for the last 20 minutes before bed.",
            SleepPlan.FACTOR_LATE_NAP: "Keep tomorrow's nap earlier and shorter if possible.",
            SleepPlan.FACTOR_LATE_INTENSE_EXERCISE: "Use a gentle cooldown and keep lights low before sleep.",
            SleepPlan.FACTOR_LOW_ACTIVITY: "A short easy walk tomorrow may help sleep pressure build earlier.",
        }
        return tips.get(primary, "Keep tonight simple: consistent bedtime, dim lights, and a short wind-down.")

    @staticmethod
    def _sleep_log_quality(quality_rating: int) -> str:
        if quality_rating >= 4:
            return "Deep"
        if quality_rating == 3:
            return "Light"
        return "Interrupted"
