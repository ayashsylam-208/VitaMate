from users.models import UserProfile

from core.repositories.food_item_repository import FoodItemRepository
from core.repositories.meal_log_repository import MealLogRepository
from users.repositories.user_profile_repository import UserProfileRepository
from gamification.services.points_service import PointsService


class NutritionService:
    @staticmethod
    def create_food_item(data):
        # Create a new food item in the dataset.
        return FoodItemRepository.create_item(**data)

    @staticmethod
    def log_meal(user, food, meal_type, quantity_grams):
        # Log a meal for the current user.
        log = MealLogRepository.create_for_user(
            user=user,
            food=food,
            meal_type=meal_type,
            quantity_grams=quantity_grams,
        )

        # Calculate daily calories after adding the meal.
        meals = MealLogRepository.get_for_user_on_date(user, log.date)
        calories_in = sum(m.total_calories for m in meals)

        try:
            profile = UserProfileRepository.get_for_user(user)
        except UserProfile.DoesNotExist:
            return log

        target = getattr(profile, "daily_calorie_target", None)
        if not target:
            return log

        # Points logic: deduct when over target, otherwise add.
        PointsService.apply_meal_points(user, calories_in, target)

        return log
