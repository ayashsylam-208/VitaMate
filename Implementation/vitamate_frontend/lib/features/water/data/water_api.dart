import 'package:dio/dio.dart';

import '../../../core/network/http_client.dart';
import '../../../core/config/api_endpoints.dart';
import '../../../core/network/request_metrics_interceptor.dart';
import '../../../shared/models/api_result.dart';
import '../../nutrition/models/food_item.dart';
import '../models/hydration_summary.dart';
import '../models/water_log.dart';

class WaterApi {
  Future<HydrationSummary> getSummary({CancelToken? cancelToken}) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.hydrationSummary,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'hydration.summary',
      ),
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
    return HydrationSummary.fromJson(envelope.data);
  }

  Future<List<WaterLog>> getTodayLogs() async {
    final res = await HttpClient.dio.get(ApiEndpoints.water);
    _ensureSuccess(res);
    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => WaterLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<FoodItem>> searchBeverages(
    String query, {
    int limit = 12,
    CancelToken? cancelToken,
  }) async {
    final res = await HttpClient.dio.get(
      ApiEndpoints.foods,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(tag: 'hydration.search'),
      queryParameters: {
        'item_type': 'beverage',
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'limit': limit,
      },
    );
    _ensureSuccess(res);
    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addWaterMl(int amountMl) {
    return _postWater({'amount_ml': amountMl});
  }

  Future<void> addNamedBeverage({
    required int amountMl,
    required String beverageType,
    required String beverageName,
  }) {
    return _postWater({
      'amount_ml': amountMl,
      'beverage_type': beverageType,
      'beverage_name': beverageName,
    });
  }

  Future<void> addCatalogBeverage({
    required int foodItemId,
    required int amountMl,
  }) {
    return _postWater({'food_item': foodItemId, 'amount_ml': amountMl});
  }

  Future<void> addCustomBeverage({
    required int amountMl,
    required String name,
    required String beverageType,
    required double caloriesKcal,
    required double proteinG,
    required double carbohydratesG,
    required double fatG,
    required double sugarsG,
    required double fiberG,
    required double sodiumMg,
    required double waterG,
    required double caffeineMg,
    bool saveForReuse = true,
  }) {
    return _postWater({
      'amount_ml': amountMl,
      'save_for_reuse': saveForReuse,
      'custom_beverage': {
        'name': name,
        'beverage_type': beverageType,
        'calories_kcal': caloriesKcal,
        'protein_g': proteinG,
        'carbohydrates_g': carbohydratesG,
        'fat_g': fatG,
        'sugars_g': sugarsG,
        'fiber_g': fiberG,
        'sodium_mg': sodiumMg,
        'water_g': waterG,
        'caffeine_mg': caffeineMg,
      },
    });
  }

  Future<void> _postWater(Map<String, dynamic> payload) async {
    final res = await HttpClient.dio.post(ApiEndpoints.water, data: payload);
    _ensureSuccess(res);
  }

  void _ensureSuccess(Response<dynamic> response) {
    final statusCode = response.statusCode ?? 500;
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Request failed with status code $statusCode',
    );
  }
}
