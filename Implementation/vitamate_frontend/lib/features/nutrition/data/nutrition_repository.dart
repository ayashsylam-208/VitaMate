import 'package:dio/dio.dart';

import '../models/food_item.dart';
import '../models/meal_log.dart';
import '../models/micronutrient_tracking.dart';
import '../models/nutrition_summary.dart';
import 'nutrition_api.dart';

class NutritionRepository {
  NutritionRepository({NutritionApi? api}) : _api = api ?? NutritionApi();

  final NutritionApi _api;

  Future<NutritionSummary> getSummary({CancelToken? cancelToken}) {
    return _api.getSummary(cancelToken: cancelToken);
  }

  Future<MicronutrientOverview> getMicronutrients({CancelToken? cancelToken}) {
    return _api.getMicronutrients(cancelToken: cancelToken);
  }

  Future<MicronutrientOverview> upsertMicronutrientTarget({
    required String nutrientCode,
    double? minValue,
    double? targetValue,
    double? maxValue,
    String note = '',
    String labTestName = '',
    double? labValue,
    String labUnit = '',
    double? labReferenceMin,
    double? labReferenceMax,
    String labTestDate = '',
    double? clinicianRecommendedValue,
    String currentMedicationName = '',
    String currentMedicationDose = '',
    bool createMedicationPlan = false,
    String supplementName = '',
    double? supplementAmount,
    String supplementUnit = '',
    String scheduleTime = '09:00',
  }) {
    return _api.upsertMicronutrientTarget(
      nutrientCode: nutrientCode,
      minValue: minValue,
      targetValue: targetValue,
      maxValue: maxValue,
      note: note,
      labTestName: labTestName,
      labValue: labValue,
      labUnit: labUnit,
      labReferenceMin: labReferenceMin,
      labReferenceMax: labReferenceMax,
      labTestDate: labTestDate,
      clinicianRecommendedValue: clinicianRecommendedValue,
      currentMedicationName: currentMedicationName,
      currentMedicationDose: currentMedicationDose,
      createMedicationPlan: createMedicationPlan,
      supplementName: supplementName,
      supplementAmount: supplementAmount,
      supplementUnit: supplementUnit,
      scheduleTime: scheduleTime,
    );
  }

  Future<List<FoodItem>> autocompleteFoods({
    String? itemType,
    String? query,
    String? category,
    String? mealSlot,
    bool? containsCaffeine,
    bool? isHydrationTrackable,
    int limit = 12,
    int offset = 0,
    CancelToken? cancelToken,
  }) {
    return _api.autocompleteFoods(
      itemType: itemType,
      query: query,
      category: category,
      mealSlot: mealSlot,
      containsCaffeine: containsCaffeine,
      isHydrationTrackable: isHydrationTrackable,
      limit: limit,
      offset: offset,
      cancelToken: cancelToken,
    );
  }

  Future<List<MealLog>> getMealsToday() => _api.getMealsToday();

  Future<List<FoodItem>> getFavoriteFoods() => _api.getFavoriteFoods();

  Future<List<FoodItem>> getRecentFoods({int limit = 24}) =>
      _api.getRecentFoods(limit: limit);

  Future<bool> setFoodFavorite({
    required int foodId,
    required bool isFavorite,
  }) => _api.setFoodFavorite(foodId: foodId, isFavorite: isFavorite);

  Future<List<MealLog>> getMeals({DateTime? date}) => _api.getMeals(date: date);

  Future<MealLog> updateMeal({
    required int mealId,
    String? mealType,
    double? quantityGrams,
    DateTime? consumedAt,
    String? notes,
  }) => _api.updateMeal(
    mealId: mealId,
    mealType: mealType,
    quantityGrams: quantityGrams,
    consumedAt: consumedAt,
    notes: notes,
  );

  Future<void> deleteMeal(int mealId) => _api.deleteMeal(mealId);

  Future<void> addFood({
    required String name,
    required int calories100g,
    required double protein100g,
    required double carbs100g,
    required double fat100g,
    required String servingLabel,
    required int servingGrams,
  }) {
    return _api.addFood(
      name: name,
      calories100g: calories100g,
      protein100g: protein100g,
      carbs100g: carbs100g,
      fat100g: fat100g,
      servingLabel: servingLabel,
      servingGrams: servingGrams,
    );
  }

  Future<MealLog> addMeal({
    required int foodId,
    required String mealType,
    double? quantityGrams,
    double? quantity,
    String? unit,
    int? servingOptionId,
    String? servingLabelSnapshot,
    double? servingGramsEquivalent,
    double? servingMillilitersEquivalent,
    DateTime? consumedAt,
    bool isFastFood = false,
  }) {
    return _api.addMeal(
      foodId: foodId,
      mealType: mealType,
      quantityGrams: quantityGrams,
      quantity: quantity,
      unit: unit,
      servingOptionId: servingOptionId,
      servingLabelSnapshot: servingLabelSnapshot,
      servingGramsEquivalent: servingGramsEquivalent,
      servingMillilitersEquivalent: servingMillilitersEquivalent,
      consumedAt: consumedAt,
      isFastFood: isFastFood,
    );
  }
}
