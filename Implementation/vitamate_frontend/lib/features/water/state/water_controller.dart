import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/health/chronic_target_guide.dart';
import '../../../core/health/condition_limit_alert_service.dart';
import '../../../core/health/diabetes_sugar_guard_service.dart';
import '../../../core/network/network_error_mapper.dart';
import '../../../core/network/request_manager.dart';
import '../../../core/notification_hub/notification_hub.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../../nutrition/data/nutrition_api.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../nutrition/models/nutrition_summary.dart';
import '../../nutrition/models/food_item.dart';
import '../data/water_api.dart';
import '../data/water_repository.dart';
import '../models/hydration_summary.dart';
import '../models/water_log.dart';

class WaterController extends ChangeNotifier {
  WaterController({
    WaterRepository? repository,
    WaterApi? api,
    NutritionRepository? nutritionRepository,
    NutritionApi? nutritionApi,
    RequestManager? requestManager,
    DiabetesSugarGuardService? diabetesSugarGuardService,
    ChronicTargetGuideService? chronicTargetGuideService,
    ConditionLimitAlertEvaluator? conditionLimitAlertEvaluator,
    Future<void> Function(DiabetesSugarWarning warning)?
    diabetesSugarAlertNotifier,
    Future<void> Function(ConditionLimitWarning warning)?
    conditionLimitAlertNotifier,
  }) : _repository = repository ?? WaterRepository(api: api),
       _nutritionRepository =
           nutritionRepository ?? NutritionRepository(api: nutritionApi),
       _requestManager = requestManager ?? RequestManager(),
       _diabetesSugarGuardService =
           diabetesSugarGuardService ?? const DiabetesSugarGuardService(),
       _chronicTargetGuideService =
           chronicTargetGuideService ?? const ChronicTargetGuideService(),
       _conditionLimitAlertEvaluator =
           conditionLimitAlertEvaluator ?? const ConditionLimitAlertEvaluator(),
       _diabetesSugarAlertNotifier =
           diabetesSugarAlertNotifier ??
           ((warning) => InAppEventPresenter.showDiabetesSugarWarning(
             limitG: warning.limitG,
             currentG: warning.currentG,
             sourceLabel: warning.sourceLabel,
           )),
       _conditionLimitAlertNotifier =
           conditionLimitAlertNotifier ?? ((warning) async {});

  final WaterRepository _repository;
  final NutritionRepository _nutritionRepository;
  final RequestManager _requestManager;
  final ChronicTargetGuideService _chronicTargetGuideService;
  final ConditionLimitAlertEvaluator _conditionLimitAlertEvaluator;
  final DiabetesSugarGuardService _diabetesSugarGuardService;
  final Future<void> Function(DiabetesSugarWarning warning)
  _diabetesSugarAlertNotifier;
  final Future<void> Function(ConditionLimitWarning warning)
  _conditionLimitAlertNotifier;
  DiabetesSugarGuard? _cachedSugarGuard;
  NutritionSummary _cachedNutritionSummary = NutritionSummary.empty();
  List<ChronicGuideCardData> _cachedNutritionLimitGuides = const [];

  bool loading = false;
  bool saving = false;
  bool catalogLoading = false;
  String? error;
  String? catalogError;
  String lastLinkedHabitFeedbackMessage = '';

  List<WaterLog> logs = [];
  List<FoodItem> beverageCatalog = [];
  List<ChronicGuideCardData> chronicHydrationGuides = const [];

  HydrationSummary summary = HydrationSummary.empty();

