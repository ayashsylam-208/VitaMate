from datetime import date

from core.models import MealLog


class MealLogRepository:
    @staticmethod
    def create_for_user(user, food, meal_type, quantity_grams):
        return MealLog.objects.create(
            user=user,
            food=food,
            meal_type=meal_type,
            quantity_grams=quantity_grams,
        )

    @staticmethod
    def get_for_user_on_date(user, log_date=None):
        if log_date is None:
            log_date = date.today()
        return MealLog.objects.filter(user=user, date=log_date)
