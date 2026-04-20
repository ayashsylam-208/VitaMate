from datetime import date

from core.models import MealLog


class NutritionLogRepository:
    @staticmethod
    def create_for_user(user, food, meal_type, quantity_grams, **extra_fields):
        return MealLog.objects.create(
            user=user,
            food=food,
            meal_type=meal_type,
            quantity_grams=quantity_grams,
            **extra_fields,
        )

    @staticmethod
    def get_for_user_on_date(user, log_date=None):
        if log_date is None:
            log_date = date.today()
        return (
            MealLog.objects.filter(user=user, date=log_date)
            .select_related("food", "serving_option")
            .order_by("consumed_at", "id")
        )

    @staticmethod
    def list_for_user(user):
        return (
            MealLog.objects.filter(user=user)
            .select_related("food", "serving_option")
            .order_by("-date", "-id")
        )

    @staticmethod
    def save(meal_log, *, update_fields=None):
        if update_fields is None:
            meal_log.save()
        else:
            meal_log.save(update_fields=update_fields)
        return meal_log

    @staticmethod
    def delete(log):
        log.delete()


MealLogRepository = NutritionLogRepository
