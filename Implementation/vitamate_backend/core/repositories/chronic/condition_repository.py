from __future__ import annotations

from core.models import ConditionDailyEvaluation, HealthTarget, UserCondition


class ConditionRepository:
    @staticmethod
    def get_by_id_for_user(*, user, condition_id: int):
        return (
            UserCondition.objects.select_related("condition_type")
            .filter(id=condition_id, user=user)
            .first()
        )

    @staticmethod
    def find_active_duplicate(*, user, condition_type, exclude_id=None):
        queryset = UserCondition.objects.filter(
            user=user,
            condition_type=condition_type,
            is_active=True,
        )
        if exclude_id is not None:
            queryset = queryset.exclude(pk=exclude_id)
        return queryset.first()

    @staticmethod
    def create_condition(**attrs):
        return UserCondition.objects.create(**attrs)

    @staticmethod
    def save_condition(user_condition, *, update_fields=None):
        if update_fields is None:
            user_condition.save()
        else:
            user_condition.save(update_fields=update_fields)
        return user_condition

    @staticmethod
    def get_or_create_daily_evaluation(*, user_condition, evaluation_date, defaults=None):
        return ConditionDailyEvaluation.objects.get_or_create(
            user_condition=user_condition,
            evaluation_date=evaluation_date,
            defaults=defaults or {},
        )

    @staticmethod
    def delete_dynamic_targets_except(*, user_condition, target_keys: set[str]):
        queryset = user_condition.targets.filter(
            source_type=HealthTarget.SOURCE_DYNAMIC_CONDITION,
        )
        if target_keys:
            queryset = queryset.exclude(target_key__in=target_keys)
        queryset.delete()

    @staticmethod
    def delete_dynamic_targets_by_keys(*, user_condition, target_keys: set[str]):
        if not target_keys:
            return
        user_condition.targets.filter(
            source_type=HealthTarget.SOURCE_DYNAMIC_CONDITION,
            target_key__in=target_keys,
        ).delete()

    @staticmethod
    def upsert_dynamic_target(*, user_condition, target_key: str, defaults: dict):
        return HealthTarget.objects.update_or_create(
            user_condition=user_condition,
            target_key=target_key,
            source_type=HealthTarget.SOURCE_DYNAMIC_CONDITION,
            defaults=defaults,
        )

    @staticmethod
    def create_dynamic_target(*, user_condition, **attrs):
        return HealthTarget.objects.create(
            user_condition=user_condition,
            source_type=HealthTarget.SOURCE_DYNAMIC_CONDITION,
            **attrs,
        )
