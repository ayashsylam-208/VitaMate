import '../models/medication_adherence_summary.dart';
import '../models/medication_dose_log.dart';
import '../models/medication_item.dart';
import '../models/reminder_sync_payload.dart';
import 'medications_api.dart';

class MedicationsRepository {
  MedicationsRepository({MedicationsApi? api}) : _api = api ?? MedicationsApi();

  final MedicationsApi _api;

  Future<List<MedicationItem>> getMedications() async {
    final raw = await _api.fetchMedications();
    return raw
        .map(
          (item) =>
              MedicationItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<MedicationItem> createMedication(Map<String, dynamic> payload) async {
    final raw = await _api.createMedication(payload);
    return MedicationItem.fromJson(
      Map<String, dynamic>.from(raw['medication'] as Map),
    );
  }

  Future<MedicationItem> updateMedication(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final raw = await _api.updateMedication(id, payload);
    return MedicationItem.fromJson(
      Map<String, dynamic>.from(raw['medication'] as Map),
    );
  }

  Future<MedicationItem> deactivateMedication(int id) async {
    final raw = await _api.deactivateMedication(id);
    return MedicationItem.fromJson(
      Map<String, dynamic>.from(raw['medication'] as Map),
    );
  }

  Future<List<MedicationDoseLog>> getTodayPlan() async {
    final raw = await _api.fetchTodayPlan();
    return raw
        .map(
          (item) => MedicationDoseLog.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<MedicationDoseLog> markTaken(
    int logId, {
    DateTime? takenAt,
    String? doseTakenAmount,
  }) async {
    final raw = await _api.markDoseTaken(logId, {
      if (takenAt != null) 'taken_at': takenAt.toIso8601String(),
      if (doseTakenAmount != null && doseTakenAmount.trim().isNotEmpty)
        'dose_taken_amount': doseTakenAmount.trim(),
    });
    return MedicationDoseLog.fromJson(raw);
  }

  Future<MedicationDoseLog> markMissed(int logId) async {
    final raw = await _api.markDoseMissed(logId);
    return MedicationDoseLog.fromJson(raw);
  }

  Future<MedicationDoseLog> markSkipped(int logId, {String reason = ''}) async {
    final raw = await _api.markDoseSkipped(logId, {'reason': reason});
    return MedicationDoseLog.fromJson(raw);
  }

  Future<MedicationDoseLog> snooze(int logId, DateTime snoozedUntil) async {
    final raw = await _api.snoozeDose(logId, {
      'snoozed_until': snoozedUntil.toIso8601String(),
    });
    return MedicationDoseLog.fromJson(raw);
  }

  Future<MedicationAdherenceSummary> getMedicationAdherence(
    int medicationId,
  ) async {
    return MedicationAdherenceSummary.fromJson(
      await _api.fetchMedicationAdherence(medicationId),
    );
  }

  Future<MedicationAdherenceSummary> getOverallAdherence() async {
    return MedicationAdherenceSummary.fromJson(
      await _api.fetchOverallAdherence(),
    );
  }

  Future<ReminderSyncPayload> getReminderSync() async {
    return ReminderSyncPayload.fromJson(await _api.fetchReminderSync());
  }
}
