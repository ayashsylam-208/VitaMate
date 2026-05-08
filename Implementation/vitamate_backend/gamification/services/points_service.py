from gamification.repositories.user_score_repository import UserScoreRepository


class PointsService:
    @staticmethod
    def add_points(user, points):
        # Add points while ensuring the score record exists.
        score, _ = UserScoreRepository.get_or_create_for_user(user)
        score.add_points(points)
        return score

    @staticmethod
    def deduct_points(user, points):
        # Deduct points without going below zero.
        score, _ = UserScoreRepository.get_or_create_for_user(user)
        score.deduct_points(points)
        return score

    @staticmethod
    def award_water_points(user):
        # Fixed points per water log.
        return PointsService.add_points(user, 5)

    @staticmethod
    def award_activity_points(user):
        # Fixed points per activity log.
        return PointsService.add_points(user, 5)

    @staticmethod
    def award_steps_points(user, steps_count):
        # Steps points per 1000 steps (minimum 1 point).
        points = max(1, (steps_count // 1000) * 5)
        return PointsService.add_points(user, points)

    @staticmethod
    def apply_meal_points(user, calories_in, target):
        # Add/deduct points based on daily calorie target.
        if target and calories_in > target:
            return PointsService.deduct_points(user, 5)
        return PointsService.add_points(user, 5)

    @staticmethod
    def award_sleep_points_if_eligible(user, duration_hours, goal_hours):
        # Award sleep points when reaching 90% of the goal.
        if goal_hours and duration_hours >= 0.9 * goal_hours:
            return PointsService.add_points(user, 10)
        return None

    @staticmethod
    def award_unhealthy_habit_log(user):
        return PointsService.add_points(user, 2)

    @staticmethod
    def award_unhealthy_habit_within_limit(user):
        return PointsService.add_points(user, 3)

    @staticmethod
    def award_unhealthy_habit_improvement(user):
        return PointsService.add_points(user, 5)

    @staticmethod
    def award_unhealthy_habit_replacement(user):
        return PointsService.add_points(user, 4)
