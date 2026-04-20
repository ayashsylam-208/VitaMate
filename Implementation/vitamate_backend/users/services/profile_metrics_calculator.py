from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from users.models import UserProfile


@dataclass(frozen=True)
class ProfileMetrics:
    bmi: float
    daily_calorie_target: int
    daily_water_target: float
    daily_step_goal: int
    daily_burn_goal: int
    target_bed_time: time | None


class ProfileMetricsCalculator:
    @staticmethod
    def calculate(profile: "UserProfile", *, today: date | None = None) -> ProfileMetrics:
        today = today or date.today()
        birth_date = profile.birth_date
        if isinstance(birth_date, str):
            birth_date = date.fromisoformat(birth_date)

        age = today.year - birth_date.year - (
            (today.month, today.day) < (birth_date.month, birth_date.day)
        )

        if profile.gender == "M":
            bmr = (10 * profile.weight) + (6.25 * profile.height) - (5 * age) + 5
        else:
            bmr = (10 * profile.weight) + (6.25 * profile.height) - (5 * age) - 161

        tdee = bmr * profile.activity_level
        if profile.goal == "lose":
            daily_calorie_target = int(tdee - 500)
        elif profile.goal in ["gain", "muscle"]:
            daily_calorie_target = int(tdee + 500)
        else:
            daily_calorie_target = int(tdee)

        daily_water_target = round((profile.weight * 0.033), 2)

        step_goal = 6000
        if profile.goal == "lose":
            step_goal += 2000
        elif profile.goal in ["muscle", "gain"]:
            step_goal += 1000
        if profile.activity_level >= 1.55:
            step_goal += 1000
        if profile.activity_level >= 1.725:
            step_goal += 500
        daily_step_goal = max(5000, step_goal)

        steps_burn_target = int(daily_step_goal * 0.04)
        activity_component = int(profile.activity_level * 150)
        goal_bonus = 100 if profile.goal == "lose" else 0
        daily_burn_goal = steps_burn_target + activity_component + goal_bonus

        height_m = profile.height / 100
        bmi = round(profile.weight / (height_m * height_m), 2)

        target_bed_time = None
        if profile.target_wake_time:
            dummy_date = datetime.combine(today, profile.target_wake_time)
            bed_time = dummy_date - timedelta(hours=profile.recommended_sleep_hours)
            target_bed_time = bed_time.time()

        return ProfileMetrics(
            bmi=bmi,
            daily_calorie_target=daily_calorie_target,
            daily_water_target=daily_water_target,
            daily_step_goal=daily_step_goal,
            daily_burn_goal=daily_burn_goal,
            target_bed_time=target_bed_time,
        )

    @classmethod
    def apply(
        cls,
        profile: "UserProfile",
        *,
        today: date | None = None,
        persist: bool = False,
    ) -> ProfileMetrics:
        metrics = cls.calculate(profile, today=today)
        profile.bmi = metrics.bmi
        profile.daily_calorie_target = metrics.daily_calorie_target
        profile.daily_water_target = metrics.daily_water_target
        profile.daily_step_goal = metrics.daily_step_goal
        profile.daily_burn_goal = metrics.daily_burn_goal
        profile.target_bed_time = metrics.target_bed_time

        if persist:
            profile.save(
                update_fields=[
                    "bmi",
                    "daily_calorie_target",
                    "daily_water_target",
                    "daily_step_goal",
                    "daily_burn_goal",
                    "target_bed_time",
                ]
            )
        return metrics
