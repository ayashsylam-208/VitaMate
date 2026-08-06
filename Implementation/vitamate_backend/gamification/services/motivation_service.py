from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from core.models import (
    ActivityLog,
    MealLog,
    SleepLog,
    UnifiedHealthState,
    UnhealthyHabit,
    UnhealthyHabitLog,
)
from core.repositories.hydration.water_log_repository import HydrationRepository
from core.services.constraints import EffectiveConstraintReader
from core.services.medication_adherence_service import MedicationAdherenceService
from gamification.models import (
    Badge,
    DailyMission,
    DailyMotivationState,
    PointsTransaction,
    UserBadge,
    UserScore,
    UserStreak,
)
from gamification.services.motivation_experience_service import MotivationExperienceService
from gamification.services.points_service import PointsService
from notification_hub.services import NotificationHubRefreshService


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


@dataclass(frozen=True)
class MissionSpec:
    mission_type: str
    title: str
    description: str
    points_reward: int
    reason: str


class MotivationService:
    LEVEL_NAMES = {
        1: "Beginner",
        2: "Builder",
        3: "Consistent",
        4: "Achiever",
        5: "Health Hero",
        6: "Wellness Master",
    }
    STREAK_MILESTONES = {3: 10, 7: 25, 14: 50, 30: 100}
    BADGE_BONUS = 20
    DEFAULT_MISSIONS = (
        MissionSpec(
            mission_type="hydration_goal",
            title="Drink hydration goal",
            description="Reach your adjusted hydration target today.",
            points_reward=10,
            reason="Recommended because hydration consistency improves daily energy.",
        ),
        MissionSpec(
            mission_type="nutrition_meals",
            title="Log 3 meals",
            description="Track breakfast, lunch, and dinner today.",
            points_reward=8,
            reason="Recommended because meal logging quality drives better nutrition guidance.",
        ),
        MissionSpec(
            mission_type="activity_minutes",
            title="Complete 20 active minutes",
            description="Reach at least 20 minutes of activity today.",
            points_reward=10,
            reason="Recommended because your activity trend benefits from short daily sessions.",
        ),
        MissionSpec(
            mission_type="medications_all",
            title="Take all medications",
            description="Complete all scheduled doses for today.",
            points_reward=10,
            reason="Recommended because adherence has the strongest health impact.",
        ),
        MissionSpec(
            mission_type="avoid_fast_food",
            title="Avoid fast food today",
            description="Stay fast-food free for this day.",
            points_reward=12,
            reason="Recommended to support long-term habit change.",
        ),
        MissionSpec(
            mission_type="sleep_goal",
            title="Meet sleep goal",
            description="Reach 90% of your sleep target.",
            points_reward=8,
            reason="Recommended because sleep consistency improves recovery and focus.",
        ),
    )

    BADGE_DEFINITIONS = (
        {
            "code": "hydration_hero",
            "name": "Hydration Hero",
            "description": "Reach hydration goal for 7 days.",
            "icon": "water_drop",
            "condition_type": Badge.CONDITION_STREAK,
            "condition_key": "hydration",
            "required_value": 7,
        },
        {
            "code": "sleep_master",
            "name": "Sleep Master",
            "description": "Reach sleep goal for 7 days.",
            "icon": "bedtime",
            "condition_type": Badge.CONDITION_STREAK,
            "condition_key": "sleep",
            "required_value": 7,
        },
        {
            "code": "active_starter",
            "name": "Active Starter",
            "description": "Complete 5 activity logs.",
            "icon": "directions_run",
            "condition_type": Badge.CONDITION_COUNTER,
            "condition_key": "activity_logs",
            "required_value": 5,
        },
        {
            "code": "smoke_fighter",
            "name": "Smoke Fighter",
            "description": "Stay smoke-free for 7 days.",
            "icon": "smoke_free",
            "condition_type": Badge.CONDITION_STREAK,
            "condition_key": "smoking_free",
            "required_value": 7,
        },
        {
            "code": "caffeine_control",
            "name": "Caffeine Control",
            "description": "Stay within caffeine plan for 5 days.",
            "icon": "coffee",
            "condition_type": Badge.CONDITION_STREAK,
            "condition_key": "caffeine_free",
            "required_value": 5,
        },
        {
            "code": "fast_food_free",
            "name": "Fast Food Free",
            "description": "Stay fast-food free for 7 days.",
            "icon": "fastfood",
            "condition_type": Badge.CONDITION_STREAK,
            "condition_key": "fast_food_free",
            "required_value": 7,
        },
        {
            "code": "meds_champion",
            "name": "Meds Champion",
            "description": "Complete medication mission for 7 days.",
            "icon": "medication",
            "condition_type": Badge.CONDITION_STREAK,
            "condition_key": "medications",
            "required_value": 7,
        },
        {
            "code": "balanced_nutrition",
            "name": "Balanced Nutrition",
            "description": "Complete nutrition mission for 5 days.",
            "icon": "nutrition",
            "condition_type": Badge.CONDITION_STREAK,
            "condition_key": "nutrition",
            "required_value": 5,
        },
    )

    @staticmethod
    def _level_name(level: int) -> str:
        if level >= 6:
            return MotivationService.LEVEL_NAMES[6]
        return MotivationService.LEVEL_NAMES.get(level, MotivationService.LEVEL_NAMES[1])

    @staticmethod
    def _today() -> date:
        return timezone.localdate()

    @staticmethod
    def _envelope(*, data: dict, request_id: str, is_stale: bool = False) -> dict:
        return {
            "data": data,
            "meta": {
                "is_stale": is_stale,
                "computed_at": timezone.now().isoformat(),
                "snapshot_version": None,
                "request_id": request_id,
            },
        }

    @staticmethod
    def _profile_target(*, user, attr: str, tracker_type: str | None = None, metric_key: str | None = None) -> float:
        profile = getattr(user, "userprofile", None)
        value = _as_float(getattr(profile, attr, 0) if profile is not None else 0)
        if value <= 0 or tracker_type is None or metric_key is None:
            return value
        return _as_float(
            EffectiveConstraintReader.get_effective_constraint(
                user=user,
                tracker_type=tracker_type,
                constraint_key=metric_key,
                default_value=value,
                default_source="profile_fallback",
            ).value
        )

    @classmethod
    def _mission_metrics(cls, *, user, target_date: date) -> dict:
        hydration_current = HydrationRepository.total_hydration_for_user_on_date(
            user,
            target_date,
        )
        hydration_base_target = cls._profile_target(
            user=user,
            attr="daily_water_target",
            tracker_type="hydration",
            metric_key="daily_water_liters",
        )
        activity_minutes = (
            ActivityLog.objects.filter(user=user, date=target_date)
            .aggregate(total=Sum("duration_minutes"))
            .get("total")
            or 0
        )
        state_window = (
            UnifiedHealthState.WINDOW_CURRENT
            if target_date == timezone.localdate()
            else UnifiedHealthState.WINDOW_DAILY
        )
        state = UnifiedHealthState.objects.filter(
            user=user,
            state_date=target_date,
            window_kind=state_window,
        ).first()
        hydration_state = dict(
            (state.progress_summary.get("hydration") if state else {}) or {}
        )
        hydration_target = _as_float(
            hydration_state.get("adjusted_target")
            or hydration_state.get("target")
            or hydration_state.get("constraint_target")
            or hydration_base_target
        )
        meals_count = MealLog.objects.filter(user=user, date=target_date).exclude(meal_type="drink").count()
        medication_counts = MedicationAdherenceService.counts_for_day(
            user=user,
            target_date=target_date,
        )
        sleep_logs = list(SleepLog.objects.filter(user=user, date=target_date))
        sleep_hours = sum(_as_float(item.duration_hours) for item in sleep_logs)
        sleep_goal = cls._profile_target(
            user=user,
            attr="recommended_sleep_hours",
            tracker_type="sleep",
            metric_key="sleep_hours",
        )
        fast_food_active = UnhealthyHabit.objects.filter(
            user=user,
            status=UnhealthyHabit.STATUS_ACTIVE,
            habit_type=UnhealthyHabit.TYPE_FAST_FOOD,
            plan__isnull=False,
        ).exists()
        fast_food_completed = False
        if fast_food_active:
            from core.services.habits import HabitEvaluationService

            habit = (
                UnhealthyHabit.objects.filter(
                    user=user,
                    status=UnhealthyHabit.STATUS_ACTIVE,
                    habit_type=UnhealthyHabit.TYPE_FAST_FOOD,
                    plan__isnull=False,
                )
                .order_by("-created_at", "-id")
                .first()
            )
            if habit is not None:
                evaluation = HabitEvaluationService.evaluate_habit(
                    habit=habit,
                    target_date=target_date,
                )
                fast_food_completed = bool(evaluation.get("is_complete"))

        return {
            "hydration_current": _as_float(hydration_current),
            "hydration_target": _as_float(hydration_target),
            "meals_count": meals_count,
            "activity_minutes": _as_float(activity_minutes),
            "medication_total": _as_int(medication_counts.get("today_total_doses")),
            "medication_taken": _as_int(medication_counts.get("taken_today")),
            "sleep_hours": _as_float(sleep_hours),
            "sleep_goal": _as_float(sleep_goal),
            "fast_food_active": fast_food_active,
            "fast_food_completed": fast_food_completed,
        }

    @staticmethod
    def _status_from_progress(*, current: float, target: float | None) -> str:
        if target is None or target <= 0:
            return DailyMission.STATUS_NOT_APPLICABLE
        if current >= target:
            return DailyMission.STATUS_COMPLETED
        if current > 0:
            return DailyMission.STATUS_IN_PROGRESS
        return DailyMission.STATUS_PENDING

    @classmethod
    def _mission_values(cls, *, mission_type: str, metrics: dict) -> tuple[float, float | None, int, str]:
        if mission_type == "hydration_goal":
            target = metrics["hydration_target"]
            return (
                metrics["hydration_current"],
                target if target > 0 else None,
                10 if target > 0 else 0,
                "Hydration target comes from your profile and active constraints.",
            )
        if mission_type == "nutrition_meals":
            return (
                float(metrics["meals_count"]),
                3.0,
                8,
                "Only real meals count. Drinks are excluded from this mission.",
            )
        if mission_type == "activity_minutes":
            return (
                metrics["activity_minutes"],
                20.0,
                10,
                "Short activity sessions compound over the week.",
            )
        if mission_type == "medications_all":
            if metrics["medication_total"] <= 0:
                return (0.0, None, 0, "No scheduled medication doses today.")
            return (
                float(metrics["medication_taken"]),
                float(metrics["medication_total"]),
                10,
                "Completing all doses protects adherence streaks.",
            )
        if mission_type == "avoid_fast_food":
            if not metrics["fast_food_active"]:
                return (0.0, None, 0, "Enable a fast-food reduction plan to activate this mission.")
            current = 1.0 if metrics.get("fast_food_completed") else 0.0
            return (current, 1.0, 12, "Avoiding fast food supports habit recovery.")
        if mission_type == "sleep_goal":
            if metrics["sleep_goal"] <= 0:
                return (0.0, None, 0, "Sleep mission needs a sleep target.")
            target = round(metrics["sleep_goal"] * 0.9, 2)
            return (
                metrics["sleep_hours"],
                target,
                8,
                "Consistency in sleep duration improves recovery.",
            )
        return (0.0, None, 0, "")

    @classmethod
    def _default_mission_specs(cls) -> list[MissionSpec]:
        return list(cls.DEFAULT_MISSIONS)

    @classmethod
    def _mission_rule_code(cls, mission_type: str) -> str:
        return f"MISSION_{mission_type.upper()}_COMPLETED"

    @classmethod
    def _mission_snapshot_payloads(cls, *, user, target_date: date) -> list[dict]:
        metrics = cls._mission_metrics(user=user, target_date=target_date)
        payloads = []
        for spec in cls._default_mission_specs():
            current, target, reward, dynamic_reason = cls._mission_values(
                mission_type=spec.mission_type,
                metrics=metrics,
            )
            status = cls._status_from_progress(current=current, target=target)
            payloads.append(
                {
                    "mission_type": spec.mission_type,
                    "title": spec.title,
                    "description": spec.description,
                    "points_reward": reward,
                    "reason": dynamic_reason or spec.reason,
                    "target_value": target if target is not None else 0,
                    "current_value": current,
                    "status": status,
                }
            )
        return payloads

    @classmethod
    def _upsert_daily_missions(cls, *, user, target_date: date) -> list[DailyMission]:
        missions = []
        for payload in cls._mission_snapshot_payloads(user=user, target_date=target_date):
            mission, created = DailyMission.objects.get_or_create(
                user=user,
                mission_date=target_date,
                mission_type=payload["mission_type"],
                defaults=payload,
            )
            previous_status = mission.status
            dirty = False
            for field in (
                "title",
                "description",
                "points_reward",
                "reason",
                "target_value",
                "current_value",
                "status",
            ):
                next_value = payload[field]
                current_value = getattr(mission, field)
                if field in {"target_value", "current_value"}:
                    if abs(float(current_value or 0) - float(next_value or 0)) <= 0.001:
                        continue
                elif current_value == next_value:
                    continue
                setattr(mission, field, next_value)
                dirty = True
            if dirty:
                mission.save(
                    update_fields=[
                        "title",
                        "description",
                        "points_reward",
                        "reason",
                        "target_value",
                        "current_value",
                        "status",
                        "updated_at",
                    ]
                )

            desired_points = mission.points_reward if mission.status == DailyMission.STATUS_COMPLETED else 0
            PointsService.sync_source_rule_total(
                user,
                source_type=PointsTransaction.SOURCE_MOTIVATION,
                source_id=mission.mission_type,
                rule_code=cls._mission_rule_code(mission.mission_type),
                desired_points=desired_points,
                event_date=target_date,
                reason=f"Adjusted mission reward for {mission.title}.",
                metadata={"mission_id": mission.id, "mission_status": mission.status},
            )
            if mission.status == DailyMission.STATUS_COMPLETED and (
                created or previous_status != DailyMission.STATUS_COMPLETED
            ):
                MotivationExperienceService.record_mission_completed(
                    user=user,
                    mission=mission,
                )
            missions.append(mission)
        return missions

    @classmethod
    def _mission_lookup(cls, missions: list[DailyMission]) -> dict[str, str]:
        return {item.mission_type: item.status for item in missions}

    @classmethod
    def _update_streak(
        cls,
        *,
        user,
        streak_type: str,
        applicable: bool,
        completed: bool,
        target_date: date,
    ) -> UserStreak | None:
        streak = UserStreak.objects.filter(user=user, streak_type=streak_type).first()
        if not applicable:
            if streak is None:
                return None
            if streak.last_completed_date and streak.last_completed_date < target_date and streak.current_count != 0:
                streak.current_count = 0
                streak.save(update_fields=["current_count", "updated_at"])
            return streak

        if streak is None:
            streak = UserStreak.objects.create(
                user=user,
                streak_type=streak_type,
                current_count=0,
                longest_count=0,
            )

        previous = streak.current_count
        if completed:
            if streak.last_completed_date == target_date:
                pass
            elif streak.last_completed_date == (target_date - timedelta(days=1)):
                streak.current_count += 1
            else:
                streak.current_count = 1
            streak.longest_count = max(streak.longest_count, streak.current_count)
            streak.last_completed_date = target_date
        elif streak.last_completed_date and streak.last_completed_date < target_date:
            streak.current_count = 0
        streak.save(update_fields=["current_count", "longest_count", "last_completed_date", "updated_at"])

        if completed and streak.current_count in cls.STREAK_MILESTONES and streak.current_count != previous:
            bonus = cls.STREAK_MILESTONES[streak.current_count]
            PointsService.award_rule(
                user,
                rule_code=f"STREAK_{streak_type.upper()}_{streak.current_count}",
                points=bonus,
                reason=f"Reached {streak.current_count}-day streak for {streak_type}",
                source_type=PointsTransaction.SOURCE_MOTIVATION,
                source_id=f"{streak_type}:{streak.current_count}",
                event_date=target_date,
                idempotency_key=f"streak:{user.id}:{streak_type}:{streak.current_count}",
                event_type=PointsTransaction.EVENT_BONUS,
            )
            MotivationExperienceService.record_streak_milestone(
                user=user,
                streak_type=streak_type,
                streak_count=streak.current_count,
                points_bonus=bonus,
            )
        return streak

    @classmethod
    def _free_day_for_habit(cls, *, user, habit_type: str, target_date: date) -> tuple[bool, bool]:
        habit = UnhealthyHabit.objects.filter(
            user=user,
            status=UnhealthyHabit.STATUS_ACTIVE,
            habit_type=habit_type,
        ).order_by("-created_at", "-id").first()
        if habit is None:
            return False, False
        from core.services.habits import HabitEvaluationService

        evaluation = HabitEvaluationService.evaluate_habit(
            habit=habit,
            target_date=target_date,
        )
        return True, bool(evaluation.get("is_complete"))

    @classmethod
    def _refresh_streaks(cls, *, user, target_date: date, missions: list[DailyMission]) -> list[UserStreak]:
        lookup = cls._mission_lookup(missions)
        smoking_applicable, smoking_completed = cls._free_day_for_habit(
            user=user,
            habit_type=UnhealthyHabit.TYPE_SMOKING,
            target_date=target_date,
        )
        caffeine_applicable, caffeine_completed = cls._free_day_for_habit(
            user=user,
            habit_type=UnhealthyHabit.TYPE_CAFFEINE,
            target_date=target_date,
        )
        streak_specs = [
            ("hydration", lookup.get("hydration_goal") != DailyMission.STATUS_NOT_APPLICABLE, lookup.get("hydration_goal") == DailyMission.STATUS_COMPLETED),
            ("nutrition", lookup.get("nutrition_meals") != DailyMission.STATUS_NOT_APPLICABLE, lookup.get("nutrition_meals") == DailyMission.STATUS_COMPLETED),
            ("activity", lookup.get("activity_minutes") != DailyMission.STATUS_NOT_APPLICABLE, lookup.get("activity_minutes") == DailyMission.STATUS_COMPLETED),
            ("medications", lookup.get("medications_all") != DailyMission.STATUS_NOT_APPLICABLE, lookup.get("medications_all") == DailyMission.STATUS_COMPLETED),
            ("sleep", lookup.get("sleep_goal") != DailyMission.STATUS_NOT_APPLICABLE, lookup.get("sleep_goal") == DailyMission.STATUS_COMPLETED),
            ("fast_food_free", lookup.get("avoid_fast_food") != DailyMission.STATUS_NOT_APPLICABLE, lookup.get("avoid_fast_food") == DailyMission.STATUS_COMPLETED),
            ("smoking_free", smoking_applicable, smoking_completed),
            ("caffeine_free", caffeine_applicable, caffeine_completed),
        ]

        streaks = []
        for streak_type, applicable, completed in streak_specs:
            streak = cls._update_streak(
                user=user,
                streak_type=streak_type,
                applicable=applicable,
                completed=completed,
                target_date=target_date,
            )
            if streak is not None:
                streaks.append(streak)

        max_current = max((item.current_count for item in streaks), default=0)
        max_longest = max((item.longest_count for item in streaks), default=0)
        score, _ = UserScore.objects.get_or_create(user=user)
        if score.current_streak != max_current or score.longest_streak != max_longest:
            score.current_streak = max_current
            score.longest_streak = max_longest
            score.save(update_fields=["current_streak", "longest_streak", "updated_at"])
        return streaks

    @classmethod
    def _ensure_badges_seeded(cls) -> None:
        for item in cls.BADGE_DEFINITIONS:
            Badge.objects.get_or_create(
                code=item["code"],
                defaults={
                    "name": item["name"],
                    "description": item["description"],
                    "icon": item["icon"],
                    "condition_type": item["condition_type"],
                    "condition_key": item["condition_key"],
                    "required_value": item["required_value"],
                    "points_bonus": cls.BADGE_BONUS,
                    "is_active": True,
                },
            )

    @classmethod
    def _badge_progress(cls, *, user, badge: Badge, streak_lookup: dict[str, UserStreak]) -> int:
        if badge.condition_type == Badge.CONDITION_STREAK:
            return _as_int((streak_lookup.get(badge.condition_key) or UserStreak(current_count=0)).current_count)
        if badge.condition_key == "activity_logs":
            return ActivityLog.objects.filter(user=user).count()
        return 0

    @classmethod
    def _refresh_badges(cls, *, user, target_date: date, streaks: list[UserStreak]) -> list[UserBadge]:
        cls._ensure_badges_seeded()
        streak_lookup = {item.streak_type: item for item in streaks}
        rows = []
        for badge in Badge.objects.filter(is_active=True).order_by("id"):
            progress = cls._badge_progress(user=user, badge=badge, streak_lookup=streak_lookup)
            user_badge, _ = UserBadge.objects.get_or_create(
                user=user,
                badge=badge,
                defaults={"progress_value": progress, "status": UserBadge.STATUS_IN_PROGRESS},
            )
            earned_now = False
            if user_badge.status == UserBadge.STATUS_EARNED:
                if user_badge.progress_value != progress:
                    user_badge.progress_value = progress
                    user_badge.save(update_fields=["progress_value", "updated_at"])
            else:
                user_badge.progress_value = progress
                if progress >= badge.required_value:
                    user_badge.status = UserBadge.STATUS_EARNED
                    user_badge.earned_at = user_badge.earned_at or timezone.now()
                    earned_now = True
                else:
                    user_badge.status = UserBadge.STATUS_IN_PROGRESS
                user_badge.save(update_fields=["progress_value", "status", "earned_at", "updated_at"])

            if earned_now and badge.points_bonus > 0:
                PointsService.award_rule(
                    user,
                    rule_code="BADGE_UNLOCKED",
                    points=badge.points_bonus,
                    reason=f"Unlocked badge: {badge.name}",
                    source_type=PointsTransaction.SOURCE_MOTIVATION,
                    source_id=badge.code,
                    event_date=target_date,
                    idempotency_key=f"badge:{user.id}:{badge.code}:earned",
                    metadata={"badge_id": badge.id},
                    event_type=PointsTransaction.EVENT_BONUS,
                )
            if earned_now:
                MotivationExperienceService.record_badge_earned(
                    user=user,
                    badge_code=badge.code,
                    badge_name=badge.name,
                    points_bonus=int(badge.points_bonus or 0),
                )
            rows.append(user_badge)
        return rows

    @classmethod
    def _points_for_day(cls, *, user, target_date: date) -> int:
        total = (
            PointsTransaction.objects.filter(user=user, event_date=target_date)
            .aggregate(total=Sum("points"))
            .get("total")
            or 0
        )
        return int(total)

    @classmethod
    def _points_between(cls, *, user, start_date: date, end_date: date) -> int:
        total = (
            PointsTransaction.objects.filter(
                user=user,
                event_date__gte=start_date,
                event_date__lte=end_date,
            )
            .aggregate(total=Sum("points"))
            .get("total")
            or 0
        )
        return int(total)

    @classmethod
    def _insight(cls, *, missions: list[DailyMission], streaks: list[UserStreak]) -> str:
        actionable = [
            item
            for item in missions
            if item.status not in {DailyMission.STATUS_COMPLETED, DailyMission.STATUS_NOT_APPLICABLE}
            and item.points_reward > 0
        ]
        if actionable:
            return f"Next best action: {actionable[0].title.lower()}."
        strongest = max(streaks, key=lambda item: item.current_count, default=None)
        if strongest and strongest.current_count > 0:
            return f"Best trend: {strongest.streak_type.replace('_', ' ')} streak is {strongest.current_count} days."
        return "Start with one mission and momentum will follow."

    @classmethod
    def _upsert_daily_state(
        cls,
        *,
        user,
        target_date: date,
        missions: list[DailyMission],
        streaks: list[UserStreak],
        badges: list[UserBadge],
    ) -> DailyMotivationState:
        mission_lookup = {item.mission_type: item for item in missions}
        completed_count = sum(1 for item in missions if item.status == DailyMission.STATUS_COMPLETED)
        not_applicable_count = sum(1 for item in missions if item.status == DailyMission.STATUS_NOT_APPLICABLE)
        applicable_total = len(missions) - not_applicable_count
        badges_earned = sum(1 for item in badges if item.status == UserBadge.STATUS_EARNED)
        badges_in_progress = sum(1 for item in badges if item.status != UserBadge.STATUS_EARNED)
        state, _ = DailyMotivationState.objects.update_or_create(
            user=user,
            state_date=target_date,
            defaults={
                "hydration_status": getattr(mission_lookup.get("hydration_goal"), "status", DailyMission.STATUS_PENDING),
                "nutrition_status": getattr(mission_lookup.get("nutrition_meals"), "status", DailyMission.STATUS_PENDING),
                "activity_status": getattr(mission_lookup.get("activity_minutes"), "status", DailyMission.STATUS_PENDING),
                "sleep_status": getattr(mission_lookup.get("sleep_goal"), "status", DailyMission.STATUS_PENDING),
                "medication_status": getattr(mission_lookup.get("medications_all"), "status", DailyMission.STATUS_NOT_APPLICABLE),
                "habits_status": getattr(mission_lookup.get("avoid_fast_food"), "status", DailyMission.STATUS_NOT_APPLICABLE),
                "completed_missions_count": completed_count,
                "not_applicable_missions_count": not_applicable_count,
                "total_daily_points": cls._points_for_day(user=user, target_date=target_date),
                "metadata": {
                    "missions_total": applicable_total,
                    "badges_earned": badges_earned,
                    "badges_in_progress": badges_in_progress,
                    "insight": cls._insight(missions=missions, streaks=streaks),
                },
            },
        )
        return state

    @classmethod
    @transaction.atomic
    def refresh_daily(cls, *, user, target_date: date | None = None) -> dict:
        target_date = target_date or cls._today()
        missions = cls._upsert_daily_missions(user=user, target_date=target_date)
        streaks = cls._refresh_streaks(user=user, target_date=target_date, missions=missions)
        badges = cls._refresh_badges(user=user, target_date=target_date, streaks=streaks)
        state = cls._upsert_daily_state(
            user=user,
            target_date=target_date,
            missions=missions,
            streaks=streaks,
            badges=badges,
        )
        NotificationHubRefreshService.refresh_user(user=user)
        return {
            "missions": missions,
            "streaks": streaks,
            "badges": badges,
            "state": state,
        }

    @classmethod
    def _state_for_day(cls, *, user, target_date: date) -> DailyMotivationState | None:
        return DailyMotivationState.objects.filter(user=user, state_date=target_date).first()

    @classmethod
    def _overview_from_state(cls, *, user, target_date: date, state: DailyMotivationState | None) -> dict:
        score, _ = UserScore.objects.get_or_create(user=user)
        daily_points = cls._points_for_day(user=user, target_date=target_date)
        weekly_points = cls._points_between(
            user=user,
            start_date=target_date - timedelta(days=6),
            end_date=target_date,
        )
        streaks = list(UserStreak.objects.filter(user=user).order_by("streak_type", "id"))
        active_streak = max((item.current_count for item in streaks), default=0)
        badges_earned = UserBadge.objects.filter(user=user, status=UserBadge.STATUS_EARNED).count()
        badges_in_progress = UserBadge.objects.filter(user=user).exclude(status=UserBadge.STATUS_EARNED).count()
        missions_total = _as_int(dict(getattr(state, "metadata", {}) or {}).get("missions_total"))
        if missions_total <= 0:
            missions_total = DailyMission.objects.filter(user=user, mission_date=target_date).exclude(
                status=DailyMission.STATUS_NOT_APPLICABLE
            ).count()
        if missions_total <= 0:
            preview = cls._mission_snapshot_payloads(user=user, target_date=target_date)
            missions_total = len([item for item in preview if item["status"] != DailyMission.STATUS_NOT_APPLICABLE])
            completed_missions = len([item for item in preview if item["status"] == DailyMission.STATUS_COMPLETED])
            insight = cls._insight(missions=[], streaks=streaks)
        else:
            completed_missions = _as_int(getattr(state, "completed_missions_count", 0))
            insight = str(dict(getattr(state, "metadata", {}) or {}).get("insight") or "")
        next_level_threshold = (int(score.level or 1) * 1000)
        return {
            "date": target_date.isoformat(),
            "total_points": int(score.total_points or 0),
            "daily_points": daily_points,
            "weekly_points": weekly_points,
            "level": int(score.level or 1),
            "level_name": cls._level_name(int(score.level or 1)),
            "next_level_threshold": next_level_threshold,
            "points_to_next_level": max(next_level_threshold - int(score.total_points or 0), 0),
            "missions_completed": completed_missions,
            "missions_total": missions_total,
            "current_streak": active_streak,
            "longest_streak": int(score.longest_streak or 0),
            "badges_earned": badges_earned,
            "badges_in_progress": badges_in_progress,
            "insight": insight or "Start with one mission and momentum will follow.",
        }

    @classmethod
    def overview(cls, *, user, request_id: str, target_date: date | None = None) -> dict:
        target_date = target_date or cls._today()
        state = cls._state_for_day(user=user, target_date=target_date)
        data = cls._overview_from_state(user=user, target_date=target_date, state=state)
        return cls._envelope(data=data, request_id=request_id)

    @classmethod
    def points(cls, *, user, request_id: str, range_days: int = 7, target_date: date | None = None) -> dict:
        target_date = target_date or cls._today()
        range_days = max(7, min(int(range_days or 7), 30))
        start_date = target_date - timedelta(days=range_days - 1)
        txs = list(
            PointsTransaction.objects.filter(
                user=user,
                event_date__gte=start_date,
                event_date__lte=target_date,
            ).order_by("-created_at")
        )
        by_date = {}
        for offset in range(range_days):
            day = start_date + timedelta(days=offset)
            by_date[day] = 0
        for tx in txs:
            by_date[tx.event_date] = by_date.get(tx.event_date, 0) + int(tx.points or 0)
        data = {
            "range_days": range_days,
            "days": [{"date": item.isoformat(), "points": by_date.get(item, 0)} for item in sorted(by_date.keys())],
            "breakdown_today": [
                {
                    "rule_code": tx.rule_code,
                    "points": int(tx.points or 0),
                    "reason": tx.reason,
                    "source_type": tx.source_type,
                    "created_at": tx.created_at.isoformat(),
                    "event_type": tx.event_type,
                }
                for tx in txs
                if tx.event_date == target_date
            ],
            "transactions": [
                {
                    "event_date": tx.event_date.isoformat(),
                    "points": int(tx.points or 0),
                    "rule_code": tx.rule_code,
                    "source_type": tx.source_type,
                    "source_id": tx.source_id,
                    "reason": tx.reason,
                    "metadata": dict(tx.metadata or {}),
                    "event_type": tx.event_type,
                    "reversal_of": tx.reversal_of_id,
                }
                for tx in txs[:120]
            ],
            "total_in_range": sum(by_date.values()),
        }
        return cls._envelope(data=data, request_id=request_id)

    @classmethod
    def missions(cls, *, user, request_id: str, target_date: date | None = None) -> dict:
        target_date = target_date or cls._today()
        missions = list(
            DailyMission.objects.filter(user=user, mission_date=target_date).order_by("id")
        )
        data = {
            "date": target_date.isoformat(),
            "missions": [
                {
                    "id": mission.id,
                    "mission_type": mission.mission_type,
                    "title": mission.title,
                    "description": mission.description,
                    "status": mission.status,
                    "target_value": round(float(mission.target_value or 0), 2),
                    "current_value": round(float(mission.current_value or 0), 2),
                    "points_reward": int(mission.points_reward or 0),
                    "reason": mission.reason,
                }
                for mission in missions
            ],
        }
        return cls._envelope(data=data, request_id=request_id)

    @classmethod
    def refresh_mission(cls, *, user, mission_id: int, request_id: str) -> dict:
        mission = DailyMission.objects.filter(user=user, id=mission_id).first()
        if mission is None:
            raise ValueError("Mission not found.")
        cls.refresh_daily(user=user, target_date=mission.mission_date)
        mission.refresh_from_db()
        return cls._envelope(
            data={
                "mission": {
                    "id": mission.id,
                    "mission_type": mission.mission_type,
                    "title": mission.title,
                    "description": mission.description,
                    "status": mission.status,
                    "target_value": round(float(mission.target_value or 0), 2),
                    "current_value": round(float(mission.current_value or 0), 2),
                    "points_reward": int(mission.points_reward or 0),
                    "reason": mission.reason,
                }
            },
            request_id=request_id,
        )

    @classmethod
    def badges(cls, *, user, request_id: str, target_date: date | None = None) -> dict:
        del target_date
        rows = list(
            UserBadge.objects.select_related("badge")
            .filter(user=user, badge__is_active=True)
            .order_by("badge__id")
        )
        data = {
            "badges": [
                {
                    "code": row.badge.code,
                    "name": row.badge.name,
                    "description": row.badge.description,
                    "icon": row.badge.icon,
                    "required_value": int(row.badge.required_value or 0),
                    "progress_value": int(row.progress_value or 0),
                    "progress_percent": min(
                        100,
                        round((float(row.progress_value or 0) / float(row.badge.required_value or 1)) * 100),
                    ),
                    "status": row.status,
                    "earned_at": row.earned_at.isoformat() if row.earned_at else None,
                }
                for row in rows
            ]
        }
        return cls._envelope(data=data, request_id=request_id)
