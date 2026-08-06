import '../models/medication_adherence_summary.dart';
import '../models/medication_dose_log.dart';
import '../models/medication_history.dart';
import '../models/medication_item.dart';
import '../models/medication_today_plan.dart';
import 'medications_api.dart';

class MedicationsOverviewData {
  const MedicationsOverviewData({
    required this.medications,
    required this.todayPlan,
    required this.overallAdherence,
    required this.todayAdherence,
    required this.nextDose,
    required this.streak,
    required this.shortcutCounts,
    required this.motivationStrip,
  });

  final List<MedicationItem> medications;
  final List<MedicationDoseLog> todayPlan;
  final MedicationAdherenceSummary overallAdherence;
  final MedicationTodaySummary todayAdherence;
  final MedicationDoseLog? nextDose;
  final int streak;
  final Map<String, dynamic> shortcutCounts;
  final Map<String, dynamic>? motivationStrip;
}

class MedicationsRepository {
  MedicationsRepository({MedicationsApi? api}) : _api = api ?? MedicationsApi();

  final MedicationsApi _api;

  Future<MedicationsOverviewData> getOverview() async {
    final raw = _overviewData(await _api.fetchOverview());
    final medicationsRaw = raw['medications'];
    final todayPlanRaw = raw['today_plan'];
    return MedicationsOverviewData(
      medications: medicationsRaw is List
          ? medicationsRaw
                .map(
                  (item) => MedicationItem.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(growable: false)
          : const <MedicationItem>[],
      todayPlan: todayPlanRaw is List
          ? todayPlanRaw
                .map(
                  (item) => MedicationDoseLog.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(growable: false)
          : const <MedicationDoseLog>[],
      overallAdherence: MedicationAdherenceSummary.fromJson(
        Map<String, dynamic>.from(
          (raw['overall_adherence'] as Map?) ?? const {},
        ),
      ),
      todayAdherence: MedicationTodaySummary.fromJson(
        _asMap(raw['today_adherence']),
      ),
      nextDose: raw['next_dose'] is Map
          ? MedicationDoseLog.fromJson(_asMap(raw['next_dose']))
          : null,
      streak: _asInt(raw['streak']),
      shortcutCounts: _asMap(raw['shortcut_counts']),
      motivationStrip: raw['motivation_strip'] is Map
          ? _asMap(raw['motivation_strip'])
          : null,
    );
  }

  Map<String, dynamic> _overviewData(Map<String, dynamic> raw) {
    final data = raw['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return raw;
  }

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

  Future<MedicationTodayPlanData> getTodayPlanData({String? date}) async {
    return MedicationTodayPlanData.fromJson(
      await _api.fetchTodayPlan(date: date),
    );
  }

  Future<List<MedicationDoseLog>> getTodayPlan({String? date}) async {
    return (await getTodayPlanData(date: date)).doses;
  }

  Future<Map<String, dynamic>> materializePlans() {
    return _api.materializePlans();
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
    return _doseLogFromAction(raw);
  }

  Future<MedicationDoseLog> markMissed(int logId) async {
    final raw = await _api.markDoseMissed(logId);
    return _doseLogFromAction(raw);
  }

  Future<MedicationDoseLog> markSkipped(int logId, {String reason = ''}) async {
    final raw = await _api.markDoseSkipped(logId, {'reason': reason});
    return _doseLogFromAction(raw);
  }

  Future<MedicationDoseLog> snooze(int logId, DateTime snoozedUntil) async {
    final raw = await _api.snoozeDose(logId, {
      'snoozed_until': snoozedUntil.toIso8601String(),
    });
    return _doseLogFromAction(raw);
  }

  Future<MedicationDoseLog> logPrnDose(
    int medicationId, {
    DateTime? takenAt,
    String? doseTakenAmount,
    String notes = '',
  }) async {
    final raw = await _api.logPrnDose(medicationId, {
      if (takenAt != null) 'taken_at': takenAt.toIso8601String(),
      if (doseTakenAmount != null && doseTakenAmount.trim().isNotEmpty)
        'dose_taken_amount': doseTakenAmount.trim(),
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return _doseLogFromAction(raw);
  }

  Future<MedicationHistoryPage> getHistory({
    String status = 'all',
    int page = 1,
    int pageSize = 30,
  }) async {
    return MedicationHistoryPage.fromJson(
      await _api.fetchMedicationHistory(
        status: status,
        page: page,
        pageSize: pageSize,
      ),
    );
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

  MedicationDoseLog _doseLogFromAction(Map<String, dynamic> raw) {
    final doseRaw = raw['dose_log'];
    if (doseRaw is Map) {
      return MedicationDoseLog.fromJson(doseRaw.cast<String, dynamic>());
    }
    return MedicationDoseLog.fromJson(raw);
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}
