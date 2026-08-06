import json

from django.core.management.base import BaseCommand, CommandError
from django.db.models import Count, Q

from core.models import FoodItem, NutritionFacts, NutritionServingOption


NUTRIENT_FIELDS = (
    "calories_kcal",
    "protein_g",
    "carbohydrates_g",
    "sugars_g",
    "fiber_g",
    "fat_g",
    "saturated_fat_g",
    "trans_fat_g",
    "cholesterol_mg",
    "sodium_mg",
    "potassium_mg",
    "calcium_mg",
    "iron_mg",
    "magnesium_mg",
    "zinc_mg",
    "phosphorus_mg",
    "vitamin_a_mcg",
    "vitamin_c_mg",
    "vitamin_d_mcg",
    "vitamin_b12_mcg",
    "folate_mcg",
    "monounsaturated_fat_g",
    "polyunsaturated_fat_g",
    "added_sugars_g",
    "water_g",
    "caffeine_mg",
    "vitamin_e_mg",
    "vitamin_k_mcg",
    "vitamin_b1_mg",
    "vitamin_b2_mg",
    "vitamin_b3_mg",
    "vitamin_b6_mg",
)


class Command(BaseCommand):
    help = "Audit nutrition catalog consistency and AI mapping readiness."

    def add_arguments(self, parser):
        parser.add_argument(
            "--strict",
            action="store_true",
            help="Exit with an error when blocking catalog issues exist.",
        )

    def handle(self, *args, **options):
        negative_filter = Q()
        for field in NUTRIENT_FIELDS:
            negative_filter |= Q(**{f"{field}__lt": 0})

        basis_mismatch = (
            ~Q(basis_type="per_100g", basis_unit="g")
            & ~Q(basis_type="per_100ml", basis_unit="ml")
            & ~Q(basis_type="per_serving", basis_unit="serving")
        )
        duplicate_names = (
            FoodItem.objects.filter(created_by__isnull=True)
            .exclude(normalized_name="")
            .values("normalized_name")
            .annotate(total=Count("id"))
            .filter(total__gt=1)
        )
        multiple_defaults = (
            NutritionServingOption.objects.filter(is_default=True)
            .values("food_item_id")
            .annotate(total=Count("id"))
            .filter(total__gt=1)
        )

        report = {
            "foods": FoodItem.objects.count(),
            "active_foods": FoodItem.objects.filter(is_active=True).count(),
            "global_foods": FoodItem.objects.filter(created_by__isnull=True).count(),
            "verified_global_foods": FoodItem.objects.filter(
                created_by__isnull=True,
                is_verified=True,
            ).count(),
            "nutrition_facts": NutritionFacts.objects.count(),
            "serving_options": NutritionServingOption.objects.count(),
            "blocking_issues": {
                "foods_missing_facts": FoodItem.objects.filter(
                    nutrition_facts__isnull=True
                ).count(),
                "duplicate_global_names": duplicate_names.count(),
                "invalid_basis": NutritionFacts.objects.filter(
                    Q(basis_value__lte=0)
                    | Q(basis_amount__lte=0)
                    | Q(serving_size__lte=0)
                    | basis_mismatch
                ).count(),
                "negative_nutrient_rows": NutritionFacts.objects.filter(
                    negative_filter
                ).count(),
                "multiple_default_servings": multiple_defaults.count(),
            },
            "readiness_warnings": {
                "facts_without_confidence": NutritionFacts.objects.filter(
                    confidence_score__isnull=True
                ).count(),
                "active_unverified_global_foods": FoodItem.objects.filter(
                    created_by__isnull=True,
                    is_active=True,
                    is_verified=False,
                ).count(),
                "foods_without_serving_options": FoodItem.objects.filter(
                    serving_options__isnull=True
                ).count(),
            },
        }
        self.stdout.write(json.dumps(report, indent=2, sort_keys=True))
        blocking_total = sum(report["blocking_issues"].values())
        if options["strict"] and blocking_total:
            raise CommandError(f"Nutrition catalog has {blocking_total} blocking issue(s).")
