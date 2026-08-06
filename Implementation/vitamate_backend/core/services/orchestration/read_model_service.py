from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from django.db.models import Sum
from django.utils import timezone

from core.models import HealthStateComputationRun, StepLog, UnifiedHealthState
from core.repositories.hydration.water_log_repository import HydrationRepository
from core.services.chronic.chronic_condition_service import ChronicConditionService
from core.services.chronic.condition_read_service import ConditionReadService
from core.services.constraints import EffectiveConstraintReader
from core.services.health_progress import DailyHealthProgressService, MovementEvaluator
from core.services.medication.medication_dose_workflow_service import MedicationDoseWorkflowService
from core.services.medication.medication_read_service import MedicationReadService
from core.services.medication_adherence_service import MedicationAdherenceService
from core.services.orchestration.tracker_dependency_map import HealthStateTriggers
from core.services.tracking.activity_session_service import ActivitySessionService
from gamification.models import PointsTransaction, UserScore
from gamification.services.motivation_service import MotivationService


def _as_int(value) -> int:
    if value is None:
        return 0
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return round(value)
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def _as_float(value) -> float:
    if value is None:
        return 0.0
    if isinstance(value, float):
        return value
    if isinstance(value, int):
        return float(value)
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _as_str_list(values) -> list[str]:
    if not isinstance(values, list):
        return []
    return [str(item) for item in values]


def _system_local_date() -> date:
    return timezone.localdate()


@dataclass(frozen=True)
class EnvelopeMeta:
    is_stale: bool
    computed_at: str | None
    snapshot_version: int | None
    request_id: str

    def as_dict(self) -> dict:
        return {
            "is_stale": self.is_stale,
            "computed_at": self.computed_at,
            "snapshot_version": self.snapshot_version,
            "request_id": self.request_id,
        }


