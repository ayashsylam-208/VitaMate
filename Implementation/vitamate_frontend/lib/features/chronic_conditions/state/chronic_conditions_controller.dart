import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/network_error_mapper.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../data/chronic_conditions_api.dart';
import '../data/chronic_conditions_repository.dart';
import '../models/chronic_condition.dart';

class ChronicConditionsController extends ChangeNotifier {
  ChronicConditionsController({
    ChronicConditionsApi? api,
    ChronicConditionsRepository? repository,
  }) : _repository = repository ?? ChronicConditionsRepository(api: api);

  final ChronicConditionsRepository _repository;
  final Map<int, ChronicCondition> _conditionDetailsById =
      <int, ChronicCondition>{};
  final Set<int> _loadingConditionIds = <int>{};

  bool loading = false;
  bool submitting = false;
  String? error;
  List<ChronicCondition> conditions = const [];
  List<ChronicConditionType> catalog = const [];
  List<ChronicDoseEntry> todayDoses = const [];

  List<ChronicCondition> get activeConditions => conditions
      .where(
        (condition) => condition.isActive && condition.status != 'inactive',
      )
      .toList(growable: false);

  int get pendingSchedules {
    if (todayDoses.isNotEmpty) {
      return todayDoses
          .where((dose) => dose.schedule.isPending || dose.schedule.isSnoozed)
          .length;
    }
    return activeConditions.fold<int>(
      0,
      (sum, condition) => sum + condition.dailyPendingDoses,
    );
  }

  int get openAlerts => activeConditions.fold<int>(
    0,
    (sum, condition) => sum + condition.openAlertsCount,
  );

  bool isConditionDetailLoading(int conditionId) =>
      _loadingConditionIds.contains(conditionId);

  Future<void> load({bool includeCatalog = true}) async {
    await loadCenter(includeCatalog: includeCatalog);
  }

