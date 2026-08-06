from __future__ import annotations

from datetime import time

from django.db import transaction

from notification_hub.models import NotificationPreferenceProfile
from users.services.user_profile_service import UserProfileService


class NotificationPreferencesService:
    DEFAULT_BREAKFAST = time(9, 0)
    DEFAULT_LUNCH = time(13, 0)
    DEFAULT_DINNER = time(20, 0)
    DEFAULT_STEPS = time(11, 0)
    DEFAULT_WATER_START = time(9, 0)
    DEFAULT_WATER_END = time(21, 0)

    @classmethod
    def get_or_create(cls, *, user) -> NotificationPreferenceProfile:
        user_profile = UserProfileService.ensure_profile(user)
        profile, created = NotificationPreferenceProfile.objects.get_or_create(
            user=user,
            defaults={
                "enable_motivation_reminders": bool(
                    getattr(user_profile, "enable_motivation_reminders", True)
                ),
                "enable_sleep_reminders": bool(
                    getattr(user_profile, "enable_sleep_improvement", False)
                ),
                "enable_water_reminders": bool(
                    getattr(user_profile, "enable_water_reminders", True)
                ),
                "enable_activity_reminders": bool(
                    getattr(user_profile, "enable_activity_reminders", True)
                ),
                "enable_habit_reminders": True,
                "breakfast_reminder_time": cls.DEFAULT_BREAKFAST,
                "lunch_reminder_time": cls.DEFAULT_LUNCH,
                "dinner_reminder_time": cls.DEFAULT_DINNER,
                "steps_reminder_time": cls.DEFAULT_STEPS,
                "water_reminder_start_time": cls.DEFAULT_WATER_START,
                "water_reminder_end_time": cls.DEFAULT_WATER_END,
            },
        )
        if created:
            return profile

        dirty_fields: list[str] = []
        if profile.breakfast_reminder_time is None:
            profile.breakfast_reminder_time = cls.DEFAULT_BREAKFAST
            dirty_fields.append("breakfast_reminder_time")
        if profile.lunch_reminder_time is None:
            profile.lunch_reminder_time = cls.DEFAULT_LUNCH
            dirty_fields.append("lunch_reminder_time")
        if profile.dinner_reminder_time is None:
            profile.dinner_reminder_time = cls.DEFAULT_DINNER
            dirty_fields.append("dinner_reminder_time")
        if profile.steps_reminder_time is None:
            profile.steps_reminder_time = cls.DEFAULT_STEPS
            dirty_fields.append("steps_reminder_time")
        if profile.water_reminder_start_time is None:
            profile.water_reminder_start_time = cls.DEFAULT_WATER_START
            dirty_fields.append("water_reminder_start_time")
        if profile.water_reminder_end_time is None:
            profile.water_reminder_end_time = cls.DEFAULT_WATER_END
            dirty_fields.append("water_reminder_end_time")
        if dirty_fields:
            dirty_fields.append("updated_at")
            profile.save(update_fields=dirty_fields)
        return profile

    @classmethod
    def serialize(cls, *, user) -> dict:
        profile = cls.get_or_create(user=user)
        user_profile = UserProfileService.ensure_profile(user)
        return {
            "enable_routine_reminders": profile.enable_routine_reminders,
            "enable_motivation_reminders": profile.enable_motivation_reminders,
            "enable_health_alerts": profile.enable_health_alerts,
            "enable_medication_reminders": profile.enable_medication_reminders,
            "enable_sleep_reminders": profile.enable_sleep_reminders,
            "enable_water_reminders": profile.enable_water_reminders,
            "enable_meal_reminders": profile.enable_meal_reminders,
            "enable_activity_reminders": profile.enable_activity_reminders,
            "enable_step_reminders": profile.enable_step_reminders,
            "enable_habit_reminders": profile.enable_habit_reminders,
            "quiet_hours_enabled": profile.quiet_hours_enabled,
            "quiet_start": profile.quiet_start.isoformat() if profile.quiet_start else None,
            "quiet_end": profile.quiet_end.isoformat() if profile.quiet_end else None,
            "motivation_max_per_day": profile.motivation_max_per_day,
            "motivation_type_cooldown_hours": profile.motivation_type_cooldown_hours,
            "critical_bypass_quiet_hours": profile.critical_bypass_quiet_hours,
            "breakfast_reminder_time": (
                profile.breakfast_reminder_time.isoformat()
                if profile.breakfast_reminder_time
                else None
            ),
            "lunch_reminder_time": (
                profile.lunch_reminder_time.isoformat() if profile.lunch_reminder_time else None
            ),
            "dinner_reminder_time": (
                profile.dinner_reminder_time.isoformat()
                if profile.dinner_reminder_time
                else None
            ),
            "steps_reminder_time": (
                profile.steps_reminder_time.isoformat() if profile.steps_reminder_time else None
            ),
            "daily_water_target_ml": round(float(user_profile.daily_water_target or 0) * 1000),
            "water_reminder_interval_minutes": int(
                getattr(user_profile, "water_reminder_interval_minutes", 60) or 60
            ),
            "water_reminder_start_time": (
                profile.water_reminder_start_time.isoformat()
                if profile.water_reminder_start_time
                else None
            ),
            "water_reminder_end_time": (
                profile.water_reminder_end_time.isoformat()
                if profile.water_reminder_end_time
                else None
            ),
            "activity_reminder_interval_hours": int(
                getattr(user_profile, "activity_reminder_interval_hours", 2) or 2
            ),
            "activity_reminder_time": getattr(
                user_profile, "activity_reminder_time", time(10, 0)
            ).isoformat(),
            "activity_reminder_days": list(
                getattr(user_profile, "activity_reminder_days", []) or []
            ),
            "inactive_reminder_enabled": bool(
                getattr(user_profile, "inactive_reminder_enabled", False)
            ),
            "inactive_reminder_hours": int(
                getattr(user_profile, "inactive_reminder_hours", 3) or 3
            ),
            "target_wake_time": getattr(user_profile, "target_wake_time", time(7, 0)).isoformat(),
            "target_bed_time": (
                user_profile.target_bed_time.isoformat() if user_profile.target_bed_time else None
            ),
            "updated_at": profile.updated_at.isoformat(),
        }

    @classmethod
    @transaction.atomic
    def apply_patch(cls, *, user, payload: dict) -> dict:
        profile = cls.get_or_create(user=user)
        user_profile = UserProfileService.ensure_profile(user)

        local_fields = [
            "enable_routine_reminders",
            "enable_motivation_reminders",
            "enable_health_alerts",
            "enable_medication_reminders",
            "enable_sleep_reminders",
            "enable_water_reminders",
            "enable_meal_reminders",
            "enable_activity_reminders",
            "enable_step_reminders",
            "enable_habit_reminders",
            "quiet_hours_enabled",
            "quiet_start",
            "quiet_end",
            "motivation_max_per_day",
            "motivation_type_cooldown_hours",
            "critical_bypass_quiet_hours",
            "breakfast_reminder_time",
            "lunch_reminder_time",
            "dinner_reminder_time",
            "steps_reminder_time",
            "water_reminder_start_time",
            "water_reminder_end_time",
        ]
        for field_name in local_fields:
            if field_name in payload:
                setattr(profile, field_name, payload[field_name])
        profile.save()

        profile_updates = {}
        if "enable_motivation_reminders" in payload:
            profile_updates["enable_motivation_reminders"] = profile.enable_motivation_reminders
        if "enable_activity_reminders" in payload:
            profile_updates["enable_activity_reminders"] = profile.enable_activity_reminders
        if "enable_water_reminders" in payload:
            profile_updates["enable_water_reminders"] = profile.enable_water_reminders
        if "enable_sleep_reminders" in payload:
            profile_updates["enable_sleep_improvement"] = profile.enable_sleep_reminders
        if "daily_water_target_ml" in payload:
            water_liters = round(float(payload["daily_water_target_ml"]) / 1000, 2)
            profile_updates["daily_water_target"] = water_liters
            profile_updates["manual_daily_water_target"] = water_liters
        for field_name in [
            "activity_reminder_interval_hours",
            "activity_reminder_time",
            "activity_reminder_days",
            "inactive_reminder_enabled",
            "inactive_reminder_hours",
            "water_reminder_interval_minutes",
            "target_wake_time",
            "target_bed_time",
        ]:
            if field_name in payload:
                profile_updates[field_name] = payload[field_name]
        for field_name, value in profile_updates.items():
            setattr(user_profile, field_name, value)
        if profile_updates:
            UserProfileService.recalculate_profile(user_profile)
        return cls.serialize(user=user)