class ReadModelService:
    STALE_REFRESH_TRIGGER = HealthStateTriggers.READ_MODEL_REFRESH_REQUESTED

    @classmethod
    def home_overview(cls, *, user, request_id: str) -> dict:
        state, is_stale = cls._synchronize_current_state(
            user=user,
            source="home_overview",
        )
        dashboard = cls._dashboard_payload(state)
        projection_summary = dict(state.progress_summary or {}) if state else None
        dashboard = cls._with_live_score(dashboard, user=user)
        compact_conditions = cls._home_conditions(user=user)
        summary = dict(dashboard.get("summary") or {})
        hydration = dict(dashboard.get("hydration") or {})
        sleep = dict(dashboard.get("sleep") or {})
        activity = dict(dashboard.get("activity") or {})
        history_entry = dict(
            (projection_summary or {}).get("history_entry")
            or (state.progress_summary.get("history_entry") if state else {})
            or {}
        )
        motivation = cls._motivation_overview_data(user=user)
        daily_points = _as_int(motivation.get("daily_points")) or _as_int(
            history_entry.get("points_estimate")
        )
        if "medication_points" not in history_entry:
            daily_points += MedicationAdherenceService.points_for_day(
                user=user,
                target_date=_system_local_date(),
            )
        daily_health = DailyHealthProgressService.evaluate(
            user=user,
            target_date=_system_local_date(),
        )
        data = {
            "points": _as_int(dashboard.get("gamification", {}).get("points")),
            "level": _as_int(dashboard.get("gamification", {}).get("level")) or 1,
            "daily_points": daily_points,
            "today_steps": _as_int(activity.get("steps")),
            "step_target": _as_int(activity.get("steps_target")),
            "activity_burned_kcal": _as_int(summary.get("calories_burned")),
            "activity_minutes": _as_int(history_entry.get("exercise_minutes")),
            "burn_target_kcal": _as_int(summary.get("burn_target")),
            "water_ml": round(
                _as_float(hydration.get("current")) * 1000
            ),
            "water_base_target_ml": round(_as_float(hydration.get("base_target")) * 1000),
            "water_adjusted_target_ml": round(
                _as_float(hydration.get("adjusted_target")) * 1000
            ),
            "water_active_target_ml": round(_as_float(hydration.get("target")) * 1000),
            "sleep_minutes": round(
                _as_float(sleep.get("logged_hours_today")) * 60
            ),
            "sleep_target_minutes": round(
                _as_float(sleep.get("recommended_sleep_hours")) * 60
            ),
            "calories": _as_int(summary.get("calories_consumed")),
            "calorie_target": _as_int(summary.get("calories_target")),
            "state_version": state.version if state else None,
            "generated_at": state.last_computed_at.isoformat() if state else None,
            "missions_completed": _as_int(motivation.get("missions_completed")),
            "missions_total": _as_int(motivation.get("missions_total")),
            "current_streak": _as_int(motivation.get("current_streak")),
            "level_name": str(motivation.get("level_name") or "Beginner"),
            "chronic_conditions": dashboard.get("chronic_conditions", cls._empty_chronic_dashboard_summary()),
            "conditions_center": compact_conditions,
            "daily_health": daily_health["daily_health"],
            "domains": daily_health["domains"],
            "focus": daily_health["focus"],
            "xp": {
                "total_points": _as_int(dashboard.get("gamification", {}).get("points")),
                "daily_points": daily_points,
                "level": _as_int(dashboard.get("gamification", {}).get("level")) or 1,
                "level_name": str(motivation.get("level_name") or "Beginner"),
            },
            "streaks": {
                "current_streak": _as_int(motivation.get("current_streak")),
            },
        }
        try:
            from core.services.habits import UnhealthyHabitService

            data["unhealthy_habits"] = UnhealthyHabitService.summary_for_user(user=user)
        except Exception:
            data["unhealthy_habits"] = {
                "active_count": 0,
                "logs_today": 0,
                "relapses_today": 0,
                "points_today": 0,
                "habit_types": [],
            }
        return cls._envelope(
            data=data,
            state=state,
            is_stale=is_stale,
            request_id=request_id,
        )

    @classmethod
    def progress_overview(cls, *, user, request_id: str) -> dict:
        state, is_stale = cls._synchronize_current_state(
            user=user,
            source="progress_overview",
        )
        data = cls._dashboard_payload(state)
        data = cls._with_live_score(data, user=user)
        data["motivation"] = cls._motivation_overview_data(user=user)
        try:
            from core.services.habits import UnhealthyHabitService

            data["unhealthy_habits"] = UnhealthyHabitService.summary_for_user(user=user)
        except Exception:
            data["unhealthy_habits"] = {}
        history_payload = cls.progress_history(user=user, request_id=request_id, days=7)
        history_items = list(dict(history_payload.get("data") or {}).get("history") or [])
        data.update(
            cls._modern_progress_overview_payload(
                data=data,
                history_items=history_items,
            )
        )
        return cls._envelope(
            data=data,
            state=state,
            is_stale=(
                is_stale
                or bool(dict(history_payload.get("meta") or {}).get("is_stale"))
            ),
            request_id=request_id,
        )

    @classmethod
    def progress_detail(
        cls,
        *,
        user,
        request_id: str,
        tracker: str,
        range_days: int = 7,
    ) -> dict:
        tracker = str(tracker or "").strip().lower().replace("-", "_")
        if tracker == "water":
            tracker = "hydration"
        if tracker == "meds":
            tracker = "medications"
        if tracker == "steps":
            tracker = "activity"
        allowed = {
            "nutrition",
            "hydration",
            "activity",
            "steps",
            "sleep",
            "medications",
            "chronic",
            "habits",
            "motivation",
        }
        if tracker not in allowed:
            tracker = "nutrition"

        range_days = max(7, min(int(range_days or 7), 30))
        state, is_stale = cls._synchronize_current_state(
            user=user,
            source="progress_detail",
        )
        overview = cls._dashboard_payload(state)
        history_payload = cls.progress_history(
            user=user,
            request_id=request_id,
            days=range_days,
        )
        history_items = list(dict(history_payload.get("data") or {}).get("history") or [])
        data = cls._progress_detail_payload(
            user=user,
            tracker=tracker,
            overview=overview,
            history_items=history_items,
            range_days=range_days,
            request_id=request_id,
        )
        return cls._envelope(
            data=data,
            state=state,
            is_stale=is_stale or bool(dict(history_payload.get("meta") or {}).get("is_stale")),
            request_id=request_id,
        )

    @classmethod
    def progress_history(cls, *, user, request_id: str, days: int = 7) -> dict:
        today = _system_local_date()
        start = today - timedelta(days=max(days - 1, 0))
        states = {
            item.state_date: item
            for item in UnifiedHealthState.objects.filter(
                user=user,
                state_date__gte=start,
                state_date__lte=today,
                window_kind=UnifiedHealthState.WINDOW_DAILY,
            ).order_by("state_date")
        }
        missing_dates = []
        items = []
        for offset in range(days):
            state_date = start + timedelta(days=offset)
            state = states.get(state_date)
            if state is None:
                missing_dates.append(state_date)
                items.append(cls._empty_history_entry(state_date))
                continue
            items.append(dict(state.progress_summary.get("history_entry") or cls._empty_history_entry(state_date)))

        latest_state = states.get(today) or next(iter(states.values()), None)
        is_stale = bool(missing_dates)
        if latest_state is not None:
            is_stale = is_stale or cls._is_state_stale(user=user, state=latest_state)
        if missing_dates:
            fallback_history = cls._history_projection_payload(
                user=user,
                today=today,
                days=days,
            )
            if fallback_history and len(fallback_history) == days:
                items = fallback_history
        items = cls._with_medication_points_in_history(user=user, items=items)

        return cls._envelope(
            data={"history": items},
            state=latest_state,
            is_stale=is_stale or latest_state is None,
            request_id=request_id,
        )

    @classmethod
    def _modern_progress_overview_payload(
        cls,
        *,
        data: dict,
        history_items: list[dict],
    ) -> dict:
        tracker_cards = cls._progress_tracker_cards(data=data)
        overall_score = cls._weighted_overall_score(tracker_cards)
        return {
            "overall_score": overall_score,
            "points": _as_int(dict(data.get("gamification") or {}).get("points")),
            "level": _as_int(dict(data.get("gamification") or {}).get("level")) or 1,
            "weekly_consistency": cls._weekly_consistency(history_items),
            "tracker_cards": tracker_cards,
            "timeline_7d": cls._timeline_payload(history_items),
            "insight": cls._progress_insight(overall_score=overall_score, cards=tracker_cards),
        }

    @classmethod
    def _progress_tracker_cards(cls, *, data: dict) -> list[dict]:
        summary = dict(data.get("summary") or {})
        hydration = dict(data.get("hydration") or {})
        sleep = dict(data.get("sleep") or {})
        activity = dict(data.get("activity") or {})
        medications = dict(data.get("medications") or {})
        chronic = dict(data.get("chronic_conditions") or {})
        habits = dict(data.get("unhealthy_habits") or {})
        motivation = dict(data.get("motivation") or {})

        calories_target = _as_float(summary.get("calories_target"))
        calories_consumed = _as_float(summary.get("calories_consumed"))
        hydration_target = _as_float(hydration.get("target"))
        hydration_current = _as_float(hydration.get("current"))
        burn_target = _as_float(summary.get("burn_target"))
        burn_current = _as_float(summary.get("calories_burned"))
        steps_target = _as_float(activity.get("steps_target"))
        steps = _as_float(activity.get("steps"))
        movement = dict(activity.get("movement") or {})
        movement_percent = _as_int(movement.get("score"))
        if movement_percent <= 0:
            movement_percent = max(
                cls._bounded_percent(burn_current, burn_target),
                cls._bounded_percent(steps, steps_target),
            )
        sleep_goal = _as_float(sleep.get("recommended_sleep_hours"))
        sleep_logged = _as_float(sleep.get("logged_hours_today"))
        medication_active = _as_int(medications.get("active_medications")) > 0 or _as_int(
            medications.get("today_total_doses")
        ) > 0
        chronic_active = _as_int(chronic.get("count")) > 0
        habits_active = _as_int(habits.get("active_count")) > 0

        cards = [
            cls._tracker_card(
                code="nutrition",
                title="Nutrition",
                icon="nutrition",
                percent=cls._bounded_percent(calories_consumed, calories_target),
                current=round(calories_consumed),
                target=round(calories_target),
                unit="kcal",
                active=calories_target > 0,
                summary="Meal quality and nutrient balance",
                detail_endpoint="/api/progress/details/nutrition/",
            ),
            cls._tracker_card(
                code="hydration",
                title="Water",
                icon="water",
                percent=cls._bounded_percent(hydration_current, hydration_target),
                current=round(hydration_current, 2),
                target=round(hydration_target, 2),
                unit="L",
                active=hydration_target > 0,
                summary="Hydration and beverage consistency",
                detail_endpoint="/api/progress/details/hydration/",
            ),
            cls._tracker_card(
                code="activity",
                title="Activity / Movement",
                icon="activity",
                percent=movement_percent,
                current=round(burn_current),
                target=round(burn_target),
                unit="kcal",
                active=burn_target > 0 or steps_target > 0,
                summary="Workout burn, active minutes, and automatic steps",
                detail_endpoint="/api/progress/details/activity/",
            ),
            cls._tracker_card(
                code="sleep",
                title="Sleep",
                icon="sleep",
                percent=_as_int(sleep.get("progress_percent"))
                or cls._bounded_percent(sleep_logged, sleep_goal),
                current=round(sleep_logged, 2),
                target=round(sleep_goal, 2),
                unit="h",
                active=sleep_goal > 0,
                summary="Duration and consistency",
                detail_endpoint="/api/progress/details/sleep/",
            ),
            cls._tracker_card(
                code="medications",
                title="Medication adherence",
                icon="medications",
                percent=_as_float(medications.get("adherence_7d")),
                current=_as_int(medications.get("taken_today")),
                target=_as_int(medications.get("today_total_doses")),
                unit="doses",
                active=medication_active,
                summary="Dose completion and timing",
                detail_endpoint="/api/progress/details/medications/",
            ),
            cls._tracker_card(
                code="chronic",
                title="Chronic conditions",
                icon="chronic",
                percent=_as_float(chronic.get("adherence_percent")),
                current=_as_int(chronic.get("active_medications_today")),
                target=_as_int(chronic.get("pending_doses_today")),
                unit="plans",
                active=chronic_active,
                summary="Care plans and guardrails",
                detail_endpoint="/api/progress/details/chronic/",
            ),
            cls._tracker_card(
                code="habits",
                title="Habit quitting",
                icon="habits",
                percent=cls._habits_percent(habits),
                current=_as_int(habits.get("logs_today")),
                target=_as_int(habits.get("active_count")),
                unit="logs",
                active=habits_active,
                summary="Smoking, caffeine, and fast food reduction",
                detail_endpoint="/api/progress/details/habits/",
            ),
            cls._tracker_card(
                code="motivation",
                title="Motivation",
                icon="motivation",
                percent=cls._motivation_percent(motivation),
                current=_as_int(motivation.get("missions_completed")),
                target=_as_int(motivation.get("missions_total")),
                unit="missions",
                active=(_as_int(motivation.get("missions_total")) > 0)
                or (_as_int(motivation.get("daily_points")) > 0),
                summary=str(
                    motivation.get("insight")
                    or "Daily missions, streaks, badges, and points history."
                ),
                detail_endpoint="/api/progress/details/motivation/",
            ),
        ]
        return cards

    @classmethod
    def _progress_detail_payload(
        cls,
        *,
        user,
        tracker: str,
        overview: dict,
        history_items: list[dict],
        range_days: int,
        request_id: str,
    ) -> dict:
        cards = cls._progress_tracker_cards(data=overview)
        card_lookup = {card["code"]: card for card in cards}
        card = card_lookup.get(tracker, cls._tracker_card(
            code=tracker,
            title=tracker.title(),
            icon=tracker,
            percent=0,
            current=0,
            target=0,
            unit="",
            active=False,
            summary="",
            detail_endpoint=f"/api/progress/details/{tracker}/",
        ))
        data = {
            "tracker": tracker,
            "title": card["title"],
            "score": card["percent"],
            "status": card["status"],
            "range_days": range_days,
            "summary_cards": [],
            "metrics": [],
            "trend": cls._detail_trend(tracker=tracker, history_items=history_items),
            "sections": [],
            "insight": card["summary"],
        }
        summary = dict(overview.get("summary") or {})
        hydration = dict(overview.get("hydration") or {})
        sleep = dict(overview.get("sleep") or {})
        activity = dict(overview.get("activity") or {})
        medications = dict(overview.get("medications") or {})
        chronic = dict(overview.get("chronic_conditions") or {})
        motivation = dict(overview.get("motivation") or {})

        if tracker == "nutrition":
            from core.models import MealLog

            meals_today = MealLog.objects.filter(
                user=user,
                consumed_at__date=_system_local_date(),
            ).count()
            metrics = [
                cls._metric("Protein", summary.get("protein_g"), 100, "g"),
                cls._metric("Carbs", summary.get("carbs_g"), 250, "g"),
                cls._metric("Fats", summary.get("fat_g"), 70, "g"),
                cls._metric("Fiber", summary.get("fiber_g"), 30, "g"),
                cls._metric("Sugar", summary.get("sugars_g"), 50, "g", limit=True),
                cls._metric("Sodium", summary.get("sodium_mg"), 2300, "mg", limit=True),
                cls._metric("Potassium", summary.get("potassium_mg"), 3500, "mg"),
                cls._metric("Calcium", summary.get("calcium_mg"), 1000, "mg"),
                cls._metric("Iron", summary.get("iron_mg"), 18, "mg"),
            ]
            vitamins = [
                cls._metric("Vit D", summary.get("vitamin_d_mcg"), 20, "mcg"),
                cls._metric("Vit B12", summary.get("vitamin_b12_mcg"), 2.4, "mcg"),
                cls._metric("Magnesium", summary.get("magnesium_mg"), 400, "mg"),
                cls._metric("Zinc", summary.get("zinc_mg"), 11, "mg"),
                cls._metric("Folate", summary.get("folate_mcg"), 400, "mcg"),
            ]
            data.update(
                summary_cards=[
                    cls._summary_card("Meals logged", meals_today, 3, "today"),
                    cls._summary_card("Calories", summary.get("calories_consumed"), summary.get("calories_target"), "kcal"),
                    cls._summary_card("Nutrient balance", card["percent"], 100, "%"),
                ],
                metrics=metrics,
                sections=[{"title": "Vitamins & minerals", "items": vitamins}],
                insight="Nutrition is more than calories. Track quality, balance, and key nutrients.",
            )
        elif tracker == "hydration":
            current = _as_float(hydration.get("current"))
            target = _as_float(hydration.get("target"))
            data.update(
                summary_cards=[
                    cls._summary_card("Water intake", current, target, "L"),
                    cls._summary_card("Cups logged", round((current * 1000) / 250) if current else 0, None, "today"),
                    cls._summary_card("Hydration streak", cls._streak_from_history(history_items, "water_current"), None, "days"),
                ],
                metrics=[
                    cls._metric("Water", current, target, "L"),
                    cls._metric("Remaining", max(target - current, 0), target, "L"),
                ],
                sections=[
                    {
                        "title": "Beverage split",
                        "items": [
                            {"label": "Water", "value": current, "unit": "L", "percent": card["percent"]},
                            {"label": "Other beverages", "value": 0, "unit": "L", "percent": 0},
                        ],
                    }
                ],
                insight="Sip water consistently through the day instead of waiting until the evening.",
            )
        elif tracker == "activity":
            data.update(
                summary_cards=[
                    cls._summary_card("Active minutes", cls._sum_history(history_items, "exercise_minutes"), None, "min"),
                    cls._summary_card("Calories burned", summary.get("calories_burned"), summary.get("burn_target"), "kcal"),
                    cls._summary_card("Steps", activity.get("steps"), activity.get("steps_target"), "steps"),
                ],
                metrics=[
                    cls._metric("Burn", summary.get("calories_burned"), summary.get("burn_target"), "kcal"),
                    cls._metric("Steps", activity.get("steps"), activity.get("steps_target"), "steps"),
                    cls._metric("Step burn", activity.get("steps_burned"), None, "kcal"),
                    cls._metric("Step distance", activity.get("distance_km"), None, "km"),
                    cls._metric("Active days", cls._active_days(history_items, "exercise_minutes"), range_days, "days"),
                ],
                insight="Automatic steps and logged workouts are combined into one activity score.",
            )
        elif tracker == "sleep":
            data.update(
                summary_cards=[
                    cls._summary_card("Sleep duration", sleep.get("logged_hours_today"), sleep.get("recommended_sleep_hours"), "h"),
                    cls._summary_card("Sleep goal", sleep.get("recommended_sleep_hours"), None, "h"),
                    cls._summary_card("Restfulness", card["percent"], 100, "%"),
                ],
                metrics=[
                    cls._metric("Duration", sleep.get("logged_hours_today"), sleep.get("recommended_sleep_hours"), "h"),
                    cls._metric("Bedtime consistency", cls._active_days(history_items, "sleep_hours"), range_days, "days"),
                    cls._metric("Wake feedback", card["percent"], 100, "%"),
                ],
                sections=[
                    {
                        "title": "Sleep habits",
                        "items": [
                            {"label": "Logged sleep days", "value": cls._active_days(history_items, "sleep_hours"), "unit": "days"},
                            {"label": "Target range", "value": sleep.get("recommended_sleep_hours"), "unit": "h"},
                        ],
                    }
                ],
                insight="Sleep progress uses duration and consistency only in v1, not estimated Deep/Light stages.",
            )
        elif tracker == "medications":
            data.update(
                summary_cards=[
                    cls._summary_card("Doses taken", medications.get("taken_today"), medications.get("today_total_doses"), "today"),
                    cls._summary_card("Pending", medications.get("pending_today"), None, "doses"),
                    cls._summary_card("7-day adherence", medications.get("adherence_7d"), 100, "%"),
                ],
                metrics=[
                    cls._metric("Taken today", medications.get("taken_today"), medications.get("today_total_doses"), "doses"),
                    cls._metric("Missed today", medications.get("missed_today"), medications.get("today_total_doses"), "doses", limit=True),
                    cls._metric("Overdue today", medications.get("overdue_today"), medications.get("today_total_doses"), "doses", limit=True),
                ],
                insight="Keep reminders enabled and log taken doses to keep adherence accurate.",
            )
        elif tracker == "chronic":
            data.update(
                summary_cards=[
                    cls._summary_card("Active plans", chronic.get("count"), None, "plans"),
                    cls._summary_card("Adherence", chronic.get("adherence_percent"), 100, "%"),
                    cls._summary_card("Pending doses", chronic.get("pending_doses_today"), None, "today"),
                ],
                metrics=[
                    cls._metric("Care adherence", chronic.get("adherence_percent"), 100, "%"),
                    cls._metric("Active medications", chronic.get("active_medications_today"), None, "today"),
                    cls._metric("Pending doses", chronic.get("pending_doses_today"), None, "today", limit=True),
                ],
                sections=[{"title": "Care guidance", "items": [{"label": item} for item in _as_str_list(chronic.get("applied_summaries"))]}],
                insight=chronic.get("disclaimer") or "Condition goals and limits are guardrails, not a diagnosis.",
            )
        elif tracker == "habits":
            from core.services.habits import UnhealthyHabitService

            habits_payload = UnhealthyHabitService.overview(user=user, request_id="")
            habits_data = dict(habits_payload.get("data") or {})
            habits = list(habits_data.get("habits") or [])
            data.update(
                summary_cards=[
                    cls._summary_card("Active habits", len([item for item in habits if item.get("is_setup")]), None, "plans"),
                    cls._summary_card("Logs today", dict(overview.get("unhealthy_habits") or {}).get("logs_today"), None, "logs"),
                    cls._summary_card("Relapses today", dict(overview.get("unhealthy_habits") or {}).get("relapses_today"), None, "reviews"),
                ],
                metrics=[
                    cls._metric(item.get("title") or item.get("label"), dict(item.get("progress") or {}).get("adherence_percent"), 100, "%")
                    for item in habits
                ],
                sections=[{"title": "Habit cards", "items": habits}],
                insight=habits_data.get("support_message") or "Progress is measured by consistency, not perfection.",
            )
        elif tracker == "motivation":
            missions_payload = MotivationService.missions(
                user=user,
                request_id=request_id,
                target_date=_system_local_date(),
            )
            missions = list(dict(missions_payload.get("data") or {}).get("missions") or [])
            data.update(
                summary_cards=[
                    cls._summary_card("Daily points", motivation.get("daily_points"), None, "pts"),
                    cls._summary_card("Missions", motivation.get("missions_completed"), motivation.get("missions_total"), "today"),
                    cls._summary_card("Current streak", motivation.get("current_streak"), None, "days"),
                ],
                metrics=[
                    cls._metric(
                        str(item.get("title") or item.get("mission_type")),
                        item.get("current_value"),
                        item.get("target_value"),
                        "",
                    )
                    for item in missions
                ],
                sections=[{"title": "Daily missions", "items": missions}],
                insight=str(
                    motivation.get("insight")
                    or "Complete a few daily missions to build streaks and unlock badges."
                ),
            )
        return data

    @staticmethod
    def _tracker_card(
        *,
        code: str,
        title: str,
        icon: str,
        percent,
        current,
        target,
        unit: str,
        active: bool,
        summary: str,
        detail_endpoint: str,
    ) -> dict:
        safe_percent = max(0, min(round(_as_float(percent)), 100))
        return {
            "code": code,
            "title": title,
            "icon": icon,
            "percent": safe_percent,
            "current": current,
            "target": target,
            "unit": unit,
            "active": bool(active),
            "status": ReadModelService._score_status(safe_percent),
            "summary": summary,
            "detail_endpoint": detail_endpoint,
        }

    @staticmethod
    def _metric(label: str, current, target, unit: str, *, limit: bool = False) -> dict:
        current_value = _as_float(current)
        target_value = _as_float(target)
        if limit and target_value > 0:
            percent = max(0, min(round((1 - max(current_value - target_value, 0) / target_value) * 100), 100))
        else:
            percent = ReadModelService._bounded_percent(current_value, target_value)
        return {
            "label": label,
            "current": round(current_value, 2),
            "target": round(target_value, 2) if target is not None else None,
            "unit": unit,
            "percent": percent,
            "limit": limit,
            "status": ReadModelService._score_status(percent),
        }

    @staticmethod
    def _summary_card(label: str, current, target, unit: str) -> dict:
        return {
            "label": label,
            "current": round(_as_float(current), 2),
            "target": round(_as_float(target), 2) if target is not None else None,
            "unit": unit,
            "percent": ReadModelService._bounded_percent(current, target),
        }

    @staticmethod
    def _bounded_percent(current, target) -> int:
        current_value = _as_float(current)
        target_value = _as_float(target)
        if target_value <= 0:
            return 0
        return max(0, min(round((current_value / target_value) * 100), 100))

    @staticmethod
    def _habits_percent(habits: dict) -> int:
        active_count = _as_int(habits.get("active_count"))
        if active_count <= 0:
            return 0
        return max(0, min(100, _as_int(habits.get("score"))))

    @staticmethod
    def _motivation_percent(motivation: dict) -> int:
        missions_total = _as_int(motivation.get("missions_total"))
        missions_completed = _as_int(motivation.get("missions_completed"))
        if missions_total > 0:
            return max(
                0,
                min(round((missions_completed / missions_total) * 100), 100),
            )
        daily_points = _as_int(motivation.get("daily_points"))
        if daily_points <= 0:
            return 0
        return max(0, min(round((daily_points / 60) * 100), 100))

    @staticmethod
    def _weighted_overall_score(cards: list[dict]) -> int:
        weights = {
            "nutrition": 20,
            "hydration": 15,
            "activity": 15,
            "sleep": 15,
            "medications": 10,
            "chronic": 10,
            "habits": 5,
            "motivation": 0,
        }
        active_cards = [card for card in cards if card.get("active")]
        total_weight = sum(weights.get(card["code"], 0) for card in active_cards)
        if total_weight <= 0:
            return 0
        score = sum(
            _as_float(card.get("percent")) * weights.get(card["code"], 0)
            for card in active_cards
        ) / total_weight
        return max(0, min(round(score), 100))

    @staticmethod
    def _score_status(percent: int) -> str:
        if percent >= 85:
            return "Great"
        if percent >= 70:
            return "Good"
        if percent >= 45:
            return "Improving"
        return "Needs attention"

    @classmethod
    def _weekly_consistency(cls, history_items: list[dict]) -> dict:
        days = cls._timeline_payload(history_items)
        met = sum(1 for item in days if _as_int(item.get("score")) >= 60)
        total = len(days) or 7
        return {
            "days_met": met,
            "total_days": total,
            "percent": round((met / total) * 100) if total else 0,
            "days": days,
        }

    @classmethod
    def _timeline_payload(cls, history_items: list[dict]) -> list[dict]:
        items = []
        for item in history_items:
            score = cls._history_day_score(item)
            items.append(
                {
                    "date": item.get("date"),
                    "score": score,
                    "points": _as_int(item.get("points_estimate")),
                    "complete": score >= 60,
                }
            )
        return items

    @classmethod
    def _history_day_score(cls, item: dict) -> int:
        parts = [
            cls._bounded_percent(item.get("calories_in"), item.get("calories_target")),
            cls._bounded_percent(item.get("water_current"), item.get("water_target")),
            cls._bounded_percent(item.get("calories_burned"), item.get("burn_target")),
            cls._bounded_percent(item.get("steps"), item.get("steps_target")),
            cls._bounded_percent(item.get("sleep_hours"), item.get("sleep_target")),
        ]
        med = _as_float(item.get("medication_adherence_percent"))
        chronic = _as_float(item.get("condition_adherence_percent"))
        if med > 0:
            parts.append(round(med))
        if chronic > 0:
            parts.append(round(chronic))
        active = [part for part in parts if part > 0]
        if not active:
            return 0
        return max(0, min(round(sum(active) / len(active)), 100))

    @staticmethod
    def _progress_insight(*, overall_score: int, cards: list[dict]) -> dict:
        weakest = next(
            (
                card
                for card in sorted(cards, key=lambda item: item.get("percent", 0))
                if card.get("active") and card.get("code") != "motivation"
            ),
            None,
        )
        if weakest:
            message = f"Focus on {weakest['title'].lower()} today to lift your overall progress."
        elif overall_score > 0:
            message = "Keep logging trackers consistently to build a stronger weekly pattern."
        else:
            message = "Start with one tracker update and the rest will follow."
        return {
            "title": "Insight",
            "message": message,
        }

    @classmethod
    def _detail_trend(cls, *, tracker: str, history_items: list[dict]) -> list[dict]:
        key_map = {
            "nutrition": ("calories_in", "calories_target"),
            "hydration": ("water_current", "water_target"),
            "activity": ("calories_burned", "burn_target"),
            "steps": ("steps", "steps_target"),
            "sleep": ("sleep_hours", "sleep_target"),
            "medications": ("medication_adherence_percent", None),
            "chronic": ("condition_adherence_percent", None),
            "habits": ("points_estimate", None),
            "motivation": ("points_estimate", None),
        }
        current_key, target_key = key_map.get(tracker, ("points_estimate", None))
        trend = []
        for item in history_items:
            current = _as_float(item.get(current_key))
            target = _as_float(item.get(target_key)) if target_key else 100
            percent = cls._bounded_percent(current, target) if target_key else max(0, min(round(current), 100))
            trend.append(
                {
                    "date": item.get("date"),
                    "value": round(current, 2),
                    "target": round(target, 2) if target_key else None,
                    "percent": percent,
                    "points": _as_int(item.get("points_estimate")),
                }
            )
        return trend

    @staticmethod
    def _sum_history(history_items: list[dict], key: str) -> float:
        return round(sum(_as_float(item.get(key)) for item in history_items), 2)

    @staticmethod
    def _active_days(history_items: list[dict], key: str) -> int:
        return sum(1 for item in history_items if _as_float(item.get(key)) > 0)

    @staticmethod
    def _streak_from_history(history_items: list[dict], key: str) -> int:
        streak = 0
        for item in reversed(history_items):
            if _as_float(item.get(key)) <= 0:
                break
            streak += 1
        return streak

    @classmethod
    def nutrition_summary(cls, *, user, request_id: str) -> dict:
        state, is_stale = cls._synchronize_current_state(
            user=user,
            source="nutrition_summary",
        )
        summary = dict((state.progress_summary.get("summary") if state else {}) or {})

        # Nutrition writes are immediately visible to the user. The unified
        # health snapshot can legitimately lag behind the command-side meal
        # rows, so use today's immutable meal snapshots for consumed nutrients.
        from core.services.nutrition.nutrition_service import NutritionLoggingService

        live_totals = NutritionLoggingService.nutrition_totals_for_day(
            user=user,
            on_date=_system_local_date(),
        )
        summary.update(live_totals)
        summary["calories_consumed"] = live_totals["calories_kcal"]

        gamification = cls._live_score(user=user)
        calorie_constraint = EffectiveConstraintReader.get_effective_constraint(
            user=user,
            tracker_type="nutrition",
            constraint_key="calories_kcal",
            default_value=cls._profile_daily_calorie_target(user=user),
            default_unit="kcal",
            default_source="profile_fallback",
        )
        target_calories = _as_int(summary.get("calories_target"))
        if target_calories <= 0:
            target_calories = _as_int(calorie_constraint.value)
        consumed_calories = _as_int(summary.get("calories_consumed"))
        progress_percent = round(
            (consumed_calories / target_calories) * 100,
            1,
        ) if target_calories > 0 else 0.0
        calorie_status = "not_configured"
        calorie_reason = "Set a daily calorie target to evaluate progress."
        if target_calories > 0:
            if consumed_calories > target_calories:
                calorie_status = "over_target"
                calorie_reason = "Daily energy intake is above the active target."
            elif progress_percent >= 85:
                calorie_status = "good"
                calorie_reason = "Daily energy intake is within the target range."
            else:
                calorie_status = "low"
                calorie_reason = "Daily energy intake is still below the target range."

        metric_specs = (
            ("protein", "Protein", "protein_g", "protein_g", 100.0, "g", "minimum"),
            ("carbs", "Carbohydrates", "carbs_g", "carbohydrates_g", 250.0, "g", "range"),
            ("fat", "Fat", "fat_g", "fat_g", 70.0, "g", "range"),
            ("fiber", "Fiber", "fiber_g", "fiber_g", 30.0, "g", "minimum"),
            ("sugar", "Sugar", "sugars_g", "sugars_g", 50.0, "g", "maximum"),
            ("sodium", "Sodium", "sodium_mg", "sodium_mg", 2300.0, "mg", "maximum"),
            (
                "saturated_fat",
                "Saturated fat",
                "saturated_fat_g",
                "saturated_fat_g",
                20.0,
                "g",
                "maximum",
            ),
            (
                "cholesterol",
                "Cholesterol",
                "cholesterol_mg",
                "cholesterol_mg",
                300.0,
                "mg",
                "maximum",
            ),
        )
        effective_metrics = EffectiveConstraintReader.get_effective_constraints(
            user=user,
            requests=[
                {
                    "tracker_type": "nutrition",
                    "constraint_key": constraint_key,
                    "default_value": default_target,
                    "default_unit": unit,
                    "default_source": "documented_nutrition_reference_default",
                }
                for _, _, _, constraint_key, default_target, unit, _ in metric_specs
            ],
        )
        metrics = []
        for code, label, value_key, constraint_key, default_target, unit, target_kind in metric_specs:
            effective = effective_metrics[("nutrition", constraint_key)]
            metric = cls._nutrition_metric(
                code=code,
                label=label,
                value=_as_float(summary.get(value_key)),
                target=_as_float(effective.value),
                unit=unit,
                target_kind=target_kind,
            )
            metric["target_source"] = effective.source_type
            metric["constraint_reason"] = effective.reason
            metric["constraint_id"] = effective.constraint_id
            metrics.append(metric)
        data = {
            "target_calories": target_calories,
            "active_target_calories": target_calories,
            "constraint_source": calorie_constraint.source_type,
            "constraint_reason": calorie_constraint.reason,
            "consumed_calories": consumed_calories,
            "burned_calories": _as_int(summary.get("calories_burned")),
            "remaining_calories": max(target_calories - consumed_calories, 0)
            if target_calories > 0
            else _as_int(summary.get("calories_remaining")),
            "points": _as_int(gamification.get("points")),
            "progress_percent": progress_percent,
            "status": calorie_status,
            "status_reason": calorie_reason,
            "metrics": metrics,
            "protein_g": _as_float(summary.get("protein_g")),
            "carbs_g": _as_float(summary.get("carbs_g")),
            "fat_g": _as_float(summary.get("fat_g")),
            "sugars_g": _as_float(summary.get("sugars_g")),
            "added_sugars_g": _as_float(summary.get("added_sugars_g")),
            "fiber_g": _as_float(summary.get("fiber_g")),
            "sodium_mg": _as_float(summary.get("sodium_mg")),
            "saturated_fat_g": _as_float(summary.get("saturated_fat_g")),
            "cholesterol_mg": _as_float(summary.get("cholesterol_mg")),
            "potassium_mg": _as_float(summary.get("potassium_mg")),
            "calcium_mg": _as_float(summary.get("calcium_mg")),
            "iron_mg": _as_float(summary.get("iron_mg")),
            "magnesium_mg": _as_float(summary.get("magnesium_mg")),
            "zinc_mg": _as_float(summary.get("zinc_mg")),
            "phosphorus_mg": _as_float(summary.get("phosphorus_mg")),
            "vitamin_a_mcg": _as_float(summary.get("vitamin_a_mcg")),
            "vitamin_c_mg": _as_float(summary.get("vitamin_c_mg")),
            "vitamin_d_mcg": _as_float(summary.get("vitamin_d_mcg")),
            "vitamin_e_mg": _as_float(summary.get("vitamin_e_mg")),
            "vitamin_k_mcg": _as_float(summary.get("vitamin_k_mcg")),
            "vitamin_b1_mg": _as_float(summary.get("vitamin_b1_mg")),
            "vitamin_b2_mg": _as_float(summary.get("vitamin_b2_mg")),
            "vitamin_b3_mg": _as_float(summary.get("vitamin_b3_mg")),
            "vitamin_b6_mg": _as_float(summary.get("vitamin_b6_mg")),
            "vitamin_b12_mcg": _as_float(summary.get("vitamin_b12_mcg")),
            "folate_mcg": _as_float(summary.get("folate_mcg")),
            "caffeine_mg": _as_float(summary.get("caffeine_mg")),
            "state_version": state.version if state else None,
            "generated_at": state.last_computed_at.isoformat() if state else None,
        }
        return cls._envelope(data=data, state=state, is_stale=is_stale, request_id=request_id)

    @staticmethod
    def _nutrition_metric(*, code, label, value, target, unit, target_kind):
        progress_percent = round((value / target) * 100, 1) if target > 0 else 0.0
        if target_kind == "maximum":
            status = "high" if value > target else "good"
            reason = (
                f"Above the daily limit of {target:g} {unit}."
                if status == "high"
                else f"Within the daily limit of {target:g} {unit}."
            )
        elif target_kind == "minimum":
            status = "good" if value >= target else "low"
            reason = (
                f"Daily target of {target:g} {unit} reached."
                if status == "good"
                else f"Below the daily target of {target:g} {unit}."
            )
        else:
            status = "high" if value > target else ("good" if value >= target * 0.75 else "low")
            reason = (
                f"Above the reference target of {target:g} {unit}."
                if status == "high"
                else (
                    f"Within the reference range for a {target:g} {unit} target."
                    if status == "good"
                    else f"Below the reference range for a {target:g} {unit} target."
                )
            )
        return {
            "code": code,
            "label": label,
            "value": round(value, 2),
            "target": target,
            "unit": unit,
            "progress_percent": progress_percent,
            "status": status,
            "reason": reason,
            "target_kind": target_kind,
        }

    @staticmethod
    def _profile_daily_calorie_target(*, user) -> int:
        profile = getattr(user, "userprofile", None)
        if profile is None:
            return 0
        return _as_int(getattr(profile, "daily_calorie_target", 0))

    @classmethod
    def hydration_summary(cls, *, user, request_id: str, target_date: date | None = None) -> dict:
        target_date = target_date or timezone.localdate()
        state, is_stale = cls._synchronize_current_state(
            user=user,
            source="hydration_summary",
        )
        hydration = dict((state.progress_summary.get("hydration") if state else {}) or {})
        start, end = HydrationRepository.day_bounds(target_date)
        breakdown = HydrationRepository.contribution_breakdown_for_period(
            user=user,
            start=start,
            end=end,
        )
        consumed_volume_ml = round(_as_float(breakdown.get("consumed_volume_liters")) * 1000)
        current_ml = round(_as_float(breakdown.get("hydration_contribution_liters")) * 1000)
        water_contribution_ml = round(_as_float(breakdown.get("water_contribution_liters")) * 1000)
        other_drinks_contribution_ml = round(
            _as_float(breakdown.get("other_drinks_contribution_liters")) * 1000
        )
        base_target_ml = round(_as_float(hydration.get("base_target")) * 1000)
        constraint_target_ml = round(_as_float(hydration.get("constraint_target")) * 1000)
        adjusted_target_ml = round(_as_float(hydration.get("adjusted_target")) * 1000)
        target_ml = round(_as_float(hydration.get("target")) * 1000)
        profile = getattr(user, "userprofile", None)
        profile_target = _as_float(getattr(profile, "daily_water_target", 0))
        hydration_constraint = EffectiveConstraintReader.get_effective_constraint(
            user=user,
            tracker_type="hydration",
            constraint_key="daily_water_liters",
            default_value=profile_target,
            default_unit="liters",
            default_source="profile_fallback",
        )
        if base_target_ml <= 0:
            base_target_ml = round(_as_float(hydration_constraint.value) * 1000)
        if constraint_target_ml <= 0:
            constraint_target_ml = target_ml or base_target_ml
        active_target_ml = adjusted_target_ml if adjusted_target_ml > 0 else constraint_target_ml
        adjustment_reasons = []
        if constraint_target_ml and base_target_ml and abs(constraint_target_ml - base_target_ml) > 1:
            adjustment_reasons.append("chronic_condition")
        if adjusted_target_ml and constraint_target_ml and adjusted_target_ml > constraint_target_ml + 1:
            adjustment_reasons.append("activity")
        last_log = HydrationRepository.list_for_user_on_date(user, target_date).first()
        points_earned_today = (
            PointsTransaction.objects.filter(
                user=user,
                source_type=PointsTransaction.SOURCE_HYDRATION,
                event_date=target_date,
            )
            .aggregate(total=Sum("points"))
            .get("total")
            or 0
        )
        progress_percent = (
            0
            if active_target_ml <= 0
            else round(min(current_ml / active_target_ml, 1.0) * 100)
        )
        data = {
            "date": target_date.isoformat(),
            "consumed_volume_ml": consumed_volume_ml,
            "hydration_contribution_ml": current_ml,
            "water_contribution_ml": water_contribution_ml,
            "other_drinks_contribution_ml": other_drinks_contribution_ml,
            "base_target_ml": base_target_ml,
            "adjusted_target_ml": adjusted_target_ml,
            "active_target_ml": active_target_ml,
            "target_ml": active_target_ml,
            "consumed_ml": current_ml,
            "remaining_ml": max(active_target_ml - current_ml, 0),
            "progress_percent": progress_percent,
            "goal_completed": active_target_ml > 0 and current_ml >= active_target_ml,
            "last_drink_at": last_log.consumed_at.isoformat() if last_log else None,
            "points_earned_today": int(points_earned_today),
            "adjustment_reasons": adjustment_reasons,
            "constraint_source": hydration_constraint.source_type,
            "constraint_reason": hydration_constraint.reason,
            "state_version": state.version if state else None,
            "generated_at": state.last_computed_at.isoformat() if state else None,
        }
        return cls._envelope(data=data, state=state, is_stale=is_stale, request_id=request_id)

    @classmethod
    def sleep_summary(cls, *, user, request_id: str) -> dict:
        state, is_stale = cls._synchronize_current_state(
            user=user,
            source="sleep_summary",
        )
        sleep = dict((state.progress_summary.get("sleep") if state else {}) or {})
        profile = getattr(user, "userprofile", None)
        sleep_constraint = EffectiveConstraintReader.get_effective_constraint(
            user=user,
            tracker_type="sleep",
            constraint_key="sleep_hours",
            default_value=_as_float(getattr(profile, "recommended_sleep_hours", 0)),
            default_unit="hours",
            default_source="profile_fallback",
        )
        gamification = cls._live_score(user=user)
        data = {
            "base_target_hours": _as_float(getattr(profile, "recommended_sleep_hours", 0)),
            "active_target_hours": _as_float(sleep.get("recommended_sleep_hours")),
            "goal_hours": _as_float(sleep.get("recommended_sleep_hours")),
            "logged_hours_today": _as_float(sleep.get("logged_hours_today")),
            "progress_percent": _as_int(sleep.get("progress_percent")),
            "sleep_points": _as_int(gamification.get("points")),
            "constraint_source": sleep_constraint.source_type,
            "constraint_reason": sleep_constraint.reason,
            "state_version": state.version if state else None,
            "generated_at": state.last_computed_at.isoformat() if state else None,
        }
        return cls._envelope(data=data, state=state, is_stale=is_stale, request_id=request_id)

    @classmethod
    def steps_summary(cls, *, user, request_id: str) -> dict:
        state, is_stale = cls._synchronize_current_state(
            user=user,
            source="steps_summary",
        )
        activity = dict((state.progress_summary.get("activity") if state else {}) or {})
        steps = _as_int(activity.get("steps"))
        target = _as_int(activity.get("steps_target"))
        profile = getattr(user, "userprofile", None)
        steps_constraint = EffectiveConstraintReader.get_effective_constraint(
            user=user,
            tracker_type="steps",
            constraint_key="steps_count",
            default_value=_as_int(getattr(profile, "daily_step_goal", 0)),
            default_unit="steps",
            default_source="profile_fallback",
        )
        today = _system_local_date()
        direct_log = StepLog.objects.filter(user=user, date=today).first()
        if direct_log is not None:
            direct_steps = _as_int(direct_log.steps_count)
            if direct_steps >= steps:
                steps = direct_steps
                activity["steps"] = direct_steps
                activity["distance_km"] = _as_float(direct_log.distance_km)
                activity["steps_burned"] = _as_int(direct_log.calories_burned)
                if direct_log.distance_km:
                    activity["steps_burn_rate"] = round(
                        _as_int(direct_log.calories_burned)
                        / _as_float(direct_log.distance_km),
                        1,
                    )
                else:
                    activity["steps_burn_rate"] = 0
        extra_steps = max(steps - target, 0) if target > 0 else 0
        progress_percent = round((steps / target) * 100) if target > 0 else 0
        data = {
            "date": today.isoformat(),
            "target_steps": target,
            "steps_today": steps,
            "remaining_steps": max(target - steps, 0),
            "extra_steps": extra_steps,
            "steps_progress_percent": progress_percent,
            "distance_km": _as_float(activity.get("distance_km")),
            "calories_burned": _as_int(activity.get("steps_burned")),
            "burn_rate_kcal_per_km": _as_float(activity.get("steps_burn_rate")),
            "sensor_steps": _as_int(getattr(direct_log, "sensor_steps", 0)) if direct_log else 0,
            "manual_adjustment_steps": _as_int(getattr(direct_log, "manual_adjustment_steps", 0)) if direct_log else 0,
            "imported_adjustment_steps": _as_int(getattr(direct_log, "imported_adjustment_steps", 0)) if direct_log else 0,
            "sync_version": _as_int(getattr(direct_log, "sync_version", 0)) if direct_log else 0,
            "points": sum(
                int(item.points or 0)
                for item in PointsTransaction.objects.filter(
                    user=user,
                    source_type=PointsTransaction.SOURCE_STEPS,
                    event_date=today,
                ).only("points")
            ),
            "base_target_steps": _as_int(getattr(profile, "daily_step_goal", 0)),
            "active_target_steps": target,
            "constraint_source": steps_constraint.source_type,
            "constraint_reason": steps_constraint.reason,
            "state_version": state.version if state else None,
            "generated_at": state.last_computed_at.isoformat() if state else None,
        }
        return cls._envelope(data=data, state=state, is_stale=is_stale, request_id=request_id)

    @classmethod
    def activity_summary(cls, *, user, request_id: str) -> dict:
        state, is_stale = cls._synchronize_current_state(
            user=user,
            source="activity_summary",
        )
        summary = dict((state.progress_summary.get("summary") if state else {}) or {})
        history_entry = dict((state.progress_summary.get("history_entry") if state else {}) or {})
        burn_target = _as_int(summary.get("burn_target"))
        burn_current = _as_int(summary.get("calories_burned"))
        exercise_minutes = _as_int(history_entry.get("exercise_minutes"))
        points_estimate = _as_int(history_entry.get("points_estimate"))
        profile = getattr(user, "userprofile", None)
        burn_constraint = EffectiveConstraintReader.get_effective_constraint(
            user=user,
            tracker_type="activity",
            constraint_key="calories_burned",
            default_value=_as_int(getattr(profile, "daily_burn_goal", 0)),
            default_unit="kcal",
            default_source="profile_fallback",
        )
        today = _system_local_date()
        movement = MovementEvaluator.evaluate(user=user, target_date=today)
        active_calories = dict(movement.get("active_calories") or {})
        steps_component = dict((movement.get("components") or {}).get("steps") or {})
        exercise_component = dict((movement.get("components") or {}).get("exercise") or {})
        active_time = dict(movement.get("active_time") or {})
        weekly_active_time = dict(movement.get("weekly_active_time") or {})
        data = {
            "date": today.isoformat(),
            "burn_target": burn_target,
            "burn_current": _as_int(active_calories.get("value")) or burn_current,
            "exercise_minutes": _as_int(exercise_component.get("current")) or exercise_minutes,
            "points_estimate": points_estimate,
            "active_calories": active_calories,
            "steps_card": {
                "steps": _as_int(steps_component.get("current")),
                "target": _as_int(steps_component.get("target")),
                "percent": _as_int(steps_component.get("progress_percent")),
                "remaining": max(
                    _as_int(steps_component.get("target")) - _as_int(steps_component.get("current")),
                    0,
                ),
                "calories": _as_int(steps_component.get("calories")),
                "distance_km": _as_float(steps_component.get("distance_km")),
                "status": steps_component.get("status"),
            },
            "active_time_card": {
                "today_minutes": _as_int(active_time.get("today_minutes")),
                "target_minutes": _as_int(active_time.get("daily_target_minutes")),
                "percent": _as_int(active_time.get("percent")),
                "remaining_minutes": _as_int(active_time.get("remaining_minutes")),
                "weekly_minutes": _as_int(weekly_active_time.get("weekly_minutes")),
                "weekly_target_minutes": _as_int(weekly_active_time.get("weekly_target_minutes")),
                "active_day_count": _as_int(weekly_active_time.get("active_day_count")),
                "breakdown": active_time.get("breakdown") or {},
                "coverage_status": active_time.get("coverage_status"),
            },
            "workouts_card": {
                "count": _as_int(exercise_component.get("workout_count")),
                "minutes": _as_int(exercise_component.get("current")),
                "target_minutes": _as_int(exercise_component.get("target")),
                "percent": _as_int(exercise_component.get("progress_percent")),
                "calories": _as_int(exercise_component.get("calories")),
                "status": exercise_component.get("status"),
            },
            "sync": {
                "state": "stale" if is_stale else "synced",
                "last_synced_at": state.last_computed_at.isoformat() if state and state.last_computed_at else None,
            },
            "today_summary": ActivitySessionService.build_today_summary(user=user),
            "weekly_summary": ActivitySessionService.build_weekly_summary(user=user),
            "active_session": ActivitySessionService.active_session_payload(user=user),
            "suggestions": ActivitySessionService.build_suggestions(user=user),
            "base_target_kcal": _as_int(getattr(profile, "daily_burn_goal", 0)),
            "active_target_kcal": burn_target,
            "constraint_source": burn_constraint.source_type,
            "constraint_reason": burn_constraint.reason,
            "state_version": state.version if state else None,
            "generated_at": state.last_computed_at.isoformat() if state else None,
        }
        return cls._envelope(data=data, state=state, is_stale=is_stale, request_id=request_id)

    @classmethod
    def medications_overview(cls, *, user, request_id: str) -> dict:
        state, is_stale = cls._synchronize_current_state(
            user=user,
            source="medications_overview",
        )
        medications = list(MedicationReadService.get_medication_plans(user=user).filter(is_active=True))
        today_plan = list(MedicationReadService.get_today_dose_logs(user=user))
        today = timezone.localdate()
        summary = MedicationAdherenceService.get_user_adherence(
            user=user,
            start_date=today - timedelta(days=29),
            end_date=today,
        )
        from core.api.medication.serializers import serialize_adherence, serialize_dose_log, serialize_medication

        today_counts = MedicationAdherenceService.counts_for_day(user=user, target_date=today)
        expected_today = _as_int(today_counts.get("today_total_doses"))
        taken_today = _as_int(today_counts.get("taken_today"))
        missed_today = _as_int(today_counts.get("missed_today")) + _as_int(today_counts.get("overdue_today"))
        pending_today = _as_int(today_counts.get("pending_today"))
        percent_today = round((taken_today / expected_today) * 100, 2) if expected_today else 0.0
        next_due = MedicationAdherenceService.next_due(user=user)
        has_missed_or_overdue = missed_today > 0
        if expected_today == 0:
            motivation_strip = None
        elif has_missed_or_overdue:
            motivation_strip = {
                "tone": "attention",
                "title": "Review missed medication",
                "subtitle": "Log or resolve overdue doses to keep adherence accurate.",
            }
        elif taken_today >= expected_today:
            motivation_strip = {
                "tone": "positive",
                "title": "Medication plan complete",
                "subtitle": "All scheduled doses are recorded for today.",
            }
        elif pending_today > 0:
            motivation_strip = {
                "tone": "focus",
                "title": "Keep today's plan moving",
                "subtitle": f"{pending_today} dose{'s' if pending_today != 1 else ''} still pending.",
            }
        else:
            motivation_strip = None

        data = {
            "medications": [serialize_medication(item) for item in medications],
            "today_plan": [serialize_dose_log(item) for item in today_plan],
            "overall_adherence": serialize_adherence(summary),
            "today_adherence": {
                "completed": taken_today,
                "expected": expected_today,
                "percent": percent_today,
                "taken": taken_today,
                "pending": pending_today,
                "missed": missed_today,
                "skipped": _as_int(today_counts.get("skipped_today")),
            },
            "next_dose": serialize_dose_log(next_due) if next_due else None,
            "streak": summary.streak_days,
            "shortcut_counts": {
                "today_plan": len(today_plan),
                "all_medications": len(medications),
                "history": summary.expected_doses,
                "insights": round(summary.adherence_percent, 2),
            },
            "motivation_strip": motivation_strip,
            "snapshot_summary": dict((state.progress_summary.get("medications") if state else {}) or {}),
        }
        return cls._envelope(data=data, state=state, is_stale=is_stale, request_id=request_id)

    @classmethod
    def chronic_overview(cls, *, user, request_id: str, view: str = "") -> dict:
        state, is_stale = cls._synchronize_current_state(
            user=user,
            source="chronic_overview",
        )
        if view == "guidance":
            data = {
                "conditions": cls._guidance_conditions(user=user),
                "summary": dict(
                    (state.progress_summary.get("chronic_conditions") if state else {})
                    or cls._empty_chronic_dashboard_summary()
                ),
            }
            return cls._envelope(
                data=data,
                state=state,
                is_stale=is_stale,
                request_id=request_id,
            )

        from core.services.chronic.condition_medication_service import ConditionMedicationService
        compact_conditions = cls._compact_conditions(user=user)
        doses = ConditionMedicationService.today_dose_list(user=user)
        data = {
            "conditions": compact_conditions,
            "today_doses": doses,
            "summary": dict(
                (state.progress_summary.get("chronic_conditions") if state else {})
                or cls._empty_chronic_dashboard_summary()
            ),
        }
        return cls._envelope(data=data, state=state, is_stale=is_stale, request_id=request_id)

    @classmethod
    def _compact_conditions(cls, *, user) -> list[dict]:
        return [
            ChronicConditionService.condition_compact_overview(user_condition=item)
            for item in ConditionReadService.get_user_conditions(user=user, compact=True)
        ]

    @classmethod
    def _home_conditions(cls, *, user) -> list[dict]:
        return [
            ChronicConditionService.condition_light_overview(
                user_condition=item,
                include_targets=False,
            )
            for item in ConditionReadService.get_user_conditions_home(user=user)
        ]

    @classmethod
    def _guidance_conditions(cls, *, user) -> list[dict]:
        return [
            ChronicConditionService.condition_light_overview(
                user_condition=item,
                include_targets=True,
            )
            for item in ConditionReadService.get_user_conditions_guidance(user=user)
        ]

    @classmethod
    def _dashboard_payload(cls, state) -> dict:
        if state is None:
            return cls._empty_progress_overview()
        return cls._progress_summary_payload(state.progress_summary)

    @classmethod
    def _progress_summary_payload(cls, progress_summary) -> dict:
        progress_summary = dict(progress_summary or {})
        payload = {
            "summary": dict(progress_summary.get("summary") or {}),
            "hydration": dict(progress_summary.get("hydration") or {}),
            "sleep": dict(progress_summary.get("sleep") or {}),
            "activity": dict(progress_summary.get("activity") or {}),
            "gamification": dict(progress_summary.get("gamification") or {}),
            "chronic_conditions": dict(
                progress_summary.get("chronic_conditions") or cls._empty_chronic_dashboard_summary()
            ),
            "medications": dict(progress_summary.get("medications") or {}),
        }
        if progress_summary.get("active_warnings"):
            payload["active_warnings"] = list(progress_summary.get("active_warnings") or [])
        if progress_summary.get("impacted_trackers"):
            payload["impacted_trackers"] = list(progress_summary.get("impacted_trackers") or [])
        return payload

    @classmethod
    def _is_empty_progress_overview(cls, data: dict) -> bool:
        summary = dict(data.get("summary") or {})
        hydration = dict(data.get("hydration") or {})
        sleep = dict(data.get("sleep") or {})
        activity = dict(data.get("activity") or {})
        return not any(
            [
                _as_int(summary.get("calories_target")),
                _as_int(summary.get("calories_consumed")),
                _as_int(summary.get("burn_target")),
                _as_float(hydration.get("target")),
                _as_float(hydration.get("current")),
                _as_float(sleep.get("recommended_sleep_hours")),
                _as_float(sleep.get("logged_hours_today")),
                _as_int(activity.get("steps_target")),
                _as_int(activity.get("steps")),
            ]
        )

    @classmethod
    def _current_projection_payload(cls, *, user) -> dict | None:
        progress_summary = cls._current_projection_progress_summary(
            user=user,
            source="progress_overview_read_fallback",
        )
        if progress_summary is None:
            return None
        return cls._progress_summary_payload(progress_summary)

    @classmethod
    def _current_projection_progress_summary(cls, *, user, source: str) -> dict | None:
        state, _is_stale = cls._synchronize_current_state(user=user, source=source)
        if state is None:
            return None
        return dict(state.progress_summary or {})

    @classmethod
    def _history_projection_payload(cls, *, user, today: date, days: int) -> list[dict] | None:
        from core.services.tracking.health_tracker_coordinator import (
            HealthTrackerCoordinator,
        )

        return HealthTrackerCoordinator().build_history(
            user=user,
            today=today,
            days=days,
        )

    @classmethod
    def _synchronize_current_state(cls, *, user, source: str):
        from core.services.orchestration.health_state_bootstrap_service import (
            HealthStateBootstrapService,
        )
        from core.services.orchestration.health_state_orchestrator import (
            HealthStateOrchestrator,
        )

        today = _system_local_date()
        state = cls._current_state(user=user)
        if state is None:
            state = HealthStateBootstrapService.ensure_initialized(
                user=user,
                state_date=today,
            )
        elif cls._is_state_stale(user=user, state=state):
            latest_running = (
                HealthStateComputationRun.objects.filter(
                    user=user,
                    run_status=HealthStateComputationRun.STATUS_RUNNING,
                    started_at__gt=state.last_computed_at,
                )
                .order_by("-started_at", "-id")
                .first()
            )
            refresh_identity = latest_running.id if latest_running else state.version
            HealthStateOrchestrator().handle_event(
                user=user,
                trigger_type=cls.STALE_REFRESH_TRIGGER,
                payload={
                    "trigger_reference": (
                        f"read-model-refresh:{user.id}:{today}:{refresh_identity}"
                    ),
                    "idempotency_key": (
                        f"health-state-read-refresh:{user.id}:{today}:{refresh_identity}"
                    ),
                    "event_dates": [today],
                    "today": today,
                    "source": source,
                },
                synchronous=True,
            )
            state = cls._current_state(user=user)
        return state, cls._is_state_stale(user=user, state=state)

    @classmethod
    def _current_state(cls, *, user):
        return UnifiedHealthState.objects.filter(
            user=user,
            state_date=_system_local_date(),
            window_kind=UnifiedHealthState.WINDOW_CURRENT,
        ).first()

    @staticmethod
    def _repair_recent_medication_points(*, user) -> None:
        today = _system_local_date()
        MedicationDoseWorkflowService.repair_missing_points_for_user(
            user=user,
            start_date=today - timedelta(days=30),
            end_date=today,
        )

    @staticmethod
    def _live_score(*, user) -> dict:
        score = (
            UserScore.objects.filter(user=user)
            .only("total_points", "level")
            .first()
        )
        if score is None:
            return {"points": 0, "level": 1}
        return {"points": int(score.total_points or 0), "level": int(score.level or 1)}

    @classmethod
    def _with_live_score(cls, payload: dict, *, user) -> dict:
        next_payload = dict(payload or {})
        gamification = dict(next_payload.get("gamification") or {})
        gamification.update(cls._live_score(user=user))
        next_payload["gamification"] = gamification
        return next_payload

    @staticmethod
    def _motivation_overview_data(*, user) -> dict:
        try:
            payload = MotivationService.overview(
                user=user,
                request_id="read-model",
                target_date=_system_local_date(),
            )
            return dict(payload.get("data") or {})
        except Exception:
            return {
                "daily_points": 0,
                "missions_completed": 0,
                "missions_total": 0,
                "current_streak": 0,
                "level_name": "Beginner",
                "insight": "",
            }

    @classmethod
    def _with_medication_points_in_history(cls, *, user, items: list[dict]) -> list[dict]:
        next_items = []
        for item in items:
            next_item = dict(item)
            if "medication_points" in next_item:
                next_items.append(next_item)
                continue
            item_date = next_item.get("date")
            try:
                target_date = date.fromisoformat(str(item_date))
            except (TypeError, ValueError):
                next_items.append(next_item)
                continue
            medication_points = MedicationAdherenceService.points_for_day(
                user=user,
                target_date=target_date,
            )
            next_item["medication_points"] = medication_points
            next_item["tracker_points_estimate"] = _as_int(
                next_item.get("points_estimate")
            )
            next_item["points_estimate"] = (
                _as_int(next_item.get("points_estimate")) + medication_points
            )
            next_items.append(next_item)
        return next_items

    @classmethod
    def _is_state_stale(cls, *, user, state) -> bool:
        if state is None:
            return True
        return HealthStateComputationRun.objects.filter(
            user=user,
            run_status=HealthStateComputationRun.STATUS_RUNNING,
            started_at__gt=state.last_computed_at,
        ).exists()

    @classmethod
    def _envelope(cls, *, data: dict, state, is_stale: bool, request_id: str) -> dict:
        meta = EnvelopeMeta(
            is_stale=bool(is_stale),
            computed_at=state.last_computed_at.isoformat() if state is not None else None,
            snapshot_version=state.version if state is not None else None,
            request_id=request_id,
        )
        return {
            "data": data,
            "meta": meta.as_dict(),
        }

    @staticmethod
    def _empty_chronic_dashboard_summary() -> dict:
        return {
            "count": 0,
            "labels": [],
            "adherence_percent": 0.0,
            "active_medications_today": 0,
            "pending_doses_today": 0,
            "applied_summaries": [],
            "disclaimer": "",
        }

    @classmethod
    def _empty_progress_overview(cls) -> dict:
        return {
            "summary": {
                "calories_target": 0,
                "calories_consumed": 0,
                "calories_remaining": 0,
                "calories_burned": 0,
                "burn_target": 0,
                "protein_g": 0.0,
                "carbs_g": 0.0,
                "fat_g": 0.0,
                "sugars_g": 0.0,
                "added_sugars_g": 0.0,
                "fiber_g": 0.0,
                "caffeine_mg": 0.0,
            },
            "hydration": {
                "target": 0.0,
                "current": 0.0,
                "adjusted_target": 0.0,
            },
            "sleep": {
                "target_bed_time": None,
                "target_wake_time": None,
                "recommended_sleep_hours": 0.0,
                "logged_hours_today": 0.0,
                "progress_percent": 0,
            },
            "activity": {
                "steps": 0,
                "steps_target": 0,
                "distance_km": 0.0,
                "steps_burned": 0,
                "steps_burn_rate": 0.0,
            },
            "gamification": {
                "points": 0,
                "level": 1,
            },
            "chronic_conditions": cls._empty_chronic_dashboard_summary(),
            "medications": {
                "active_medications": 0,
                "today_total_doses": 0,
                "taken_today": 0,
                "pending_today": 0,
                "missed_today": 0,
                "overdue_today": 0,
                "adherence_7d": 0.0,
                "next_due": None,
            },
        }

    @staticmethod
    def _empty_history_entry(state_date: date) -> dict:
        return {
            "date": str(state_date),
            "water_current": 0.0,
            "water_target": 0.0,
            "steps": 0,
            "steps_target": 0,
            "distance_km": 0.0,
            "steps_burned": 0,
            "steps_burn_rate": 0.0,
            "calories_in": 0,
            "calories_target": 0,
            "calories_burned": 0,
            "protein_g": 0.0,
            "carbs_g": 0.0,
            "fat_g": 0.0,
            "sugars_g": 0.0,
            "added_sugars_g": 0.0,
            "fiber_g": 0.0,
            "caffeine_mg": 0.0,
            "sleep_hours": 0.0,
            "sleep_target": 0.0,
            "exercise_minutes": 0,
            "tracker_points_estimate": 0,
            "medication_points": 0,
            "points_estimate": 0,
            "burn_target": 0,
            "burn_current": 0,
            "condition_adherence_percent": 0.0,
            "pending_condition_doses": 0,
            "medication_adherence_percent": 0.0,
            "medication_total_doses": 0,
            "medication_taken_today": 0,
            "medication_pending_today": 0,
            "medication_missed_today": 0,
            "medication_overdue_today": 0,
        }
