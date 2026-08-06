from __future__ import annotations

from typing import Iterable

from django.utils import timezone

from gamification.models import DailyMission, MotivationExperienceEvent, PointsTransaction


class MotivationExperienceService:
    ROUTE_HOME = "/home"
    ROUTE_SCORE = "/score"
    ROUTE_WATER = "/water"
    ROUTE_MEALS = "/meals"
    ROUTE_ACTIVITY = "/activities"
    ROUTE_STEPS = "/steps"
    ROUTE_SLEEP = "/sleep"
    ROUTE_MEDICATIONS = "/medications"
    ROUTE_HABITS = "/habits"

    SOURCE_ROUTE_MAP = {
        PointsTransaction.SOURCE_HYDRATION: ROUTE_WATER,
        PointsTransaction.SOURCE_NUTRITION: ROUTE_MEALS,
        PointsTransaction.SOURCE_ACTIVITY: ROUTE_ACTIVITY,
        PointsTransaction.SOURCE_STEPS: ROUTE_STEPS,
        PointsTransaction.SOURCE_SLEEP: ROUTE_SLEEP,
        PointsTransaction.SOURCE_MEDICATION: ROUTE_MEDICATIONS,
        PointsTransaction.SOURCE_CHRONIC: ROUTE_MEDICATIONS,
        PointsTransaction.SOURCE_HABITS: ROUTE_HABITS,
        PointsTransaction.SOURCE_MOTIVATION: ROUTE_SCORE,
    }
    SOURCE_LABEL_MAP = {
        PointsTransaction.SOURCE_HYDRATION: "Hydration",
        PointsTransaction.SOURCE_NUTRITION: "Nutrition",
        PointsTransaction.SOURCE_ACTIVITY: "Activity",
        PointsTransaction.SOURCE_STEPS: "Steps",
        PointsTransaction.SOURCE_SLEEP: "Sleep",
        PointsTransaction.SOURCE_MEDICATION: "Medication",
        PointsTransaction.SOURCE_CHRONIC: "Care plan",
        PointsTransaction.SOURCE_HABITS: "Habit plan",
        PointsTransaction.SOURCE_MOTIVATION: "Motivation",
        PointsTransaction.SOURCE_SYSTEM: "Progress",
    }
    MISSION_ROUTE_MAP = {
        "hydration_goal": ROUTE_WATER,
        "nutrition_meals": ROUTE_MEALS,
        "activity_minutes": ROUTE_ACTIVITY,
        "medications_all": ROUTE_MEDICATIONS,
        "avoid_fast_food": ROUTE_HABITS,
        "sleep_goal": ROUTE_SLEEP,
    }
    STREAK_ROUTE_MAP = {
        "hydration": ROUTE_WATER,
        "nutrition": ROUTE_MEALS,
        "activity": ROUTE_ACTIVITY,
        "medications": ROUTE_MEDICATIONS,
        "sleep": ROUTE_SLEEP,
        "fast_food_free": ROUTE_HABITS,
        "smoking_free": ROUTE_HABITS,
        "caffeine_free": ROUTE_HABITS,
    }

    @classmethod
    def route_for_source(cls, *, source_type: str, fallback: str = ROUTE_SCORE) -> str:
        return cls.SOURCE_ROUTE_MAP.get(source_type, fallback)

    @classmethod
    def route_for_mission(cls, mission_type: str) -> str:
        return cls.MISSION_ROUTE_MAP.get(mission_type, cls.ROUTE_SCORE)

    @classmethod
    def route_for_streak(cls, streak_type: str) -> str:
        return cls.STREAK_ROUTE_MAP.get(streak_type, cls.ROUTE_SCORE)

    @classmethod
    def create_event(
        cls,
        *,
        user,
        event_type: str,
        title: str,
        subtitle: str = "",
        points_delta: int = 0,
        animation: str = "burst",
        route: str = ROUTE_SCORE,
        metadata: dict | None = None,
        dedupe_key: str,
    ) -> MotivationExperienceEvent:
        event, _ = MotivationExperienceEvent.objects.get_or_create(
            user=user,
            dedupe_key=dedupe_key,
            defaults={
                "event_type": event_type,
                "title": title[:120],
                "subtitle": subtitle[:240],
                "points_delta": int(points_delta or 0),
                "animation": animation[:32],
                "route": route[:64],
                "metadata": dict(metadata or {}),
            },
        )
        return event

    @classmethod
    def record_points_transaction(
        cls,
        *,
        user,
        transaction: PointsTransaction,
        previous_level: int,
        next_level: int,
    ) -> None:
        points = int(transaction.points or 0)
        if points > 0 and transaction.source_type in cls.SOURCE_ROUTE_MAP and transaction.source_type != PointsTransaction.SOURCE_MOTIVATION:
            source_label = cls.SOURCE_LABEL_MAP.get(transaction.source_type, "Progress")
            cls.create_event(
                user=user,
                event_type=MotivationExperienceEvent.TYPE_POINTS_AWARDED,
                title=f"+{points} points",
                subtitle=transaction.reason or f"{source_label} progress recorded.",
                points_delta=points,
                animation="burst",
                route=cls.route_for_source(source_type=transaction.source_type, fallback=cls.ROUTE_HOME),
                metadata={
                    "transaction_id": transaction.id,
                    "rule_code": transaction.rule_code,
                    "source_type": transaction.source_type,
                    "event_type": transaction.event_type,
                },
                dedupe_key=f"points-transaction:{transaction.id}",
            )

        if next_level > previous_level:
            cls.create_event(
                user=user,
                event_type=MotivationExperienceEvent.TYPE_LEVEL_UP,
                title=f"Level {next_level} unlocked",
                subtitle=f"You climbed from level {previous_level} to level {next_level}.",
                points_delta=points,
                animation="level_up",
                route=cls.ROUTE_SCORE,
                metadata={
                    "previous_level": int(previous_level or 1),
                    "next_level": int(next_level or 1),
                    "transaction_id": transaction.id,
                },
                dedupe_key=f"level-up:{user.id}:{next_level}",
            )

    @classmethod
    def record_points_transactions(cls, *, user, transactions: Iterable[PointsTransaction]) -> None:
        events = []
        for transaction in transactions:
            points = int(transaction.points or 0)
            previous_level = int(getattr(transaction, "_previous_level", 1) or 1)
            next_level = int(getattr(transaction, "_next_level", previous_level) or previous_level)
            if (
                points > 0
                and transaction.source_type in cls.SOURCE_ROUTE_MAP
                and transaction.source_type != PointsTransaction.SOURCE_MOTIVATION
            ):
                source_label = cls.SOURCE_LABEL_MAP.get(transaction.source_type, "Progress")
                events.append(
                    MotivationExperienceEvent(
                        user=user,
                        event_type=MotivationExperienceEvent.TYPE_POINTS_AWARDED,
                        title=f"+{points} points",
                        subtitle=(
                            transaction.reason
                            or f"{source_label} progress recorded."
                        )[:240],
                        points_delta=points,
                        animation="burst",
                        route=cls.route_for_source(
                            source_type=transaction.source_type,
                            fallback=cls.ROUTE_HOME,
                        ),
                        metadata={
                            "transaction_id": transaction.id,
                            "rule_code": transaction.rule_code,
                            "source_type": transaction.source_type,
                            "event_type": transaction.event_type,
                        },
                        dedupe_key=f"points-transaction:{transaction.id}",
                    )
                )
            if next_level > previous_level:
                events.append(
                    MotivationExperienceEvent(
                        user=user,
                        event_type=MotivationExperienceEvent.TYPE_LEVEL_UP,
                        title=f"Level {next_level} unlocked",
                        subtitle=f"You climbed from level {previous_level} to level {next_level}.",
                        points_delta=points,
                        animation="level_up",
                        route=cls.ROUTE_SCORE,
                        metadata={
                            "previous_level": previous_level,
                            "next_level": next_level,
                            "transaction_id": transaction.id,
                        },
                        dedupe_key=f"level-up:{user.id}:{next_level}",
                    )
                )
        if events:
            MotivationExperienceEvent.objects.bulk_create(events, ignore_conflicts=True)

    @classmethod
    def record_mission_completed(cls, *, user, mission: DailyMission) -> None:
        cls.create_event(
            user=user,
            event_type=MotivationExperienceEvent.TYPE_MISSION_COMPLETED,
            title="Mission complete",
            subtitle=mission.title,
            points_delta=int(mission.points_reward or 0),
            animation="quest",
            route=cls.route_for_mission(mission.mission_type),
            metadata={
                "mission_id": mission.id,
                "mission_type": mission.mission_type,
                "mission_date": mission.mission_date.isoformat(),
            },
            dedupe_key=f"mission-complete:{user.id}:{mission.id}",
        )

    @classmethod
    def record_badge_earned(cls, *, user, badge_code: str, badge_name: str, points_bonus: int) -> None:
        cls.create_event(
            user=user,
            event_type=MotivationExperienceEvent.TYPE_BADGE_EARNED,
            title="Badge unlocked",
            subtitle=badge_name,
            points_delta=int(points_bonus or 0),
            animation="badge",
            route=cls.ROUTE_SCORE,
            metadata={
                "badge_code": badge_code,
                "badge_name": badge_name,
            },
            dedupe_key=f"badge-earned:{user.id}:{badge_code}",
        )

    @classmethod
    def record_streak_milestone(
        cls,
        *,
        user,
        streak_type: str,
        streak_count: int,
        points_bonus: int,
    ) -> None:
        label = streak_type.replace("_", " ").title()
        cls.create_event(
            user=user,
            event_type=MotivationExperienceEvent.TYPE_STREAK_MILESTONE,
            title=f"{streak_count}-day streak",
            subtitle=f"{label} is building real momentum.",
            points_delta=int(points_bonus or 0),
            animation="streak",
            route=cls.route_for_streak(streak_type),
            metadata={
                "streak_type": streak_type,
                "streak_count": int(streak_count or 0),
            },
            dedupe_key=f"streak-milestone:{user.id}:{streak_type}:{streak_count}",
        )

    @staticmethod
    def acknowledge_events(*, user, ids: Iterable[int]) -> list[int]:
        normalized_ids = sorted({int(item) for item in ids if str(item).strip()})
        if not normalized_ids:
            return []
        MotivationExperienceEvent.objects.filter(
            user=user,
            id__in=normalized_ids,
            is_acknowledged=False,
        ).update(
            is_acknowledged=True,
            acknowledged_at=timezone.now(),
        )
        return normalized_ids
