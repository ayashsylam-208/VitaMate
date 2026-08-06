class MedicationDoseLog {
  final int logId;
  final int medicationId;
  final String displayName;
  final int? linkedConditionId;
  final String? linkedConditionName;
  final DateTime? scheduledFor;
  final String status;
  final String rawStatus;
  final DateTime? snoozedUntil;
  final DateTime? takenAt;
  final String doseAmount;
  final String doseUnit;
  final String form;
  final String mealRelation;
  final String notes;
  final int pointsApplied;
  final String? scheduledDate;
  final bool isPrn;

  const MedicationDoseLog({
    required this.logId,
    required this.medicationId,
    required this.displayName,
    required this.linkedConditionId,
    required this.linkedConditionName,
    required this.scheduledFor,
    required this.status,
    required this.rawStatus,
    required this.snoozedUntil,
    required this.takenAt,
    required this.doseAmount,
    required this.doseUnit,
    required this.form,
    required this.mealRelation,
    required this.notes,
    required this.pointsApplied,
    required this.scheduledDate,
    required this.isPrn,
  });

  factory MedicationDoseLog.fromJson(Map<String, dynamic> json) {
    final linked = _asMap(json['linked_condition']);
    return MedicationDoseLog(
      logId: _asInt(json['log_id']),
      medicationId: _asInt(json['medication_id']),
      displayName: (json['display_name'] ?? '').toString(),
      linkedConditionId: linked['id'] == null ? null : _asInt(linked['id']),
      linkedConditionName:
          json['linked_condition_name']?.toString() ??
          linked['name']?.toString(),
      scheduledFor: DateTime.tryParse((json['scheduled_for'] ?? '').toString()),
      status: (json['status'] ?? 'pending').toString(),
      rawStatus: (json['raw_status'] ?? json['status'] ?? 'pending').toString(),
      snoozedUntil: DateTime.tryParse((json['snoozed_until'] ?? '').toString()),
      takenAt: DateTime.tryParse((json['taken_at'] ?? '').toString()),
      doseAmount: (json['dose_amount'] ?? '').toString(),
      doseUnit: (json['dose_unit'] ?? '').toString(),
      form: (json['form'] ?? '').toString(),
      mealRelation: (json['meal_relation'] ?? 'none').toString(),
      notes: (json['notes'] ?? '').toString(),
      pointsApplied: _asInt(json['points_applied']),
      scheduledDate: json['scheduled_date']?.toString(),
      isPrn: _asBool(json['is_prn']),
    );
  }

  String get doseLabel => [
    doseAmount,
    doseUnit,
    form,
  ].where((item) => item.trim().isNotEmpty).join(' ');
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return false;
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
