import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/core/health/diabetes_sugar_guard_service.dart';
import 'package:vitamate/features/nutrition/data/nutrition_api.dart';
import 'package:vitamate/features/nutrition/models/food_item.dart';
import 'package:vitamate/features/nutrition/models/meal_log.dart';
import 'package:vitamate/features/nutrition/models/nutrition_summary.dart';
import 'package:vitamate/features/nutrition/state/nutrition_controller.dart';

class _FakeNutritionApi extends NutritionApi {
  _FakeNutritionApi({
    required this.summary,
    required this.foods,
    required this.meals,
    this.diabetesActive = false,
  });

  final NutritionSummary summary;
  final List<FoodItem> foods;
  final List<MealLog> meals;
  final bool diabetesActive;
  int _nextId = 20;

  @override
  Future<NutritionSummary> getSummary() async {
    final consumedCalories = meals.fold<int>(
      0,
      (sum, item) => sum + item.caloriesKcal.round(),
    );
    final proteinG = meals.fold<double>(0, (sum, item) => sum + item.proteinG);
    final carbsG = meals.fold<double>(0, (sum, item) => sum + item.carbsG);
    final fatG = meals.fold<double>(0, (sum, item) => sum + item.fatG);
    final sugarsG = meals.fold<double>(0, (sum, item) => sum + item.sugarsG);
    return NutritionSummary(
      targetCalories: summary.targetCalories,
      consumedCalories: consumedCalories,
      burnedCalories: summary.burnedCalories,
      remainingCalories: (summary.targetCalories - consumedCalories).clamp(
        0,
        summary.targetCalories,
      ),
      points: summary.points,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      sugarsG: sugarsG,
    );
  }

  @override
  Future<List<FoodItem>> listFoods({
    String? itemType,
    String? query,
    String? category,
    bool? containsCaffeine,
    bool? isHydrationTrackable,
    int? limit,
  }) async {
    return List<FoodItem>.from(foods);
  }

  @override
  Future<List<MealLog>> getMealsToday() async => List<MealLog>.from(meals);

  @override
  Future<bool> hasActiveDiabetes() async => diabetesActive;

  @override
  Future<void> addMeal({
    required int foodId,
    required String mealType,
    double? quantityGrams,
    double? quantity,
    String? unit,
  }) async {
    final food = foods.firstWhere((item) => item.id == foodId);
    final amount = quantity ?? quantityGrams ?? 0;
    final factor = amount / 100.0;
    meals.add(
      MealLog(
        id: _nextId++,
        foodId: foodId,
        foodName: food.name,
        mealType: mealType,
        quantityGrams: quantityGrams ?? amount,
        quantity: amount,
        unit: unit ?? 'g',
        millilitersConsumed: unit == 'ml' ? amount : 0,
        caloriesKcal: food.calories100g * factor,
        proteinG: food.protein100g * factor,
        carbsG: food.carbs100g * factor,
        fatG: food.fat100g * factor,
        sugarsG: food.sugars100g * factor,
        caffeineMg: food.caffeineMg * factor,
      ),
    );
  }
}

class _FakeDiabetesSugarGuardService extends DiabetesSugarGuardService {
  const _FakeDiabetesSugarGuardService(this.guard);

  final DiabetesSugarGuard? guard;

  @override
  Future<DiabetesSugarGuard?> getActiveGuard() async => guard;
}

