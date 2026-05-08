import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/core/health/diabetes_sugar_guard_service.dart';
import 'package:vitamate/features/nutrition/data/nutrition_api.dart';
import 'package:vitamate/features/nutrition/models/food_item.dart';
import 'package:vitamate/features/nutrition/models/nutrition_summary.dart';
import 'package:vitamate/features/water/data/water_api.dart';
import 'package:vitamate/features/water/models/hydration_summary.dart';
import 'package:vitamate/features/water/models/water_log.dart';
import 'package:vitamate/features/water/state/water_controller.dart';

class _FakeWaterApi extends WaterApi {
  _FakeWaterApi({
    required this.logs,
    required this.catalog,
    this.failReadsAfterWrite = false,
    this.summaryConsumedMlOverride,
  });

  List<WaterLog> logs;
  final List<FoodItem> catalog;
  bool failReads = false;
  final bool failReadsAfterWrite;
  final int? summaryConsumedMlOverride;
  int _nextId = 10;

  @override
  Future<List<WaterLog>> getTodayLogs() async {
    if (failReads) {
      throw Exception('read failed');
    }
    return List<WaterLog>.from(logs);
  }

  @override
  Future<HydrationSummary> getSummary({CancelToken? cancelToken}) async {
    if (failReads) {
      throw Exception('read failed');
    }
    final consumedMl =
        summaryConsumedMlOverride ??
        logs.fold<int>(
          0,
          (sum, item) =>
              sum + (item.hydrationMl > 0 ? item.hydrationMl : item.amountMl),
        );
    return HydrationSummary(
      targetMl: 2400,
      consumedMl: consumedMl,
      remainingMl: (2400 - consumedMl).clamp(0, 2400),
      progressPercent: ((consumedMl / 2400) * 100).round(),
    );
  }

