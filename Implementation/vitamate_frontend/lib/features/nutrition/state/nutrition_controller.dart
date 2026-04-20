import 'package:flutter/foundation.dart';

import '../../../core/health/chronic_target_guide.dart';
import '../../../core/health/diabetes_sugar_guard_service.dart';
import '../../../core/network/network_error_mapper.dart';
import '../../../core/notifications/notifications_service.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../data/nutrition_api.dart';
import '../models/food_item.dart';
import '../models/meal_log.dart';
import '../models/nutrition_summary.dart';

typedef DiabetesSugarAlertNotifier =
    Future<void> Function(DiabetesSugarWarning warning);

class NutritionController extends ChangeNotifier {
  NutritionController({
    NutritionApi? api,
    DiabetesSugarGuardService? diabetesSugarGuardService,
    DiabetesSugarAlertNotifier? diabetesSugarAlertNotifier,
    ChronicTargetGuideService? chronicTargetGuideService,
  }) : _api = api ?? NutritionApi(),
       _diabetesSugarGuardService =
           diabetesSugarGuardService ?? const DiabetesSugarGuardService(),
       _chronicTargetGuideService =
           chronicTargetGuideService ?? const ChronicTargetGuideService(),
       _diabetesSugarAlertNotifier =
           diabetesSugarAlertNotifier ??
           ((warning) => NotificationsService.showDiabetesSugarWarning(
             limitG: warning.limitG,
             currentG: warning.currentG,
             sourceLabel: warning.sourceLabel,
           ));

  final NutritionApi _api;
  final ChronicTargetGuideService _chronicTargetGuideService;
  final DiabetesSugarGuardService _diabetesSugarGuardService;
  final DiabetesSugarAlertNotifier _diabetesSugarAlertNotifier;

  bool loading = false;
  String? error;

  NutritionSummary summary = NutritionSummary.empty();
  NutritionDetailBreakdown detailBreakdown = const NutritionDetailBreakdown();
  DiabetesSugarGuard? diabetesSugarGuard;
  List<ChronicGuideCardData> chronicNutritionGuides = const [];
  List<FoodItem> foods = [];
  List<MealLog> meals = [];
  int mealPointsToday = 0;
  int mealPointsDelta = 0;
  bool diabetesActive = false;

  Future<void> load() async {
    loading = true;
    error = null;
    chronicNutritionGuides = const [];
    notifyListeners();
    try {
      summary = await _api.getSummary();
      foods = await _api.listFoods();
      meals = await _api.getMealsToday();
      try {
        diabetesSugarGuard = await _diabetesSugarGuardService.getActiveGuard();
        diabetesActive = diabetesSugarGuard != null;
      } catch (_) {
        diabetesSugarGuard = null;
        diabetesActive = false;
      }
      try {
        chronicNutritionGuides = await _chronicTargetGuideService.loadForScope(
          ChronicGuideScope.nutrition,
        );
      } catch (_) {
        chronicNutritionGuides = const [];
      }
      detailBreakdown = _buildDetailBreakdown(meals);
      mealPointsToday = _computeMealPointsToday(
        meals: meals,
        targetCalories: summary.targetCalories,
      );
      mealPointsDelta = 0;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load nutrition data.',
      );
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
    double? quantityGrams,
    double? quantity,
    String? unit,
  }) async {
    final before = mealPointsToday;
    final beforeSugar = _currentDiabetesSugarTotal();
    final sourceLabel = _foodNameForId(foodId);
    await _api.addMeal(
      foodId: foodId,
      mealType: mealType,
      quantityGrams: quantityGrams,
      quantity: quantity,
      unit: unit,
    );
    await load();
    HealthSyncBus.instance.notifyTrackerDataChanged();
    mealPointsDelta = mealPointsToday - before;
    await _maybeNotifyDiabetesSugarExceeded(
      beforeSugar: beforeSugar,
      sourceLabel: sourceLabel,
    );
  }

  int _computeMealPointsToday({
    required List<MealLog> meals,
    required int targetCalories,
  }) {
    final sortedMeals = [...meals]..sort((a, b) => a.id.compareTo(b.id));
    double cumulativeCalories = 0;
    int points = 0;
    for (final m in sortedMeals) {
      cumulativeCalories += m.caloriesKcal;
      if (targetCalories > 0 && cumulativeCalories > targetCalories) {
        points -= 5;
      } else {
        points += 5;
      }
    }
    return points;
  }

  NutritionDetailBreakdown _buildDetailBreakdown(List<MealLog> input) {
    double caloriesKcal = 0;
    double proteinG = 0;
    double carbsG = 0;
    double fatG = 0;
    double sugarsG = 0;
    double addedSugarsG = 0;
    double fiberG = 0;
    double sodiumMg = 0;
    double saturatedFatG = 0;
    double transFatG = 0;
    double cholesterolMg = 0;
    double potassiumMg = 0;
    double caffeineMg = 0;

    for (final meal in input) {
      caloriesKcal += meal.caloriesKcal;
      proteinG += meal.proteinG;
      carbsG += meal.carbsG;
      fatG += meal.fatG;
      sugarsG += meal.sugarsG;
      addedSugarsG += meal.addedSugarsG;
      fiberG += meal.fiberG;
      sodiumMg += meal.sodiumMg;
      saturatedFatG += meal.saturatedFatG;
      transFatG += meal.transFatG;
      cholesterolMg += meal.cholesterolMg;
      potassiumMg += meal.potassiumMg;
      caffeineMg += meal.caffeineMg;
    }

    return NutritionDetailBreakdown(
      caloriesKcal: caloriesKcal,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      sugarsG: sugarsG,
      addedSugarsG: addedSugarsG,
      fiberG: fiberG,
      sodiumMg: sodiumMg,
      saturatedFatG: saturatedFatG,
      transFatG: transFatG,
      cholesterolMg: cholesterolMg,
      potassiumMg: potassiumMg,
      caffeineMg: caffeineMg,
    );
  }

  String _foodNameForId(int foodId) {
    for (final food in foods) {
      if (food.id == foodId) {
        return food.name;
      }
    }
    return 'Your latest meal';
  }

  Future<void> _maybeNotifyDiabetesSugarExceeded({
    required double beforeSugar,
    required String sourceLabel,
  }) async {
    final guard = diabetesSugarGuard;
    if (guard == null) {
      return;
    }
    final afterSugar = _currentDiabetesSugarTotal();
    if (beforeSugar <= guard.limitG && afterSugar > guard.limitG) {
      await _diabetesSugarAlertNotifier(
        DiabetesSugarWarning(
          limitG: guard.limitG,
          currentG: afterSugar,
          sourceLabel: sourceLabel,
        ),
      );
    }
  }

  double _currentDiabetesSugarTotal() {
    if (summary.addedSugarsG > 0) {
      return summary.addedSugarsG;
    }
    if (detailBreakdown.addedSugarsG > 0) {
      return detailBreakdown.addedSugarsG;
    }
    if (summary.sugarsG > 0) {
      return summary.sugarsG;
    }
    return detailBreakdown.sugarsG;
  }
}
