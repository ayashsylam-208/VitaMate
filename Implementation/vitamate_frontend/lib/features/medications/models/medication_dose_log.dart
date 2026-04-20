class MedicationDoseLog {
  final int logId;
  final int medicationId;
  final String displayName;
  final int? linkedConditionId;
  final String? linkedConditionName;
  final DateTime? scheduledFor;
  final String status;
  final DateTime? snoozedUntil;
  final String doseAmount;
  final String doseUnit;
  final String form;

  const MedicationDoseLog({
    required this.logId,
    required this.medicationId,
    required this.displayName,
    required this.linkedConditionId,
    required this.linkedConditionName,
    required this.scheduledFor,
    required this.status,
    required this.snoozedUntil,
    required this.doseAmount,
    required this.doseUnit,
    required this.form,
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
      snoozedUntil: DateTime.tryParse((json['snoozed_until'] ?? '').toString()),
      doseAmount: (json['dose_amount'] ?? '').toString(),
      doseUnit: (json['dose_unit'] ?? '').toString(),
      form: (json['form'] ?? '').toString(),
    );
  }

  String get doseLabel => [
    doseAmount,
    doseUnit,
    form,
  ].where((item) => item.trim().isNotEmpty).join(' ');
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
