import 'package:flutter/foundation.dart';

import '../../../core/network/network_error_mapper.dart';
import '../data/ai_meal_api.dart';
import '../models/ai_meal_analysis.dart';
import '../models/food_item.dart';

enum AiMealFlowStatus {
  idle,
  capturing,
  uploading,
  analyzing,
  reviewing,
  finalizing,
  success,
  failure,
  expired,
}

class AiMealController extends ChangeNotifier {
  AiMealController({AiMealApi? api}) : _api = api ?? AiMealApi();

  final AiMealApi _api;
  AiMealFlowStatus state = AiMealFlowStatus.idle;
  AiMealAnalysis? analysis;
  AiMealFinalizeResult? result;
  String? error;
  String? _idempotencyKey;
  String? _analysisKey;
  bool _dishChoiceConfirmed = false;
  int _temporaryComponentId = -1;
  final Map<int, FoodItem> _mappedFoodCache = <int, FoodItem>{};

  bool get busy =>
      state == AiMealFlowStatus.uploading ||
      state == AiMealFlowStatus.analyzing ||
      state == AiMealFlowStatus.finalizing;

  bool get requiresDishChoice =>
      (analysis?.selectedDishCandidate?.confidence ?? 1) < 0.6;

  bool get dishChoiceConfirmed => !requiresDishChoice || _dishChoiceConfirmed;

  void beginCapture() {
    state = AiMealFlowStatus.capturing;
    error = null;
    _analysisKey = null;
    _idempotencyKey = null;
    _dishChoiceConfirmed = false;
    notifyListeners();
  }

  Future<bool> analyze(String imagePath) async {
    state = AiMealFlowStatus.uploading;
    error = null;
    result = null;
    _idempotencyKey = null;
    _analysisKey ??= 'capture-${DateTime.now().microsecondsSinceEpoch}';
    notifyListeners();
    try {
      state = AiMealFlowStatus.analyzing;
      notifyListeners();
      analysis = await _api.analyze(
        imagePath: imagePath,
        idempotencyKey: _analysisKey!,
      );
      state = analysis!.status == 'expired'
          ? AiMealFlowStatus.expired
          : AiMealFlowStatus.reviewing;
      notifyListeners();
      return true;
    } catch (exception) {
      error = NetworkErrorMapper.toMessage(
        exception,
        fallback: 'Meal analysis failed. Retake the photo and try again.',
      );
      state = AiMealFlowStatus.failure;
      notifyListeners();
      return false;
    }
  }

  void updateComponentGrams(int componentId, double grams) {
    final current = analysis;
    if (current == null || grams <= 0) return;
    analysis = _copyAnalysis(
      current,
      components: current.components
          .map((item) {
            if (item.id != componentId) return item;
            final previousGrams =
                item.confirmedGrams ?? item.suggestedGrams ?? 0;
            final cachedFood = _mappedFoodCache[item.id];
            final mappedFacts = item.mappedFoodNutrition100g;
            return item.copyWith(
              confirmedGrams: grams,
              estimatedNutrition: _updatedNutrition(
                item,
                cachedFood: cachedFood,
                mappedFacts: mappedFacts,
                previousGrams: previousGrams,
                nextGrams: grams,
              ),
            );
          })
          .toList(growable: false),
    );
    notifyListeners();
  }

  void updateTotalGrams(double grams) {
    final current = analysis;
    if (current == null || grams <= 0) return;
    final included = current.components
        .where((item) => item.isIncluded)
        .toList(growable: false);
    if (included.isEmpty) return;

    final basis = included
        .map((item) => _weightDistributionBasis(item))
        .toList(growable: false);
    final distributed = _distributeGrams(grams, basis);
    var includedIndex = 0;
    analysis = _copyAnalysis(
      current,
      estimatedWeightGrams: grams,
      components: current.components
          .map((item) {
            if (!item.isIncluded) return item;
            final nextGrams = distributed[includedIndex++];
            final previousGrams =
                item.confirmedGrams ?? item.suggestedGrams ?? 0;
            final cachedFood = _mappedFoodCache[item.id];
            final mappedFacts = item.mappedFoodNutrition100g;
            return item.copyWith(
              confirmedGrams: nextGrams,
              estimatedNutrition: _updatedNutrition(
                item,
                cachedFood: cachedFood,
                mappedFacts: mappedFacts,
                previousGrams: previousGrams,
                nextGrams: nextGrams,
              ),
            );
          })
          .toList(growable: false),
    );
    notifyListeners();
  }

