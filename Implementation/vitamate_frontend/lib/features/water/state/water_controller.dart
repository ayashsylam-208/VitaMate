import 'package:flutter/foundation.dart';

import '../../../core/health/chronic_target_guide.dart';
import '../../../core/health/diabetes_sugar_guard_service.dart';
import '../../../core/network/network_error_mapper.dart';
import '../../../core/notifications/notifications_service.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../../nutrition/data/nutrition_api.dart';
import '../../nutrition/models/nutrition_summary.dart';
import '../../nutrition/models/food_item.dart';
import '../data/water_api.dart';
import '../models/water_log.dart';

class WaterController extends ChangeNotifier {
  WaterController({
    WaterApi? api,
    NutritionApi? nutritionApi,
    DiabetesSugarGuardService? diabetesSugarGuardService,
    ChronicTargetGuideService? chronicTargetGuideService,
    Future<void> Function(DiabetesSugarWarning warning)?
    diabetesSugarAlertNotifier,
  }) : _api = api ?? WaterApi(),
       _nutritionApi = nutritionApi ?? NutritionApi(),
       _diabetesSugarGuardService =
           diabetesSugarGuardService ?? const DiabetesSugarGuardService(),
       _chronicTargetGuideService =
           chronicTargetGuideService ?? const ChronicTargetGuideService(),
       _diabetesSugarAlertNotifier =
           diabetesSugarAlertNotifier ??
           ((warning) => NotificationsService.showDiabetesSugarWarning(
             limitG: warning.limitG,
             currentG: warning.currentG,
             sourceLabel: warning.sourceLabel,
           ));

  final WaterApi _api;
  final NutritionApi _nutritionApi;
  final ChronicTargetGuideService _chronicTargetGuideService;
  final DiabetesSugarGuardService _diabetesSugarGuardService;
  final Future<void> Function(DiabetesSugarWarning warning)
  _diabetesSugarAlertNotifier;

  bool loading = false;
  bool saving = false;
  bool catalogLoading = false;
  String? error;
  String? catalogError;

  List<WaterLog> logs = [];
  List<FoodItem> beverageCatalog = [];
  List<ChronicGuideCardData> chronicHydrationGuides = const [];

  int targetMl = 0; // from backend (dashboard) converted to ml
  int consumedMl = 0;
  int waterPointsToday = 0;

  int get remainingMl => (targetMl - consumedMl).clamp(0, targetMl);
  double get progress =>
      targetMl == 0 ? 0 : (consumedMl / targetMl).clamp(0, 1);

  Future<void> load({required int targetMlFromBackend}) async {
    loading = true;
    error = null;
    chronicHydrationGuides = const [];
    notifyListeners();

    try {
      await _reloadHydration(targetMlFromBackend: targetMlFromBackend);
      try {
        chronicHydrationGuides = await _chronicTargetGuideService.loadForScope(
          ChronicGuideScope.hydration,
        );
      } catch (_) {
        chronicHydrationGuides = const [];
      }
      loading = false;
      notifyListeners();
    } catch (_) {
      loading = false;
      error = 'Failed to load hydration data.';
      notifyListeners();
    }
  }

  Future<void> drink(int amountMl) async {
    await _saveAndReload(() => _api.addWaterMl(amountMl), sourceLabel: 'Water');
  }

  Future<void> searchBeverages(String query) async {
    catalogLoading = true;
    catalogError = null;
    notifyListeners();
    try {
      beverageCatalog = await _api.searchBeverages(query);
    } catch (e) {
      catalogError = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not load beverages.',
      );
    } finally {
      catalogLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addCatalogBeverage({
    required int foodItemId,
    required int amountMl,
  }) {
    final label = _catalogLabelForId(foodItemId);
    return _saveAndReload(
      () => _api.addCatalogBeverage(foodItemId: foodItemId, amountMl: amountMl),
      sourceLabel: label,
    );
  }

  Future<bool> addCustomBeverage({
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
    return _saveAndReload(
      () => _api.addCustomBeverage(
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
      ),
      sourceLabel: name,
    );
  }

  Future<bool> addNamedBeverage({
    required int amountMl,
    required String beverageType,
    required String beverageName,
  }) async {
    return _saveAndReload(
      () => _api.addNamedBeverage(
        amountMl: amountMl,
        beverageType: beverageType,
        beverageName: beverageName,
      ),
      sourceLabel: beverageName,
    );
  }

  Future<bool> _saveAndReload(
    Future<void> Function() action, {
    required String sourceLabel,
  }) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      final beforeGuard = await _readDiabetesSugarGuard();
      final beforeSummary = beforeGuard != null
          ? await _readNutritionSummary()
          : NutritionSummary.empty();
      await action();
      await _reloadHydration(targetMlFromBackend: targetMl);
      HealthSyncBus.instance.notifyTrackerDataChanged();
      final afterGuard = await _readDiabetesSugarGuard();
      if (afterGuard != null) {
        final afterSummary = await _readNutritionSummary();
        final beforeSugar = _diabetesSugarTotal(beforeSummary);
        final afterSugar = _diabetesSugarTotal(afterSummary);
        if (beforeSugar <= afterGuard.limitG &&
            afterSugar > afterGuard.limitG) {
          await _diabetesSugarAlertNotifier(
            DiabetesSugarWarning(
              limitG: afterGuard.limitG,
              currentG: afterSugar,
              sourceLabel: sourceLabel,
            ),
          );
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not save beverage log.',
      );
      notifyListeners();
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> _reloadHydration({required int targetMlFromBackend}) async {
    targetMl = targetMlFromBackend;
    logs = await _api.getTodayLogs();
    consumedMl = logs.fold<int>(
      0,
      (sum, e) => sum + (e.hydrationMl > 0 ? e.hydrationMl : e.amountMl),
    );
    waterPointsToday = logs.length * 5; // backend awards 5 pts per log
  }

  String _catalogLabelForId(int foodItemId) {
    for (final item in beverageCatalog) {
      if (item.id == foodItemId) {
        return item.name;
      }
    }
    return 'Your latest drink';
  }

  Future<DiabetesSugarGuard?> _readDiabetesSugarGuard() async {
    try {
      return await _diabetesSugarGuardService.getActiveGuard();
    } catch (_) {
      return null;
    }
  }

  Future<NutritionSummary> _readNutritionSummary() async {
    try {
      return await _nutritionApi.getSummary();
    } catch (_) {
      return NutritionSummary.empty();
    }
  }

  double _diabetesSugarTotal(NutritionSummary summary) {
    if (summary.addedSugarsG > 0) {
      return summary.addedSugarsG;
    }
    return summary.sugarsG;
  }
}