void main() {
  test(
    'nutrition controller keeps drink rows and computes points from snapshots',
    () async {
      final oats = FoodItem(
        id: 1,
        name: 'Oats',
        calories100g: 380,
        protein100g: 12,
        carbs100g: 64,
        fat100g: 7,
        servingLabel: 'Bowl',
        servingGrams: 80,
      );
      final latte = FoodItem(
        id: 2,
        name: 'Iced Latte',
        itemType: 'beverage',
        category: 'Coffee',
        calories100g: 50,
        protein100g: 2,
        carbs100g: 6,
        fat100g: 1,
        sugars100g: 5,
        caffeineMg: 32,
        servingLabel: 'Cup',
        servingGrams: 250,
      );
      final api = _FakeNutritionApi(
        summary: const NutritionSummary(
          targetCalories: 700,
          consumedCalories: 0,
          burnedCalories: 0,
          remainingCalories: 700,
          points: 0,
        ),
        foods: [oats, latte],
        meals: [
          MealLog(
            id: 1,
            foodId: oats.id,
            foodName: oats.name,
            mealType: 'breakfast',
            quantityGrams: 80,
            quantity: 80,
            unit: 'g',
            caloriesKcal: 304,
            proteinG: 9.6,
            carbsG: 51.2,
            fatG: 5.6,
            sugarsG: 1.2,
          ),
          MealLog(
            id: 2,
            foodId: latte.id,
            foodName: latte.name,
            mealType: 'drink',
            quantityGrams: 200,
            quantity: 200,
            unit: 'ml',
            millilitersConsumed: 200,
            caloriesKcal: 100,
            proteinG: 4,
            carbsG: 12,
            fatG: 2,
            sugarsG: 10,
            caffeineMg: 64,
          ),
        ],
        diabetesActive: true,
      );
      final controller = NutritionController(
        api: api,
        diabetesSugarGuardService: const _FakeDiabetesSugarGuardService(
          DiabetesSugarGuard(limitG: 25, source: 'default_diabetes_limit'),
        ),
        diabetesSugarAlertNotifier: (_) async {},
      );

      await controller.load();

      expect(controller.meals, hasLength(2));
      expect(controller.meals.last.isDrink, isTrue);
      expect(controller.diabetesActive, isTrue);
      expect(controller.detailBreakdown.sugarsG, closeTo(11.2, 0.001));
      expect(controller.mealPointsToday, 10);

      await controller.logMeal(
        foodId: latte.id,
        mealType: 'drink',
        quantity: 300,
        unit: 'ml',
      );

      expect(controller.meals, hasLength(3));
      expect(controller.meals.last.foodName, 'Iced Latte');
      expect(controller.meals.last.millilitersConsumed, 300);
      expect(controller.detailBreakdown.sugarsG, closeTo(26.2, 0.001));
      expect(controller.mealPointsToday, 15);
    },
  );

  test(
    'nutrition controller sends warning when sugar crosses diabetes limit',
    () async {
      final juice = FoodItem(
        id: 8,
        name: 'Mango Juice',
        itemType: 'beverage',
        category: 'Juice',
        calories100g: 60,
        protein100g: 0,
        carbs100g: 14,
        fat100g: 0,
        sugars100g: 14,
        servingLabel: 'Glass',
        servingGrams: 250,
      );
      final api = _FakeNutritionApi(
        summary: const NutritionSummary(
          targetCalories: 900,
          consumedCalories: 0,
          burnedCalories: 0,
          remainingCalories: 900,
          points: 0,
        ),
        foods: [juice],
        meals: [
          MealLog(
            id: 1,
            foodId: juice.id,
            foodName: juice.name,
            mealType: 'drink',
            quantityGrams: 150,
            quantity: 150,
            unit: 'ml',
            millilitersConsumed: 150,
            caloriesKcal: 90,
            carbsG: 21,
            sugarsG: 21,
          ),
        ],
        diabetesActive: true,
      );
      final warnings = <DiabetesSugarWarning>[];
      final controller = NutritionController(
        api: api,
        diabetesSugarGuardService: const _FakeDiabetesSugarGuardService(
          DiabetesSugarGuard(limitG: 25, source: 'default_diabetes_limit'),
        ),
        diabetesSugarAlertNotifier: (warning) async {
          warnings.add(warning);
        },
      );

      await controller.load();
      await controller.logMeal(
        foodId: juice.id,
        mealType: 'drink',
        quantity: 100,
        unit: 'ml',
      );

      expect(warnings, hasLength(1));
      expect(warnings.single.limitG, 25);
      expect(warnings.single.currentG, greaterThan(25));
      expect(warnings.single.sourceLabel, 'Mango Juice');
    },
  );
}
