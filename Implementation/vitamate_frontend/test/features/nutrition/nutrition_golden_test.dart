import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/core/theme/vitamate_theme.dart';
import 'package:vitamate/features/nutrition/models/ai_meal_analysis.dart';
import 'package:vitamate/features/nutrition/models/food_item.dart';
import 'package:vitamate/features/nutrition/models/meal_log.dart';
import 'package:vitamate/features/nutrition/models/micronutrient_tracking.dart';
import 'package:vitamate/features/nutrition/models/nutrition_summary.dart';
import 'package:vitamate/features/nutrition/screens/ai_meal_review_screen.dart';
import 'package:vitamate/features/nutrition/screens/food_library_screen.dart';
import 'package:vitamate/features/nutrition/screens/log_meal_screen.dart';
import 'package:vitamate/features/nutrition/screens/meal_details_screen.dart';
import 'package:vitamate/features/nutrition/screens/meal_saved_screen.dart';
import 'package:vitamate/features/nutrition/screens/micronutrients_screen.dart';
import 'package:vitamate/features/nutrition/screens/nutrition_dashboard_screen.dart';
import 'package:vitamate/features/nutrition/screens/nutrition_details_screen.dart';
import 'package:vitamate/features/nutrition/screens/today_meals_screen.dart';
import 'package:vitamate/features/nutrition/state/ai_meal_controller.dart';
import 'package:vitamate/features/nutrition/state/nutrition_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GoldenNutritionController nutrition;

  setUp(() => nutrition = _GoldenNutritionController());

  tearDown(() => nutrition.dispose());

  testWidgets('nutrition dashboard golden', (tester) async {
    await _pumpGolden(
      tester,
      NutritionScreen(controller: nutrition, autoLoad: false),
    );
    await expectLater(
      find.byKey(_goldenSurfaceKey),
      matchesGoldenFile('goldens/nutrition/dashboard.png'),
    );
  });

  testWidgets('log meal golden', (tester) async {
    await _pumpGolden(
      tester,
      LogMealScreen(
        controller: nutrition,
        initialConsumedAt: DateTime(2026, 8, 3, 12, 30),
      ),
    );
    await expectLater(
      find.byKey(_goldenSurfaceKey),
      matchesGoldenFile('goldens/nutrition/log_meal.png'),
    );
  });

  testWidgets('food library golden', (tester) async {
    await _pumpGolden(
      tester,
      FoodLibraryScreen(controller: nutrition, selectionMode: true),
    );
    await expectLater(
      find.byKey(_goldenSurfaceKey),
      matchesGoldenFile('goldens/nutrition/food_library.png'),
    );
  });

  testWidgets('todays meals golden', (tester) async {
    await _pumpGolden(tester, TodayMealsScreen(controller: nutrition));
    await expectLater(
      find.byKey(_goldenSurfaceKey),
      matchesGoldenFile('goldens/nutrition/todays_meals.png'),
    );
  });

  testWidgets('nutrition details golden', (tester) async {
    await _pumpGolden(tester, NutritionDetailsScreen(controller: nutrition));
    await expectLater(
      find.byKey(_goldenSurfaceKey),
      matchesGoldenFile('goldens/nutrition/nutrition_details.png'),
    );
  });

  testWidgets('micronutrients golden', (tester) async {
    await _pumpGolden(tester, MicronutrientsScreen(controller: nutrition));
    await expectLater(
      find.byKey(_goldenSurfaceKey),
      matchesGoldenFile('goldens/nutrition/micronutrients.png'),
    );
  });

  testWidgets('meal details golden', (tester) async {
    await _pumpGolden(
      tester,
      MealDetailsScreen(controller: nutrition, meal: nutrition.meals.first),
    );
    await expectLater(
      find.byKey(_goldenSurfaceKey),
      matchesGoldenFile('goldens/nutrition/meal_details.png'),
    );
  });

  testWidgets('meal saved golden', (tester) async {
    await _pumpGolden(
      tester,
      MealSavedScreen(
        controller: nutrition,
        result: AiMealFinalizeResult(
          meal: nutrition.meals.first,
          summary: const <String, dynamic>{},
          points: const <String, dynamic>{},
          nutritionSummary: const <String, dynamic>{'calories_kcal': 484},
          pointsDelta: 8,
        ),
      ),
    );
    await expectLater(
      find.byKey(_goldenSurfaceKey),
      matchesGoldenFile('goldens/nutrition/meal_saved.png'),
    );
  });

  testWidgets('AI review golden', (tester) async {
    final ai = AiMealController()
      ..analysis = _analysis
      ..state = AiMealFlowStatus.reviewing;
    addTearDown(ai.dispose);
    await _pumpGolden(
      tester,
      AiMealReviewScreen(controller: ai, nutritionController: nutrition),
    );
    await expectLater(
      find.byKey(_goldenSurfaceKey),
      matchesGoldenFile('goldens/nutrition/ai_review.png'),
    );
  });

  testWidgets('nutrition compact viewport goldens', (tester) async {
    final ai = AiMealController()
      ..analysis = _analysis
      ..state = AiMealFlowStatus.reviewing;
    addTearDown(ai.dispose);
    final screens = <String, Widget>{
      'dashboard_compact': NutritionScreen(
        controller: nutrition,
        autoLoad: false,
      ),
      'log_meal_compact': LogMealScreen(
        controller: nutrition,
        initialConsumedAt: DateTime(2026, 8, 3, 12, 30),
      ),
      'food_library_compact': FoodLibraryScreen(
        controller: nutrition,
        selectionMode: true,
      ),
      'todays_meals_compact': TodayMealsScreen(controller: nutrition),
      'nutrition_details_compact': NutritionDetailsScreen(
        controller: nutrition,
      ),
      'micronutrients_compact': MicronutrientsScreen(controller: nutrition),
      'meal_details_compact': MealDetailsScreen(
        controller: nutrition,
        meal: nutrition.meals.first,
      ),
      'meal_saved_compact': MealSavedScreen(
        controller: nutrition,
        result: AiMealFinalizeResult(
          meal: nutrition.meals.first,
          summary: const <String, dynamic>{},
          points: const <String, dynamic>{},
          nutritionSummary: const <String, dynamic>{'calories_kcal': 484},
          pointsDelta: 8,
        ),
      ),
      'ai_review_compact': AiMealReviewScreen(
        controller: ai,
        nutritionController: nutrition,
      ),
    };

    for (final entry in screens.entries) {
      await _pumpGolden(tester, entry.value, size: const Size(360, 800));
      await expectLater(
        find.byKey(_goldenSurfaceKey),
        matchesGoldenFile('goldens/nutrition/${entry.key}.png'),
      );
    }
  });
}

