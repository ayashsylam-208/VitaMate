class HealthConstraintEngine:
    """Pure calculations isolated from I/O and ORM side effects."""

    @staticmethod
    def calories_remaining(*, target: int, consumed: int, burned: int) -> int:
        return target - consumed + burned

    @staticmethod
    def adjusted_water_target(*, base_target_liters: float, exercise_minutes: int) -> float:
        extra_water_liters = (exercise_minutes / 30) * 0.35
        return round(base_target_liters + extra_water_liters, 2)

    @staticmethod
    def sleep_progress_percent(*, logged_hours_today: float, goal_hours: float) -> int:
        if not goal_hours:
            return 0
        return min(100, int((logged_hours_today / goal_hours) * 100))

    @staticmethod
    def estimate_day_points(
        *,
        water_sum: float,
        steps: int,
        has_activities: bool,
        calories_in: int,
        calories_target: int,
        sleep_hours: float,
        sleep_target: float,
    ) -> int:
        day_points = 0
        if water_sum > 0:
            day_points += 5
        if steps > 0:
            day_points += max(1, (steps // 1000) * 5)
        if has_activities:
            day_points += 5
        if calories_in > 0:
            if calories_target and calories_in > calories_target:
                day_points -= 5
            else:
                day_points += 5
        if sleep_target and sleep_hours >= 0.9 * sleep_target:
            day_points += 10
        return day_points

