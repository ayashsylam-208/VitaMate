from django.test import SimpleTestCase


class CoreImportCompatibilityTests(SimpleTestCase):
    def test_models_barrel_exports_remain_available(self):
        from core.models import ConditionMedication, FoodItem, ResolvedTrackerConstraint, StepLog

        self.assertIsNotNone(FoodItem)
        self.assertIsNotNone(StepLog)
        self.assertIsNotNone(ConditionMedication)
        self.assertIsNotNone(ResolvedTrackerConstraint)

    def test_legacy_service_and_repository_import_paths_still_work(self):
        from core.repositories.step_log_repository import StepRepository
        from core.repositories.food_item_repository import NutritionCatalogRepository
        from core.services.health_tracker_coordinator import HealthTrackerCoordinator
        from core.services.nutrition_service import NutritionService

        self.assertIsNotNone(StepRepository)
        self.assertIsNotNone(NutritionCatalogRepository)
        self.assertIsNotNone(HealthTrackerCoordinator)
        self.assertIsNotNone(NutritionService)

    def test_new_structured_import_paths_are_available(self):
        from core.api.nutrition.views import FoodItemViewSet
        from core.repositories.medication.medication_repository import MedicationRepository
        from core.services.chronic.condition_setup_service import ConditionSetupService
        from core.services.tracking.steps_service import StepsService

        self.assertIsNotNone(FoodItemViewSet)
        self.assertIsNotNone(MedicationRepository)
        self.assertIsNotNone(ConditionSetupService)
        self.assertIsNotNone(StepsService)
