from __future__ import annotations

import json
from collections import defaultdict

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.db.models import Count
from django.utils import timezone

from core.models import MealLog, UnhealthyHabit, UnhealthyHabitLog, UnhealthyHabitReminder, WaterLog
from core.services.habits.habit_projection_service import TrackerToHabitProjectionService
from core.services.habits.unhealthy_habit_service import UnhealthyHabitService
from notification_hub.models import NotificationPlan


class Command(BaseCommand):
    help = "Audit and optionally reconcile bidirectional unhealthy-habit tracker projections."

    def add_arguments(self, parser):
        parser.add_argument(
            "--apply",
            action="store_true",
            help="Apply deterministic repairs. Dry-run is the default.",
        )
        parser.add_argument(
            "--username",
            default="",
            help="Limit reconciliation to a single username.",
        )

    def handle(self, *args, **options):
        username = str(options.get("username") or "").strip()
        apply_changes = bool(options.get("apply"))
        users = User.objects.all()
        if username:
            users = users.filter(username=username)
            if not users.exists():
                raise CommandError(f"User '{username}' was not found.")

        report = {
            "mode": "apply" if apply_changes else "dry_run",
            "generated_at": timezone.now().isoformat(),
            "users_scanned": users.count(),
            "duplicates": [],
            "linked_repairs": [],
            "created_projection_repairs": [],
            "ambiguous": [],
            "partial_setups": [],
            "paused_plan_repairs": [],
        }

        with transaction.atomic():
            user_ids = list(users.values_list("id", flat=True))
            self._find_duplicate_source_refs(report=report, user_ids=user_ids)
            for user in users:
                self._reconcile_user(user=user, report=report, apply_changes=apply_changes)
            self._reconcile_paused_notification_plans(
                report=report,
                user_ids=user_ids,
                apply_changes=apply_changes,
            )
            if not apply_changes:
                transaction.set_rollback(True)

        self.stdout.write(json.dumps(report, indent=2, sort_keys=True))

    @classmethod
    def _find_duplicate_source_refs(cls, *, report: dict, user_ids: list[int]) -> None:
        duplicate_specs = [
            ("meal_log", MealLog.objects.filter(user_id__in=user_ids).exclude(source_ref=""), ("user_id", "source_type", "source_ref")),
            ("water_log", WaterLog.objects.filter(user_id__in=user_ids).exclude(source_ref=""), ("user_id", "source_type", "source_ref")),
            ("habit_log", UnhealthyHabitLog.objects.filter(habit__user_id__in=user_ids).exclude(source_ref=""), ("habit_id", "source_type", "source_ref")),
        ]
        for label, query, fields in duplicate_specs:
            for row in (
                query.values(*fields)
                .annotate(count=Count("id"))
                .filter(count__gt=1)
                .order_by(*fields)
            ):
                report["duplicates"].append({"model": label, **row})

    @classmethod
    def _reconcile_user(cls, *, user: User, report: dict, apply_changes: bool) -> None:
        cls._report_partial_setups(user=user, report=report)
        cls._link_habit_origin_tracker_projections(user=user, report=report, apply_changes=apply_changes)
        cls._link_tracker_origin_habit_projections(user=user, report=report, apply_changes=apply_changes)
        cls._create_missing_tracker_to_habit_projections(user=user, report=report, apply_changes=apply_changes)
        cls._create_missing_habit_to_tracker_projections(user=user, report=report, apply_changes=apply_changes)

    @classmethod
    def _report_partial_setups(cls, *, user: User, report: dict) -> None:
        for habit in (
            UnhealthyHabit.objects.filter(user=user)
            .select_related("baseline", "plan")
            .prefetch_related("reminders")
            .order_by("id")
        ):
            missing = []
            if not hasattr(habit, "baseline"):
                missing.append("baseline")
            if not hasattr(habit, "plan"):
                missing.append("plan")
            if missing:
                report["partial_setups"].append(
                    {
                        "user": user.username,
                        "habit_id": habit.id,
                        "habit_type": habit.habit_type,
                        "status": habit.status,
                        "missing": missing,
                    }
                )

    @classmethod
    def _link_habit_origin_tracker_projections(cls, *, user: User, report: dict, apply_changes: bool) -> None:
        for meal in MealLog.objects.filter(
            user=user,
            source_type=MealLog.SOURCE_TYPE_HABIT_PROJECTION,
        ).exclude(source_ref=""):
            habit_log_id = cls._source_id(source_ref=meal.source_ref, expected_prefix="habit_log")
            if habit_log_id is None:
                cls._ambiguous(report, user, "meal_log", meal.id, "Malformed habit projection source_ref.", meal.source_ref)
                continue
            log = UnhealthyHabitLog.objects.filter(id=habit_log_id, habit__user=user).first()
            if log is None:
                cls._ambiguous(report, user, "meal_log", meal.id, "Habit source log was not found.", meal.source_ref)
                continue
            if log.linked_meal_log_id == meal.id:
                continue
            report["linked_repairs"].append(
                {
                    "direction": "habits_to_nutrition",
                    "user": user.username,
                    "habit_log_id": log.id,
                    "meal_log_id": meal.id,
                    "applied": apply_changes,
                }
            )
            if apply_changes:
                log.linked_meal_log = meal
                log.save(update_fields=["linked_meal_log"])

        for water in WaterLog.objects.filter(
            user=user,
            source_type=WaterLog.SOURCE_TYPE_HABIT_PROJECTION,
        ).exclude(source_ref=""):
            habit_log_id = cls._source_id(source_ref=water.source_ref, expected_prefix="habit_log")
            if habit_log_id is None:
                cls._ambiguous(report, user, "water_log", water.id, "Malformed habit projection source_ref.", water.source_ref)
                continue
            log = UnhealthyHabitLog.objects.filter(id=habit_log_id, habit__user=user).first()
            if log is None:
                cls._ambiguous(report, user, "water_log", water.id, "Habit source log was not found.", water.source_ref)
                continue
            if log.linked_water_log_id == water.id:
                continue
            report["linked_repairs"].append(
                {
                    "direction": "habits_to_hydration",
                    "user": user.username,
                    "habit_log_id": log.id,
                    "water_log_id": water.id,
                    "applied": apply_changes,
                }
            )
            if apply_changes:
                log.linked_water_log = water
                log.save(update_fields=["linked_water_log"])

    @classmethod
    def _link_tracker_origin_habit_projections(cls, *, user: User, report: dict, apply_changes: bool) -> None:
        for log in UnhealthyHabitLog.objects.filter(
            habit__user=user,
            source_type=UnhealthyHabitLog.SOURCE_TYPE_TRACKER_PROJECTION,
        ).exclude(source_ref=""):
            if log.source_ref.startswith("meal_log:"):
                meal_id = cls._source_id(source_ref=log.source_ref, expected_prefix="meal_log")
                meal = MealLog.objects.filter(id=meal_id, user=user).first() if meal_id else None
                if meal is None:
                    cls._ambiguous(report, user, "habit_log", log.id, "Nutrition source log was not found.", log.source_ref)
                    continue
                if log.linked_meal_log_id == meal.id:
                    continue
                report["linked_repairs"].append(
                    {
                        "direction": "nutrition_to_habits",
                        "user": user.username,
                        "meal_log_id": meal.id,
                        "habit_log_id": log.id,
                        "applied": apply_changes,
                    }
                )
                if apply_changes:
                    log.linked_meal_log = meal
                    log.save(update_fields=["linked_meal_log"])
            elif log.source_ref.startswith("water_log:"):
                water_id = cls._source_id(source_ref=log.source_ref, expected_prefix="water_log")
                water = WaterLog.objects.filter(id=water_id, user=user).first() if water_id else None
                if water is None:
                    cls._ambiguous(report, user, "habit_log", log.id, "Hydration source log was not found.", log.source_ref)
                    continue
                if log.linked_water_log_id == water.id:
                    continue
                report["linked_repairs"].append(
                    {
                        "direction": "hydration_to_habits",
                        "user": user.username,
                        "water_log_id": water.id,
                        "habit_log_id": log.id,
                        "applied": apply_changes,
                    }
                )
                if apply_changes:
                    log.linked_water_log = water
                    log.save(update_fields=["linked_water_log"])
            else:
                cls._ambiguous(report, user, "habit_log", log.id, "Malformed tracker projection source_ref.", log.source_ref)

    @classmethod
    def _create_missing_tracker_to_habit_projections(cls, *, user: User, report: dict, apply_changes: bool) -> None:
        active_types = set(
            UnhealthyHabit.objects.filter(user=user, status=UnhealthyHabit.STATUS_ACTIVE)
            .values_list("habit_type", flat=True)
        )
        for meal in MealLog.objects.filter(
            user=user,
            source_type__in=["", MealLog.SOURCE_TYPE_DIRECT],
        ).order_by("id"):
            if meal.origin_domain == MealLog.ORIGIN_HABITS or meal.source_type == MealLog.SOURCE_TYPE_HABIT_PROJECTION:
                continue
            needs_fast_food = bool(meal.is_fast_food or "fast_food" in {str(item).lower() for item in meal.quality_tags or []})
            needs_caffeine = bool(float(meal.snapshot_caffeine_mg or 0) > 0 or getattr(meal.food, "contains_caffeine", False))
            if needs_fast_food and UnhealthyHabit.TYPE_FAST_FOOD in active_types:
                cls._create_projection_from_meal(user=user, meal=meal, habit_type=UnhealthyHabit.TYPE_FAST_FOOD, report=report, apply_changes=apply_changes)
            if needs_caffeine and UnhealthyHabit.TYPE_CAFFEINE in active_types:
                cls._create_projection_from_meal(user=user, meal=meal, habit_type=UnhealthyHabit.TYPE_CAFFEINE, report=report, apply_changes=apply_changes)

        for water in WaterLog.objects.filter(
            user=user,
            source_type__in=["", WaterLog.SOURCE_TYPE_DIRECT],
        ).order_by("id"):
            if water.origin_domain == WaterLog.ORIGIN_HABITS or water.source_type == WaterLog.SOURCE_TYPE_HABIT_PROJECTION:
                continue
            needs_caffeine = bool(
                float(water.caffeine_mg or 0) > 0
                or getattr(water.food_item, "contains_caffeine", False)
                or getattr(water.drink_item, "contains_caffeine", False)
            )
            if needs_caffeine and UnhealthyHabit.TYPE_CAFFEINE in active_types:
                existing = UnhealthyHabitLog.objects.filter(
                    habit__user=user,
                    source_type=UnhealthyHabitLog.SOURCE_TYPE_TRACKER_PROJECTION,
                    source_ref=f"water_log:{water.id}",
                ).exists()
                if existing:
                    continue
                report["created_projection_repairs"].append(
                    {
                        "direction": "hydration_to_habits",
                        "user": user.username,
                        "water_log_id": water.id,
                        "habit_type": UnhealthyHabit.TYPE_CAFFEINE,
                        "applied": apply_changes,
                    }
                )
                if apply_changes:
                    TrackerToHabitProjectionService.sync_from_water(water_log=water)

    @classmethod
    def _create_projection_from_meal(cls, *, user: User, meal: MealLog, habit_type: str, report: dict, apply_changes: bool) -> None:
        existing = UnhealthyHabitLog.objects.filter(
            habit__user=user,
            habit__habit_type=habit_type,
            source_type=UnhealthyHabitLog.SOURCE_TYPE_TRACKER_PROJECTION,
            source_ref=f"meal_log:{meal.id}",
        ).exists()
        if existing:
            return
        report["created_projection_repairs"].append(
            {
                "direction": "nutrition_to_habits",
                "user": user.username,
                "meal_log_id": meal.id,
                "habit_type": habit_type,
                "applied": apply_changes,
            }
        )
        if apply_changes:
            TrackerToHabitProjectionService.sync_from_meal(meal_log=meal)

    @classmethod
    def _create_missing_habit_to_tracker_projections(cls, *, user: User, report: dict, apply_changes: bool) -> None:
        for log in (
            UnhealthyHabitLog.objects.filter(
                habit__user=user,
                habit__habit_type__in=[UnhealthyHabit.TYPE_CAFFEINE, UnhealthyHabit.TYPE_FAST_FOOD],
                source_type=UnhealthyHabitLog.SOURCE_TYPE_DIRECT,
                sync_to_tracker=True,
            )
            .select_related("habit", "linked_meal_log", "linked_water_log")
            .order_by("id")
        ):
            has_projection = log.linked_meal_log_id or log.linked_water_log_id
            if has_projection:
                continue
            if not log.food_name and not log.caffeine_mg and not log.calories_kcal:
                cls._ambiguous(report, user, "habit_log", log.id, "Missing food/beverage metadata for tracker projection.", log.source_ref)
                continue
            report["created_projection_repairs"].append(
                {
                    "direction": "habits_to_tracker",
                    "user": user.username,
                    "habit_log_id": log.id,
                    "habit_type": log.habit.habit_type,
                    "applied": apply_changes,
                }
            )
            if apply_changes:
                UnhealthyHabitService._sync_tracker_log(log=log, payload={})

    @classmethod
    def _reconcile_paused_notification_plans(cls, *, report: dict, user_ids: list[int], apply_changes: bool) -> None:
        reminder_ids_by_paused_habit = set(
            UnhealthyHabitReminder.objects.filter(
                habit__user_id__in=user_ids,
                habit__status=UnhealthyHabit.STATUS_PAUSED,
            ).values_list("id", flat=True)
        )
        if not reminder_ids_by_paused_habit:
            return

        active_plans = NotificationPlan.objects.filter(
            user_id__in=user_ids,
            source_domain="habits",
            status__in=[NotificationPlan.STATUS_PLANNED, NotificationPlan.STATUS_SCHEDULED],
        )
        for plan in active_plans:
            source_ref = str(plan.source_ref or "").strip()
            if not source_ref.isdigit() or int(source_ref) not in reminder_ids_by_paused_habit:
                continue
            report["paused_plan_repairs"].append(
                {
                    "user_id": plan.user_id,
                    "plan_id": plan.plan_id,
                    "source_ref": plan.source_ref,
                    "applied": apply_changes,
                }
            )
            if apply_changes:
                plan.status = NotificationPlan.STATUS_CANCELLED
                plan.save(update_fields=["status", "updated_at"])

    @staticmethod
    def _source_id(*, source_ref: str, expected_prefix: str) -> int | None:
        prefix = f"{expected_prefix}:"
        if not str(source_ref).startswith(prefix):
            return None
        raw_id = str(source_ref)[len(prefix) :]
        return int(raw_id) if raw_id.isdigit() else None

    @staticmethod
    def _ambiguous(report: dict, user: User, model: str, object_id: int, reason: str, source_ref: str) -> None:
        report["ambiguous"].append(
            {
                "user": user.username,
                "model": model,
                "id": object_id,
                "reason": reason,
                "source_ref": source_ref,
            }
        )
