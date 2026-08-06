import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/health/chronic_target_guide.dart';
import '../../../core/health/condition_limit_alert_service.dart';
import '../../../core/health/diabetes_sugar_guard_service.dart';
import '../../../core/network/network_error_mapper.dart';
import '../../../core/network/request_manager.dart';
import '../../../core/notification_hub/notification_hub.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../data/nutrition_api.dart';
import '../data/nutrition_repository.dart';
import '../models/food_item.dart';
import '../models/meal_log.dart';
import '../models/micronutrient_tracking.dart';
import '../models/nutrition_summary.dart';

typedef DiabetesSugarAlertNotifier =
    Future<void> Function(DiabetesSugarWarning warning);
typedef ConditionLimitAlertNotifier =
    Future<void> Function(ConditionLimitWarning warning);

class NutritionController extends ChangeNotifier {
  NutritionController({
    NutritionRepository? repository,
    NutritionApi? api,
    RequestManager? requestManager,
    DiabetesSugarGuardService? diabetesSugarGuardService,
    DiabetesSugarAlertNotifier? diabetesSugarAlertNotifier,
    ConditionLimitAlertNotifier? conditionLimitAlertNotifier,
    ChronicTargetGuideService? chronicTargetGuideService,
    ConditionLimitAlertEvaluator? conditionLimitAlertEvaluator,
  }) : _repository = repository ?? NutritionRepository(api: api),
       _requestManager = requestManager ?? RequestManager(),
       _diabetesSugarGuardService =
           diabetesSugarGuardService ?? const DiabetesSugarGuardService(),
       _chronicTargetGuideService =
           chronicTargetGuideService ?? const ChronicTargetGuideService(),
       _conditionLimitAlertEvaluator =
           conditionLimitAlertEvaluator ?? const ConditionLimitAlertEvaluator(),
       _diabetesSugarAlertNotifier =
           diabetesSugarAlertNotifier ??
           ((warning) => InAppEventPresenter.showDiabetesSugarWarning(
             limitG: warning.limitG,
             currentG: warning.currentG,
             sourceLabel: warning.sourceLabel,
           )),
       _conditionLimitAlertNotifier =
           conditionLimitAlertNotifier ?? ((warning) async {});

  final NutritionRepository _repository;
  final RequestManager _requestManager;
  final ChronicTargetGuideService _chronicTargetGuideService;
  final DiabetesSugarGuardService _diabetesSugarGuardService;
  final DiabetesSugarAlertNotifier _diabetesSugarAlertNotifier;
  final ConditionLimitAlertEvaluator _conditionLimitAlertEvaluator;
  final ConditionLimitAlertNotifier _conditionLimitAlertNotifier;

  bool loading = false;
  String? error;

