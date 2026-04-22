from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from core.models import (
    ActivityLog,
    ConditionMedication,
    ConstraintResolutionRun,
    Habit,
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
    HealthStateComputationRun,
    HealthStateDelta,
)
from gamification.models import UserScore
from users.services.user_profile_service import UserProfileService


class Command(BaseCommand):
    help = "Create or reset the reproducible E2E user used by Flutter integration tests."

    def add_arguments(self, parser):
        parser.add_argument("--scenario", default="chronic_flow")
        parser.add_argument("--reset", action="store_true")
        parser.add_argument("--username", default="e2e_chronic")
        parser.add_argument("--password", default="Pass123!")

    def handle(self, *args, **options):
        scenario = options["scenario"]
        if scenario != "chronic_flow":
            raise CommandError(
                f"Unsupported scenario '{scenario}'. Only 'chronic_flow' is available."
            )

        username = options["username"]
        password = options["password"]
        reset = options["reset"]

        with transaction.atomic():
            user, _ = User.objects.get_or_create(
                username=username,
                defaults={
                    "email": f"{username}@example.com",
                    "first_name": "E2E",
                    "last_name": "Chronic",
                },
            )

            user.email = f"{username}@example.com"
            user.first_name = "E2E"
            user.last_name = "Chronic"
            if not user.check_password(password):
                user.set_password(password)
            user.save()

            profile = UserProfileService.ensure_profile(user)
            profile.gender = profile.gender or "M"
            profile.height = profile.height or 170
            profile.weight = profile.weight or 70
            profile.activity_level = profile.activity_level or 1.2
            profile.save()

            if reset:
                self._reset_user_state(user)

            UserScore.objects.update_or_create(
                user=user,
                defaults={"total_points": 0, "level": 1},
            )

        self.stdout.write(
            self.style.SUCCESS(
                f"Prepared integration user '{username}' for scenario '{scenario}'."
            )
        )

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
