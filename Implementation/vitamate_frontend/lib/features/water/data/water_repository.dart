import 'package:dio/dio.dart';

import '../../nutrition/models/food_item.dart';
import '../models/hydration_summary.dart';
import '../models/water_log.dart';
import 'water_api.dart';

class WaterRepository {
  WaterRepository({WaterApi? api}) : _api = api ?? WaterApi();

  final WaterApi _api;

  Future<HydrationSummary> getSummary({CancelToken? cancelToken}) {
    return _api.getSummary(cancelToken: cancelToken);
  }

  Future<List<WaterLog>> getTodayLogs() => _api.getTodayLogs();

  Future<List<FoodItem>> searchBeverages(
    String query, {
    int limit = 12,
    CancelToken? cancelToken,
  }) {
    return _api.searchBeverages(query, limit: limit, cancelToken: cancelToken);
  }

  Future<void> addWaterMl(int amountMl) => _api.addWaterMl(amountMl);

  Future<void> addNamedBeverage({
    required int amountMl,
    required String beverageType,
    required String beverageName,
  }) {
    return _api.addNamedBeverage(
      amountMl: amountMl,
      beverageType: beverageType,
      beverageName: beverageName,
    );
  }

  Future<void> addCatalogBeverage({
    required int foodItemId,
    required int amountMl,
  }) {
    return _api.addCatalogBeverage(foodItemId: foodItemId, amountMl: amountMl);
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
    );
  }
}
