import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/notification_hub/notification_hub.dart';
import '../../../core/network/network_error_mapper.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../data/medications_repository.dart';
import '../models/medication_dose_log.dart';
import '../models/medication_item.dart';
import 'medications_state.dart';

class MedicationsController extends ChangeNotifier {
  MedicationsController({
    MedicationsRepository? repository,
  }) : _repository = repository ?? MedicationsRepository();

  final MedicationsRepository _repository;

  MedicationsState state = MedicationsState.initial();

  List<MedicationItem> get medications => state.medications;
  List<MedicationDoseLog> get todayPlan => state.todayPlan;

  Future<void> refreshAll() async {
    await _refreshOverview(
      showLoading: true,
      fallbackError: 'Failed to load medications.',
      clearSuccess: true,
    );
  }

  Future<void> loadMedications() async {
    state = state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      state = state.copyWith(
        isLoading: false,
        medications: await _repository.getMedications(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: NetworkErrorMapper.toMessage(
          e,
          fallback: 'Failed to load medications.',
        ),
      );
    }
    notifyListeners();
  }

  Future<void> loadTodayPlan({String? date}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      final plan = await _repository.getTodayPlanData(date: date);
      state = state.copyWith(
        isLoading: false,
        todayPlan: plan.doses,
        todayAdherence: plan.summary,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: NetworkErrorMapper.toMessage(
          e,
          fallback: 'Failed to load today plan.',
        ),
      );
    }
    notifyListeners();
  }

  Future<void> loadHistory({String status = 'all'}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      state = state.copyWith(
        isLoading: false,
        history: await _repository.getHistory(status: status),
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: NetworkErrorMapper.toMessage(
          e,
          fallback: 'Failed to load medication history.',
        ),
      );
    }
    notifyListeners();
  }

  Future<bool> createMedication(Map<String, dynamic> payload) async {
    return _save(
      () => _repository.createMedication(payload),
      success: 'Medication saved.',
    );
  }

  Future<bool> updateMedication(int id, Map<String, dynamic> payload) async {
    return _save(
      () => _repository.updateMedication(id, payload),
      success: 'Medication updated.',
    );
  }

  Future<bool> deactivateMedication(int id) async {
    return _save(
      () => _repository.deactivateMedication(id),
      success: 'Medication deactivated.',
    );
  }

  Future<void> loadMedicationAdherence(int id) async {
    state = state.copyWith(clearSelectedMedicationAdherence: true);
    notifyListeners();
    try {
      state = state.copyWith(
        selectedMedicationAdherence: await _repository.getMedicationAdherence(
          id,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: NetworkErrorMapper.toMessage(
          e,
          fallback: 'Failed to load medication adherence.',
        ),
      );
    }
    notifyListeners();
  }

  Future<bool> markDoseTaken(int logId) {
    return _doseAction(
      () => _repository.markTaken(logId, takenAt: DateTime.now()),
      success: 'Dose marked as taken.',
    );
  }

  Future<bool> markDoseMissed(int logId) {
    return _doseAction(
      () => _repository.markMissed(logId),
      success: 'Dose marked as missed.',
    );
  }

  Future<bool> markDoseSkipped(int logId, {String reason = ''}) {
    return _doseAction(
      () => _repository.markSkipped(logId, reason: reason),
      success: 'Dose skipped.',
    );
  }

  Future<bool> snoozeDose(int logId, DateTime snoozedUntil) {
    return _doseAction(
      () => _repository.snooze(logId, snoozedUntil),
      success: 'Dose snoozed.',
      afterSuccess: () => NotificationHubController.instance.syncNow(
        reason: 'medication-snooze',
      ),
    );
  }

  Future<bool> logPrnDose(
    int medicationId, {
    String? doseTakenAmount,
    String notes = '',
  }) {
    return _doseAction(
      () => _repository.logPrnDose(
        medicationId,
        takenAt: DateTime.now(),
        doseTakenAmount: doseTakenAmount,
        notes: notes,
      ),
      success: 'As-needed dose logged.',
      afterSuccess: () => NotificationHubController.instance.syncNow(
        reason: 'medication-prn-dose',
      ),
    );
  }

  MedicationItem? medicationById(int id) {
    for (final item in state.medications) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<bool> _save(
    Future<MedicationItem> Function() action, {
    required String success,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    notifyListeners();
    try {
      final medication = await action();
      state = state.copyWith(
        isSaving: false,
        medications: _upsertMedication(state.medications, medication),
        successMessage: success,
        clearError: true,
      );
      notifyListeners();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.medication,
        HealthSyncScope.nutrition,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
      unawaited(_refreshAfterMedicationMutation());
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: NetworkErrorMapper.toMessage(
          e,
          fallback: 'Failed to save medication.',
        ),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> _doseAction(
    Future<MedicationDoseLog> Function() action, {
    required String success,
    Future<void> Function()? afterSuccess,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    notifyListeners();
    try {
      final log = await action();
      state = state.copyWith(
        isSaving: false,
        todayPlan: _upsertDoseLog(state.todayPlan, log),
        lastDoseAction: log,
        successMessage: success,
        clearError: true,
      );
      notifyListeners();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.medication,
        HealthSyncScope.nutrition,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
      if (afterSuccess != null) {
        unawaited(afterSuccess());
      } else {
        unawaited(
          NotificationHubController.instance.syncNow(
            reason: 'medication-dose-action',
          ),
        );
      }
      unawaited(
        _refreshOverview(
          showLoading: false,
          fallbackError:
              'Medication updated, but some data is still refreshing.',
        ),
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: NetworkErrorMapper.toMessage(
          e,
          fallback: 'Failed to update dose.',
        ),
      );
      notifyListeners();
      return false;
    }
  }

  Future<void> _refreshOverview({
    required bool showLoading,
    required String fallbackError,
    bool clearSuccess = false,
  }) async {
    if (showLoading) {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
        clearSuccess: clearSuccess,
      );
      notifyListeners();
    }
    try {
      final overview = await _repository.getOverview();
      state = state.copyWith(
        isLoading: false,
        medications: overview.medications,
        todayPlan: overview.todayPlan,
        overallAdherence: overview.overallAdherence,
        todayAdherence: overview.todayAdherence,
        nextDose: overview.nextDose,
        clearNextDose: overview.nextDose == null,
        streak: overview.streak,
        shortcutCounts: overview.shortcutCounts,
        motivationStrip: overview.motivationStrip,
        clearMotivationStrip: overview.motivationStrip == null,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: NetworkErrorMapper.toMessage(e, fallback: fallbackError),
      );
    }
    notifyListeners();
  }

  Future<void> _refreshAfterMedicationMutation() async {
    await Future.wait<Object?>([
      _refreshOverview(
        showLoading: false,
        fallbackError: 'Medication saved, but some data is still refreshing.',
      ),
      NotificationHubController.instance.syncNow(reason: 'medication-mutation'),
    ]);
  }

  List<MedicationItem> _upsertMedication(
    List<MedicationItem> medications,
    MedicationItem medication,
  ) {
    final next = List<MedicationItem>.from(medications);
    final index = next.indexWhere((item) => item.id == medication.id);
    if (index >= 0) {
      next[index] = medication;
    } else {
      next.insert(0, medication);
    }
    return next;
  }

  List<MedicationDoseLog> _upsertDoseLog(
    List<MedicationDoseLog> logs,
    MedicationDoseLog updatedLog,
  ) {
    final next = List<MedicationDoseLog>.from(logs);
    final index = next.indexWhere((item) => item.logId == updatedLog.logId);
    if (index >= 0) {
      next[index] = updatedLog;
    } else {
      next.insert(0, updatedLog);
    }
    return next;
  }
}
