import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../models/food_item.dart';
import '../models/meal_log.dart';
import '../models/nutrition_summary.dart';

class NutritionApi {
  Future<NutritionSummary> getSummary() async {
    final res = await HttpClient.dio.get(ApiEndpoints.dashboard);
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return NutritionSummary.fromDashboard(data);
    }
    if (data is Map) {
      return NutritionSummary.fromDashboard(Map<String, dynamic>.from(data));
    }
    return NutritionSummary.empty();
  }

  Future<List<FoodItem>> listFoods({
    String? itemType,
    String? query,
    String? category,
    bool? containsCaffeine,
    bool? isHydrationTrackable,
    int? limit,
  }) async {
    final res = await HttpClient.dio.get(
      ApiEndpoints.foods,
      queryParameters: _foodSearchParams(
        itemType: itemType,
        query: query,
        category: category,
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
    bool? containsCaffeine,
    bool? isHydrationTrackable,
    int limit = 12,
  }) async {
    final res = await HttpClient.dio.get(
      ApiEndpoints.foodsAutocomplete,
      queryParameters: _foodSearchParams(
        itemType: itemType,
        query: query,
        category: category,
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
  }) async {
    await HttpClient.dio.post(
      ApiEndpoints.meals,
      data: {
        'food': foodId,
        'meal_type': mealType,
        if (quantityGrams != null) 'quantity_grams': quantityGrams,
        if (quantity != null) 'quantity': quantity,
        if (unit != null && unit.isNotEmpty) 'unit': unit,
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
    bool? containsCaffeine,
    bool? isHydrationTrackable,
    int? limit,
  }) {
    return {
      if (itemType != null && itemType.isNotEmpty) 'item_type': itemType,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (containsCaffeine != null) 'contains_caffeine': containsCaffeine,
      if (isHydrationTrackable != null)
        'is_hydration_trackable': isHydrationTrackable,
      if (limit != null && limit > 0) 'limit': limit,
    };
  }
}
