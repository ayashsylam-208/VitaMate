class MedicationAdherenceSummary {
  final int? medicationId;
  final int expectedDoses;
  final int takenDoses;
  final int missedDoses;
  final int skippedDoses;
  final int pendingDoses;
  final int overdueDoses;
  final double adherencePercent;
  final int streakDays;
  final double onTimePercent;

  const MedicationAdherenceSummary({
    required this.medicationId,
    required this.expectedDoses,
    required this.takenDoses,
    required this.missedDoses,
    required this.skippedDoses,
    required this.pendingDoses,
    required this.overdueDoses,
    required this.adherencePercent,
    required this.streakDays,
    required this.onTimePercent,
  });

  factory MedicationAdherenceSummary.empty() {
    return const MedicationAdherenceSummary(
      medicationId: null,
      expectedDoses: 0,
      takenDoses: 0,
      missedDoses: 0,
      skippedDoses: 0,
      pendingDoses: 0,
      overdueDoses: 0,
      adherencePercent: 0,
      streakDays: 0,
      onTimePercent: 0,
    );
  }

  factory MedicationAdherenceSummary.fromJson(Map<String, dynamic> json) {
    return MedicationAdherenceSummary(
      medicationId: json['medication_id'] == null
          ? null
          : _asInt(json['medication_id']),
      expectedDoses: _asInt(json['expected_doses']),
      takenDoses: _asInt(json['taken_doses']),
      missedDoses: _asInt(json['missed_doses']),
      skippedDoses: _asInt(json['skipped_doses']),
      pendingDoses: _asInt(json['pending_doses']),
      overdueDoses: _asInt(json['overdue_doses']),
      adherencePercent: _asDouble(json['adherence_percent']),
      streakDays: _asInt(json['streak_days']),
      onTimePercent: _asDouble(json['on_time_percent']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
