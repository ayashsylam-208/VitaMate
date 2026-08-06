from __future__ import annotations

from django.utils import timezone

from core.models import ConditionMedication, HealthIndicatorRecord, UserCondition
from core.services.orchestration.read_model_service import ReadModelService
from gamification.services.motivation_feed_service import MotivationFeedService
from manager.models import AccountDeletionRequest, PrivacyExportRequest
from manager.services.goals_service import ManagerGoalsService, active_medication_count
from notification_hub.models import NotificationDevice
from notification_hub.services.preferences_service import NotificationPreferencesService
from users.services.profile_metrics_calculator import ProfileMetricsCalculator
from users.services.user_profile_service import UserProfileService


class ManagerReadModelService:
    @classmethod
    def overview(cls, *, user, request_id: str) -> dict:
        profile = UserProfileService.ensure_profile(user)
        home = ReadModelService.home_overview(user=user, request_id=request_id)
        home_data = dict(home.get("data") or {})
        motivation = MotivationFeedService.feed(user=user, request_id=request_id)
        motivation_data = dict(motivation.get("data") or {})
        goals = ManagerGoalsService.list_goals(user=user)
        notification_prefs = NotificationPreferencesService.serialize(user=user)

        daily_health = dict(home_data.get("daily_health") or {})
        xp = dict(home_data.get("xp") or {})
        streaks = dict(home_data.get("streaks") or {})
        focus = dict(motivation_data.get("focus") or {})
        summary = dict(motivation_data.get("summary") or {})

        completed = len([goal for goal in goals if goal.get("is_complete")])
        total = len(goals)

        return {
            "data": {
                "user": cls._user_payload(user=user, profile=profile),
                "profile": cls._profile_payload(profile=profile),
                "my_day": {
                    "score": int(daily_health.get("score") or daily_health.get("progress_percent") or 0),
                    "progress_percent": int(daily_health.get("progress_percent") or 0),
                    "completed_goals": completed,
                    "total_goals": total,
                    "message": daily_health.get("message") or "Keep your day balanced.",
                    "focus": focus,
                },
                "motivation": {
                    "total_points": int(summary.get("total_points") or xp.get("total_points") or home_data.get("points") or 0),
                    "daily_points": int(summary.get("daily_points") or xp.get("daily_points") or home_data.get("daily_points") or 0),
                    "level": int(summary.get("level") or xp.get("level") or home_data.get("level") or 1),
                    "level_name": summary.get("level_name") or xp.get("level_name") or home_data.get("level_name") or "Beginner",
                    "current_streak": int(summary.get("current_streak") or streaks.get("current_streak") or home_data.get("current_streak") or 0),
                    "missions_completed": int(summary.get("missions_completed") or home_data.get("missions_completed") or 0),
                    "missions_total": int(summary.get("missions_total") or home_data.get("missions_total") or 0),
                },
                "goals_preview": goals[:4],
                "notifications": cls._notification_summary(
                    user=user,
                    preferences=notification_prefs,
                ),
                "medical": cls._medical_summary(user=user),
                "privacy": cls.privacy(user=user)["data"],
                "quick_actions": [
                    {"key": "health_profile", "title": "Health Profile", "route": "/my-vitamate/health-profile", "icon": "favorite"},
                    {"key": "goals", "title": "Goals", "route": "/my-vitamate/goals", "icon": "flag"},
                    {"key": "notifications", "title": "Notifications", "route": "/my-vitamate/notifications", "icon": "notifications"},
                    {"key": "privacy", "title": "Privacy", "route": "/my-vitamate/privacy", "icon": "shield"},
                ],
                "updated_at": timezone.now().isoformat(),
            },
            "meta": {
                "is_stale": bool(home.get("meta", {}).get("is_stale", False)),
                "computed_at": timezone.now().isoformat(),
                "snapshot_version": 1,
                "request_id": request_id,
            },
        }

    @classmethod
    def security(cls, *, user) -> dict:
        devices = [
            {
                "id": row.id,
                "platform": row.platform,
                "timezone": row.timezone,
                "locale": row.locale,
                "app_version": row.app_version,
                "is_primary": row.is_primary,
                "notifications_authorized": row.notifications_authorized,
                "last_seen_at": row.last_seen_at.isoformat() if row.last_seen_at else None,
            }
            for row in NotificationDevice.objects.filter(user=user).order_by("-is_primary", "-last_seen_at")
        ]
        profile = UserProfileService.ensure_profile(user)
        return {
            "data": {
                "email": user.email,
                "pending_email": getattr(profile, "pending_email", ""),
                "email_verified": bool(getattr(profile, "email_verified", False)),
                "active_sessions": 1,
                "devices": devices,
            }
        }

    @classmethod
    def privacy(cls, *, user) -> dict:
        latest_export = PrivacyExportRequest.objects.filter(user=user).first()
        deletion = AccountDeletionRequest.objects.filter(
            user=user,
            status=AccountDeletionRequest.STATUS_REQUESTED,
        ).first()
        return {
            "data": {
                "permissions": {
                    "notifications": NotificationDevice.objects.filter(
                        user=user,
                        notifications_authorized=True,
                    ).exists(),
                    "activity_sensor": True,
                    "local_storage": True,
                },
                "latest_export": cls._export_payload(latest_export),
                "account_deletion": cls._deletion_payload(deletion),
            }
        }

    @staticmethod
    def _user_payload(*, user, profile) -> dict:
        full_name = f"{user.first_name} {user.last_name}".strip() or user.username
        return {
            "username": user.username,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "full_name": full_name,
            "email": user.email,
            "pending_email": getattr(profile, "pending_email", ""),
            "email_verified": bool(getattr(profile, "email_verified", False)),
            "avatar_url": getattr(profile, "avatar_url", ""),
            "preferred_language": getattr(profile, "preferred_language", "English"),
            "region": getattr(profile, "region", "Romania"),
        }

    @staticmethod
    def _profile_payload(*, profile) -> dict:
        metrics = ProfileMetricsCalculator.calculate(profile)
        return {
            "birth_date": profile.birth_date.isoformat() if profile.birth_date else None,
            "gender": profile.gender,
            "gender_confirmed": bool(getattr(profile, "gender_confirmed", False)),
            "height": float(profile.height or 0),
            "weight": float(profile.weight or 0),
            "activity_level": float(profile.activity_level or 1.2),
            "goal": profile.goal,
            "bmi": float(metrics.bmi or 0),
            "bmr": ManagerReadModelService._bmr(profile=profile),
            "daily_calorie_target": int(metrics.daily_calorie_target or 0),
            "daily_water_target_ml": round(float(metrics.daily_water_target or 0) * 1000),
            "daily_step_goal": int(metrics.daily_step_goal or 0),
            "recommended_sleep_hours": float(profile.recommended_sleep_hours or 8),
        }

    @staticmethod
    def _bmr(*, profile) -> int:
        today = timezone.localdate()
        age = today.year - profile.birth_date.year - (
            (today.month, today.day) < (profile.birth_date.month, profile.birth_date.day)
        )
        sex_adjustment = 5 if profile.gender == "M" else -161
        return round((10 * profile.weight) + (6.25 * profile.height) - (5 * age) + sex_adjustment)

    @staticmethod
    def _notification_summary(*, user, preferences: dict) -> dict:
        return {
            "enabled": any(
                bool(preferences.get(key))
                for key in [
                    "enable_health_alerts",
                    "enable_medication_reminders",
                    "enable_routine_reminders",
                    "enable_motivation_reminders",
                ]
            ),
            "quiet_hours_enabled": bool(preferences.get("quiet_hours_enabled")),
            "active_devices": NotificationDevice.objects.filter(user=user, is_primary=True).count(),
            "preferences": preferences,
        }

    @staticmethod
    def _medical_summary(*, user) -> dict:
        conditions = UserCondition.objects.filter(user=user, is_active=True)
        return {
            "active_conditions": conditions.count(),
            "active_medications": active_medication_count(user=user),
            "health_indicators": HealthIndicatorRecord.objects.filter(
                user_condition__user=user,
            ).count(),
            "manual_medications": ConditionMedication.objects.filter(
                user=user,
                is_active=True,
                source_type=ConditionMedication.SOURCE_MANUAL,
            ).count(),
            "condition_labels": [
                row.condition_type.display_name or row.condition_type.name
                for row in conditions.select_related("condition_type")[:3]
            ],
        }

    @staticmethod
    def _export_payload(row: PrivacyExportRequest | None) -> dict | None:
        if row is None:
            return None
        return {
            "id": row.id,
            "status": row.status,
            "requested_at": row.requested_at.isoformat() if row.requested_at else None,
            "completed_at": row.completed_at.isoformat() if row.completed_at else None,
            "expires_at": row.expires_at.isoformat() if row.expires_at else None,
        }

    @staticmethod
    def _deletion_payload(row: AccountDeletionRequest | None) -> dict | None:
        if row is None:
            return None
        return {
            "id": row.id,
            "status": row.status,
            "requested_at": row.requested_at.isoformat() if row.requested_at else None,
            "grace_period_ends_at": row.grace_period_ends_at.isoformat()
            if row.grace_period_ends_at
            else None,
        }
