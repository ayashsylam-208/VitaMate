from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, time, timedelta

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from core.models import (
    ActivityLog,
    ConditionAlert,
    ConditionDailyEvaluation,
    ConditionMedication,
    ConditionMedicationLog,
    ConditionMedicationSchedule,
    ConstraintResolutionRun,
    Exercise,
    FoodItem,
    Habit,
    HabitLog,
    HealthIndicatorRecord,
    HealthStateComputationRun,
    HealthStateDelta,
    MealLog,
    Medicine,
    NotificationDispatchRecord,
    ResolvedTrackerConstraint,
    SleepLog,
    StepLog,
    UnifiedHealthState,
    UserCondition,
    UserNutrientTarget,
    WaterLog,
)
from core.services.nutrition.nutrition_service import NutritionService
from gamification.models import UserScore
from users.services.profile_metrics_calculator import ProfileMetricsCalculator
from users.services.user_profile_service import UserProfileService


@dataclass(frozen=True)
class SeedContext:
    today: datetime
    day_count: int
    foods: dict[str, FoodItem]
    exercises: list[Exercise]
    condition_types: dict[str, object]


class Command(BaseCommand):
    help = "Seed a reproducible representative dataset for Locust performance baseline runs."

    def add_arguments(self, parser):
        parser.add_argument("--profile", default="representative")
        parser.add_argument("--reset", action="store_true")
        parser.add_argument("--username-base", default="locust")
        parser.add_argument("--password", default="Pass123!")
        parser.add_argument("--user-count", type=int, default=40)
        parser.add_argument("--days", type=int, default=7)

    def handle(self, *args, **options):
        profile = options["profile"]
        if profile != "representative":
            raise CommandError(
                f"Unsupported profile '{profile}'. Only 'representative' is available."
            )

        username_base = options["username_base"]
        password = options["password"]
        user_count = int(options["user_count"])
        day_count = int(options["days"])
        reset = bool(options["reset"])

        if user_count <= 0:
            raise CommandError("--user-count must be greater than zero.")
        if day_count <= 0:
            raise CommandError("--days must be greater than zero.")

        usernames = [f"{username_base}{index}" for index in range(user_count)]
        today = timezone.localtime()

        with transaction.atomic():
            if reset:
                User.objects.filter(username__in=usernames).delete()

            context = SeedContext(
                today=today,
                day_count=day_count,
                foods=self._ensure_food_catalog(),
                exercises=self._ensure_exercises(),
                condition_types=self._condition_types(),
            )

            for index, username in enumerate(usernames):
                user, created = User.objects.get_or_create(
                    username=username,
                    defaults={
                        "email": f"{username}@example.com",
                        "first_name": "Locust",
                        "last_name": "User",
                    },
                )
                if not created:
                    self._reset_user_state(user)

                self._prepare_user(user=user, password=password, index=index)
                self._seed_user(user=user, index=index, context=context)

        self.stdout.write(
            self.style.SUCCESS(
                f"Seeded representative performance dataset for {user_count} users over {day_count} days."
            )
        )

    def _prepare_user(self, *, user: User, password: str, index: int) -> None:
        user.email = f"{user.username}@example.com"
        user.first_name = "Locust"
        user.last_name = f"User{index:02d}"
        if not user.check_password(password):
            user.set_password(password)
        user.save()

        profile = UserProfileService.ensure_profile(user)
        profile.gender = "M" if index % 2 == 0 else "F"
        profile.height = 168 + (index % 7)
        profile.weight = 64 + (index % 11)
        profile.activity_level = [1.2, 1.375, 1.55][index % 3]
        profile.goal = "maintain" if index % 4 else "lose"
        profile.recommended_sleep_hours = 7.5 if index % 5 else 8.0
        profile.target_wake_time = time(7, 0)
        ProfileMetricsCalculator.apply(profile, persist=False)
        profile.save()

        UserScore.objects.update_or_create(
            user=user,
            defaults={
                "total_points": 180 + (index * 23),
                "level": 1 + ((180 + (index * 23)) // 1000),
            },
        )

    def _seed_user(self, *, user: User, index: int, context: SeedContext) -> None:
        habits = self._seed_habits(user=user)
        hypertension = self._seed_hypertension_condition(
            user=user,
            index=index,
            context=context,
        )
        diabetes = None
        if index % 4 == 0:
            diabetes = self._seed_diabetes_condition(
                user=user,
                index=index,
                context=context,
            )

        for day_offset in range(context.day_count):
            target_day = (context.today - timedelta(days=context.day_count - day_offset - 1)).date()
            self._seed_day_logs(
                user=user,
                index=index,
                target_day=target_day,
                day_offset=day_offset,
                context=context,
            )
            self._seed_habit_logs(
                habits=habits,
                index=index,
                target_day=target_day,
                day_offset=day_offset,
            )
            self._seed_medication_logs_for_day(
                condition=hypertension,
                index=index,
                target_day=target_day,
                day_offset=day_offset,
            )
            self._seed_condition_evaluation(
                condition=hypertension,
                index=index,
                target_day=target_day,
                day_offset=day_offset,
            )
            if diabetes is not None:
                self._seed_medication_logs_for_day(
                    condition=diabetes,
                    index=index,
                    target_day=target_day,
                    day_offset=day_offset,
                )
                self._seed_condition_evaluation(
                    condition=diabetes,
                    index=index,
                    target_day=target_day,
                    day_offset=day_offset,
                )

        self._seed_indicator_records(
            condition=hypertension,
            index=index,
            recorded_at=context.today - timedelta(minutes=15),
        )
        if diabetes is not None:
            self._seed_indicator_records(
                condition=diabetes,
                index=index,
                recorded_at=context.today - timedelta(minutes=8),
            )

    def _seed_day_logs(
        self,
        *,
        user: User,
        index: int,
        target_day,
        day_offset: int,
        context: SeedContext,
    ) -> None:
        steps = 5400 + (index * 35) + (day_offset * 210)
        distance_km = round(steps / 1312, 2)
        step_log = StepLog.objects.create(
            user=user,
            steps_count=steps,
            distance_km=distance_km,
        )
        self._force_date(step_log, target_day)

        sleep_hours = 6.8 + (((index + day_offset) % 4) * 0.35)
        sleep_start = self._aware_datetime(target_day, 23, 0) - timedelta(hours=sleep_hours)
        sleep_end = sleep_start + timedelta(hours=sleep_hours)
        sleep_log = SleepLog.objects.create(
            user=user,
            start_time=sleep_start,
            end_time=sleep_end,
            quality="Deep" if (index + day_offset) % 3 else "Light",
        )
        self._force_date(sleep_log, target_day)

        self._create_water_log(
            user=user,
            target_day=target_day,
            amount_liter=0.45,
            beverage_type=WaterLog.BEVERAGE_WATER,
            beverage_name="Water",
        )
        self._create_water_log(
            user=user,
            target_day=target_day,
            amount_liter=0.55,
            beverage_type=WaterLog.BEVERAGE_WATER,
            beverage_name="Water",
        )
        self._create_water_log(
            user=user,
            target_day=target_day,
            amount_liter=0.35 + ((index + day_offset) % 3) * 0.1,
            beverage_type=WaterLog.BEVERAGE_TEA,
            beverage_name="Tea",
        )

        if day_offset % 2 == 0 or index % 3 == 0:
            exercise = context.exercises[(index + day_offset) % len(context.exercises)]
            activity = ActivityLog.objects.create(
                user=user,
                exercise=exercise,
                duration_minutes=25 + (((index + day_offset) % 4) * 10),
                distance_km=round(2.2 + (((index + day_offset) % 5) * 0.6), 2),
            )
            self._force_date(activity, target_day)

        breakfast_time = self._aware_datetime(target_day, 8, 0)
        lunch_time = self._aware_datetime(target_day, 13, 0)
        snack_time = self._aware_datetime(target_day, 16, 30)
        dinner_time = self._aware_datetime(target_day, 19, 30)
        coffee_time = self._aware_datetime(target_day, 10, 15)

        NutritionService.log_meal(
            user=user,
            food=context.foods["oats"],
            meal_type="breakfast",
            quantity_grams=180 + (index % 3) * 10,
            consumed_at=breakfast_time,
            publish_event=False,
            sync_hydration=False,
        )
        NutritionService.log_meal(
            user=user,
            food=context.foods["chicken_plate"],
            meal_type="lunch",
            quantity_grams=230 + (day_offset % 3) * 10,
            consumed_at=lunch_time,
            publish_event=False,
            sync_hydration=False,
        )
        NutritionService.log_meal(
            user=user,
            food=context.foods["fruit_snack"],
            meal_type="snack",
            quantity_grams=150,
            consumed_at=snack_time,
            publish_event=False,
            sync_hydration=False,
        )
        NutritionService.log_meal(
            user=user,
            food=context.foods["chicken_plate"],
            meal_type="dinner",
            quantity_grams=210 + ((index + day_offset) % 2) * 15,
            consumed_at=dinner_time,
            publish_event=False,
            sync_hydration=False,
        )
        NutritionService.log_meal(
            user=user,
            food=context.foods["coffee"],
            meal_type="drink",
            quantity=250,
            unit="ml",
            consumed_at=coffee_time,
            publish_event=False,
            sync_hydration=False,
        )

    def _seed_hypertension_condition(self, *, user: User, index: int, context: SeedContext) -> UserCondition:
        stage = "stage_2" if index % 5 == 0 else "stage_1"
        condition = UserCondition.objects.create(
            user=user,
            condition_type=context.condition_types["hypertension"],
            diagnosis_date=(context.today - timedelta(days=540 + index)).date(),
            status=(
                UserCondition.STATUS_NEEDS_ATTENTION if stage == "stage_2" else UserCondition.STATUS_ACTIVE
            ),
            severity_code=stage,
            profile_data={
                "systolic_baseline": 136 + (index % 7),
                "diastolic_baseline": 84 + (index % 5),
            },
        )
        medication = ConditionMedication.objects.create(
            user=user,
            user_condition=condition,
            name="Lisinopril",
            display_name="Lisinopril",
            dosage="10 mg",
            dosage_amount="10",
            dosage_unit="mg",
            instructions="Take consistently each day.",
            source_type=ConditionMedication.SOURCE_CONDITION,
            relation_to_meal=ConditionMedication.RELATION_ANYTIME,
            adherence_mode=ConditionMedication.ADHERENCE_STRICT,
            reminder_enabled=True,
            reminder_lead_minutes=20,
            start_date=(context.today - timedelta(days=90)).date(),
        )
        ConditionMedicationSchedule.objects.create(
            medication=medication,
            time_of_day=time(8, 0),
            grace_period_minutes=90,
            snooze_default_minutes=15,
        )
        ConditionMedicationSchedule.objects.create(
            medication=medication,
            time_of_day=time(20, 0),
            grace_period_minutes=90,
            snooze_default_minutes=15,
        )
        return condition

    def _seed_diabetes_condition(self, *, user: User, index: int, context: SeedContext) -> UserCondition:
        condition = UserCondition.objects.create(
            user=user,
            condition_type=context.condition_types["diabetes"],
            diagnosis_date=(context.today - timedelta(days=700 + index)).date(),
            status=UserCondition.STATUS_CONTROLLED,
            severity_code="diabetes_managed",
            profile_data={"glucose_target": 110, "hba1c_target": 6.8},
        )
        medication = ConditionMedication.objects.create(
            user=user,
            user_condition=condition,
            name="Metformin",
            display_name="Metformin",
            dosage="500 mg",
            dosage_amount="500",
            dosage_unit="mg",
            instructions="Take with food.",
            source_type=ConditionMedication.SOURCE_CONDITION,
            relation_to_meal=ConditionMedication.RELATION_WITH_MEAL,
            adherence_mode=ConditionMedication.ADHERENCE_STRICT,
            reminder_enabled=True,
            reminder_lead_minutes=15,
            start_date=(context.today - timedelta(days=120)).date(),
        )
        ConditionMedicationSchedule.objects.create(
            medication=medication,
            time_of_day=time(9, 0),
            grace_period_minutes=90,
            snooze_default_minutes=15,
        )
        return condition

    def _seed_medication_logs_for_day(
        self,
        *,
        condition: UserCondition,
        index: int,
        target_day,
        day_offset: int,
    ) -> None:
        today = timezone.localdate()
        schedules = list(condition.medications.first().schedules.order_by("time_of_day", "id"))
        for schedule_index, schedule in enumerate(schedules):
            scheduled_for = self._aware_datetime(
                target_day,
                schedule.time_of_day.hour,
                schedule.time_of_day.minute,
            )
            status = ConditionMedicationLog.STATUS_TAKEN_ON_TIME
            taken_at = scheduled_for + timedelta(minutes=7 + schedule_index)

            if target_day == today and schedule_index == 0 and index % 3 == 0:
                status = ConditionMedicationLog.STATUS_OVERDUE
                taken_at = None
            elif target_day == today and schedule_index == 1:
                status = ConditionMedicationLog.STATUS_PENDING
                taken_at = None
            elif day_offset == 2 and schedule_index == 0 and index % 5 == 0:
                status = ConditionMedicationLog.STATUS_MISSED
                taken_at = None

            ConditionMedicationLog.objects.create(
                medication=schedule.medication,
                schedule=schedule,
                scheduled_date=target_day,
                scheduled_for=scheduled_for,
                taken_at=taken_at,
                status=status,
                action_source=ConditionMedicationLog.ACTION_SYSTEM,
                notes="Seeded performance baseline dose log.",
            )

    def _seed_condition_evaluation(
        self,
        *,
        condition: UserCondition,
        index: int,
        target_day,
        day_offset: int,
    ) -> None:
        adherence = 92.0 - ((index + day_offset) % 4) * 6
        restriction = 88.0 - ((index + day_offset) % 3) * 5
        status = ConditionDailyEvaluation.STATUS_STABLE
        risk_flags: list[str] = []
        if condition.status == UserCondition.STATUS_NEEDS_ATTENTION and target_day == timezone.localdate():
            status = ConditionDailyEvaluation.STATUS_ATTENTION_NEEDED
            risk_flags = ["blood_pressure_elevated"]

        ConditionDailyEvaluation.objects.create(
            user_condition=condition,
            evaluation_date=target_day,
            status=status,
            risk_flags=risk_flags,
            recommendations_payload=[
                {
                    "code": "stay_consistent",
                    "message": "Keep logging medications and readings consistently.",
                }
            ],
            tracker_impacts_payload=[],
            latest_recorded_at=self._aware_datetime(target_day, 12, 0),
            medication_adherence_percent=adherence,
            restriction_adherence_percent=restriction,
            points_delta=3 if status == ConditionDailyEvaluation.STATUS_STABLE else 0,
            notes="Seeded representative evaluation.",
        )

        if risk_flags:
            ConditionAlert.objects.create(
                user_condition=condition,
                code=risk_flags[0],
                level="warning",
                message="Latest reading suggests attention is needed.",
                alert_type=ConditionAlert.TYPE_MONITORING,
                status=ConditionAlert.STATUS_OPEN,
            )

    def _seed_indicator_records(self, *, condition: UserCondition, index: int, recorded_at: datetime) -> None:
        if condition.condition_type.slug == "hypertension":
            systolic = 132 + (index % 8)
            diastolic = 82 + (index % 5)
            classification = "high" if condition.status == UserCondition.STATUS_NEEDS_ATTENTION else ""
            risk_level = "medium" if classification else "low"
            HealthIndicatorRecord.objects.create(
                user_condition=condition,
                indicator_name="Blood pressure",
                indicator_type="blood_pressure",
                value=float(systolic),
                value_1=float(systolic),
                value_2=float(diastolic),
                value_3=float(72 + (index % 6)),
                unit="mmHg",
                payload={
                    "systolic": systolic,
                    "diastolic": diastolic,
                    "pulse": 72 + (index % 6),
                },
                classification=classification,
                risk_level=risk_level,
                recorded_at=recorded_at,
            )
            return

        HealthIndicatorRecord.objects.create(
            user_condition=condition,
            indicator_name="Fasting glucose",
            indicator_type="glucose",
            value=float(108 + (index % 6) * 4),
            unit="mg/dL",
            reading_context="fasting",
            classification="high" if index % 6 == 0 else "",
            risk_level="medium" if index % 6 == 0 else "low",
            recorded_at=recorded_at,
        )

    def _seed_habits(self, *, user: User) -> list[Habit]:
        return [
            Habit.objects.create(user=user, name="Morning hydration", habit_type="good"),
            Habit.objects.create(user=user, name="Evening walk", habit_type="good"),
        ]

    def _seed_habit_logs(self, *, habits: list[Habit], index: int, target_day, day_offset: int) -> None:
        for habit_index, habit in enumerate(habits):
            log = HabitLog.objects.create(
                habit=habit,
                completed=((index + day_offset + habit_index) % 3 != 0),
            )
            self._force_date(log, target_day)

    def _create_water_log(
        self,
        *,
        user: User,
        target_day,
        amount_liter: float,
        beverage_type: str,
        beverage_name: str,
    ) -> None:
        log = WaterLog.objects.create(
            user=user,
            amount_liter=amount_liter,
            beverage_type=beverage_type,
            beverage_name=beverage_name,
        )
        self._force_date(log, target_day)

    def _ensure_food_catalog(self) -> dict[str, FoodItem]:
        oats, _ = FoodItem.objects.get_or_create(
            name="Performance Oats Bowl",
            defaults={
                "item_type": FoodItem.TYPE_FOOD,
                "category": "Breakfast",
                "source": FoodItem.SOURCE_MANUAL,
                "default_serving_size": 180,
                "default_serving_unit": "g",
                "default_reference_unit": "g",
                "calories_100g": 155,
                "protein_100g": 5.5,
                "carbs_100g": 27,
                "fat_100g": 3.2,
                "fiber_100g": 4.0,
                "sugar_100g": 1.6,
                "sodium_mg_100g": 95,
            },
        )
        chicken_plate, _ = FoodItem.objects.get_or_create(
            name="Performance Chicken Plate",
            defaults={
                "item_type": FoodItem.TYPE_FOOD,
                "category": "Main",
                "source": FoodItem.SOURCE_MANUAL,
                "default_serving_size": 220,
                "default_serving_unit": "g",
                "default_reference_unit": "g",
                "calories_100g": 215,
                "protein_100g": 22,
                "carbs_100g": 18,
                "fat_100g": 6.5,
                "fiber_100g": 2.8,
                "sugar_100g": 2.5,
                "sodium_mg_100g": 520,
                "saturated_fat_100g": 1.7,
                "potassium_mg_100g": 340,
            },
        )
        fruit_snack, _ = FoodItem.objects.get_or_create(
            name="Performance Fruit Snack",
            defaults={
                "item_type": FoodItem.TYPE_FOOD,
                "category": "Snack",
                "source": FoodItem.SOURCE_MANUAL,
                "default_serving_size": 150,
                "default_serving_unit": "g",
                "default_reference_unit": "g",
                "calories_100g": 96,
                "protein_100g": 4.3,
                "carbs_100g": 16.4,
                "fat_100g": 2.2,
                "fiber_100g": 2.1,
                "sugar_100g": 12.0,
                "sodium_mg_100g": 42,
                "potassium_mg_100g": 180,
            },
        )
        coffee, _ = FoodItem.objects.get_or_create(
            name="Performance Coffee",
            defaults={
                "item_type": FoodItem.TYPE_BEVERAGE,
                "category": "Coffee",
                "source": FoodItem.SOURCE_MANUAL,
                "default_serving_size": 250,
                "default_serving_unit": "ml",
                "default_reference_unit": "ml",
                "density_g_per_ml": 1.0,
                "is_hydration_trackable": True,
                "contains_caffeine": True,
                "calories_100g": 2,
                "protein_100g": 0.2,
                "carbs_100g": 0.0,
                "fat_100g": 0.0,
                "fiber_100g": 0.0,
                "sugar_100g": 0.0,
                "sodium_mg_100g": 4.0,
                "serving_label": "Cup",
                "serving_grams": 250,
            },
        )
        return {
            "oats": oats,
            "chicken_plate": chicken_plate,
            "fruit_snack": fruit_snack,
            "coffee": coffee,
        }

    def _ensure_exercises(self) -> list[Exercise]:
        exercises = [
            Exercise.objects.get_or_create(name="Brisk Walk", defaults={"met_value": 4.3})[0],
            Exercise.objects.get_or_create(name="Cycling", defaults={"met_value": 6.8})[0],
            Exercise.objects.get_or_create(name="Jogging", defaults={"met_value": 7.5})[0],
        ]
        return exercises

    def _condition_types(self) -> dict[str, object]:
        condition_types = {
            item.slug: item
            for item in UserCondition._meta.get_field("condition_type").remote_field.model.objects.filter(
                slug__in=["hypertension", "diabetes"]
            )
        }
        if "hypertension" not in condition_types or "diabetes" not in condition_types:
            raise CommandError(
                "Required chronic condition types are missing. Run migrations first."
            )
        return condition_types

    def _reset_user_state(self, user: User) -> None:
        ConditionMedication.objects.filter(user=user).delete()
        UserCondition.objects.filter(user=user).delete()

        MealLog.objects.filter(user=user).delete()
        WaterLog.objects.filter(user=user).delete()
        StepLog.objects.filter(user=user).delete()
        SleepLog.objects.filter(user=user).delete()
        ActivityLog.objects.filter(user=user).delete()

        Habit.objects.filter(user=user).delete()
        Medicine.objects.filter(user=user).delete()

        UserNutrientTarget.objects.filter(user=user).delete()
        ResolvedTrackerConstraint.objects.filter(user=user).delete()
        ConstraintResolutionRun.objects.filter(user=user).delete()

        UnifiedHealthState.objects.filter(user=user).delete()
        HealthStateComputationRun.objects.filter(user=user).delete()
        HealthStateDelta.objects.filter(user=user).delete()
        NotificationDispatchRecord.objects.filter(user=user).delete()
        UserScore.objects.filter(user=user).delete()

    @staticmethod
    def _force_date(instance, target_day) -> None:
        instance.date = target_day
        instance.save(update_fields=["date"])

    @staticmethod
    def _aware_datetime(target_day, hour: int, minute: int) -> datetime:
        naive = datetime.combine(target_day, time(hour, minute))
        return timezone.make_aware(naive, timezone.get_current_timezone())
