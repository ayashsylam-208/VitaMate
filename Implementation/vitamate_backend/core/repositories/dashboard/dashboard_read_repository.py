from __future__ import annotations

from core.models import (
    ActivityLog,
    ConditionAlert,
    ConditionDailyEvaluation,
    ConditionMedication,
    Habit,
    HabitLog,
    MealLog,
    SleepLog,
    StepLog,
    UnhealthyHabit,
    UnhealthyHabitLog,
    UserCondition,
)
from core.repositories.hydration.water_log_repository import HydrationRepository
from gamification.models import UserScore
from users.models import UserProfile


class DashboardReadRepository:
    @staticmethod
    def get_profile(user):
        return UserProfile.objects.get(user=user)

    @staticmethod
    def meal_logs_on_date(*, user, log_date):
        return (
            MealLog.objects.select_related("food", "serving_option")
            .filter(user=user, date=log_date)
            .order_by("consumed_at", "id")
        )

    @staticmethod
    def activity_logs_on_date(*, user, log_date):
        return ActivityLog.objects.filter(user=user, date=log_date).select_related("exercise")

    @staticmethod
    def get_or_create_step_log(*, user, log_date):
        return StepLog.objects.get_or_create(user=user, date=log_date)

    @staticmethod
    def step_log_on_date(*, user, log_date):
        return StepLog.objects.filter(user=user, date=log_date).first()

    @staticmethod
    def sleep_logs_on_date(*, user, log_date):
        return SleepLog.objects.filter(user=user, date=log_date).order_by("start_time", "id")

    @staticmethod
    def water_total_on_date(*, user, log_date):
        return HydrationRepository.total_hydration_for_user_on_date(user, log_date)

    @staticmethod
    def active_medication_count(*, user):
        return ConditionMedication.objects.filter(user=user, is_active=True).count()

    @staticmethod
    def habit_counts(*, user, log_date):
        total_habits = Habit.objects.filter(user=user).count()
        completed_habits = HabitLog.objects.filter(
            habit__user=user,
            date=log_date,
            completed=True,
        ).count()
        from core.services.habits import HabitEvaluationService

        summary = HabitEvaluationService.evaluate_user(user=user, target_date=log_date)
        evaluations = [
            item for item in summary.get("evaluations", []) if item.get("is_applicable")
        ]
        total_habits += len(evaluations)
        completed_habits += sum(1 for item in evaluations if item.get("is_complete"))
        return total_habits, completed_habits

    @staticmethod
    def active_condition_count(*, user):
        return UserCondition.objects.filter(
            user=user,
            is_active=True,
            status__in=(
                UserCondition.STATUS_ACTIVE,
                UserCondition.STATUS_CONTROLLED,
                UserCondition.STATUS_NEEDS_ATTENTION,
            ),
        ).count()

    @staticmethod
    def open_condition_alert_count(*, user):
        return ConditionAlert.objects.filter(
            user_condition__user=user,
            status=ConditionAlert.STATUS_OPEN,
        ).count()

    @staticmethod
    def condition_evaluation_pairs(*, user, log_date):
        return list(
            ConditionDailyEvaluation.objects.filter(
                user_condition__user=user,
                evaluation_date=log_date,
            )
            .order_by("-updated_at")
            .values_list("medication_adherence_percent", "restriction_adherence_percent")
        )

    @staticmethod
    def get_user_score(*, user):
        return UserScore.objects.get(user=user)
