from __future__ import annotations

from dataclasses import asdict
from datetime import date, timedelta

from core.domain.trackers import (
    ActivityTrackerAdapter,
    ChronicConditionTrackerAdapter,
    HabitTrackerAdapter,
    HydrationTrackerAdapter,
    MedicationTrackerAdapter,
    NutritionTrackerAdapter,
    SleepTrackerAdapter,
    StepsTrackerAdapter,
)
from core.models import ConditionAlert, ConditionDailyEvaluation, HealthTarget, StepLog, UserCondition
from core.repositories.dashboard.dashboard_read_repository import DashboardReadRepository
from core.services.chronic.condition_constraint_engine import ConditionConstraintEngine
from core.services.constraints import ConstraintReadService
from core.services.medication_adherence_service import MedicationAdherenceService
from core.services.nutrition_service import NutritionService
from core.services.tracking.health_constraint_engine import HealthConstraintEngine
from gamification.models import UserScore
from users.models import UserProfile


class HealthStateProjectionService:
    def __init__(
        self,
        *,
        constraint_engine: HealthConstraintEngine | None = None,
        condition_constraint_engine: ConditionConstraintEngine | None = None,
    ):
        self._constraint_engine = constraint_engine or HealthConstraintEngine()
        self._condition_constraint_engine = condition_constraint_engine or ConditionConstraintEngine()

    def build_projection(
        self,
        *,
        user,
        state_date: date,
        window_kind: str,
        affected_trackers=None,
        trigger_metadata=None,
    ) -> dict | None:
        try:
            profile = DashboardReadRepository.get_profile(user)
        except UserProfile.DoesNotExist:
            return None

        effective_constraints = self._condition_constraint_engine.build_effective_constraints(
            user=user,
            profile=profile,
            on_date=state_date,
        )
        active_constraints = ConstraintReadService.active_summary_for_user(user=user)

        calories_target = int(
            self._effective_numeric_constraint(
                user=user,
                tracker_type="nutrition",
                metric_key="calories_kcal",
                fallback=effective_constraints.calories_target,
            )
        )
        water_target_liters = float(
            self._effective_numeric_constraint(
                user=user,
                tracker_type="hydration",
                metric_key="daily_water_liters",
                fallback=effective_constraints.water_target_liters,
            )
        )
        steps_target = int(
            self._effective_numeric_constraint(
                user=user,
                tracker_type="steps",
                metric_key="steps_count",
                fallback=effective_constraints.step_target,
            )
        )
        burn_target = int(
            self._effective_numeric_constraint(
                user=user,
                tracker_type="activity",
                metric_key="calories_burned",
                fallback=effective_constraints.burn_target,
            )
        )
        sleep_goal_hours = float(
            self._effective_numeric_constraint(
                user=user,
                tracker_type="sleep",
                metric_key="sleep_hours",
                fallback=profile.recommended_sleep_hours,
            )
        )

        meals = DashboardReadRepository.meal_logs_on_date(user=user, log_date=state_date)
        nutrition_totals = NutritionService.summarize_meal_logs(meals)
        calories_in = int(round(nutrition_totals["calories_kcal"]))

        activities = DashboardReadRepository.activity_logs_on_date(user=user, log_date=state_date)
        exercise_burn = sum(activity.calories_burned for activity in activities)
        exercise_minutes = sum(activity.duration_minutes for activity in activities)

        steps_log = DashboardReadRepository.step_log_on_date(user=user, log_date=state_date)
        if steps_log is None:
            steps_log = StepLog(user=user, date=state_date, steps_count=0, distance_km=0)
        steps_burn = int((steps_log.steps_count or 0) * 0.04)
        steps_burn_rate = 0
        if steps_log.distance_km:
            steps_burn_rate = round(steps_burn / steps_log.distance_km, 1)
        total_burned = exercise_burn + steps_burn

        sleep_logs = DashboardReadRepository.sleep_logs_on_date(user=user, log_date=state_date)
        sleep_hours = sum(log.duration_hours for log in sleep_logs)
        sleep_progress = self._constraint_engine.sleep_progress_percent(
            logged_hours_today=sleep_hours,
            goal_hours=sleep_goal_hours,
        )

        water_current = DashboardReadRepository.water_total_on_date(user=user, log_date=state_date)
        adjusted_water_target = self._constraint_engine.adjusted_water_target(
            base_target_liters=water_target_liters,
            exercise_minutes=exercise_minutes,
        )

        score_points = 0
        score_level = 1
        try:
            score = DashboardReadRepository.get_user_score(user=user)
        except UserScore.DoesNotExist:
            score = None
        if score is not None:
            score_points = score.total_points
            score_level = score.level

        calories_remaining = self._constraint_engine.calories_remaining(
            target=calories_target,
            consumed=calories_in,
            burned=total_burned,
        )

        medication_summary = self._medication_summary(user=user, target_date=state_date)
        chronic_summary = {
            "count": len(effective_constraints.active_condition_labels),
            "labels": list(effective_constraints.active_condition_labels),
            "adherence_percent": effective_constraints.adherence_percent,
            "active_medications_today": effective_constraints.medication_count_today,
            "pending_doses_today": effective_constraints.pending_doses_today,
            "applied_summaries": list(effective_constraints.applied_summaries),
            "disclaimer": effective_constraints.disclaimer,
            "exercise_intensity_mode": effective_constraints.exercise_intensity_mode,
        }

        warnings = self._warnings(
            user=user,
            state_date=state_date,
            window_kind=window_kind,
            medication_summary=medication_summary,
        )
        active_targets = self._active_targets(user=user)
        tracker_snapshots = self._build_snapshots(
            user=user,
            state_date=state_date,
            nutrition_totals=nutrition_totals,
            calories_in=calories_in,
            calories_remaining=calories_remaining,
            calories_target=calories_target,
            water_target_liters=water_target_liters,
            adjusted_water_target=adjusted_water_target,
            water_current=water_current,
            sleep_goal_hours=sleep_goal_hours,
            sleep_hours=sleep_hours,
            sleep_progress=sleep_progress,
            steps_log=steps_log,
            steps_target=steps_target,
            steps_burn=steps_burn,
            steps_burn_rate=steps_burn_rate,
            burn_target=burn_target,
            total_burned=total_burned,
            exercise_minutes=exercise_minutes,
            exercise_count=activities.count(),
            medication_summary=medication_summary,
            active_constraints=active_constraints,
            warnings=warnings,
        )

        history_entry = {
            "date": str(state_date),
            "water_current": round(water_current, 3),
            "water_target": water_target_liters,
            "steps": steps_log.steps_count,
            "steps_target": steps_target,
            "distance_km": steps_log.distance_km,
            "steps_burned": steps_burn,
            "steps_burn_rate": steps_burn_rate,
            "calories_in": calories_in,
            "calories_target": calories_target,
            "calories_burned": total_burned,
            "protein_g": round(nutrition_totals["protein_g"], 2),
            "carbs_g": round(nutrition_totals["carbs_g"], 2),
            "fat_g": round(nutrition_totals["fat_g"], 2),
            "sugars_g": round(nutrition_totals["sugars_g"], 2),
            "added_sugars_g": round(nutrition_totals.get("added_sugars_g", 0), 2),
            "fiber_g": round(nutrition_totals["fiber_g"], 2),
            "caffeine_mg": round(nutrition_totals["caffeine_mg"], 2),
            "sleep_hours": round(sleep_hours, 2),
            "sleep_target": sleep_goal_hours,
            "exercise_minutes": exercise_minutes,
            "points_estimate": self._constraint_engine.estimate_day_points(
                water_sum=water_current,
                steps=steps_log.steps_count,
                has_activities=activities.exists(),
                calories_in=calories_in,
                calories_target=calories_target,
                sleep_hours=sleep_hours,
                sleep_target=sleep_goal_hours,
            ),
            "burn_target": burn_target,
            "burn_current": total_burned,
            "condition_adherence_percent": effective_constraints.adherence_percent,
            "pending_condition_doses": effective_constraints.pending_doses_today,
            "medication_adherence_percent": medication_summary["adherence_7d"],
            "medication_total_doses": medication_summary["today_total_doses"],
            "medication_taken_today": medication_summary["taken_today"],
            "medication_pending_today": medication_summary["pending_today"],
            "medication_missed_today": medication_summary["missed_today"],
            "medication_overdue_today": medication_summary["overdue_today"],
        }

        progress_summary = {
            "summary": {
                "calories_target": calories_target,
                "base_calories_target": profile.daily_calorie_target,
                "calories_consumed": calories_in,
                "calories_remaining": calories_remaining,
                "calories_burned": total_burned,
                "burn_target": burn_target,
                "base_burn_target": profile.daily_burn_goal,
                "protein_g": round(nutrition_totals["protein_g"], 2),
                "carbs_g": round(nutrition_totals["carbs_g"], 2),
                "fat_g": round(nutrition_totals["fat_g"], 2),
                "sugars_g": round(nutrition_totals["sugars_g"], 2),
                "added_sugars_g": round(nutrition_totals.get("added_sugars_g", 0), 2),
                "fiber_g": round(nutrition_totals["fiber_g"], 2),
                "caffeine_mg": round(nutrition_totals["caffeine_mg"], 2),
            },
            "hydration": {
                "target": water_target_liters,
                "base_target": profile.daily_water_target,
                "current": water_current,
                "adjusted_target": adjusted_water_target,
            },
            "sleep": {
                "target_bed_time": profile.target_bed_time,
                "target_wake_time": profile.target_wake_time,
                "recommended_sleep_hours": profile.recommended_sleep_hours,
                "logged_hours_today": round(sleep_hours, 2),
                "progress_percent": sleep_progress,
            },
            "activity": {
                "steps": steps_log.steps_count,
                "steps_target": steps_target,
                "base_steps_target": profile.daily_step_goal,
                "distance_km": steps_log.distance_km,
                "steps_burned": steps_burn,
                "steps_burn_rate": steps_burn_rate,
                "exercise_intensity_mode": effective_constraints.exercise_intensity_mode,
            },
            "gamification": {
                "points": score_points,
                "level": score_level,
            },
            "chronic_conditions": {
                "count": chronic_summary["count"],
                "labels": chronic_summary["labels"],
                "adherence_percent": chronic_summary["adherence_percent"],
                "active_medications_today": chronic_summary["active_medications_today"],
                "pending_doses_today": chronic_summary["pending_doses_today"],
                "applied_summaries": chronic_summary["applied_summaries"],
                "disclaimer": chronic_summary["disclaimer"],
            },
            "medications": medication_summary,
            "history_entry": history_entry,
        }
        if warnings:
            progress_summary["active_warnings"] = warnings
        if affected_trackers:
            progress_summary["impacted_trackers"] = list(affected_trackers)

        return {
            "state_date": state_date,
            "window_kind": window_kind,
            "affected_trackers": list(affected_trackers or [item["tracker_id"] for item in tracker_snapshots]),
            "tracker_snapshots": tracker_snapshots,
            "progress_summary": progress_summary,
            "active_targets": active_targets,
            "active_constraints": active_constraints,
            "warnings": warnings,
            "medication_summary": medication_summary,
            "trigger_metadata": dict(trigger_metadata or {}),
        }

    def _effective_numeric_constraint(
        self,
        *,
        user,
        tracker_type: str,
        metric_key: str,
        fallback,
    ):
        value = ConstraintReadService.effective_numeric_value(
            user=user,
            tracker_type=tracker_type,
            metric_key=metric_key,
            fallback=fallback,
        )
        return fallback if value is None else value

    def _warnings(self, *, user, state_date: date, window_kind: str, medication_summary: dict) -> list[dict]:
        warnings: list[dict] = []
        seen: set[str] = set()

        if window_kind == "current":
            alerts = ConditionAlert.objects.filter(
                user_condition__user=user,
                status=ConditionAlert.STATUS_OPEN,
            ).select_related("user_condition", "user_condition__condition_type")
        else:
            alerts = ConditionAlert.objects.filter(
                user_condition__user=user,
                created_at__date=state_date,
            ).select_related("user_condition", "user_condition__condition_type")

        for alert in alerts:
            key = f"alert:{alert.user_condition_id}:{alert.code}:{alert.message}"
            if key in seen:
                continue
            seen.add(key)
            warnings.append(
                {
                    "source": "condition_alert",
                    "id": alert.id,
                    "code": alert.code or "condition_alert",
                    "level": alert.level or "warning",
                    "message": alert.message,
                    "alert_type": alert.alert_type,
                    "condition_id": alert.user_condition_id,
                    "condition_label": alert.user_condition.condition_type.name,
                }
            )

        evaluations = ConditionDailyEvaluation.objects.filter(
            user_condition__user=user,
            evaluation_date=state_date,
        ).select_related("user_condition", "user_condition__condition_type")
        for evaluation in evaluations:
            for risk_flag in evaluation.risk_flags or []:
                key = f"risk:{evaluation.user_condition_id}:{risk_flag}"
                if key in seen:
                    continue
                seen.add(key)
                warnings.append(
                    {
                        "source": "condition_risk",
                        "code": str(risk_flag),
                        "level": evaluation.status,
                        "message": str(risk_flag).replace("_", " ").title(),
                        "condition_id": evaluation.user_condition_id,
                        "condition_label": evaluation.user_condition.condition_type.name,
                    }
                )

        if medication_summary.get("overdue_today", 0):
            warnings.append(
                {
                    "source": "medication_summary",
                    "code": "medication_overdue",
                    "level": "warning",
                    "message": f"{medication_summary['overdue_today']} medication doses overdue today.",
                    "count": medication_summary["overdue_today"],
                }
            )

        return warnings

    @staticmethod
    def _active_targets(*, user) -> list[dict]:
        targets = (
            HealthTarget.objects.filter(
                user_condition__user=user,
                user_condition__is_active=True,
                user_condition__status__in=(
                    UserCondition.STATUS_ACTIVE,
                    UserCondition.STATUS_CONTROLLED,
                    UserCondition.STATUS_NEEDS_ATTENTION,
                ),
            )
            .select_related("user_condition", "user_condition__condition_type")
            .order_by("user_condition__condition_type__name", "priority", "target_name")
        )
        return [
            {
                "id": target.id,
                "user_condition_id": target.user_condition_id,
                "condition_label": target.user_condition.condition_type.name,
                "target_key": target.target_key,
                "target_name": target.target_name,
                "category": target.category,
                "metric_key": target.metric_key,
                "evaluation_mode": target.evaluation_mode,
                "unit": target.unit,
                "min_value": target.min_value,
                "max_value": target.max_value,
                "status": target.status,
                "current_value": target.last_evaluated_value,
                "source_type": target.source_type,
                "priority": target.priority,
                "guidance": target.guidance,
                "is_scored": target.is_scored,
            }
            for target in targets
        ]

    def _medication_summary(self, *, user, target_date: date) -> dict:
        active_medications = DashboardReadRepository.active_medication_count(user=user)
        counts = MedicationAdherenceService.counts_for_day(
            user=user,
            target_date=target_date,
        )
        seven_day = MedicationAdherenceService.get_user_adherence(
            user=user,
            start_date=target_date - timedelta(days=6),
            end_date=target_date,
        )
        next_due = MedicationAdherenceService.next_due(user=user)
        return {
            "active_medications": active_medications,
            **counts,
            "next_due": next_due.scheduled_for.isoformat() if next_due and next_due.scheduled_for else None,
            "adherence_7d": seven_day.adherence_percent,
        }

    def _build_snapshots(
        self,
        *,
        user,
        state_date: date,
        nutrition_totals: dict,
        calories_in: int,
        calories_remaining: int,
        calories_target: int,
        water_target_liters: float,
        adjusted_water_target: float,
        water_current: float,
        sleep_goal_hours: float,
        sleep_hours: float,
        sleep_progress: int,
        steps_log: StepLog,
        steps_target: int,
        steps_burn: int,
        steps_burn_rate: float,
        burn_target: int,
        total_burned: int,
        exercise_minutes: int,
        exercise_count: int,
        medication_summary: dict,
        active_constraints: dict,
        warnings: list[dict],
    ) -> list[dict]:
        total_habits, completed_habits_today = DashboardReadRepository.habit_counts(
            user=user,
            log_date=state_date,
        )
        active_conditions = DashboardReadRepository.active_condition_count(user=user)
        adherence_percent = 0.0
        pairs = DashboardReadRepository.condition_evaluation_pairs(user=user, log_date=state_date)
        if pairs:
            adherence_percent = round(
                sum((med + restriction) / 2 for med, restriction in pairs) / len(pairs),
                2,
            )

        trackers = [
            ActivityTrackerAdapter(
                calories_burned=total_burned,
                burn_target=burn_target,
                exercise_minutes=exercise_minutes,
                sessions_count=exercise_count,
                constraints=tuple(active_constraints.get("activity", [])),
            ),
            StepsTrackerAdapter(
                steps=steps_log.steps_count,
                steps_target=steps_target,
                distance_km=steps_log.distance_km,
                calories_burned=steps_burn,
                burn_rate_kcal_per_km=steps_burn_rate,
                constraints=tuple(active_constraints.get("steps", [])),
            ),
            SleepTrackerAdapter(
                logged_hours_today=round(sleep_hours, 2),
                recommended_sleep_hours=sleep_goal_hours,
                progress_percent=sleep_progress,
                constraints=tuple(active_constraints.get("sleep", [])),
            ),
            HydrationTrackerAdapter(
                water_current_liters=float(water_current),
                water_target_liters=float(water_target_liters),
                adjusted_target_liters=float(adjusted_water_target),
                constraints=tuple(active_constraints.get("hydration", [])),
            ),
            NutritionTrackerAdapter(
                calories_consumed=calories_in,
                calories_target=calories_target,
                calories_remaining=calories_remaining,
                protein_g=nutrition_totals["protein_g"],
                carbs_g=nutrition_totals["carbs_g"],
                fat_g=nutrition_totals["fat_g"],
                sugars_g=nutrition_totals["sugars_g"],
                fiber_g=nutrition_totals["fiber_g"],
                caffeine_mg=nutrition_totals["caffeine_mg"],
                constraints=tuple(active_constraints.get("nutrition", [])),
            ),
            MedicationTrackerAdapter(
                active_medications=medication_summary["active_medications"],
                today_total_doses=medication_summary["today_total_doses"],
                taken_today=medication_summary["taken_today"],
                pending_today=medication_summary["pending_today"],
                missed_today=medication_summary["missed_today"],
                overdue_today=medication_summary["overdue_today"],
                next_due=medication_summary["next_due"],
                adherence_7d=medication_summary["adherence_7d"],
                constraints=tuple(active_constraints.get("medication", [])),
            ),
            HabitTrackerAdapter(
                total_habits=total_habits,
                completed_today=completed_habits_today,
                constraints=tuple(active_constraints.get("habit", [])),
            ),
            ChronicConditionTrackerAdapter(
                active_conditions=active_conditions,
                adherence_percent=adherence_percent,
                open_alerts=len(warnings),
                constraints=tuple(active_constraints.get("monitoring", [])),
            ),
        ]
        return [self._serialize_tracker_snapshot(tracker.snapshot()) for tracker in trackers]

    @staticmethod
    def _serialize_tracker_snapshot(snapshot) -> dict:
        payload = asdict(snapshot)
        status = payload.get("status")
        if hasattr(status, "value"):
            payload["status"] = status.value
        goal = payload.get("goal")
        if goal and hasattr(goal, "get"):
            payload["goal"] = dict(goal)
        return payload