  void mapComponent(int componentId, FoodItem food) {
    final current = analysis;
    if (current == null) return;
    _mappedFoodCache[componentId] = food;
    analysis = _copyAnalysis(
      current,
      components: current.components
          .map((item) {
            if (item.id != componentId) return item;
            final grams = item.confirmedGrams ?? item.suggestedGrams;
            return item.copyWith(
              mappedFoodItemId: food.id,
              mappedFoodName: food.name,
              mappedFoodNutrition100g: _nutritionFactsForFood(food),
              estimatedNutrition: grams != null && grams > 0
                  ? _nutritionForFood(food, grams)
                  : const <String, dynamic>{},
            );
          })
          .toList(growable: false),
    );
    notifyListeners();
  }

  void selectDish(AiMealCandidate candidate) {
    final current = analysis;
    if (current == null || candidate.kind != 'dish') return;
    analysis = _copyAnalysis(
      current,
      components: current.components,
      selectedDishId: candidate.providerId,
      selectedDishLabel: candidate.label,
    );
    _dishChoiceConfirmed = true;
    notifyListeners();
  }

  void addComponent(FoodItem food) {
    final current = analysis;
    if (current == null) return;
    final component = AiMealComponent(
      id: _temporaryComponentId--,
      providerId: '',
      providerLabel: food.name,
      mappedFoodItemId: food.id,
      mappedFoodName: food.name,
      mappedFoodNutrition100g: _nutritionFactsForFood(food),
      confidence: null,
      suggestedGrams: null,
      confirmedGrams: null,
      isIncluded: true,
      isUserConfirmed: false,
      estimatedNutrition: const <String, dynamic>{},
    );
    _mappedFoodCache[component.id] = food;
    analysis = _copyAnalysis(
      current,
      components: <AiMealComponent>[...current.components, component],
    );
    notifyListeners();
  }

  void removeComponent(int componentId) {
    final current = analysis;
    if (current == null) return;
    analysis = _copyAnalysis(
      current,
      components: current.components
          .where((item) => item.id != componentId)
          .toList(growable: false),
    );
    _mappedFoodCache.remove(componentId);
    notifyListeners();
  }

  void toggleComponent(int componentId, bool included) {
    final current = analysis;
    if (current == null) return;
    analysis = _copyAnalysis(
      current,
      components: current.components
          .map(
            (item) => item.id == componentId
                ? item.copyWith(isIncluded: included)
                : item,
          )
          .toList(growable: false),
    );
    notifyListeners();
  }

  Future<bool> confirm({
    required String dishLabel,
    required String dishId,
    required String mealType,
    required DateTime consumedAt,
  }) async {
    final current = analysis;
    if (current == null || !current.canConfirm || !dishChoiceConfirmed) {
      return false;
    }
    state = AiMealFlowStatus.finalizing;
    error = null;
    notifyListeners();
    try {
      analysis = await _api.confirm(
        analysis: current,
        selectedDishLabel: dishLabel,
        selectedDishId: dishId,
        mealType: mealType,
        consumedAt: consumedAt,
        components: current.components
            .where((item) => item.isIncluded)
            .toList(growable: false),
      );
      state = analysis!.status == 'expired'
          ? AiMealFlowStatus.expired
          : AiMealFlowStatus.reviewing;
      notifyListeners();
      return true;
    } catch (exception) {
      error = NetworkErrorMapper.toMessage(
        exception,
        fallback: 'Could not confirm the meal components.',
      );
      state = AiMealFlowStatus.failure;
      notifyListeners();
      return false;
    }
  }

  Future<bool> finalize() async {
    final current = analysis;
    if (current == null || current.status != 'ready_to_finalize') return false;
    state = AiMealFlowStatus.finalizing;
    error = null;
    _idempotencyKey ??=
        'mobile-${current.id}-${DateTime.now().microsecondsSinceEpoch}';
    notifyListeners();
    try {
      result = await _api.finalize(
        analysisId: current.id,
        idempotencyKey: _idempotencyKey!,
      );
      if (result == null || result!.meal.id <= 0) {
        throw const FormatException('The backend did not return a saved meal.');
      }
      state = AiMealFlowStatus.success;
      notifyListeners();
      return true;
    } catch (exception) {
      error = NetworkErrorMapper.toMessage(
        exception,
        fallback: 'Could not save the analyzed meal.',
      );
      state = AiMealFlowStatus.failure;
      notifyListeners();
      return false;
    }
  }

