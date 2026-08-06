from __future__ import annotations

from datetime import date
from uuid import uuid4

from django.db import IntegrityError, transaction
from django.db.models import Count, Sum
from django.utils import timezone

from gamification.models import DailyStepPointsAward, PointsTransaction, UserScore
from gamification.repositories.user_score_repository import UserScoreRepository
from gamification.services.motivation_experience_service import MotivationExperienceService


class PointsService:
    NEGATIVE_ALLOWED_SOURCES = {
        PointsTransaction.SOURCE_MEDICATION,
        PointsTransaction.SOURCE_CHRONIC,
        PointsTransaction.SOURCE_NUTRITION,
    }
    STEP_MILESTONES = (
        (1000, 3),
        (3000, 5),
        (5000, 8),
        (8000, 12),
        (10000, 15),
    )
    STEP_GOAL_BONUS = 10

    RULE_DEFAULTS = {
        "WATER_LOGGED": {"points": 3, "reason": "Logged water intake"},
        "WATER_GOAL_COMPLETED": {"points": 10, "reason": "Reached daily hydration goal"},
        "MEAL_LOGGED": {"points": 5, "reason": "Logged a meal"},
        "MEALS_LOGGED_3": {"points": 8, "reason": "Logged three meals today"},
        "NUTRITION_PROTEIN_TARGET": {"points": 5, "reason": "Reached protein target"},
        "NUTRITION_FIBER_TARGET": {"points": 5, "reason": "Reached fiber target"},
        "NUTRITION_SUGAR_LIMIT": {"points": 5, "reason": "Stayed within sugar limit"},
        "NUTRITION_SODIUM_LIMIT": {"points": 5, "reason": "Stayed within sodium limit"},
        "NUTRITION_SCORE_80": {"points": 15, "reason": "Nutrition quality exceeded 80%"},
        "NUTRITION_CALORIE_ALIGNMENT": {"points": 0, "reason": "Calories aligned with goal"},
        "ACTIVITY_SESSION_STARTED": {"points": 2, "reason": "Started workout session"},
        "ACTIVITY_SESSION_HALF": {"points": 5, "reason": "Reached half workout progress"},
        "ACTIVITY_SESSION_COMPLETED": {"points": 10, "reason": "Completed workout session"},
        "ACTIVITY_DAILY_GOAL_COMPLETED": {"points": 10, "reason": "Reached daily activity goal"},
        "STEPS_MILESTONE": {"points": 3, "reason": "Reached a daily steps milestone"},
        "STEPS_GOAL_COMPLETED": {"points": 10, "reason": "Reached daily steps goal"},
        "SLEEP_GOAL_COMPLETED": {"points": 10, "reason": "Reached sleep goal"},
        "UNHEALTHY_HABIT_LOGGED": {"points": 2, "reason": "Logged habit event honestly"},
        "UNHEALTHY_HABIT_WITHIN_LIMIT": {"points": 5, "reason": "Stayed within planned habit limit"},
        "UNHEALTHY_HABIT_DAY_FREE": {"points": 10, "reason": "Completed a habit-free day"},
        "UNHEALTHY_HABIT_REPLACEMENT": {"points": 5, "reason": "Used a healthy replacement"},
        "UNHEALTHY_HABIT_IMPROVEMENT": {"points": 5, "reason": "Improved versus baseline"},
        "UNHEALTHY_HABIT_RELAPSE_REASON": {"points": 1, "reason": "Logged relapse reason"},
        "MEDICATION_DAILY_COMPLETED": {"points": 10, "reason": "Completed all medication doses today"},
        "MEDICATION_WEEKLY_STREAK": {"points": 25, "reason": "Completed a 7-day medication streak"},
        "MANUAL_DELTA": {"points": 0, "reason": "Manual points adjustment"},
    }

    @staticmethod
    def _safe_date(event_date: date | None) -> date:
        return event_date or timezone.localdate()

    @staticmethod
    def _normalize_source_id(source_id) -> str:
        if source_id is None:
            return ""
        return str(source_id)

    @staticmethod
    def _score_level(total_points: int) -> int:
        return max((max(int(total_points or 0), 0) // 1000) + 1, 1)

    @classmethod
    def _default_reason(cls, rule_code: str) -> str:
        default = cls.RULE_DEFAULTS.get(str(rule_code or "").strip())
        if not default:
            return str(rule_code or "").replace("_", " ").title()
        return str(default.get("reason") or "")

    @classmethod
    def _default_points(cls, rule_code: str, points_override: int | None) -> int:
        if points_override is not None:
            return int(points_override)
        default = cls.RULE_DEFAULTS.get(str(rule_code or "").strip())
        if default is None:
            return 0
        return int(default.get("points") or 0)

    @classmethod
    def _can_apply_negative(cls, *, source_type: str, points: int, event_type: str) -> bool:
        if points >= 0:
            return True
        if event_type in {
            PointsTransaction.EVENT_CORRECTION,
            PointsTransaction.EVENT_REVERSAL,
        }:
            return True
        return source_type in cls.NEGATIVE_ALLOWED_SOURCES

    @staticmethod
    def _idempotency_key(
        *,
        user_id: int,
        rule_code: str,
        source_type: str,
        source_id: str,
        event_date: date,
        custom: str | None,
    ) -> str:
        if custom and custom.strip():
            return custom.strip()
        return f"{user_id}:{rule_code}:{source_type}:{source_id}:{event_date.isoformat()}"

    @staticmethod
    def _locked_score_for_user(user) -> UserScore:
        while True:
            score = UserScore.objects.select_for_update().filter(user=user).first()
            if score is not None:
                return score
            try:
                UserScore.objects.create(user=user)
            except IntegrityError:
                continue

    @classmethod
    def _source_rule_points_total(
        cls,
        *,
        user,
        source_type: str,
        source_id,
        rule_code: str,
        event_date: date,
    ) -> int:
        total = (
            PointsTransaction.objects.filter(
                user=user,
                source_type=source_type,
                source_id=cls._normalize_source_id(source_id),
                rule_code=rule_code,
                event_date=event_date,
            )
            .aggregate(total=Sum("points"))
            .get("total")
            or 0
        )
        return int(total)

    @classmethod
    def _next_sync_sequence(
        cls,
        *,
        user,
        source_type: str,
        source_id,
        rule_code: str,
        event_date: date,
    ) -> int:
        return (
            PointsTransaction.objects.filter(
                user=user,
                source_type=source_type,
                source_id=cls._normalize_source_id(source_id),
                rule_code=rule_code,
                event_date=event_date,
            ).count()
            + 1
        )

    @classmethod
    @transaction.atomic
    def apply_delta(
        cls,
        user,
        *,
        points: int,
        rule_code: str = "MANUAL_DELTA",
        source_type: str = PointsTransaction.SOURCE_SYSTEM,
        source_id=None,
        reason: str = "",
        event_date: date | None = None,
        metadata: dict | None = None,
        idempotency_key: str | None = None,
        event_type: str = PointsTransaction.EVENT_AWARD,
        reversal_of=None,
    ):
        points = int(points or 0)
        event_date = cls._safe_date(event_date)
        source_id_str = cls._normalize_source_id(source_id)
        if points == 0:
            return UserScoreRepository.get_or_create_for_user(user)[0]

        if not cls._can_apply_negative(
            source_type=source_type,
            points=points,
            event_type=event_type,
        ):
            return UserScoreRepository.get_or_create_for_user(user)[0]

        key = cls._idempotency_key(
            user_id=user.id,
            rule_code=rule_code,
            source_type=source_type,
            source_id=source_id_str,
            event_date=event_date,
            custom=idempotency_key,
        )
        score = cls._locked_score_for_user(user)
        previous_level = int(score.level or 1)
        existing = PointsTransaction.objects.filter(idempotency_key=key).first()
        if existing is not None:
            score.refresh_from_db(fields=["total_points", "level", "current_streak", "longest_streak"])
            return score

        try:
            transaction_row = PointsTransaction.objects.create(
                user=user,
                source_type=source_type,
                source_id=source_id_str,
                event_type=event_type,
                rule_code=rule_code,
                points=points,
                reason=reason or cls._default_reason(rule_code),
                event_date=event_date,
                metadata=metadata or {},
                idempotency_key=key,
                reversal_of=reversal_of,
            )
        except IntegrityError:
            score.refresh_from_db(fields=["total_points", "level", "current_streak", "longest_streak"])
            return score

        score.total_points = max(int(score.total_points or 0) + points, 0)
        score.level = cls._score_level(score.total_points)
        score.save(update_fields=["total_points", "level", "updated_at"])
        MotivationExperienceService.record_points_transaction(
            user=user,
            transaction=transaction_row,
            previous_level=previous_level,
            next_level=int(score.level or 1),
        )
        return score

    @classmethod
    def award_rule(
        cls,
        user,
        *,
        rule_code: str,
        source_type: str = PointsTransaction.SOURCE_SYSTEM,
        source_id=None,
        points: int | None = None,
        reason: str = "",
        event_date: date | None = None,
        metadata: dict | None = None,
        idempotency_key: str | None = None,
        event_type: str = PointsTransaction.EVENT_AWARD,
    ):
        resolved_points = cls._default_points(rule_code, points)
        return cls.apply_delta(
            user,
            points=resolved_points,
            rule_code=rule_code,
            source_type=source_type,
            source_id=source_id,
            reason=reason or cls._default_reason(rule_code),
            event_date=event_date,
            metadata=metadata,
            idempotency_key=idempotency_key,
            event_type=event_type,
        )

    @classmethod
    def sync_source_rule_total(
        cls,
        user,
        *,
        source_type: str,
        source_id,
        rule_code: str,
        desired_points: int,
        event_date: date,
        reason: str = "",
        metadata: dict | None = None,
    ):
        event_date = cls._safe_date(event_date)
        current_total = cls._source_rule_points_total(
            user=user,
            source_type=source_type,
            source_id=source_id,
            rule_code=rule_code,
            event_date=event_date,
        )
        desired_points = int(desired_points or 0)
        delta = desired_points - current_total
        if delta == 0:
            return UserScoreRepository.get_or_create_for_user(user)[0]

        sequence = cls._next_sync_sequence(
            user=user,
            source_type=source_type,
            source_id=source_id,
            rule_code=rule_code,
            event_date=event_date,
        )
        return cls.apply_delta(
            user,
            points=delta,
            rule_code=rule_code,
            source_type=source_type,
            source_id=source_id,
            reason=reason or cls._default_reason(rule_code),
            event_date=event_date,
            metadata={
                **(metadata or {}),
                "desired_points": desired_points,
                "current_points_before": current_total,
                "sync_sequence": sequence,
            },
            idempotency_key=(
                f"sync:{user.id}:{source_type}:{cls._normalize_source_id(source_id)}:"
                f"{rule_code}:{event_date.isoformat()}:{sequence}"
            ),
            event_type=(
                PointsTransaction.EVENT_CORRECTION
                if current_total != 0 or delta < 0
                else PointsTransaction.EVENT_AWARD
            ),
        )

    @classmethod
    def _sync_rule_totals_batch(
        cls,
        *,
        user,
        score,
        source_type: str,
        event_date: date,
        desired_rules: list[dict],
        existing_totals: dict[tuple[str, str], dict],
    ):
        pending = []
        running_points = int(score.total_points or 0)
        running_level = int(score.level or 1)

        for rule in desired_rules:
            source_id = cls._normalize_source_id(rule["source_id"])
            rule_code = str(rule["rule_code"])
            current = existing_totals.get((source_id, rule_code), {})
            current_total = int(current.get("total") or 0)
            desired_points = int(rule.get("desired_points") or 0)
            delta = desired_points - current_total
            if delta == 0:
                continue
            if not cls._can_apply_negative(
                source_type=source_type,
                points=delta,
                event_type=PointsTransaction.EVENT_CORRECTION,
            ):
                continue

            sequence = int(current.get("count") or 0) + 1
            previous_level = running_level
            running_points = max(running_points + delta, 0)
            running_level = cls._score_level(running_points)
            transaction_row = PointsTransaction(
                user=user,
                source_type=source_type,
                source_id=source_id,
                event_type=(
                    PointsTransaction.EVENT_CORRECTION
                    if current_total != 0 or delta < 0
                    else PointsTransaction.EVENT_AWARD
                ),
                rule_code=rule_code,
                points=delta,
                reason=rule.get("reason") or cls._default_reason(rule_code),
                event_date=event_date,
                metadata={
                    **dict(rule.get("metadata") or {}),
                    "desired_points": desired_points,
                    "current_points_before": current_total,
                    "sync_sequence": sequence,
                },
                idempotency_key=(
                    f"sync:{user.id}:{source_type}:{source_id}:"
                    f"{rule_code}:{event_date.isoformat()}:{sequence}"
                ),
            )
            transaction_row._previous_level = previous_level
            transaction_row._next_level = running_level
            pending.append(transaction_row)

        if not pending:
            return score

        PointsTransaction.objects.bulk_create(pending)
        score.total_points = running_points
        score.level = running_level
        score.save(update_fields=["total_points", "level", "updated_at"])
        MotivationExperienceService.record_points_transactions(
            user=user,
            transactions=pending,
        )
        return score

    @classmethod
    def reverse_points_for_source(
        cls,
        user,
        *,
        source_type: str,
        source_id,
        reason: str,
        event_date: date | None = None,
    ):
        source_id_str = cls._normalize_source_id(source_id)
        originals = PointsTransaction.objects.filter(
            user=user,
            source_type=source_type,
            source_id=source_id_str,
            points__gt=0,
        ).order_by("created_at", "id")
        if event_date is not None:
            originals = originals.filter(event_date=cls._safe_date(event_date))

        for original in originals:
            if original.reversal_transactions.exists():
                continue
            cls.apply_delta(
                user,
                points=-int(original.points or 0),
                rule_code=f"{original.rule_code}_REVERSAL",
                source_type=source_type,
                source_id=source_id_str,
                reason=reason,
                event_date=event_date or original.event_date,
                metadata={
                    "original_transaction_id": original.id,
                    "original_rule_code": original.rule_code,
                },
                idempotency_key=f"reversal:{original.id}",
                event_type=PointsTransaction.EVENT_REVERSAL,
                reversal_of=original,
            )
        return UserScoreRepository.get_or_create_for_user(user)[0]

    @staticmethod
    def add_points(user, points, *, source_type=PointsTransaction.SOURCE_SYSTEM, source_id=None, reason=""):
        return PointsService.apply_delta(
            user,
            points=int(points or 0),
            rule_code="LEGACY_ADD_POINTS",
            source_type=source_type,
            source_id=source_id,
            reason=reason or "Legacy points addition",
            idempotency_key=f"legacy:add:{uuid4()}",
        )

    @staticmethod
    def deduct_points(user, points, *, source_type=PointsTransaction.SOURCE_SYSTEM, source_id=None, reason=""):
        return PointsService.apply_delta(
            user,
            points=-abs(int(points or 0)),
            rule_code="LEGACY_DEDUCT_POINTS",
            source_type=source_type,
            source_id=source_id,
            reason=reason or "Legacy points deduction",
            idempotency_key=f"legacy:deduct:{uuid4()}",
        )

    @staticmethod
    def award_water_points(user, *, source_id=None, event_date: date | None = None):
        return PointsService.award_rule(
            user,
            rule_code="WATER_LOGGED",
            source_type=PointsTransaction.SOURCE_HYDRATION,
            source_id=source_id,
            event_date=event_date,
        )

    @staticmethod
    def award_activity_points(user, *, source_id=None, event_date: date | None = None):
        return PointsService.award_rule(
            user,
            rule_code="ACTIVITY_SESSION_COMPLETED",
            source_type=PointsTransaction.SOURCE_ACTIVITY,
            source_id=source_id,
            event_date=event_date,
        )

    @classmethod
    def _step_reward(cls, steps_count: int) -> tuple[int, int]:
        step_total = max(int(steps_count or 0), 0)
        threshold = 0
        points = 0
        for candidate_threshold, candidate_points in cls.STEP_MILESTONES:
            if step_total < candidate_threshold:
                break
            threshold = candidate_threshold
            points = candidate_points
        return threshold, points

    @classmethod
    def award_steps_points(cls, user, steps_count, *, source_id=None, event_date: date | None = None):
        step_total = max(int(steps_count or 0), 0)
        event_date = cls._safe_date(event_date)
        threshold, desired_points = cls._step_reward(step_total)
        source_key = f"daily:{event_date.isoformat()}"

        try:
            from core.services.constraints import EffectiveConstraintReader
            from users.repositories.user_profile_repository import UserProfileRepository

            profile = UserProfileRepository.get_for_user(user)
            profile_goal = int(getattr(profile, "daily_step_goal", 0) or 0)
            goal = int(
                EffectiveConstraintReader.get_effective_constraint(
                    user=user,
                    tracker_type="steps",
                    constraint_key="steps_count",
                    default_value=profile_goal,
                    default_unit="steps",
                    default_source="profile_fallback",
                ).value
                or 0
            )
        except Exception:
            goal = 0

        with transaction.atomic():
            award, _ = DailyStepPointsAward.objects.select_for_update().get_or_create(
                user=user,
                award_date=event_date,
            )
            previous_points = int(award.points_awarded or 0)
            previous_goal_bonus = cls.STEP_GOAL_BONUS if award.goal_bonus_awarded else 0
            desired_goal_bonus = cls.STEP_GOAL_BONUS if goal > 0 and step_total >= goal else 0

            if previous_points != desired_points:
                sequence = cls._next_sync_sequence(
                    user=user,
                    source_type=PointsTransaction.SOURCE_STEPS,
                    source_id=f"{source_key}:milestone",
                    rule_code="STEPS_MILESTONE",
                    event_date=event_date,
                )
                cls.apply_delta(
                    user,
                    points=desired_points - previous_points,
                    rule_code="STEPS_MILESTONE",
                    source_type=PointsTransaction.SOURCE_STEPS,
                    source_id=f"{source_key}:milestone",
                    reason=(
                        f"Adjusted daily steps milestone to {threshold} steps"
                        if threshold > 0
                        else "Removed daily steps milestone points"
                    ),
                    event_date=event_date,
                    metadata={
                        "threshold": threshold,
                        "step_total": step_total,
                        "source_log_id": source_id,
                    },
                    idempotency_key=(
                        f"steps:{user.id}:{event_date.isoformat()}:milestone:{sequence}"
                    ),
                    event_type=(
                        PointsTransaction.EVENT_CORRECTION
                        if desired_points < previous_points
                        else PointsTransaction.EVENT_AWARD
                    ),
                )
                award.highest_threshold_awarded = threshold
                award.points_awarded = desired_points

            if previous_goal_bonus != desired_goal_bonus:
                sequence = cls._next_sync_sequence(
                    user=user,
                    source_type=PointsTransaction.SOURCE_STEPS,
                    source_id=f"{source_key}:goal",
                    rule_code="STEPS_GOAL_COMPLETED",
                    event_date=event_date,
                )
                cls.apply_delta(
                    user,
                    points=desired_goal_bonus - previous_goal_bonus,
                    rule_code="STEPS_GOAL_COMPLETED",
                    source_type=PointsTransaction.SOURCE_STEPS,
                    source_id=f"{source_key}:goal",
                    reason=(
                        "Adjusted daily step-goal bonus"
                        if goal > 0
                        else "Removed daily step-goal bonus"
                    ),
                    event_date=event_date,
                    metadata={
                        "goal": goal,
                        "step_total": step_total,
                        "source_log_id": source_id,
                    },
                    idempotency_key=(
                        f"steps:{user.id}:{event_date.isoformat()}:goal:{sequence}"
                    ),
                    event_type=(
                        PointsTransaction.EVENT_CORRECTION
                        if desired_goal_bonus < previous_goal_bonus
                        else PointsTransaction.EVENT_AWARD
                    ),
                )
                award.goal_bonus_awarded = desired_goal_bonus > 0

            award.save(
                update_fields=[
                    "highest_threshold_awarded",
                    "points_awarded",
                    "goal_bonus_awarded",
                    "updated_at",
                ]
            )
        return UserScoreRepository.get_or_create_for_user(user)[0]

    @classmethod
    @transaction.atomic
    def sync_nutrition_day_points(cls, user, *, event_date: date | None = None):
        event_date = cls._safe_date(event_date)

        from core.models import MealLog
        from core.services.nutrition_service import NutritionLoggingService

        real_meals = list(
            MealLog.objects.filter(user=user, date=event_date)
            .exclude(meal_type="drink")
            .select_related("food")
            .order_by("id")
        )
        totals = NutritionLoggingService.summarize_meal_logs(real_meals)
        calories_in = sum(meal.total_calories for meal in real_meals)

        try:
            from core.services.constraints import EffectiveConstraintReader
            from users.repositories.user_profile_repository import UserProfileRepository

            profile = UserProfileRepository.get_for_user(user)
            profile_calorie_target = float(getattr(profile, "daily_calorie_target", 0) or 0)
            calorie_target = float(
                EffectiveConstraintReader.get_effective_constraint(
                    user=user,
                    tracker_type="nutrition",
                    constraint_key="calories_kcal",
                    default_value=profile_calorie_target,
                    default_unit="kcal",
                    default_source="profile_fallback",
                ).value
                or 0
            )
            profile_goal = str(getattr(profile, "goal", "") or "").strip().lower()
        except Exception:
            calorie_target = 0.0
            profile_goal = ""

        score = cls._locked_score_for_user(user)
        existing_rows = list(
            PointsTransaction.objects.filter(
                user=user,
                source_type=PointsTransaction.SOURCE_NUTRITION,
                event_date=event_date,
            )
            .values("source_id", "rule_code")
            .annotate(total=Sum("points"), count=Count("id"))
        )
        existing_totals = {
            (str(row["source_id"]), str(row["rule_code"])): row
            for row in existing_rows
        }

        real_meal_ids = {str(meal.id) for meal in real_meals}
        awarded_meal_ids = {
            source_id
            for source_id, rule_code in existing_totals
            if source_id and rule_code == "MEAL_LOGGED"
        }
        desired_rules = []

        for meal_id in sorted(real_meal_ids | awarded_meal_ids):
            desired_rules.append(
                {
                    "source_id": meal_id,
                    "rule_code": "MEAL_LOGGED",
                    "desired_points": (
                        cls._default_points("MEAL_LOGGED", None)
                        if meal_id in real_meal_ids
                        else 0
                    ),
                    "reason": "Adjusted points for real meal logging.",
                    "metadata": {"real_meal_ids": sorted(real_meal_ids)},
                }
            )

        daily_rules = (
            ("daily_meals", "MEALS_LOGGED_3", 8 if len(real_meals) >= 3 else 0, "Adjusted 3-meal bonus."),
            (
                "protein_target",
                "NUTRITION_PROTEIN_TARGET",
                5 if float(totals.get("protein_g", 0) or 0) >= 100 else 0,
                "Adjusted protein target bonus.",
            ),
            (
                "fiber_target",
                "NUTRITION_FIBER_TARGET",
                5 if float(totals.get("fiber_g", 0) or 0) >= 30 else 0,
                "Adjusted fiber target bonus.",
            ),
            (
                "sugar_limit",
                "NUTRITION_SUGAR_LIMIT",
                5
                if calories_in > 0 and float(totals.get("sugars_g", 0) or 0) <= 50
                else 0,
                "Adjusted sugar-limit bonus.",
            ),
            (
                "sodium_limit",
                "NUTRITION_SODIUM_LIMIT",
                5
                if calories_in > 0 and float(totals.get("sodium_mg", 0) or 0) <= 2300
                else 0,
                "Adjusted sodium-limit bonus.",
            ),
        )
        calorie_alignment_points, calorie_alignment_status = cls._nutrition_calorie_alignment(
            goal=profile_goal,
            calories_in=float(calories_in or 0),
            calorie_target=float(calorie_target or 0),
        )
        daily_rules += (
            ("nutrition_score", "NUTRITION_SCORE_80", 0, "Retired generic nutrition score bonus."),
            (
                "calorie_alignment",
                "NUTRITION_CALORIE_ALIGNMENT",
                calorie_alignment_points,
                "Adjusted goal-aware calorie alignment.",
            ),
        )

        for source_id, rule_code, desired_points, reason in daily_rules:
            desired_rules.append(
                {
                    "source_id": source_id,
                    "rule_code": rule_code,
                    "desired_points": desired_points,
                    "reason": reason,
                    "metadata": {
                        "meal_count": len(real_meals),
                        "calories_in": calories_in,
                        "calorie_target": calorie_target,
                        "profile_goal": profile_goal,
                        "calorie_alignment_status": calorie_alignment_status,
                    },
                }
            )
        return cls._sync_rule_totals_batch(
            user=user,
            score=score,
            source_type=PointsTransaction.SOURCE_NUTRITION,
            event_date=event_date,
            desired_rules=desired_rules,
            existing_totals=existing_totals,
        )

    @staticmethod
    def _nutrition_calorie_alignment(*, goal: str, calories_in: float, calorie_target: float) -> tuple[int, str]:
        if calorie_target <= 0 or calories_in <= 0:
            return 0, "insufficient_data"

        normalized_goal = str(goal or "").strip().lower()
        ratio = calories_in / calorie_target

        if normalized_goal == "lose":
            if calories_in > calorie_target:
                return -10, "over_loss_target"
            if ratio >= 0.80:
                return 10, "within_loss_target"
            return 0, "below_loss_target"

        if normalized_goal in {"gain", "muscle"}:
            if calories_in > calorie_target:
                return 15, "surplus_for_gain"
            if ratio >= 0.90:
                return 5, "near_gain_target"
            return 0, "below_gain_target"

        if 0.90 <= ratio <= 1.10:
            return 10, "within_maintenance_range"
        if ratio > 1.15:
            return -5, "over_maintenance_range"
        return 0, "outside_maintenance_range"

    @staticmethod
    def apply_meal_points(
        user,
        calories_in,
        target,
        *,
        source_id=None,
        event_date: date | None = None,
        meals_count: int = 0,
        protein_g: float = 0,
        fiber_g: float = 0,
        sugar_g: float = 0,
        sodium_mg: float = 0,
    ):
        del calories_in, target, source_id, meals_count, protein_g, fiber_g, sugar_g, sodium_mg
        return PointsService.sync_nutrition_day_points(
            user,
            event_date=event_date,
        )

    @staticmethod
    def award_sleep_points_if_eligible(
        user,
        duration_hours,
        goal_hours,
        *,
        source_id=None,
        event_date: date | None = None,
    ):
        if goal_hours and float(duration_hours or 0) >= 0.9 * float(goal_hours or 0):
            return PointsService.award_rule(
                user,
                rule_code="SLEEP_GOAL_COMPLETED",
                source_type=PointsTransaction.SOURCE_SLEEP,
                source_id=source_id,
                event_date=event_date,
            )
        return None

    @staticmethod
    def award_unhealthy_habit_log(user, *, source_id=None, event_date: date | None = None):
        return PointsService.award_rule(
            user,
            rule_code="UNHEALTHY_HABIT_LOGGED",
            source_type=PointsTransaction.SOURCE_HABITS,
            source_id=source_id,
            event_date=event_date,
        )

    @staticmethod
    def award_unhealthy_habit_within_limit(user, *, source_id=None, event_date: date | None = None):
        return PointsService.award_rule(
            user,
            rule_code="UNHEALTHY_HABIT_WITHIN_LIMIT",
            source_type=PointsTransaction.SOURCE_HABITS,
            source_id=source_id,
            event_date=event_date,
        )

    @staticmethod
    def award_unhealthy_habit_improvement(user, *, source_id=None, event_date: date | None = None):
        return PointsService.award_rule(
            user,
            rule_code="UNHEALTHY_HABIT_IMPROVEMENT",
            source_type=PointsTransaction.SOURCE_HABITS,
            source_id=source_id,
            event_date=event_date,
        )

    @staticmethod
    def award_unhealthy_habit_replacement(user, *, source_id=None, event_date: date | None = None):
        return PointsService.award_rule(
            user,
            rule_code="UNHEALTHY_HABIT_REPLACEMENT",
            source_type=PointsTransaction.SOURCE_HABITS,
            source_id=source_id,
            event_date=event_date,
        )
