import 'package:flutter/foundation.dart';

import '../data/nutrition_api.dart';
import '../models/food_item.dart';
import '../models/nutrition_summary.dart';
import '../models/meal_log.dart';

class NutritionController extends ChangeNotifier {
  NutritionController({NutritionApi? api}) : _api = api ?? NutritionApi();

  final NutritionApi _api;

  bool loading = false;
  String? error;

  NutritionSummary summary = NutritionSummary.empty();
  List<FoodItem> foods = [];
  List<MealLog> meals = [];
  int mealPointsToday = 0;
  int mealPointsDelta = 0;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      summary = await _api.getSummary();
      foods = await _api.listFoods();
      meals = await _api.getMealsToday();
      mealPointsToday = _computeMealPointsToday(
        foods: foods,
        meals: meals,
        targetCalories: summary.targetCalories,
      );
      mealPointsDelta = 0;
    } catch (e) {
      error = 'Failed to load nutrition data';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> addFood(FoodItem item) async {
    foods.add(item);
    notifyListeners();
  }

  Future<void> createFood({
    required String name,
    required int calories100g,
    required double protein100g,
    required double carbs100g,
    required double fat100g,
    required String servingLabel,
    required int servingGrams,
  }) async {
    await _api.addFood(
      name: name,
      calories100g: calories100g,
      protein100g: protein100g,
      carbs100g: carbs100g,
      fat100g: fat100g,
      servingLabel: servingLabel,
      servingGrams: servingGrams,
    );
    await load();
  }

  Future<void> logMeal({
    required int foodId,
    required String mealType,
    required double quantityGrams,
  }) async {
    final before = mealPointsToday;
    await _api.addMeal(foodId: foodId, mealType: mealType, quantityGrams: quantityGrams);
    await load();
    mealPointsDelta = mealPointsToday - before;
  }

  int _computeMealPointsToday({
    required List<FoodItem> foods,
    required List<MealLog> meals,
    required int targetCalories,
  }) {
    // Build a lookup for calories/100g
    final map = {for (final f in foods) f.id: f};
    // Sort meals by id to simulate chronological order
    final sortedMeals = [...meals]..sort((a, b) => a.id.compareTo(b.id));
    double cumulativeCalories = 0;
    int points = 0;
    for (final m in sortedMeals) {
      final food = map[m.foodId];
      if (food == null) continue;
      final mealCalories = (food.calories100g / 100.0) * m.quantityGrams;
      cumulativeCalories += mealCalories;
      if (targetCalories > 0 && cumulativeCalories > targetCalories) {
        points -= 5;
      } else {
        points += 5;
      }
    }
    return points;
  }
}