  int get targetMl => summary.activeTargetMl;
  int get consumedMl => summary.hydrationContributionMl;
  int get remainingMl => summary.remainingMl;
  int get waterContributionMl => summary.waterContributionMl;
  int get otherDrinksContributionMl => summary.otherDrinksContributionMl;
  int get waterPointsToday => summary.pointsEarnedToday;
  bool get goalCompleted => summary.goalCompleted;
  DateTime? get lastDrinkAt => summary.lastDrinkAt;
  double get progress => summary.progressRatio;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _reloadHydration();
    } catch (e) {
      if (!NetworkErrorMapper.isCanceled(e)) {
        error = NetworkErrorMapper.toMessage(
          e,
          fallback: 'Failed to load hydration data.',
        );
      }
    } finally {
      loading = false;
      notifyListeners();
    }
    unawaited(
      _warmAncillaryHydrationContext(loadGuides: true, notifyOnComplete: true),
    );
  }

  Future<bool> drink(int amountMl) async {
    return _saveAndReload(
      () => _repository.addWaterMl(amountMl, consumedAt: DateTime.now()),
      sourceLabel: 'Water',
    );
  }

  Future<void> searchBeverages(String query, {int limit = 12}) async {
    final trimmed = query.trim();
    if (trimmed.isNotEmpty && trimmed.length < 2) {
      beverageCatalog = const [];
      catalogLoading = false;
      catalogError = null;
      notifyListeners();
      return;
    }
    catalogLoading = true;
    catalogError = null;
    notifyListeners();
    final lease = _requestManager.beginLatest('hydration.search');
    try {
      beverageCatalog = await _repository.searchBeverages(
        trimmed,
        limit: limit,
        cancelToken: lease.cancelToken,
      );
    } catch (e) {
      if (NetworkErrorMapper.isCanceled(e)) {
        return;
      }
      catalogError = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not load beverages.',
      );
    } finally {
      _requestManager.complete(lease);
      catalogLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addCatalogBeverage({
    required int foodItemId,
    required int amountMl,
    DateTime? consumedAt,
  }) {
    final label = _catalogLabelForId(foodItemId);
    return _saveAndReload(
      () => _repository.addCatalogBeverage(
        foodItemId: foodItemId,
        amountMl: amountMl,
        consumedAt: consumedAt ?? DateTime.now(),
      ),
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
    DateTime? consumedAt,
  }) {
    return _saveAndReload(
      () => _repository.addCustomBeverage(
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
        consumedAt: consumedAt ?? DateTime.now(),
      ),
      sourceLabel: name,
    );
  }

  Future<bool> addNamedBeverage({
    required int amountMl,
    required String beverageType,
    required String beverageName,
    DateTime? consumedAt,
    double? caffeineMg,
  }) async {
    return _saveAndReload(
      () => _repository.addNamedBeverage(
        amountMl: amountMl,
        beverageType: beverageType,
        beverageName: beverageName,
        consumedAt: consumedAt ?? DateTime.now(),
        caffeineMg: caffeineMg,
      ),
      sourceLabel: beverageName,
    );
  }

  Future<bool> updateDrink({
    required int id,
    required int amountMl,
    required String beverageType,
    required String beverageName,
    required DateTime consumedAt,
    double? caffeineMg,
  }) async {
    return _saveAndReload(
      () => _repository.updateLog(
        id: id,
        amountMl: amountMl,
        beverageType: beverageType,
        beverageName: beverageName,
        consumedAt: consumedAt,
        caffeineMg: caffeineMg,
      ),
      sourceLabel: beverageName,
    );
  }

  Future<bool> deleteDrink(int id) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _repository.deleteLog(id);
      await _reloadHydration();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.hydration,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not delete beverage log.',
      );
      notifyListeners();
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<List<WaterLog>> logsFor({
    DateTime? date,
    DateTime? from,
    DateTime? to,
  }) {
    return _repository.getLogs(date: date, from: from, to: to);
  }

  Future<bool> _saveAndReload(
    Future<WaterLog> Function() action, {
    required String sourceLabel,
  }) async {
    saving = true;
    error = null;
    lastLinkedHabitFeedbackMessage = '';
    notifyListeners();
    try {
      final beforeGuard = _cachedSugarGuard;
      final beforeSummary = _cachedNutritionSummary;
      final savedLog = await action();
      lastLinkedHabitFeedbackMessage = savedLog.linkedHabitFeedbackMessage;
      await _reloadHydration();
      notifyListeners();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.hydration,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
      unawaited(
        _runPostSaveAncillary(
          beforeGuard: beforeGuard,
          beforeSummary: beforeSummary,
          sourceLabel: sourceLabel,
        ),
      );
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not save beverage log.',
      );
      lastLinkedHabitFeedbackMessage = '';
      notifyListeners();
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> _reloadHydration() async {
    final lease = _requestManager.beginLatest('hydration.summary');
    try {
      final results = await Future.wait<Object>([
        _repository.getSummary(cancelToken: lease.cancelToken),
        _repository.getTodayLogs(cancelToken: lease.cancelToken),
      ]);
      if (!_requestManager.isCurrent(lease)) {
        return;
      }
      summary = results[0] as HydrationSummary;
      logs = results[1] as List<WaterLog>;
    } finally {
      _requestManager.complete(lease);
    }
  }

  Future<void> _warmAncillaryHydrationContext({
    required bool loadGuides,
    bool notifyOnComplete = false,
  }) async {
    _cachedSugarGuard = await _readDiabetesSugarGuard();
    _cachedNutritionSummary = await _readNutritionSummary();
    if (loadGuides) {
      try {
        chronicHydrationGuides = await _chronicTargetGuideService.loadForScope(
          ChronicGuideScope.hydration,
        );
      } catch (_) {
        chronicHydrationGuides = const [];
      }
    }
    try {
      _cachedNutritionLimitGuides = await _chronicTargetGuideService
          .loadForScope(ChronicGuideScope.nutrition);
    } catch (_) {
      _cachedNutritionLimitGuides = const [];
    }
    if (notifyOnComplete) {
      notifyListeners();
    }
  }

  Future<void> _runPostSaveAncillary({
    required DiabetesSugarGuard? beforeGuard,
    required NutritionSummary beforeSummary,
    required String sourceLabel,
  }) async {
    await _warmAncillaryHydrationContext(
      loadGuides: false,
      notifyOnComplete: false,
    );
    final afterGuard = _cachedSugarGuard;
    if (afterGuard != null) {
      final beforeSugar = _diabetesSugarTotal(beforeSummary);
      final beforeLimit = beforeGuard?.limitG ?? afterGuard.limitG;
      final afterSugar = _diabetesSugarTotal(_cachedNutritionSummary);
      if (beforeSugar <= beforeLimit && afterSugar > afterGuard.limitG) {
        await _diabetesSugarAlertNotifier(
          DiabetesSugarWarning(
            limitG: afterGuard.limitG,
            currentG: afterSugar,
            sourceLabel: sourceLabel,
          ),
        );
      }
    }
    await _maybeNotifyNutritionLimitsExceeded(
      beforeSummary: beforeSummary,
      afterSummary: _cachedNutritionSummary,
      sourceLabel: sourceLabel,
      excludeSugar: afterGuard != null,
    );
  }

  Future<void> _maybeNotifyNutritionLimitsExceeded({
    required NutritionSummary beforeSummary,
    required NutritionSummary afterSummary,
    required String sourceLabel,
    required bool excludeSugar,
  }) async {
    final warnings = _conditionLimitAlertEvaluator.evaluate(
      guides: _cachedNutritionLimitGuides,
      beforeValues: _nutritionLimitValues(beforeSummary),
      afterValues: _nutritionLimitValues(afterSummary),
      sourceLabel: sourceLabel,
      excludedMetricKeys: excludeSugar
          ? const <String>{'added_sugars_g', 'sugars_g'}
          : const <String>{},
    );
    for (final warning in warnings) {
      await _conditionLimitAlertNotifier(warning);
    }
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
      return await _nutritionRepository.getSummary();
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

  Map<String, double> _nutritionLimitValues(NutritionSummary summary) {
    final sugars = summary.sugarsG;
    final addedSugars = summary.addedSugarsG > 0
        ? summary.addedSugarsG
        : sugars;
    return {
      'added_sugars_g': addedSugars,
      'sugars_g': sugars,
      'sodium_mg': summary.sodiumMg,
      'caffeine_mg': summary.caffeineMg,
    };
  }

  @override
  void dispose() {
    _requestManager.cancelAll();
    super.dispose();
  }
}
