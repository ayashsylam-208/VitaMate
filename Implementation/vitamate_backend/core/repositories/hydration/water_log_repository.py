from django.db.models import Case, ExpressionWrapper, F, FloatField, Sum, Value, When

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
    ):
        return WaterLog.objects.create(
            user=user,
            food_item=food_item,
            drink_item=drink_item or food_item,
            linked_meal_log=linked_meal_log,
            beverage_type=beverage_type,
            beverage_name=beverage_name,
            amount_liter=amount_liter,
        )

    @staticmethod
    def list_for_user_on_date(user, log_date):
        return (
            WaterLog.objects.select_related("food_item", "drink_item", "linked_meal_log")
            .filter(user=user, date=log_date)
            .order_by("-id")
        )

    @staticmethod
    def total_amount_for_user_on_date(user, log_date):
        return HydrationRepository.total_hydration_for_user_on_date(user, log_date)

    @staticmethod
    def total_hydration_for_user_on_date(user, log_date):
        return (
            WaterLog.objects.filter(user=user, date=log_date).aggregate(
                total_hydration_liters=Sum(HydrationRepository.hydration_amount_expression())
            )["total_hydration_liters"]
            or 0
        )

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