const _goldenSurfaceKey = ValueKey<String>('nutrition-golden-surface');

Future<void> _pumpGolden(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(430, 932),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: VitaMateTheme.light(),
      home: RepaintBoundary(key: _goldenSurfaceKey, child: child),
    ),
  );
  await tester.pumpAndSettle();
}

class _GoldenNutritionController extends NutritionController {
  _GoldenNutritionController() {
    summary = const NutritionSummary(
      targetCalories: 2100,
      consumedCalories: 1180,
      burnedCalories: 180,
      remainingCalories: 920,
      points: 24,
      progressPercent: 56.2,
      status: 'on_track',
      statusReason: 'Energy intake is within today\'s target range.',
      proteinG: 68,
      carbsG: 132,
      fatG: 44,
      sugarsG: 31,
      fiberG: 19,
      sodiumMg: 1320,
      calciumMg: 620,
      ironMg: 10,
      vitaminCMg: 74,
      vitaminDMcg: 7,
    );
    meals = <MealLog>[_meal, _drink];
    foods = <FoodItem>[_food, _coffee];
    micronutrients = _micronutrients;
  }

  @override
  Future<List<FoodItem>> searchFoods({
    required String mealType,
    String query = '',
    String? category,
    int limit = 12,
    int offset = 0,
    bool includeMealSlot = true,
  }) async => foods.skip(offset).take(limit).toList(growable: false);

  @override
  Future<List<FoodItem>> getFavoriteFoods() async => <FoodItem>[_food];

  @override
  Future<List<FoodItem>> getRecentFoods({int limit = 24}) async => foods;

  @override
  Future<bool> setFoodFavorite({
    required int foodId,
    required bool isFavorite,
  }) async => isFavorite;

  @override
  Future<List<MealLog>> getMealsForDate(DateTime date) async => meals;
}

const _serving = NutritionServingOption(
  id: 7,
  name: '1 bowl',
  amount: 1,
  unit: 'serving',
  gramsEquivalent: 320,
  isDefault: true,
);

const _food = FoodItem(
  id: 11,
  name: 'Chicken rice bowl',
  category: 'Lunch',
  calories100g: 151,
  protein100g: 12.8,
  carbs100g: 18.4,
  fat100g: 3.2,
  fiber100g: 1.8,
  sodiumMg100g: 240,
  defaultServingSize: 320,
  servingLabel: '1 bowl',
  servingGrams: 320,
  servingOptions: <NutritionServingOption>[_serving],
);

const _coffee = FoodItem(
  id: 12,
  name: 'Cold brew coffee',
  itemType: 'beverage',
  category: 'Coffee',
  calories100g: 2,
  protein100g: 0.2,
  carbs100g: 0,
  fat100g: 0,
  caffeineMg: 95,
  defaultServingSize: 250,
  defaultServingUnit: 'ml',
  servingLabel: '1 cup',
  servingGrams: 250,
  containsCaffeine: true,
  isHydrationTrackable: true,
);

