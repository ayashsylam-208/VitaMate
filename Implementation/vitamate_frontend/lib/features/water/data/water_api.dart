import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_metrics_interceptor.dart';
import '../../../shared/models/api_result.dart';
import '../../nutrition/models/food_item.dart';
import '../models/hydration_summary.dart';
import '../models/water_log.dart';

class WaterApi {
  Future<HydrationSummary> getSummary({
    DateTime? date,
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.hydrationSummary,
      cancelToken: cancelToken,
      queryParameters: {if (date != null) 'date': _dateOnly(date)},
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

  Future<List<WaterLog>> getLogs({
    DateTime? date,
    DateTime? from,
    DateTime? to,
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.hydrationLogs,
      cancelToken: cancelToken,
      queryParameters: {
        if (date != null) 'date': _dateOnly(date),
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      },
      options: RequestMetricsInterceptor.taggedOptions(tag: 'hydration.logs'),
    );
    _ensureSuccess(response);
    final list = (response.data as List?) ?? const [];
    return list
        .map(
          (item) => WaterLog.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<List<WaterLog>> getTodayLogs({CancelToken? cancelToken}) {
    return getLogs(date: DateTime.now(), cancelToken: cancelToken);
  }

  Future<List<FoodItem>> searchBeverages(
    String query, {
    int limit = 12,
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.foods,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(tag: 'hydration.search'),
      queryParameters: {
        'item_type': 'beverage',
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'limit': limit,
      },
    );
    _ensureSuccess(response);
    final list = (response.data as List).cast<dynamic>();
    return list
        .map(
          (item) => FoodItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<WaterLog> addWaterMl(int amountMl, {DateTime? consumedAt}) {
    return _postWater({
      'amount_ml': amountMl,
      'drink_type': 'water',
      'custom_name': 'Water',
      'consumed_at': (consumedAt ?? DateTime.now()).toIso8601String(),
    });
  }

  Future<WaterLog> addNamedBeverage({
    required int amountMl,
    required String beverageType,
    required String beverageName,
    DateTime? consumedAt,
    double? caffeineMg,
  }) {
    return _postWater({
      'amount_ml': amountMl,
      'drink_type': beverageType,
      'custom_name': beverageName,
      'consumed_at': (consumedAt ?? DateTime.now()).toIso8601String(),
      if (caffeineMg != null) 'metadata': {'caffeine_mg': caffeineMg},
    });
  }

  Future<WaterLog> addCatalogBeverage({
    required int foodItemId,
    required int amountMl,
    DateTime? consumedAt,
  }) {
    return _postWater({
      'food_item_id': foodItemId,
      'amount_ml': amountMl,
      'consumed_at': (consumedAt ?? DateTime.now()).toIso8601String(),
    });
  }

  Future<WaterLog> addCustomBeverage({
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
    DateTime? consumedAt,
  }) {
    return _postWater({
      'amount_ml': amountMl,
      'consumed_at': (consumedAt ?? DateTime.now()).toIso8601String(),
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

  Future<WaterLog> updateLog({
    required int id,
    int? amountMl,
    String? beverageType,
    String? beverageName,
    DateTime? consumedAt,
    double? caffeineMg,
  }) async {
    final payload = <String, dynamic>{
      if (amountMl != null) 'amount_ml': amountMl,
      if (beverageType != null) 'drink_type': beverageType,
      if (beverageName != null) 'custom_name': beverageName,
      if (consumedAt != null) 'consumed_at': consumedAt.toIso8601String(),
      if (caffeineMg != null) 'metadata': {'caffeine_mg': caffeineMg},
    };
    final response = await HttpClient.dio.patch(
      '${ApiEndpoints.hydrationLogs}$id/',
      data: payload,
    );
    _ensureSuccess(response);
    return WaterLog.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> deleteLog(int id) async {
    final response = await HttpClient.dio.delete(
      '${ApiEndpoints.hydrationLogs}$id/',
    );
    _ensureSuccess(response);
  }

  Future<WaterLog> _postWater(Map<String, dynamic> payload) async {
    final response = await HttpClient.dio.post(
      ApiEndpoints.hydrationLogs,
      data: payload,
    );
    _ensureSuccess(response);
    return WaterLog.fromJson(Map<String, dynamic>.from(response.data as Map));
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

String _dateOnly(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