  Future<void> loadCenter({bool includeCatalog = true}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      if (includeCatalog) {
        final results = await Future.wait<Object>([
          _repository.getOverviewConditions(forceRefresh: true),
          _repository.getConditionTypes(),
        ]);
        conditions = results[0] as List<ChronicCondition>;
        catalog = results[1] as List<ChronicConditionType>;
      } else {
        final compactConditions = await _repository.getOverviewConditions(
          forceRefresh: true,
        );
        conditions = compactConditions;
      }
      final activeIds = conditions.map((condition) => condition.id).toSet();
      _conditionDetailsById.removeWhere((key, _) => !activeIds.contains(key));
      todayDoses = _flattenTodayDoses(_detailedActiveConditions());
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load chronic conditions. Please try again.',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> createCondition({
    required int conditionTypeId,
    DateTime? diagnosisDate,
    required String severityCode,
    required String status,
    String notes = '',
    Map<String, dynamic> profileData = const {},
    List<ConditionTargetOverridePayload> targetOverrides = const [],
  }) async {
    submitting = true;
    error = null;
    notifyListeners();
    try {
      final created = await _repository.createCondition(
        conditionTypeId: conditionTypeId,
        diagnosisDate: diagnosisDate,
        severityCode: severityCode,
        status: status,
        notes: notes,
        profileData: profileData,
        targetOverrides: targetOverrides,
      );
      conditions = _upsertCondition(conditions, created);
      _conditionDetailsById.remove(created.id);
      _updateCatalogAvailability(conditionTypeId, isActive: true);
      ChronicConditionsApi.invalidateOverviewCache();
      notifyListeners();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.chronic,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to save the condition.',
      );
      return false;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateCondition({
    required int conditionId,
    required int conditionTypeId,
    DateTime? diagnosisDate,
    required String severityCode,
    required String status,
    String notes = '',
    Map<String, dynamic> profileData = const {},
    bool isActive = true,
    List<ConditionTargetOverridePayload>? targetOverrides,
  }) async {
    submitting = true;
    error = null;
    notifyListeners();
    try {
      final updated = await _repository.updateCondition(
        conditionId: conditionId,
        conditionTypeId: conditionTypeId,
        diagnosisDate: diagnosisDate,
        severityCode: severityCode,
        status: status,
        notes: notes,
        profileData: profileData,
        isActive: isActive,
        targetOverrides: targetOverrides,
      );
      conditions = _upsertCondition(conditions, updated);
      if (!isActive) {
        _conditionDetailsById.remove(conditionId);
      }
      _updateCatalogAvailability(conditionTypeId, isActive: isActive);
      ChronicConditionsApi.invalidateOverviewCache();
      notifyListeners();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.chronic,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
      if (isActive) {
        unawaited(loadConditionDetail(conditionId));
      }
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to update the condition.',
      );
      return false;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<bool> deactivateCondition(int conditionId) async {
    final existing = conditionById(conditionId);
    return _runSubmission(() async {
      await _repository.deactivateCondition(conditionId);
      conditions = _removeCondition(conditions, conditionId);
      _conditionDetailsById.remove(conditionId);
      if (existing != null) {
        _updateCatalogAvailability(existing.conditionType.id, isActive: false);
      }
      todayDoses = _flattenTodayDoses(_detailedActiveConditions());
      ChronicConditionsApi.invalidateOverviewCache();
      notifyListeners();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.chronic,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
    }, failureMessage: 'Failed to deactivate the condition.');
  }

  Future<bool> saveMedication(ChronicMedicationPayload payload) async {
    return _runSubmission(() async {
      if (payload.medicationId == null) {
        await _repository.createMedication(payload);
      } else {
        await _repository.updateMedication(payload);
      }
      ChronicConditionsApi.invalidateOverviewCache();
      notifyListeners();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.chronic,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
      unawaited(loadConditionDetail(payload.userConditionId));
    }, failureMessage: 'Failed to save the medication.');
  }

  Future<bool> deactivateMedication(int medicationId) async {
    final ownerConditionId = _conditionIdForMedication(medicationId);
    return _runSubmission(() async {
      await _repository.deactivateMedication(medicationId);
      ChronicConditionsApi.invalidateOverviewCache();
      notifyListeners();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.chronic,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
      if (ownerConditionId != null) {
        unawaited(loadConditionDetail(ownerConditionId));
      } else {
        unawaited(loadCenter(includeCatalog: false));
      }
    }, failureMessage: 'Failed to deactivate the medication.');
  }

  Future<DoseActionResult?> markMedicationTaken(int scheduleId) async {
    return _runDoseAction(
      scheduleId: scheduleId,
      action: () => _repository.markMedicationTaken(scheduleId),
      afterResult: (_) async {},
      failureMessage: 'Failed to update medication status.',
    );
  }

  Future<DoseActionResult?> markMedicationMissed(int scheduleId) async {
    return _runDoseAction(
      scheduleId: scheduleId,
      action: () => _repository.markMedicationMissed(scheduleId),
      afterResult: (_) async {},
      failureMessage: 'Failed to mark the dose as missed.',
    );
  }

  Future<DoseActionResult?> snoozeMedicationDose(
    int scheduleId, {
    required int snoozeMinutes,
  }) async {
    return _runDoseAction(
      scheduleId: scheduleId,
      action: () => _repository.snoozeMedicationDose(
        scheduleId,
        snoozeMinutes: snoozeMinutes,
      ),
      afterResult: (_) async {},
      failureMessage: 'Failed to snooze the dose.',
    );
  }

  Future<DoseActionResult?> skipMedicationDose(
    int scheduleId, {
    required String reason,
  }) async {
    return _runDoseAction(
      scheduleId: scheduleId,
      action: () => _repository.skipMedicationDose(scheduleId, reason: reason),
      afterResult: (_) async {},
      failureMessage: 'Failed to skip the dose.',
    );
  }

  ChronicCondition? conditionById(int id) {
    final detailed = _conditionDetailsById[id];
    if (detailed != null) {
      return detailed;
    }
    for (final condition in conditions) {
      if (condition.id == id) {
        return condition;
      }
    }
    return null;
  }

  ChronicCondition? conditionForType(int conditionTypeId) {
    for (final condition in activeConditions) {
      if (condition.conditionType.id == conditionTypeId) {
        return condition;
      }
    }
    return null;
  }

  Future<ConditionReadingResult?> logReading({
    required int conditionId,
    required Map<String, dynamic> payload,
    bool refreshDetail = true,
  }) async {
    submitting = true;
    error = null;
    notifyListeners();

    try {
      final result = await _repository.logReading(
        conditionId: conditionId,
        payload: payload,
      );
      ChronicConditionsApi.invalidateOverviewCache();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.chronic,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
      if (refreshDetail) {
        unawaited(loadConditionDetail(conditionId));
      }
      return result;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to save the reading.',
      );
      return null;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<void> loadConditionDetail(int conditionId) async {
    if (_loadingConditionIds.contains(conditionId)) {
      return;
    }
    _loadingConditionIds.add(conditionId);
    notifyListeners();
    try {
      final detail = await _repository.getCondition(conditionId);
      _conditionDetailsById[conditionId] = detail;
      todayDoses = _flattenTodayDoses(_detailedActiveConditions());
      notifyListeners();
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load condition details.',
      );
      notifyListeners();
    } finally {
      _loadingConditionIds.remove(conditionId);
      notifyListeners();
    }
  }

  Future<void> reloadCondition(int conditionId) async {
    await loadConditionDetail(conditionId);
  }

  ChronicDoseEntry? findDoseEntry(int scheduleId) {
    for (final dose in todayDoses) {
      if (dose.schedule.id == scheduleId) return dose;
    }
    for (final condition in _conditionDetailsById.values) {
      for (final medication in condition.medications) {
        for (final schedule in medication.schedules) {
          if (schedule.id == scheduleId) {
            return ChronicDoseEntry(
              condition: condition,
              medication: medication,
              schedule: schedule,
            );
          }
        }
      }
    }
    return null;
  }

  Future<bool> _runSubmission(
    Future<void> Function() action, {
    required String failureMessage,
  }) async {
    submitting = true;
    error = null;
    notifyListeners();

    try {
      await action();
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(e, fallback: failureMessage);
      return false;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<DoseActionResult?> _runDoseAction({
    required int scheduleId,
    required Future<DoseActionResult> Function() action,
    required Future<void> Function(DoseActionResult result) afterResult,
    required String failureMessage,
  }) async {
    submitting = true;
    error = null;
    notifyListeners();

    try {
      final result = await action();
      await afterResult(result);
      ChronicConditionsApi.invalidateOverviewCache();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.chronic,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
      final ownerConditionId = _conditionIdForSchedule(scheduleId);
      if (ownerConditionId != null) {
        unawaited(loadConditionDetail(ownerConditionId));
      } else {
        unawaited(loadCenter(includeCatalog: false));
      }
      return result;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(e, fallback: failureMessage);
      return null;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  List<ChronicDoseEntry> _flattenTodayDoses(List<ChronicCondition> input) {
    final doses = <ChronicDoseEntry>[];
    for (final condition in input) {
      for (final medication in condition.medications) {
        for (final schedule in medication.schedules) {
          if (!schedule.isScheduledToday) {
            continue;
          }
          doses.add(
            ChronicDoseEntry(
              condition: condition,
              medication: medication,
              schedule: schedule,
            ),
          );
        }
      }
    }
    doses.sort((a, b) => a.schedule.timeOfDay.compareTo(b.schedule.timeOfDay));
    return doses;
  }

  List<ChronicCondition> _upsertCondition(
    List<ChronicCondition> input,
    ChronicCondition condition,
  ) {
    final next = List<ChronicCondition>.from(input);
    final index = next.indexWhere((item) => item.id == condition.id);
    if (index >= 0) {
      next[index] = condition;
    } else {
      next.insert(0, condition);
    }
    return next;
  }

  List<ChronicCondition> _removeCondition(
    List<ChronicCondition> input,
    int id,
  ) {
    return input.where((item) => item.id != id).toList(growable: false);
  }

  List<ChronicCondition> _detailedActiveConditions() {
    return _conditionDetailsById.values
        .where((condition) => condition.isActive)
        .toList(growable: false);
  }

  int? _conditionIdForMedication(int medicationId) {
    for (final condition in _conditionDetailsById.values) {
      for (final medication in condition.medications) {
        if (medication.id == medicationId) {
          return condition.id;
        }
      }
    }
    return null;
  }

  int? _conditionIdForSchedule(int scheduleId) {
    final dose = findDoseEntry(scheduleId);
    return dose?.condition.id;
  }

  void _updateCatalogAvailability(
    int conditionTypeId, {
    required bool isActive,
  }) {
    catalog = catalog
        .map((type) {
          if (type.id != conditionTypeId) {
            return type;
          }
          return ChronicConditionType(
            id: type.id,
            code: type.code,
            slug: type.slug,
            name: type.name,
            displayName: type.displayName,
            description: type.description,
            canAdd: !isActive,
            isActiveForUser: isActive,
            severityOptions: type.severityOptions,
            restrictions: type.restrictions,
            ruleProfiles: type.ruleProfiles,
            setupFields: type.setupFields,
            measurementTypes: type.measurementTypes,
            supportsDirectDailyReading: type.supportsDirectDailyReading,
          );
        })
        .toList(growable: false);
  }
}
