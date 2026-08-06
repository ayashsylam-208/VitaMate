import 'meal_log.dart';

class AiMealCandidate {
  const AiMealCandidate({
    required this.id,
    required this.kind,
    required this.providerId,
    required this.label,
    required this.arabicLabel,
    required this.confidence,
    required this.mappedFoodItemId,
    required this.mappedFoodName,
  });

  final int id;
  final String kind;
  final String providerId;
  final String label;
  final String arabicLabel;
  final double? confidence;
  final int? mappedFoodItemId;
  final String mappedFoodName;

  factory AiMealCandidate.fromJson(Map<String, dynamic> json) =>
      AiMealCandidate(
        id: _int(json['id']),
        kind: (json['kind'] ?? '').toString(),
        providerId: (json['provider_id'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        arabicLabel: (json['display_name_ar'] ?? '').toString(),
        confidence: _nullableDouble(json['confidence_score']),
        mappedFoodItemId: _nullableInt(json['mapped_food_item']),
        mappedFoodName: (json['mapped_food_name'] ?? '').toString(),
      );
}

class AiMealComponent {
  const AiMealComponent({
    required this.id,
    required this.providerId,
    required this.providerLabel,
    required this.mappedFoodItemId,
    required this.mappedFoodName,
    this.mappedFoodNutrition100g = const <String, dynamic>{},
    required this.confidence,
    this.suggestedPercentage,
    required this.suggestedGrams,
    required this.confirmedGrams,
    required this.isIncluded,
    required this.isUserConfirmed,
    this.estimatedNutrition = const <String, dynamic>{},
  });

  final int id;
  final String providerId;
  final String providerLabel;
  final int? mappedFoodItemId;
  final String mappedFoodName;
  final Map<String, dynamic> mappedFoodNutrition100g;
  final double? confidence;
  final double? suggestedPercentage;
  final double? suggestedGrams;
  final double? confirmedGrams;
  final bool isIncluded;
  final bool isUserConfirmed;
  final Map<String, dynamic> estimatedNutrition;

  bool get ready =>
      !isIncluded || (mappedFoodItemId != null && (confirmedGrams ?? 0) > 0);

  AiMealComponent copyWith({
    int? mappedFoodItemId,
    String? mappedFoodName,
    Map<String, dynamic>? mappedFoodNutrition100g,
    double? confirmedGrams,
    bool? isIncluded,
    Map<String, dynamic>? estimatedNutrition,
  }) => AiMealComponent(
    id: id,
    providerId: providerId,
    providerLabel: providerLabel,
    mappedFoodItemId: mappedFoodItemId ?? this.mappedFoodItemId,
    mappedFoodName: mappedFoodName ?? this.mappedFoodName,
    mappedFoodNutrition100g:
        mappedFoodNutrition100g ?? this.mappedFoodNutrition100g,
    confidence: confidence,
    suggestedPercentage: suggestedPercentage,
    suggestedGrams: suggestedGrams,
    confirmedGrams: confirmedGrams ?? this.confirmedGrams,
    isIncluded: isIncluded ?? this.isIncluded,
    isUserConfirmed: isUserConfirmed,
    estimatedNutrition: estimatedNutrition ?? this.estimatedNutrition,
  );

  factory AiMealComponent.fromJson(Map<String, dynamic> json) =>
      AiMealComponent(
        id: _int(json['id']),
        providerId: (json['provider_id'] ?? '').toString(),
        providerLabel: (json['provider_label'] ?? '').toString(),
        mappedFoodItemId: _nullableInt(json['mapped_food_item']),
        mappedFoodName: (json['mapped_food_name'] ?? '').toString(),
        mappedFoodNutrition100g: json['mapped_food_nutrition_100g'] is Map
            ? Map<String, dynamic>.from(
                json['mapped_food_nutrition_100g'] as Map,
              )
            : const <String, dynamic>{},
        confidence: _nullableDouble(json['confidence_score']),
        suggestedPercentage: _nullableDouble(json['suggested_percentage']),
        suggestedGrams: _nullableDouble(json['suggested_grams']),
        confirmedGrams: _nullableDouble(json['confirmed_grams']),
        isIncluded: json['is_included'] != false,
        isUserConfirmed: json['is_user_confirmed'] == true,
        estimatedNutrition: json['estimated_nutrition'] is Map
            ? Map<String, dynamic>.from(json['estimated_nutrition'] as Map)
            : const <String, dynamic>{},
      );
}

class AiMealAnalysis {
  const AiMealAnalysis({
    required this.id,
    required this.status,
    required this.imageUrl,
    required this.selectedDishId,
    required this.selectedDishLabel,
    required this.estimatedWeightGrams,
    required this.mealType,
    required this.candidates,
    required this.components,
    required this.maskPreview,
    required this.userMessage,
    required this.weightStatus,
    required this.weightMessage,
    required this.weightEstimationAttempted,
    required this.failureMessage,
    required this.expiresAt,
    required this.finalizeAllowed,
    required this.requiredUserInputs,
    required this.modelVersions,
  });

  final String id;
  final String status;
  final String imageUrl;
  final String selectedDishId;
  final String selectedDishLabel;
  final double? estimatedWeightGrams;
  final String mealType;
  final List<AiMealCandidate> candidates;
  final List<AiMealComponent> components;
  final Map<String, dynamic> maskPreview;
  final String userMessage;
  final String weightStatus;
  final String weightMessage;
  final bool weightEstimationAttempted;
  final String failureMessage;
  final DateTime? expiresAt;
  final bool finalizeAllowed;
  final List<String> requiredUserInputs;
  final Map<String, dynamic> modelVersions;

  bool get canConfirm =>
      status != 'expired' &&
      components.any((item) => item.isIncluded) &&
      components.every((item) => item.ready);

  double get includedTotalGrams => components
      .where((item) => item.isIncluded)
      .fold<double>(
        0,
        (sum, item) => sum + (item.confirmedGrams ?? item.suggestedGrams ?? 0),
      );

  bool get hasAutomaticWeightEstimate =>
      weightEstimationAttempted && (estimatedWeightGrams ?? 0) > 0;

  bool get needsManualWeights => components.any(
    (item) =>
        item.isIncluded &&
        (item.confirmedGrams ?? item.suggestedGrams ?? 0) <= 0,
  );

  AiMealCandidate? get selectedDishCandidate {
    for (final candidate in candidates) {
      if (candidate.kind == 'dish' && candidate.providerId == selectedDishId) {
        return candidate;
      }
    }
    return null;
  }

  factory AiMealAnalysis.fromJson(Map<String, dynamic> json) => AiMealAnalysis(
    id: (json['id'] ?? '').toString(),
    status: (json['status'] ?? '').toString(),
    imageUrl: (json['image_url'] ?? '').toString(),
    selectedDishId: (json['selected_dish_id'] ?? '').toString(),
    selectedDishLabel: (json['selected_dish_label'] ?? '').toString(),
    estimatedWeightGrams: _nullableDouble(json['estimated_weight_grams']),
    mealType: (json['meal_type'] ?? 'unknown').toString(),
    candidates: _list(json['candidates'], AiMealCandidate.fromJson),
    components: _list(json['components'], AiMealComponent.fromJson),
    maskPreview: json['mask_preview'] is Map
        ? Map<String, dynamic>.from(json['mask_preview'] as Map)
        : const <String, dynamic>{},
    userMessage: (json['user_message'] ?? '').toString(),
    weightStatus: (json['weight_status'] ?? '').toString(),
    weightMessage: (json['weight_message'] ?? '').toString(),
    weightEstimationAttempted: json['weight_estimation_attempted'] == true,
    failureMessage: (json['failure_message'] ?? '').toString(),
    expiresAt: DateTime.tryParse((json['expires_at'] ?? '').toString()),
    finalizeAllowed: json['finalize_allowed'] == true,
    requiredUserInputs: json['required_user_inputs'] is List
        ? (json['required_user_inputs'] as List)
              .map((item) => item.toString())
              .toList(growable: false)
        : const <String>[],
    modelVersions: json['model_versions'] is Map
        ? Map<String, dynamic>.from(json['model_versions'] as Map)
        : const <String, dynamic>{},
  );
}

class AiMealFinalizeResult {
  const AiMealFinalizeResult({
    required this.meal,
    required this.summary,
    required this.points,
    this.nutritionSummary = const <String, dynamic>{},
    this.todaySummary = const <String, dynamic>{},
    this.hydrationDeltaMl = 0,
    this.habitEvents = const <Map<String, dynamic>>[],
    this.pointsDelta = 0,
    this.alreadyFinalized = false,
  });

  final MealLog meal;
  final Map<String, dynamic> summary;
  final Map<String, dynamic> points;
  final Map<String, dynamic> nutritionSummary;
  final Map<String, dynamic> todaySummary;
  final double hydrationDeltaMl;
  final List<Map<String, dynamic>> habitEvents;
  final int pointsDelta;
  final bool alreadyFinalized;

  factory AiMealFinalizeResult.fromJson(Map<String, dynamic> json) =>
      AiMealFinalizeResult(
        meal: _validMeal(json['meal']),
        summary: json['summary'] is Map
            ? Map<String, dynamic>.from(json['summary'] as Map)
            : const <String, dynamic>{},
        points: json['points'] is Map
            ? Map<String, dynamic>.from(json['points'] as Map)
            : const <String, dynamic>{},
        nutritionSummary: json['nutrition_summary'] is Map
            ? Map<String, dynamic>.from(json['nutrition_summary'] as Map)
            : const <String, dynamic>{},
        todaySummary: json['today_summary'] is Map
            ? Map<String, dynamic>.from(json['today_summary'] as Map)
            : const <String, dynamic>{},
        hydrationDeltaMl: _nullableDouble(json['hydration_delta_ml']) ?? 0,
        habitEvents: json['habit_events'] is List
            ? (json['habit_events'] as List)
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList(growable: false)
            : const <Map<String, dynamic>>[],
        pointsDelta: _int(json['points_delta']),
        alreadyFinalized: json['already_finalized'] == true,
      );
}

MealLog _validMeal(dynamic value) {
  if (value is! Map || _int(value['id']) <= 0) {
    throw const FormatException('The backend returned an invalid saved meal.');
  }
  return MealLog.fromJson(Map<String, dynamic>.from(value));
}

List<T> _list<T>(dynamic value, T Function(Map<String, dynamic>) parser) {
  if (value is! List) return <T>[];
  return value
      .whereType<Map>()
      .map((item) => parser(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

int? _nullableInt(dynamic value) =>
    value == null ? null : int.tryParse(value.toString());

double? _nullableDouble(dynamic value) =>
    value == null ? null : double.tryParse(value.toString());