  @override
  Future<List<FoodItem>> searchBeverages(
    String query, {
    int limit = 12,
    CancelToken? cancelToken,
  }) async {
    final target = query.trim().toLowerCase();
    if (target.isEmpty) {
      return List<FoodItem>.from(catalog).take(limit).toList();
    }
    return catalog
        .where(
          (item) =>
              item.name.toLowerCase().contains(target) ||
              item.category.toLowerCase().contains(target),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<void> addCatalogBeverage({
    required int foodItemId,
    required int amountMl,
  }) async {
    final item = catalog.firstWhere((entry) => entry.id == foodItemId);
    final factor = amountMl / 100.0;
    logs = [
      WaterLog(
        id: _nextId++,
        amountLiter: amountMl / 1000.0,
        hydrationMl: amountMl,
        beverageType: 'coffee',
        beverageName: item.name,
        foodItemId: item.id,
        foodItemName: item.name,
        linkedMealLogId: 99,
        nutritionPreview: WaterNutritionPreview(
          calories: item.calories100g * factor,
          carbs: item.carbs100g * factor,
          sugars: item.sugars100g * factor,
          caffeine: item.caffeineMg * factor,
        ),
        date: DateTime(2026, 4, 16),
      ),
      ...logs,
    ];
    if (failReadsAfterWrite) {
      failReads = true;
    }
  }
}

class _NullDiabetesSugarGuardService extends DiabetesSugarGuardService {
  const _NullDiabetesSugarGuardService();

  @override
  Future<DiabetesSugarGuard?> getActiveGuard() async => null;
}

class _FixedDiabetesSugarGuardService extends DiabetesSugarGuardService {
  const _FixedDiabetesSugarGuardService(this.guard);

  final DiabetesSugarGuard guard;

  @override
  Future<DiabetesSugarGuard?> getActiveGuard() async => guard;
}

class _FakeWaterNutritionApi extends NutritionApi {
  _FakeWaterNutritionApi(this._summaries);

  final List<NutritionSummary> _summaries;
  int _index = 0;

  @override
  Future<NutritionSummary> getSummary({CancelToken? cancelToken}) async {
    if (_summaries.isEmpty) {
      return NutritionSummary.empty();
    }
    final currentIndex = _index < _summaries.length
        ? _index
        : _summaries.length - 1;
    final summary = _summaries[currentIndex];
    if (_index < _summaries.length - 1) {
      _index += 1;
    }
    return summary;
  }
}

void main() {
  test(
    'water controller searches catalog and reloads after beverage save',
    () async {
      final coffee = FoodItem(
        id: 1,
        name: 'Cold Brew',
        itemType: 'beverage',
        category: 'Coffee',
        calories100g: 4,
        protein100g: 0,
        carbs100g: 0,
        fat100g: 0,
        caffeineMg: 28,
        servingLabel: 'Cup',
        servingGrams: 250,
      );
      final api = _FakeWaterApi(
        logs: [
          WaterLog(
            id: 1,
            amountLiter: 0.25,
            hydrationMl: 250,
            beverageType: 'water',
            beverageName: 'Water',
            date: DateTime(2026, 4, 16),
          ),
        ],
        catalog: [coffee],
      );
      final controller = WaterController(
        api: api,
        diabetesSugarGuardService: const _NullDiabetesSugarGuardService(),
      );

      await controller.load(targetMlFromBackend: 2400);
      await Future<void>.delayed(Duration.zero);
      await controller.searchBeverages('coffee');

      expect(controller.consumedMl, 250);
      expect(controller.waterPointsToday, 5);
      expect(controller.beverageCatalog, hasLength(1));

      final saved = await controller.addCatalogBeverage(
        foodItemId: coffee.id,
        amountMl: 200,
      );

      expect(saved, isTrue);
      expect(controller.logs, hasLength(2));
      expect(controller.consumedMl, 450);
      expect(controller.logs.first.foodItemName, 'Cold Brew');
      expect(controller.logs.first.nutritionPreview?.caffeine, 56);
    },
  );

  test('water controller surfaces reload failure after save', () async {
    final tea = FoodItem(
      id: 2,
      name: 'Green Tea',
      itemType: 'beverage',
      category: 'Tea',
      calories100g: 1,
      protein100g: 0,
      carbs100g: 0,
      fat100g: 0,
      caffeineMg: 12,
      servingLabel: 'Cup',
      servingGrams: 250,
    );
    final api = _FakeWaterApi(
      logs: [
        WaterLog(
          id: 1,
          amountLiter: 0.25,
          hydrationMl: 250,
          beverageType: 'water',
          beverageName: 'Water',
          date: DateTime(2026, 4, 16),
        ),
      ],
      catalog: [tea],
      failReadsAfterWrite: true,
    );
    final controller = WaterController(
      api: api,
      diabetesSugarGuardService: const _NullDiabetesSugarGuardService(),
    );

    await controller.load(targetMlFromBackend: 2400);
    await Future<void>.delayed(Duration.zero);
    final saved = await controller.addCatalogBeverage(
      foodItemId: tea.id,
      amountMl: 200,
    );

    expect(saved, isFalse);
    expect(controller.error, 'Could not save beverage log.');
    expect(controller.consumedMl, 250);
  });

  test(
    'water controller uses water logs when hydration summary snapshot is stale',
    () async {
      final api = _FakeWaterApi(
        logs: [
          WaterLog(
            id: 1,
            amountLiter: 0.5,
            hydrationMl: 500,
            beverageType: 'water',
            beverageName: 'Water',
            date: DateTime(2026, 5, 5),
          ),
        ],
        catalog: const [],
        summaryConsumedMlOverride: 0,
      );
      final controller = WaterController(
        api: api,
        diabetesSugarGuardService: const _NullDiabetesSugarGuardService(),
      );

      await controller.load(targetMlFromBackend: 2300);
      await Future<void>.delayed(Duration.zero);

      expect(controller.logs, hasLength(1));
      expect(controller.consumedMl, 500);
      expect(controller.remainingMl, 1800);
      expect(controller.progress, closeTo(500 / 2300, 0.001));
    },
  );

  test(
    'water controller warns when a sugary drink crosses diabetes limit',
    () async {
      final juice = FoodItem(
        id: 3,
        name: 'Orange Juice',
        itemType: 'beverage',
        category: 'Juice',
        calories100g: 45,
        protein100g: 0,
        carbs100g: 11,
        fat100g: 0,
        sugars100g: 11,
        servingLabel: 'Glass',
        servingGrams: 250,
      );
      final api = _FakeWaterApi(logs: [], catalog: [juice]);
      final nutritionApi = _FakeWaterNutritionApi([
        const NutritionSummary(
          targetCalories: 1800,
          consumedCalories: 0,
          burnedCalories: 0,
          remainingCalories: 1800,
          points: 0,
          sugarsG: 19,
        ),
        const NutritionSummary(
          targetCalories: 1800,
          consumedCalories: 99,
          burnedCalories: 0,
          remainingCalories: 1701,
          points: 5,
          sugarsG: 30,
        ),
      ]);
      final warnings = <DiabetesSugarWarning>[];
      final controller = WaterController(
        api: api,
        nutritionApi: nutritionApi,
        diabetesSugarGuardService: const _FixedDiabetesSugarGuardService(
          DiabetesSugarGuard(limitG: 25, source: 'condition_target'),
        ),
        diabetesSugarAlertNotifier: (warning) async {
          warnings.add(warning);
        },
      );

      await controller.load(targetMlFromBackend: 2400);
      await Future<void>.delayed(Duration.zero);
      await controller.searchBeverages('orange');
      final saved = await controller.addCatalogBeverage(
        foodItemId: juice.id,
        amountMl: 250,
      );
      await Future<void>.delayed(Duration.zero);

      expect(saved, isTrue);
      expect(warnings, hasLength(1));
      expect(warnings.single.limitG, 25);
      expect(warnings.single.currentG, 30);
      expect(warnings.single.sourceLabel, 'Orange Juice');
    },
  );
}
