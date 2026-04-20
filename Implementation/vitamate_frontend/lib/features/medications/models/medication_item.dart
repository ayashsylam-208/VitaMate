import 'medication_adherence_summary.dart';
import 'medication_schedule.dart';

class MedicationItem {
  final int id;
  final String displayName;
  final String sourceType;
  final int? linkedConditionId;
  final String? linkedConditionName;
  final String doseAmount;
  final String doseUnit;
  final String dosage;
  final String form;
  final String instructions;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final bool isPrn;
  final String timezone;
  final DateTime? nextDue;
  final MedicationAdherenceSummary adherenceSummaryShort;
  final List<MedicationSchedule> schedules;

  const MedicationItem({
    required this.id,
    required this.displayName,
    required this.sourceType,
    required this.linkedConditionId,
    required this.linkedConditionName,
    required this.doseAmount,
    required this.doseUnit,
    required this.dosage,
    required this.form,
    required this.instructions,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.isPrn,
    required this.timezone,
    required this.nextDue,
    required this.adherenceSummaryShort,
    required this.schedules,
  });

  factory MedicationItem.fromJson(Map<String, dynamic> json) {
    return MedicationItem(
      id: _asInt(json['id']),
      displayName: (json['display_name'] ?? json['name'] ?? '').toString(),
      sourceType: (json['source_type'] ?? 'manual').toString(),
      linkedConditionId: json['linked_condition_id'] == null
          ? null
          : _asInt(json['linked_condition_id']),
      linkedConditionName: json['linked_condition_name']?.toString(),
      doseAmount: (json['dose_amount'] ?? '').toString(),
      doseUnit: (json['dose_unit'] ?? '').toString(),
      dosage: (json['dosage'] ?? '').toString(),
      form: (json['form'] ?? '').toString(),
      instructions: (json['instructions'] ?? '').toString(),
      startDate: DateTime.tryParse((json['start_date'] ?? '').toString()),
      endDate: DateTime.tryParse((json['end_date'] ?? '').toString()),
      isActive: _asBool(json['is_active'], fallback: true),
      isPrn: _asBool(json['is_prn']),
      timezone: (json['timezone'] ?? 'UTC').toString(),
      nextDue: DateTime.tryParse((json['next_due'] ?? '').toString()),
      adherenceSummaryShort: MedicationAdherenceSummary.fromJson(
        _asMap(json['adherence_summary_short']),
      ),
      schedules: _asMapList(
        json['schedules'],
      ).map(MedicationSchedule.fromJson).toList(),
    );
  }

  String get doseLabel {
    final parts = [
      doseAmount,
      doseUnit,
      form,
    ].where((item) => item.trim().isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' ');
    return dosage;
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return fallback;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList();
}
