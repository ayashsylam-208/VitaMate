import '../models/chronic_condition.dart';
import 'chronic_conditions_api.dart';

class ChronicConditionsRepository {
  const ChronicConditionsRepository({ChronicConditionsApi? api})
    : _api = api ?? const ChronicConditionsApi();

  final ChronicConditionsApi _api;

  Future<List<ChronicCondition>> getOverviewConditions({
    bool forceRefresh = false,
  }) {
    return _api.getOverviewConditions(forceRefresh: forceRefresh);
  }

  Future<List<ChronicConditionType>> getConditionTypes() {
    return _api.getConditionTypes();
  }

  Future<ChronicCondition> createCondition({
    required int conditionTypeId,
    DateTime? diagnosisDate,
    required String severityCode,
    required String status,
    String notes = '',
    Map<String, dynamic> profileData = const {},
    List<ConditionTargetOverridePayload> targetOverrides = const [],
  }) {
    return _api.createCondition(
      conditionTypeId: conditionTypeId,
      diagnosisDate: diagnosisDate,
      severityCode: severityCode,
      status: status,
      notes: notes,
      profileData: profileData,
      targetOverrides: targetOverrides,
    );
  }

  Future<ChronicCondition> updateCondition({
    required int conditionId,
    required int conditionTypeId,
    DateTime? diagnosisDate,
    required String severityCode,
    required String status,
    String notes = '',
    Map<String, dynamic> profileData = const {},
    bool isActive = true,
    List<ConditionTargetOverridePayload>? targetOverrides,
  }) {
    return _api.updateCondition(
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
  }

  Future<void> deactivateCondition(int conditionId) {
    return _api.deactivateCondition(conditionId);
  }

  Future<void> createMedication(ChronicMedicationPayload payload) {
    return _api.createMedication(payload);
  }

  Future<void> updateMedication(ChronicMedicationPayload payload) {
    return _api.updateMedication(payload);
  }

  Future<void> deactivateMedication(int medicationId) {
    return _api.deactivateMedication(medicationId);
  }

  Future<DoseActionResult> markMedicationTaken(int scheduleId) {
    return _api.markMedicationTaken(scheduleId);
  }

  Future<DoseActionResult> markMedicationMissed(int scheduleId) {
    return _api.markMedicationMissed(scheduleId);
  }

  Future<DoseActionResult> snoozeMedicationDose(
    int scheduleId, {
    required int snoozeMinutes,
  }) {
    return _api.snoozeMedicationDose(scheduleId, snoozeMinutes: snoozeMinutes);
  }

  Future<DoseActionResult> skipMedicationDose(
    int scheduleId, {
    required String reason,
  }) {
    return _api.skipMedicationDose(scheduleId, reason: reason);
  }

  Future<ConditionReadingResult> logReading({
    required int conditionId,
    required Map<String, dynamic> payload,
  }) {
    return _api.logReading(conditionId: conditionId, payload: payload);
  }

  Future<ChronicCondition> getCondition(int conditionId) {
    return _api.getCondition(conditionId);
  }
}
