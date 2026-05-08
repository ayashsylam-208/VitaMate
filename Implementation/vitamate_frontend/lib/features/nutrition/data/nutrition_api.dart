import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_metrics_interceptor.dart';
import '../../../shared/models/api_result.dart';
import '../models/food_item.dart';
import '../models/meal_log.dart';
import '../models/micronutrient_tracking.dart';
import '../models/nutrition_summary.dart';

class NutritionApi {
  Future<NutritionSummary> getSummary({CancelToken? cancelToken}) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.nutritionSummary,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'nutrition.summary',
      ),
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
    return NutritionSummary.fromSummaryJson(envelope.data);
  }

  Future<MicronutrientOverview> getMicronutrients({
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.nutritionMicronutrients,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'nutrition.micronutrients',
      ),
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
    return MicronutrientOverview.fromJson(envelope.data);
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
  }) async {
    final response = await HttpClient.dio.post(
      ApiEndpoints.nutritionMicronutrientTargets,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'nutrition.micronutrient_target',
      ),
      data: {
        'nutrient_code': nutrientCode,
        if (minValue != null) 'min_value': minValue,
        if (targetValue != null) 'target_value': targetValue,
        if (maxValue != null) 'max_value': maxValue,
        'note': note,
        if (labTestName.trim().isNotEmpty) 'lab_test_name': labTestName.trim(),
        if (labValue != null) 'lab_value': labValue,
        if (labUnit.trim().isNotEmpty) 'lab_unit': labUnit.trim(),
        if (labReferenceMin != null) 'lab_reference_min': labReferenceMin,
        if (labReferenceMax != null) 'lab_reference_max': labReferenceMax,
        if (labTestDate.trim().isNotEmpty) 'lab_test_date': labTestDate.trim(),
        if (clinicianRecommendedValue != null)
          'clinician_recommended_value': clinicianRecommendedValue,
        if (currentMedicationName.trim().isNotEmpty)
          'current_medication_name': currentMedicationName.trim(),
        if (currentMedicationDose.trim().isNotEmpty)
          'current_medication_dose': currentMedicationDose.trim(),
        'create_medication_plan': createMedicationPlan,
        if (supplementName.trim().isNotEmpty)
          'supplement_name': supplementName.trim(),
        if (supplementAmount != null) 'supplement_amount': supplementAmount,
        if (supplementUnit.trim().isNotEmpty)
          'supplement_unit': supplementUnit.trim(),
        if (scheduleTime.trim().isNotEmpty)
          'schedule_time': scheduleTime.trim(),
      },
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
    return MicronutrientOverview.fromJson(envelope.data);
  }

  Future<List<FoodItem>> listFoods({
    String? itemType,
    String? query,
    String? category,
    String? mealSlot,
    bool? containsCaffeine,
    bool? isHydrationTrackable,
    int? limit,
    CancelToken? cancelToken,
  }) async {
    final res = await HttpClient.dio.get(
      ApiEndpoints.foods,
      cancelToken: cancelToken,
      queryParameters: _foodSearchParams(
        itemType: itemType,
        query: query,
        category: category,
        mealSlot: mealSlot,
        containsCaffeine: containsCaffeine,
        isHydrationTrackable: isHydrationTrackable,
        limit: limit,
      ),
    );
    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<FoodItem>> autocompleteFoods({
    String? itemType,
    String? query,
    String? category,
    String? mealSlot,
    bool? containsCaffeine,
    bool? isHydrationTrackable,
    int limit = 12,
    CancelToken? cancelToken,
  }) async {
    final res = await HttpClient.dio.get(
      ApiEndpoints.foodsAutocomplete,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(tag: 'nutrition.search'),
      queryParameters: _foodSearchParams(
        itemType: itemType,
        query: query,
        category: category,
        mealSlot: mealSlot,
        containsCaffeine: containsCaffeine,
        isHydrationTrackable: isHydrationTrackable,
        limit: limit,
      ),
    );
    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addFood({
    required String name,
    required int calories100g,
    required double protein100g,
    required double carbs100g,
    required double fat100g,
    required String servingLabel,
    required int servingGrams,
  }) async {
    await HttpClient.dio.post(
      ApiEndpoints.foods,
      data: {
        'name': name,
        'calories_100g': calories100g,
        'protein_100g': protein100g,
        'carbs_100g': carbs100g,
        'fat_100g': fat100g,
        'serving_label': servingLabel,
        'serving_grams': servingGrams,
      },
    );
  }

  Future<void> addMeal({
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
  }) async {
    await HttpClient.dio.post(
      ApiEndpoints.meals,
      data: {
        'food': foodId,
        'meal_type': mealType,
        if (quantityGrams != null) 'quantity_grams': quantityGrams,
        if (quantity != null) 'quantity': quantity,
        if (unit != null && unit.isNotEmpty) 'unit': unit,
        if (servingOptionId != null) 'serving_option': servingOptionId,
        if (servingLabelSnapshot != null && servingLabelSnapshot.isNotEmpty)
          'serving_label_snapshot': servingLabelSnapshot,
        if (servingGramsEquivalent != null)
          'serving_grams_equivalent': servingGramsEquivalent,
        if (servingMillilitersEquivalent != null)
          'serving_milliliters_equivalent': servingMillilitersEquivalent,
        if (consumedAt != null) 'consumed_at': consumedAt.toIso8601String(),
      },
    );
  }

  Future<List<MealLog>> getMealsToday() async {
    final res = await HttpClient.dio.get(ApiEndpoints.meals);
    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => MealLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<bool> hasActiveDiabetes() async {
    final res = await HttpClient.dio.get(
      ApiEndpoints.chronicSupportedConditionTypes,
    );
    final data = res.data;
    final list = data is List
        ? data
        : (data is Map && data['results'] is List
              ? data['results'] as List
              : const []);
    for (final item in list) {
      if (item is! Map) {
        continue;
      }
      final slug = item['slug']?.toString().trim().toLowerCase();
      final isActive = item['is_active_for_user'] == true;
      if (slug == 'diabetes' && isActive) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _foodSearchParams({
    String? itemType,
    String? query,
    String? category,
    String? mealSlot,
    bool? containsCaffeine,
    bool? isHydrationTrackable,
    int? limit,
  }) {
    return {
      if (itemType != null && itemType.isNotEmpty) 'item_type': itemType,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (mealSlot != null && mealSlot.trim().isNotEmpty)
        'meal_slot': mealSlot.trim(),
      if (containsCaffeine != null) 'contains_caffeine': containsCaffeine,
      if (isHydrationTrackable != null)
        'is_hydration_trackable': isHydrationTrackable,
      if (limit != null && limit > 0) 'limit': limit,
    };
  }
}