  AiMealAnalysis _copyAnalysis(
    AiMealAnalysis value, {
    required List<AiMealComponent> components,
    double? estimatedWeightGrams,
    String? selectedDishId,
    String? selectedDishLabel,
  }) => AiMealAnalysis(
    id: value.id,
    status: value.status,
    imageUrl: value.imageUrl,
    selectedDishId: selectedDishId ?? value.selectedDishId,
    selectedDishLabel: selectedDishLabel ?? value.selectedDishLabel,
    estimatedWeightGrams: estimatedWeightGrams ?? value.estimatedWeightGrams,
    mealType: value.mealType,
    candidates: value.candidates,
    components: components,
    maskPreview: value.maskPreview,
    userMessage: value.userMessage,
    weightStatus: value.weightStatus,
    weightMessage: value.weightMessage,
    weightEstimationAttempted: value.weightEstimationAttempted,
    failureMessage: value.failureMessage,
    expiresAt: value.expiresAt,
    finalizeAllowed: value.finalizeAllowed,
    requiredUserInputs: value.requiredUserInputs,
    modelVersions: value.modelVersions,
  );

  static Map<String, dynamic> _nutritionForFood(FoodItem food, double grams) {
    return _nutritionForFacts(_nutritionFactsForFood(food), grams);
  }

  static Map<String, dynamic> _nutritionFactsForFood(FoodItem food) =>
      <String, dynamic>{
        'calories_kcal': food.calories100g,
        'protein_g': food.protein100g,
        'carbs_g': food.carbs100g,
        'fat_g': food.fat100g,
      };

  static Map<String, dynamic> _nutritionForFacts(
    Map<String, dynamic> facts,
    double grams,
  ) {
    if (facts.isEmpty) return const <String, dynamic>{};
    final factor = grams / 100;
    return <String, dynamic>{
      'calories_kcal': _factValue(facts, 'calories_kcal') * factor,
      'protein_g': _factValue(facts, 'protein_g') * factor,
      'carbs_g': _factValue(facts, 'carbs_g') * factor,
      'fat_g': _factValue(facts, 'fat_g') * factor,
    };
  }

  static Map<String, dynamic> _updatedNutrition(
    AiMealComponent item, {
    required FoodItem? cachedFood,
    required Map<String, dynamic> mappedFacts,
    required double previousGrams,
    required double nextGrams,
  }) {
    if (previousGrams > 0 && item.estimatedNutrition.isNotEmpty) {
      return _scaleNutrition(
        item.estimatedNutrition,
        previousGrams: previousGrams,
        nextGrams: nextGrams,
      );
    }
    if (cachedFood != null) return _nutritionForFood(cachedFood, nextGrams);
    return _nutritionForFacts(mappedFacts, nextGrams);
  }

  static double _factValue(Map<String, dynamic> facts, String key) {
    final value = facts[key];
    return value is num ? value.toDouble() : 0;
  }

  static Map<String, dynamic> _scaleNutrition(
    Map<String, dynamic> nutrition, {
    required double previousGrams,
    required double nextGrams,
  }) {
    if (nutrition.isEmpty || previousGrams <= 0) return nutrition;
    final factor = nextGrams / previousGrams;
    return nutrition.map(
      (key, value) => MapEntry<String, dynamic>(
        key,
        value is num ? value.toDouble() * factor : value,
      ),
    );
  }

  static double _weightDistributionBasis(AiMealComponent item) {
    final percentage = item.suggestedPercentage;
    if (percentage != null && percentage > 0) return percentage;
    final grams = item.confirmedGrams ?? item.suggestedGrams;
    return grams != null && grams > 0 ? grams : 1.0;
  }

  static List<double> _distributeGrams(double totalGrams, List<double> basis) {
    final positiveBasis = basis
        .map((value) => value > 0 ? value : 1.0)
        .toList();
    final totalBasis = positiveBasis.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    var remaining = double.parse(totalGrams.toStringAsFixed(1));
    final values = <double>[];
    for (var index = 0; index < positiveBasis.length; index += 1) {
      final value = index == positiveBasis.length - 1
          ? remaining
          : double.parse(
              (totalGrams * positiveBasis[index] / totalBasis).toStringAsFixed(
                1,
              ),
            );
      values.add(value <= 0 ? 0.1 : value);
      remaining = double.parse((remaining - value).toStringAsFixed(1));
    }
    return values;
  }
}
