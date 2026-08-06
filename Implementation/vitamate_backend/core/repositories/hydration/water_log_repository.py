from datetime import datetime, time, timedelta

from django.db.models import Case, ExpressionWrapper, F, FloatField, Sum, Value, When
from django.utils import timezone

from core.models import WaterLog


class HydrationRepository:
    @staticmethod
    def hydration_amount_expression():
        return Case(
            When(
                linked_meal_log__snapshot_water_g__gt=0,
                then=ExpressionWrapper(
                    F("linked_meal_log__snapshot_water_g") / Value(1000.0),
                    output_field=FloatField(),
                ),
            ),
            default=F("amount_liter"),
            output_field=FloatField(),
        )

    @staticmethod
    def create_for_user(
        user,
        amount_liter,
        beverage_type="water",
        beverage_name="Water",
        food_item=None,
        drink_item=None,
        linked_meal_log=None,
        **extra_fields,
    ):
        return WaterLog.objects.create(
            user=user,
            food_item=food_item,
            drink_item=drink_item or food_item,
            linked_meal_log=linked_meal_log,
            beverage_type=beverage_type,
            beverage_name=beverage_name,
            amount_liter=amount_liter,
            **extra_fields,
        )

    @staticmethod
    def day_bounds(log_date):
        current_tz = timezone.get_current_timezone()
        start = timezone.make_aware(datetime.combine(log_date, time.min), current_tz)
        return start, start + timedelta(days=1)

    @staticmethod
    def list_for_user_on_date(user, log_date):
        start, end = HydrationRepository.day_bounds(log_date)
        return (
            WaterLog.objects.select_related("food_item", "drink_item", "linked_meal_log")
            .filter(user=user, consumed_at__gte=start, consumed_at__lt=end)
            .order_by("-consumed_at", "-id")
        )

    @staticmethod
    def list_for_user_between(user, *, start=None, end=None):
        qs = WaterLog.objects.select_related("food_item", "drink_item", "linked_meal_log").filter(user=user)
        if start is not None:
            qs = qs.filter(consumed_at__gte=start)
        if end is not None:
            qs = qs.filter(consumed_at__lt=end)
        return qs.order_by("-consumed_at", "-id")

    @staticmethod
    def total_amount_for_user_on_date(user, log_date):
        start, end = HydrationRepository.day_bounds(log_date)
        return HydrationRepository.total_volume_for_period(user=user, start=start, end=end)

    @staticmethod
    def total_hydration_for_user_on_date(user, log_date):
        start, end = HydrationRepository.day_bounds(log_date)
        return HydrationRepository.get_hydration_contribution_for_period(
            user=user,
            start=start,
            end=end,
        )

    @staticmethod
    def _period_queryset(*, user, start, end):
        qs = WaterLog.objects.filter(user=user)
        if start is not None:
            qs = qs.filter(consumed_at__gte=start)
        if end is not None:
            qs = qs.filter(consumed_at__lt=end)
        return qs

    @staticmethod
    def total_volume_for_period(*, user, start, end):
        return (
            HydrationRepository._period_queryset(user=user, start=start, end=end)
            .aggregate(total=Sum("amount_liter"))
            .get("total")
            or 0
        )

    @staticmethod
    def get_hydration_contribution_for_period(*, user, start, end):
        return (
            HydrationRepository._period_queryset(user=user, start=start, end=end).aggregate(
                total_hydration_liters=Sum(HydrationRepository.hydration_amount_expression())
            )["total_hydration_liters"]
            or 0
        )

    @staticmethod
    def contribution_breakdown_for_period(*, user, start, end):
        qs = HydrationRepository._period_queryset(user=user, start=start, end=end)
        total_volume = qs.aggregate(total=Sum("amount_liter")).get("total") or 0
        hydration_total = (
            qs.aggregate(total=Sum(HydrationRepository.hydration_amount_expression())).get("total")
            or 0
        )
        water_total = (
            qs.filter(beverage_type=WaterLog.BEVERAGE_WATER)
            .aggregate(total=Sum(HydrationRepository.hydration_amount_expression()))
            .get("total")
            or 0
        )
        other_total = (
            qs.exclude(beverage_type=WaterLog.BEVERAGE_WATER)
            .aggregate(total=Sum(HydrationRepository.hydration_amount_expression()))
            .get("total")
            or 0
        )
        return {
            "consumed_volume_liters": float(total_volume or 0),
            "hydration_contribution_liters": float(hydration_total or 0),
            "water_contribution_liters": float(water_total or 0),
            "other_drinks_contribution_liters": float(other_total or 0),
        }

    @staticmethod
    def get_for_linked_meal_log(meal_log):
        return (
            WaterLog.objects.select_related("food_item", "drink_item", "linked_meal_log")
            .filter(linked_meal_log=meal_log)
            .first()
        )

    @staticmethod
    def save(log, *, update_fields=None):
        if update_fields is None:
            log.save()
        else:
            log.save(update_fields=update_fields)
        return log

    @staticmethod
    def delete(log):
        log.delete()


WaterLogRepository = HydrationRepository
