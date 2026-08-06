from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from django.utils import timezone

from gamification.models import DailyMission, MotivationExperienceEvent, UserBadge
from gamification.services.motivation_experience_service import MotivationExperienceService
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


def _progress_percent(*, current: float, target: float) -> int:
    if target <= 0:
        return 0
    return max(0, min(100, round((float(current or 0) / float(target)) * 100)))


@dataclass(frozen=True)
class _MissionPreview:
    mission_type: str
    title: str
    description: str
    status: str
    current_value: float
    target_value: float
    points_reward: int
    reason: str

    @property
    def progress_percent(self) -> int:
        if self.target_value <= 0:
            return 100 if self.status == DailyMission.STATUS_COMPLETED else 0
        return _progress_percent(current=self.current_value, target=self.target_value)


class MotivationFeedService:
    MAX_CELEBRATIONS = 6

    @classmethod
    def _envelope(cls, *, data: dict, request_id: str) -> dict:
        return {
            "data": data,
            "meta": {
                "is_stale": False,
                "computed_at": timezone.now().isoformat(),
                "snapshot_version": 1,
                "request_id": request_id,
            },
        }

    @staticmethod
    def _today() -> date:
        return timezone.localdate()

    @classmethod
    def _summary(cls, *, user, target_date: date) -> dict:
        state = MotivationService._state_for_day(user=user, target_date=target_date)
        return MotivationService._overview_from_state(
            user=user,
            target_date=target_date,
            state=state,
        )

    @classmethod
    def _missions(cls, *, user, target_date: date) -> list[_MissionPreview]:
        rows = list(
            DailyMission.objects.filter(user=user, mission_date=target_date).order_by("id")
        )
        if rows:
            return [
                _MissionPreview(
                    mission_type=row.mission_type,
                    title=row.title,
                    description=row.description,
                    status=row.status,
                    current_value=float(row.current_value or 0),
                    target_value=float(row.target_value or 0),
                    points_reward=int(row.points_reward or 0),
                    reason=row.reason,
                )
                for row in rows
            ]

        return [
            _MissionPreview(
                mission_type=str(item.get("mission_type") or ""),
                title=str(item.get("title") or ""),
                description=str(item.get("description") or ""),
                status=str(item.get("status") or DailyMission.STATUS_PENDING),
                current_value=float(item.get("current_value") or 0),
                target_value=float(item.get("target_value") or 0),
                points_reward=int(item.get("points_reward") or 0),
                reason=str(item.get("reason") or ""),
            )
            for item in MotivationService._mission_snapshot_payloads(
                user=user,
                target_date=target_date,
            )
        ]

    @classmethod
    def _focus(cls, *, summary: dict, missions: list[_MissionPreview], badges: list[UserBadge]) -> dict:
        actionable = [
            mission
            for mission in missions
            if mission.status not in {
                DailyMission.STATUS_COMPLETED,
                DailyMission.STATUS_NOT_APPLICABLE,
            }
        ]
        actionable.sort(
            key=lambda item: (
                0 if item.status == DailyMission.STATUS_IN_PROGRESS else 1,
                -item.progress_percent,
                -int(item.points_reward or 0),
            )
        )
        if actionable:
            mission = actionable[0]
            return {
                "kind": "mission",
                "title": mission.title,
                "subtitle": mission.reason or mission.description,
                "progress_percent": mission.progress_percent,
                "reward_points": int(mission.points_reward or 0),
                "route": MotivationExperienceService.route_for_mission(mission.mission_type),
            }

        near_badge = None
        for row in badges:
            if row.status == UserBadge.STATUS_EARNED:
                continue
            remaining = max(int(row.badge.required_value or 0) - int(row.progress_value or 0), 0)
            if remaining <= 1:
                near_badge = row
                break
        if near_badge is not None:
            return {
                "kind": "badge",
                "title": near_badge.badge.name,
                "subtitle": "One more push unlocks this badge.",
                "progress_percent": _progress_percent(
                    current=float(near_badge.progress_value or 0),
                    target=float(near_badge.badge.required_value or 1),
                ),
                "reward_points": int(near_badge.badge.points_bonus or 0),
                "route": MotivationExperienceService.ROUTE_SCORE,
            }

        points_to_next = _as_int(summary.get("points_to_next_level"))
        next_level_threshold = max(_as_int(summary.get("next_level_threshold")), 1)
        total_points = _as_int(summary.get("total_points"))
        current_level = max(_as_int(summary.get("level")), 1)
        previous_threshold = max((current_level - 1) * 1000, 0)
        progress_denominator = max(next_level_threshold - previous_threshold, 1)
        progress_numerator = max(total_points - previous_threshold, 0)
        return {
            "kind": "level",
            "title": f"Level {max(current_level + 1, 2)} is close",
            "subtitle": f"{points_to_next} points to the next level.",
            "progress_percent": _progress_percent(
                current=float(progress_numerator),
                target=float(progress_denominator),
            ),
            "reward_points": 0,
            "route": MotivationExperienceService.ROUTE_SCORE,
        }

    @classmethod
    def _celebrations(cls, *, user) -> list[dict]:
        rows = list(
            MotivationExperienceEvent.objects.filter(
                user=user,
                is_acknowledged=False,
            ).order_by("-created_at", "-id")[: cls.MAX_CELEBRATIONS]
        )
        return [
            {
                "id": row.id,
                "type": row.event_type,
                "title": row.title,
                "subtitle": row.subtitle,
                "points_delta": int(row.points_delta or 0),
                "animation": row.animation,
                "route": row.route,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]

    @classmethod
    def _badge_candidates(cls, *, user) -> list[UserBadge]:
        return list(
            UserBadge.objects.select_related("badge")
            .filter(user=user, badge__is_active=True)
            .exclude(status=UserBadge.STATUS_EARNED)
            .order_by("badge__id")
        )

    @classmethod
    def feed(cls, *, user, request_id: str, target_date: date | None = None) -> dict:
        target_date = target_date or cls._today()
        summary = cls._summary(user=user, target_date=target_date)
        missions = cls._missions(user=user, target_date=target_date)
        badges = cls._badge_candidates(user=user)
        focus = cls._focus(summary=summary, missions=missions, badges=badges)
        data = {
            "summary": summary,
            "focus": focus,
            "celebrations": cls._celebrations(user=user),
            "updated_at": timezone.now().isoformat(),
        }
        return cls._envelope(data=data, request_id=request_id)

    @classmethod
    def acknowledge_celebrations(cls, *, user, ids: list[int], request_id: str) -> dict:
        acknowledged_ids = MotivationExperienceService.acknowledge_events(
            user=user,
            ids=ids,
        )
        return cls._envelope(
            data={
                "acknowledged_ids": acknowledged_ids,
            },
            request_id=request_id,
        )
