import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../models/food_item.dart';
import '../models/nutrition_summary.dart';
import '../models/meal_log.dart';

class NutritionApi {
  Future<NutritionSummary> getSummary() async {
    final res = await HttpClient.dio.get(ApiEndpoints.dashboard);
    final data = res.data;
    if (data is Map<String, dynamic>) return NutritionSummary.fromDashboard(data);
    if (data is Map) return NutritionSummary.fromDashboard(Map<String, dynamic>.from(data));
    return NutritionSummary.empty();
  }

  Future<List<FoodItem>> listFoods() async {
    final res = await HttpClient.dio.get(ApiEndpoints.foods);
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
    await HttpClient.dio.post(ApiEndpoints.foods, data: {
      'name': name,
      'calories_100g': calories100g,
      'protein_100g': protein100g,
      'carbs_100g': carbs100g,
      'fat_100g': fat100g,
      'serving_label': servingLabel,
      'serving_grams': servingGrams,
    });
  }

  Future<void> addMeal({
    required int foodId,
    required String mealType,
    required double quantityGrams,
  }) async {
    await HttpClient.dio.post(ApiEndpoints.meals, data: {
      'food': foodId,
      'meal_type': mealType,
      'quantity_grams': quantityGrams,
    });
  }

  Future<List<MealLog>> getMealsToday() async {
    final res = await HttpClient.dio.get(ApiEndpoints.meals);
    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => MealLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
