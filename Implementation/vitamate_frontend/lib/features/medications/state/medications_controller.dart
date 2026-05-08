import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/network_error_mapper.dart';
import '../../../core/notifications/notifications_service.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../data/medications_repository.dart';
import '../models/medication_dose_log.dart';
import '../models/medication_item.dart';
import '../models/reminder_sync_payload.dart';
import 'medications_state.dart';

typedef MedicationReminderSyncer =
    Future<void> Function(List<ChronicMedicationReminderPlan> plans);

class MedicationsController extends ChangeNotifier {
  MedicationsController({
    MedicationsRepository? repository,
    MedicationReminderSyncer? reminderSyncer,
  }) : _repository = repository ?? MedicationsRepository(),
       _reminderSyncer =
           reminderSyncer ?? NotificationsService.syncMedicationReminders;

  final MedicationsRepository _repository;
  final MedicationReminderSyncer _reminderSyncer;
  ReminderSyncPayload _cachedReminderSync = ReminderSyncPayload.empty();

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

  Future<void> loadTodayPlan() async {
    state = state.copyWith(todayPlan: await _repository.getTodayPlan());
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
      afterSuccess: () => syncMedicationReminders(),
    );
  }

  MedicationItem? medicationById(int id) {
    for (final item in state.medications) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<bool> syncMedicationReminders() async {
    state = state.copyWith(reminderSyncInProgress: true, clearError: true);
    notifyListeners();
    try {
      final payload = _cachedReminderSync.items.isNotEmpty
          ? _cachedReminderSync
          : await _repository.getReminderSync();
      await _reminderSyncer(_plansFromPayload(payload));
      state = state.copyWith(reminderSyncInProgress: false);
      notifyListeners();
      return true;
    } catch (e) {
      state = state.copyWith(
        reminderSyncInProgress: false,
        errorMessage: NetworkErrorMapper.toMessage(
          e,
          fallback: 'Medication saved, but reminder sync failed.',
        ),
      );
      notifyListeners();
      return false;
    }
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

  List<ChronicMedicationReminderPlan> _plansFromPayload(
    ReminderSyncPayload payload,
  ) {
    final plans = <ChronicMedicationReminderPlan>[];
    for (final item in payload.items) {
      for (final time in item.scheduledTimes) {
        final parts = time.split(':');
        if (parts.length < 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;
        plans.add(
          ChronicMedicationReminderPlan(
            scheduleId: item.scheduleId,
            medicationName: item.displayName,
            conditionName: item.linkedConditionName ?? 'Medication plan',
            dosage: '',
            hour: hour,
            minute: minute,
            leadMinutes: item.reminderLeadMinutes,
            recurrenceDays: item.daysOfWeek,
          ),
        );
      }
    }
    return plans;
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
      _cachedReminderSync = overview.reminderSync;
      state = state.copyWith(
        isLoading: false,
        medications: overview.medications,
        todayPlan: overview.todayPlan,
        overallAdherence: overview.overallAdherence,
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
      syncMedicationReminders(),
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
