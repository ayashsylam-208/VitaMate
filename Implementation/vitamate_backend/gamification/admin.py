from django.contrib import admin

from .models import (
    Badge,
    DailyMission,
    MotivationExperienceEvent,
    PointsTransaction,
    UserBadge,
    UserScore,
    UserStreak,
)


@admin.register(UserScore)
class UserScoreAdmin(admin.ModelAdmin):
    list_display = ("user", "total_points", "level", "current_streak", "longest_streak")
    ordering = ("-total_points",)


@admin.register(PointsTransaction)
class PointsTransactionAdmin(admin.ModelAdmin):
    list_display = ("user", "event_date", "source_type", "rule_code", "points", "created_at")
    list_filter = ("source_type", "event_date")
    search_fields = ("user__username", "rule_code", "reason", "idempotency_key")
    ordering = ("-created_at",)


@admin.register(DailyMission)
class DailyMissionAdmin(admin.ModelAdmin):
    list_display = ("user", "mission_date", "mission_type", "status", "current_value", "target_value", "points_reward")
    list_filter = ("status", "mission_type", "mission_date")
    search_fields = ("user__username", "title", "mission_type")
    ordering = ("-mission_date", "mission_type")


@admin.register(UserStreak)
class UserStreakAdmin(admin.ModelAdmin):
    list_display = ("user", "streak_type", "current_count", "longest_count", "last_completed_date")
    list_filter = ("streak_type",)
    search_fields = ("user__username", "streak_type")


@admin.register(Badge)
class BadgeAdmin(admin.ModelAdmin):
    list_display = ("code", "name", "condition_type", "condition_key", "required_value", "points_bonus", "is_active")
    list_filter = ("condition_type", "is_active")
    search_fields = ("code", "name", "condition_key")


@admin.register(UserBadge)
class UserBadgeAdmin(admin.ModelAdmin):
    list_display = ("user", "badge", "status", "progress_value", "earned_at")
    list_filter = ("status",)
    search_fields = ("user__username", "badge__code", "badge__name")


@admin.register(MotivationExperienceEvent)
class MotivationExperienceEventAdmin(admin.ModelAdmin):
    list_display = (
        "user",
        "event_type",
        "title",
        "points_delta",
        "route",
        "is_acknowledged",
        "created_at",
    )
    list_filter = ("event_type", "is_acknowledged", "created_at")
    search_fields = ("user__username", "title", "subtitle", "dedupe_key")
    ordering = ("-created_at",)
