import 'package:flutter/foundation.dart';

import '../../../core/network/network_error_mapper.dart';
import '../../../core/notifications/notifications_service.dart';
import '../../../core/runtime/app_runtime.dart';
import '../data/chronic_conditions_api.dart';
import '../models/chronic_condition.dart';

typedef ReminderSync =
    Future<void> Function(List<ChronicMedicationReminderPlan> plans);

Future<void> _noopReminderSync(List<ChronicMedicationReminderPlan> _) async {}

class ChronicConditionsController extends ChangeNotifier {
  ChronicConditionsController({
    ChronicConditionsApi? api,
    ReminderSync? reminderSync,
  }) : _api = api ?? const ChronicConditionsApi(),
       _reminderSync =
           reminderSync ??
           (AppRuntime.notificationsEnabled
               ? NotificationsService.syncChronicMedicationReminders
               : _noopReminderSync);

  final ChronicConditionsApi _api;
  final ReminderSync _reminderSync;

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

  int get pendingSchedules => todayDoses
      .where((dose) => dose.schedule.isPending || dose.schedule.isSnoozed)
      .length;

  int get openAlerts => activeConditions.fold<int>(
    0,
    (sum, condition) => sum + condition.openAlertsCount,
  );

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getConditions(),
        _api.getConditionTypes(),
      ]);
      conditions = results[0] as List<ChronicCondition>;
      catalog = results[1] as List<ChronicConditionType>;
      todayDoses = _flattenTodayDoses(activeConditions);
      await _syncMedicationReminders();
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
    return _runSubmission(() async {
      await _api.createCondition(
        conditionTypeId: conditionTypeId,
        diagnosisDate: diagnosisDate,
        severityCode: severityCode,
        status: status,
        notes: notes,
        profileData: profileData,
        targetOverrides: targetOverrides,
      );
      await load();
    }, failureMessage: 'Failed to save the condition.');
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
    return _runSubmission(() async {
      await _api.updateCondition(
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
      await load();
    }, failureMessage: 'Failed to update the condition.');
  }

  Future<bool> deactivateCondition(int conditionId) async {
    return _runSubmission(() async {
      await _api.deactivateCondition(conditionId);
      await load();
    }, failureMessage: 'Failed to deactivate the condition.');
  }

  Future<bool> saveMedication(ChronicMedicationPayload payload) async {
    return _runSubmission(() async {
      if (payload.medicationId == null) {
        await _api.createMedication(payload);
      } else {
        await _api.updateMedication(payload);
      }
      await load();
    }, failureMessage: 'Failed to save the medication.');
  }

  Future<bool> deactivateMedication(int medicationId) async {
    return _runSubmission(() async {
      await _api.deactivateMedication(medicationId);
      await load();
    }, failureMessage: 'Failed to deactivate the medication.');
  }

  Future<DoseActionResult?> markMedicationTaken(int scheduleId) async {
    return _runDoseAction(
      scheduleId: scheduleId,
      action: () => _api.markMedicationTaken(scheduleId),
      afterResult: (_) =>
          NotificationsService.cancelChronicMedicationSnooze(scheduleId),
      failureMessage: 'Failed to update medication status.',
    );
  }

  Future<DoseActionResult?> markMedicationMissed(int scheduleId) async {
    return _runDoseAction(
      scheduleId: scheduleId,
      action: () => _api.markMedicationMissed(scheduleId),
      afterResult: (_) =>
          NotificationsService.cancelChronicMedicationSnooze(scheduleId),
      failureMessage: 'Failed to mark the dose as missed.',
    );
  }

  Future<DoseActionResult?> snoozeMedicationDose(
    int scheduleId, {
    required int snoozeMinutes,
  }) async {
    return _runDoseAction(
      scheduleId: scheduleId,
      action: () =>
          _api.snoozeMedicationDose(scheduleId, snoozeMinutes: snoozeMinutes),
      afterResult: (result) async {
        final dose = findDoseEntry(scheduleId);
        if (dose == null || result.scheduledFor.isEmpty) {
          return;
        }
        final reminderAt = DateTime.tryParse(result.scheduledFor);
        if (reminderAt == null) {
          return;
        }
        await NotificationsService.scheduleChronicMedicationSnooze(
          scheduleId: scheduleId,
          medicationName: dose.medication.name,
          conditionName: dose.condition.conditionType.name,
          dosage: dose.medication.dosageLabel,
          reminderAt: reminderAt,
        );
      },
      failureMessage: 'Failed to snooze the dose.',
    );
  }

  Future<DoseActionResult?> skipMedicationDose(
    int scheduleId, {
    required String reason,
  }) async {
    return _runDoseAction(
      scheduleId: scheduleId,
      action: () => _api.skipMedicationDose(scheduleId, reason: reason),
      afterResult: (_) =>
          NotificationsService.cancelChronicMedicationSnooze(scheduleId),
      failureMessage: 'Failed to skip the dose.',
    );
  }

  ChronicCondition? conditionById(int id) {
    for (final condition in conditions) {
      if (condition.id == id) return condition;
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
  }) async {
    submitting = true;
    error = null;
    notifyListeners();

    try {
      final result = await _api.logReading(
        conditionId: conditionId,
        payload: payload,
      );
      await load();
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

  ChronicDoseEntry? findDoseEntry(int scheduleId) {
    for (final dose in todayDoses) {
      if (dose.schedule.id == scheduleId) return dose;
    }
    for (final condition in conditions) {
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
      await load();
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

  Future<void> _syncMedicationReminders() async {
    final plans = <ChronicMedicationReminderPlan>[];
    for (final condition in conditions.where((item) => item.isActive)) {
      for (final medication in condition.medications.where(
        (item) => item.isActive && item.reminderEnabled,
      )) {
        for (final schedule in medication.schedules) {
          final parts = schedule.timeOfDay.split(':');
          if (parts.length < 2) {
            continue;
          }
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour == null || minute == null) {
            continue;
          }
          plans.add(
            ChronicMedicationReminderPlan(
              scheduleId: schedule.id,
              medicationName: medication.name,
              conditionName: condition.conditionType.name,
              dosage: medication.dosageLabel,
              hour: hour,
              minute: minute,
              leadMinutes: schedule.reminderLeadMinutes > 0
                  ? schedule.reminderLeadMinutes
                  : medication.reminderLeadMinutes,
              recurrenceDays: schedule.recurrenceDays.isNotEmpty
                  ? schedule.recurrenceDays
                  : medication.recurrencePattern,
            ),
          );
        }
      }
    }
    try {
      await _reminderSync(plans);
    } catch (_) {
      // Reminder sync should not block rendering or API workflows.
    }
  }
}