final _meal = MealLog(
  id: 44,
  foodId: null,
  foodName: 'Chicken rice bowl',
  isComposite: true,
  source: 'ai',
  mealType: 'lunch',
  quantityGrams: 320,
  quantity: 320,
  unit: 'g',
  consumedAt: DateTime(2026, 8, 3, 12, 30),
  caloriesKcal: 484,
  proteinG: 41,
  carbsG: 59,
  fatG: 10,
  fiberG: 5.8,
  sodiumMg: 768,
  calciumMg: 90,
  ironMg: 3.2,
);

final _drink = MealLog(
  id: 45,
  foodId: 12,
  foodName: 'Cold brew coffee',
  mealType: 'drink',
  quantityGrams: 250,
  quantity: 250,
  unit: 'ml',
  millilitersConsumed: 250,
  consumedAt: DateTime(2026, 8, 3, 9, 15),
  caloriesKcal: 5,
  caffeineMg: 95,
);

const _micronutrients = MicronutrientOverview(
  date: '2026-08-03',
  disclaimer: 'Targets are generated from the VitaMate health profile.',
  items: <MicronutrientItem>[
    MicronutrientItem(
      code: 'calcium_mg',
      name: 'Calcium',
      unit: 'mg',
      category: 'mineral',
      foodConsumed: 620,
      supplementConsumed: 0,
      totalConsumed: 620,
      targetValue: 1000,
      progressPercent: 62,
      targetSource: 'profile',
      sourceLabel: 'Daily target',
      deficiencyTracked: false,
      status: 'low',
      note: '',
    ),
    MicronutrientItem(
      code: 'iron_mg',
      name: 'Iron',
      unit: 'mg',
      category: 'mineral',
      foodConsumed: 10,
      supplementConsumed: 0,
      totalConsumed: 10,
      targetValue: 12,
      progressPercent: 83,
      targetSource: 'profile',
      sourceLabel: 'Daily target',
      deficiencyTracked: false,
      status: 'good',
      note: '',
    ),
    MicronutrientItem(
      code: 'vitamin_c_mg',
      name: 'Vitamin C',
      unit: 'mg',
      category: 'vitamin',
      foodConsumed: 74,
      supplementConsumed: 0,
      totalConsumed: 74,
      targetValue: 75,
      progressPercent: 99,
      targetSource: 'profile',
      sourceLabel: 'Daily target',
      deficiencyTracked: false,
      status: 'good',
      note: '',
    ),
    MicronutrientItem(
      code: 'vitamin_d_mcg',
      name: 'Vitamin D',
      unit: 'mcg',
      category: 'vitamin',
      foodConsumed: 7,
      supplementConsumed: 0,
      totalConsumed: 7,
      targetValue: 15,
      progressPercent: 47,
      targetSource: 'profile',
      sourceLabel: 'Daily target',
      deficiencyTracked: true,
      status: 'low',
      note: 'Discuss persistent low intake with your clinician.',
    ),
  ],
);

final _analysis = AiMealAnalysis(
  id: 'analysis-golden',
  status: 'review',
  imageUrl: '',
  selectedDishId: 'chicken_rice',
  selectedDishLabel: 'Chicken rice bowl',
  estimatedWeightGrams: 320,
  mealType: 'lunch',
  candidates: const <AiMealCandidate>[
    AiMealCandidate(
      id: 1,
      kind: 'dish',
      providerId: 'chicken_rice',
      label: 'Chicken rice bowl',
      arabicLabel: '',
      confidence: 0.88,
      mappedFoodItemId: null,
      mappedFoodName: '',
    ),
  ],
  components: const <AiMealComponent>[
    AiMealComponent(
      id: 1,
      providerId: 'chicken',
      providerLabel: 'Grilled chicken',
      mappedFoodItemId: 11,
      mappedFoodName: 'Chicken breast',
      confidence: 0.84,
      suggestedGrams: 130,
      confirmedGrams: 130,
      isIncluded: true,
      isUserConfirmed: true,
      estimatedNutrition: <String, dynamic>{
        'calories_kcal': 215,
        'protein_g': 40,
        'carbs_g': 0,
        'fat_g': 5,
      },
    ),
    AiMealComponent(
      id: 2,
      providerId: 'rice',
      providerLabel: 'Cooked rice',
      mappedFoodItemId: 11,
      mappedFoodName: 'Cooked white rice',
      confidence: 0.79,
      suggestedGrams: 190,
      confirmedGrams: 190,
      isIncluded: true,
      isUserConfirmed: true,
      estimatedNutrition: <String, dynamic>{
        'calories_kcal': 247,
        'protein_g': 5,
        'carbs_g': 54,
        'fat_g': 1,
      },
    ),
  ],
  maskPreview: const <String, dynamic>{},
  userMessage: 'Review the suggested ingredients.',
  weightStatus: 'ok',
  weightMessage: '',
  weightEstimationAttempted: true,
  failureMessage: '',
  expiresAt: DateTime(2030),
  finalizeAllowed: true,
  requiredUserInputs: const <String>[],
  modelVersions: const <String, dynamic>{'dish': 'v1'},
);
