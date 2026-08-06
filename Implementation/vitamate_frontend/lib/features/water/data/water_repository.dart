import 'package:dio/dio.dart';

import '../../nutrition/models/food_item.dart';
import '../models/hydration_summary.dart';
import '../models/water_log.dart';
import 'water_api.dart';

class WaterRepository {
  WaterRepository({WaterApi? api}) : _api = api ?? WaterApi();

  final WaterApi _api;

  Future<HydrationSummary> getSummary({
    DateTime? date,
    CancelToken? cancelToken,
  }) {
    return _api.getSummary(date: date, cancelToken: cancelToken);
  }

  Future<List<WaterLog>> getLogs({
    DateTime? date,
    DateTime? from,
    DateTime? to,
    CancelToken? cancelToken,
  }) {
    return _api.getLogs(
      date: date,
      from: from,
      to: to,
      cancelToken: cancelToken,
    );
  }

  Future<List<WaterLog>> getTodayLogs({CancelToken? cancelToken}) {
    return _api.getTodayLogs(cancelToken: cancelToken);
  }

  Future<List<FoodItem>> searchBeverages(
    String query, {
    int limit = 12,
    CancelToken? cancelToken,
  }) {
    return _api.searchBeverages(query, limit: limit, cancelToken: cancelToken);
  }

  Future<WaterLog> addWaterMl(int amountMl, {DateTime? consumedAt}) {
    return _api.addWaterMl(amountMl, consumedAt: consumedAt);
  }

  Future<WaterLog> addNamedBeverage({
    required int amountMl,
    required String beverageType,
    required String beverageName,
    DateTime? consumedAt,
    double? caffeineMg,
  }) {
    return _api.addNamedBeverage(
      amountMl: amountMl,
      beverageType: beverageType,
      beverageName: beverageName,
      consumedAt: consumedAt,
      caffeineMg: caffeineMg,
    );
  }

  Future<WaterLog> addCatalogBeverage({
    required int foodItemId,
    required int amountMl,
    DateTime? consumedAt,
  }) {
    return _api.addCatalogBeverage(
      foodItemId: foodItemId,
      amountMl: amountMl,
      consumedAt: consumedAt,
    );
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
    return _api.addCustomBeverage(
      amountMl: amountMl,
      name: name,
      beverageType: beverageType,
      caloriesKcal: caloriesKcal,
      proteinG: proteinG,
      carbohydratesG: carbohydratesG,
      fatG: fatG,
      sugarsG: sugarsG,
      fiberG: fiberG,
      sodiumMg: sodiumMg,
      waterG: waterG,
      caffeineMg: caffeineMg,
      saveForReuse: saveForReuse,
      consumedAt: consumedAt,
    );
  }

  Future<WaterLog> updateLog({
    required int id,
    int? amountMl,
    String? beverageType,
    String? beverageName,
    DateTime? consumedAt,
    double? caffeineMg,
  }) {
    return _api.updateLog(
      id: id,
      amountMl: amountMl,
      beverageType: beverageType,
      beverageName: beverageName,
      consumedAt: consumedAt,
      caffeineMg: caffeineMg,
    );
  }

  Future<void> deleteLog(int id) => _api.deleteLog(id);
}