  NutritionSummary summary = NutritionSummary.empty();
  NutritionDetailBreakdown detailBreakdown = const NutritionDetailBreakdown();
  MicronutrientOverview micronutrients = MicronutrientOverview.empty();
  DiabetesSugarGuard? diabetesSugarGuard;
  List<ChronicGuideCardData> chronicNutritionGuides = const [];
  List<FoodItem> foods = [];
  List<MealLog> meals = [];
  int mealPointsToday = 0;
  int mealPointsDelta = 0;
  bool diabetesActive = false;
  final Map<String, List<FoodItem>> _foodSearchCache =
      <String, List<FoodItem>>{};

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _refreshCoreNutritionState(includeFoods: true);
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
    unawaited(_refreshAncillaryNutritionState(notifyOnComplete: true));
  }

  Future<List<FoodItem>> searchFoods({
    required String mealType,
    String query = '',
    String? category,
    int limit = 12,
    int offset = 0,
    bool includeMealSlot = true,
  }) async {
    final mealSlot = includeMealSlot ? _mealSlotForSearch(mealType) : null;
    final cacheKey = _foodSearchCacheKey(
      mealType: mealType,
      query: query,
      category: category,
      mealSlot: mealSlot,
      limit: limit,
      offset: offset,
    );
    final cached = _foodSearchCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final lease = _requestManager.beginLatest('nutrition.search');
    try {
      final fetched = await _repository.autocompleteFoods(
        query: query,
        category: category,
        mealSlot: mealSlot,
        itemType: mealType == 'drink' ? 'beverage' : null,
        limit: limit,
        offset: offset,
        cancelToken: lease.cancelToken,
      );
      if (!_requestManager.isCurrent(lease)) {
        return const <FoodItem>[];
      }
      final filtered = fetched
          .where((food) {
            if (mealType == 'drink') {
              return food.isBeverage;
            }
            return !food.isBeverage;
          })
          .toList(growable: false);
      _rememberFoodSearch(cacheKey, filtered);
      return filtered;
    } finally {
      _requestManager.complete(lease);
    }
  }

  Future<List<FoodItem>> getFavoriteFoods() => _repository.getFavoriteFoods();

  Future<List<FoodItem>> getRecentFoods({int limit = 24}) =>
      _repository.getRecentFoods(limit: limit);

  Future<bool> setFoodFavorite({
    required int foodId,
    required bool isFavorite,
  }) => _repository.setFoodFavorite(foodId: foodId, isFavorite: isFavorite);

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
    await _repository.addFood(
      name: name,
      calories100g: calories100g,
      protein100g: protein100g,
      carbs100g: carbs100g,
      fat100g: fat100g,
      servingLabel: servingLabel,
      servingGrams: servingGrams,
    );
    _foodSearchCache.clear();
    await _refreshCoreNutritionState(includeFoods: true);
    notifyListeners();
    HealthSyncBus.instance.publish(const {
      HealthSyncScope.nutrition,
      HealthSyncScope.homeOverview,
      HealthSyncScope.progressHistory,
    });
    unawaited(_refreshAncillaryNutritionState(notifyOnComplete: true));
  }

  String _foodSearchCacheKey({
    required String mealType,
    required String query,
    required String? category,
    required String? mealSlot,
    required int limit,
    required int offset,
  }) {
    final scope = mealType == 'drink' ? 'drink' : 'food';
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedCategory = (category ?? '').trim().toLowerCase();
    final normalizedMealSlot = (mealSlot ?? '').trim().toLowerCase();
    return '$scope|$normalizedCategory|$normalizedMealSlot|$normalizedQuery|$offset|$limit';
  }

  String? _mealSlotForSearch(String mealType) {
    final normalized = mealType.trim().toLowerCase();
    const valid = <String>{
      'breakfast',
      'lunch',
      'dinner',
      'snack',
      'dessert',
      'drink',
    };
    return valid.contains(normalized) ? normalized : null;
  }

  void _rememberFoodSearch(String key, List<FoodItem> results) {
    const maxEntries = 24;
    _foodSearchCache[key] = List<FoodItem>.unmodifiable(results);
    if (_foodSearchCache.length <= maxEntries) {
      return;
    }
    _foodSearchCache.remove(_foodSearchCache.keys.first);
  }

  Future<MealLog> logMeal({
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
  }) async {
    final before = summary.points;
    final beforeSugar = _currentDiabetesSugarTotal();
    final beforeLimitValues = _currentConditionLimitValues();
    final sourceLabel = _foodNameForId(foodId);
    final savedMeal = await _repository.addMeal(
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
    await _refreshCoreNutritionState(includeFoods: false);
    mealPointsDelta = summary.points - before;
    notifyListeners();
    HealthSyncBus.instance.publish(const {
      HealthSyncScope.nutrition,
      HealthSyncScope.homeOverview,
      HealthSyncScope.progressHistory,
    });
    unawaited(
      _runPostMealAncillary(
        beforeSugar: beforeSugar,
        sourceLabel: sourceLabel,
        beforeValues: beforeLimitValues,
      ),
    );
    return savedMeal;
  }

  Future<List<MealLog>> getMealsForDate(DateTime date) {
    return _repository.getMeals(date: date);
  }

  Future<MealLog> updateMeal({
    required int mealId,
    String? mealType,
    double? quantityGrams,
    DateTime? consumedAt,
    String? notes,
  }) async {
    final updated = await _repository.updateMeal(
      mealId: mealId,
      mealType: mealType,
      quantityGrams: quantityGrams,
      consumedAt: consumedAt,
      notes: notes,
    );
    await _refreshCoreNutritionState(includeFoods: false);
    notifyListeners();
    HealthSyncBus.instance.publish(const {
      HealthSyncScope.nutrition,
      HealthSyncScope.homeOverview,
      HealthSyncScope.progressHistory,
    });
    return updated;
  }

  Future<void> deleteMeal(int mealId) async {
    await _repository.deleteMeal(mealId);
    await _refreshCoreNutritionState(includeFoods: false);
    notifyListeners();
    HealthSyncBus.instance.publish(const {
      HealthSyncScope.nutrition,
      HealthSyncScope.homeOverview,
      HealthSyncScope.progressHistory,
    });
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
    double calciumMg = 0;
    double ironMg = 0;
    double magnesiumMg = 0;
    double zincMg = 0;
    double phosphorusMg = 0;
    double vitaminAMcg = 0;
    double vitaminCMg = 0;
    double vitaminDMcg = 0;
    double vitaminEMg = 0;
    double vitaminKMcg = 0;
    double vitaminB1Mg = 0;
    double vitaminB2Mg = 0;
    double vitaminB3Mg = 0;
    double vitaminB6Mg = 0;
    double vitaminB12Mcg = 0;
    double folateMcg = 0;
    double monounsaturatedFatG = 0;
    double polyunsaturatedFatG = 0;
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
      calciumMg += meal.calciumMg;
      ironMg += meal.ironMg;
      magnesiumMg += meal.magnesiumMg;
      zincMg += meal.zincMg;
      phosphorusMg += meal.phosphorusMg;
      vitaminAMcg += meal.vitaminAMcg;
      vitaminCMg += meal.vitaminCMg;
      vitaminDMcg += meal.vitaminDMcg;
      vitaminEMg += meal.vitaminEMg;
      vitaminKMcg += meal.vitaminKMcg;
      vitaminB1Mg += meal.vitaminB1Mg;
      vitaminB2Mg += meal.vitaminB2Mg;
      vitaminB3Mg += meal.vitaminB3Mg;
      vitaminB6Mg += meal.vitaminB6Mg;
      vitaminB12Mcg += meal.vitaminB12Mcg;
      folateMcg += meal.folateMcg;
      monounsaturatedFatG += meal.monounsaturatedFatG;
      polyunsaturatedFatG += meal.polyunsaturatedFatG;
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
      calciumMg: calciumMg,
      ironMg: ironMg,
      magnesiumMg: magnesiumMg,
      zincMg: zincMg,
      phosphorusMg: phosphorusMg,
      vitaminAMcg: vitaminAMcg,
      vitaminCMg: vitaminCMg,
      vitaminDMcg: vitaminDMcg,
      vitaminEMg: vitaminEMg,
      vitaminKMcg: vitaminKMcg,
      vitaminB1Mg: vitaminB1Mg,
      vitaminB2Mg: vitaminB2Mg,
      vitaminB3Mg: vitaminB3Mg,
      vitaminB6Mg: vitaminB6Mg,
      vitaminB12Mcg: vitaminB12Mcg,
      folateMcg: folateMcg,
      monounsaturatedFatG: monounsaturatedFatG,
      polyunsaturatedFatG: polyunsaturatedFatG,
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

  Future<void> _refreshCoreNutritionState({required bool includeFoods}) async {
    if (includeFoods || foods.isEmpty) {
      final results = await Future.wait<Object>([
        _repository.getSummary(),
        _repository.getMealsToday(),
        _repository.autocompleteFoods(limit: 16),
        _repository.getMicronutrients(),
      ]);
      summary = results[0] as NutritionSummary;
      meals = results[1] as List<MealLog>;
      foods = results[2] as List<FoodItem>;
      micronutrients = results[3] as MicronutrientOverview;
    } else {
      final results = await Future.wait<Object>([
        _repository.getSummary(),
        _repository.getMealsToday(),
        _repository.getMicronutrients(),
      ]);
      summary = results[0] as NutritionSummary;
      meals = results[1] as List<MealLog>;
      micronutrients = results[2] as MicronutrientOverview;
    }
    detailBreakdown = _buildDetailBreakdown(meals);
    mealPointsToday = summary.points;
  }

  Future<void> _refreshAncillaryNutritionState({
    bool notifyOnComplete = false,
  }) async {
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
    if (notifyOnComplete) {
      notifyListeners();
    }
  }

  Future<void> _runPostMealAncillary({
    required double beforeSugar,
    required String sourceLabel,
    required Map<String, double> beforeValues,
  }) async {
    await _refreshAncillaryNutritionState(notifyOnComplete: true);
    await _maybeNotifyDiabetesSugarExceeded(
      beforeSugar: beforeSugar,
      sourceLabel: sourceLabel,
    );
    await _maybeNotifyConditionLimitsExceeded(
      beforeValues: beforeValues,
      sourceLabel: sourceLabel,
    );
  }

  Future<void> _maybeNotifyConditionLimitsExceeded({
    required Map<String, double> beforeValues,
    required String sourceLabel,
  }) async {
    final excluded = diabetesSugarGuard == null
        ? const <String>{}
        : const <String>{'added_sugars_g', 'sugars_g'};
    final warnings = _conditionLimitAlertEvaluator.evaluate(
      guides: chronicNutritionGuides,
      beforeValues: beforeValues,
      afterValues: _currentConditionLimitValues(),
      sourceLabel: sourceLabel,
      excludedMetricKeys: excluded,
    );
    for (final warning in warnings) {
      await _conditionLimitAlertNotifier(warning);
    }
  }

  Map<String, double> _currentConditionLimitValues() {
    final calories = detailBreakdown.caloriesKcal > 0
        ? detailBreakdown.caloriesKcal
        : summary.consumedCalories.toDouble();
    final saturatedFatPct = calories <= 0
        ? 0.0
        : (detailBreakdown.saturatedFatG * 9 / calories) * 100;
    final sugars = detailBreakdown.sugarsG > 0
        ? detailBreakdown.sugarsG
        : summary.sugarsG;
    final addedSugars = detailBreakdown.addedSugarsG > 0
        ? detailBreakdown.addedSugarsG
        : summary.addedSugarsG;
    return {
      'added_sugars_g': addedSugars > 0 ? addedSugars : sugars,
      'sugars_g': sugars,
      'sodium_mg': detailBreakdown.sodiumMg > 0
          ? detailBreakdown.sodiumMg
          : summary.sodiumMg,
      'saturated_fat_pct_kcal': saturatedFatPct,
      'trans_fat_g': detailBreakdown.transFatG,
      'cholesterol_mg': detailBreakdown.cholesterolMg,
    };
  }

  Future<void> refreshMicronutrients() async {
    micronutrients = await _repository.getMicronutrients();
    notifyListeners();
  }

  Future<void> saveMicronutrientTarget({
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
  }) async {
    micronutrients = await _repository.upsertMicronutrientTarget(
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
    await _refreshAndVerifyMicronutrientSave(
      nutrientCode: nutrientCode,
      expectTarget:
          minValue != null ||
          targetValue != null ||
          maxValue != null ||
          labValue != null ||
          clinicianRecommendedValue != null,
      expectMedication: createMedicationPlan,
    );
    try {
      await _refreshAncillaryNutritionState(notifyOnComplete: false);
    } catch (_) {
      // The target is already saved. Keep the returned micronutrient overview
      // visible even if a secondary refresh fails.
    }
    notifyListeners();
    HealthSyncBus.instance.publish(const {
      HealthSyncScope.nutrition,
      HealthSyncScope.medication,
      HealthSyncScope.homeOverview,
      HealthSyncScope.progressHistory,
    });
  }

  Future<void> _refreshAndVerifyMicronutrientSave({
    required String nutrientCode,
    required bool expectTarget,
    required bool expectMedication,
  }) async {
    micronutrients = await _repository.getMicronutrients();
    final item = _micronutrientByCode(nutrientCode);
    if (expectTarget && item?.deficiencyTracked != true) {
      throw StateError(
        'The target was not saved by the backend. Restart the backend and try again.',
      );
    }
    if (expectMedication && item?.linkedMedication == null) {
      throw StateError(
        'The supplement target was saved, but no medication plan was linked. Restart the backend and try again.',
      );
    }
  }

  MicronutrientItem? _micronutrientByCode(String code) {
    for (final item in micronutrients.items) {
      if (item.code == code) {
        return item;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _requestManager.cancelAll();
    super.dispose();
  }
}
