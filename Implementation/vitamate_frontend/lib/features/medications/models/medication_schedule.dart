class MedicationSchedule {
  final int id;
  final String scheduleType;
  final String time;
  final List<int> daysOfWeek;
  final int? intervalHours;
  final String mealRelation;
  final int gracePeriodMinutes;
  final int snoozeDefaultMinutes;
  final bool isActive;

  const MedicationSchedule({
    required this.id,
    required this.scheduleType,
    required this.time,
    required this.daysOfWeek,
    required this.intervalHours,
    required this.mealRelation,
    required this.gracePeriodMinutes,
    required this.snoozeDefaultMinutes,
    required this.isActive,
  });

  factory MedicationSchedule.fromJson(Map<String, dynamic> json) {
    return MedicationSchedule(
      id: _asInt(json['id']),
      scheduleType: (json['schedule_type'] ?? 'daily').toString(),
      time: (json['time'] ?? json['time_of_day'] ?? '').toString(),
      daysOfWeek: _asIntList(json['days_of_week'] ?? json['recurrence_days']),
      intervalHours: json['interval_hours'] == null
          ? null
          : _asInt(json['interval_hours']),
      mealRelation: (json['meal_relation'] ?? 'none').toString(),
      gracePeriodMinutes: _asInt(json['grace_period_minutes'], fallback: 60),
      snoozeDefaultMinutes: _asInt(
        json['snooze_default_minutes'],
        fallback: 15,
      ),
      isActive: _asBool(json['is_active'], fallback: true),
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'schedule_type': scheduleType,
      'time': time,
      'days_of_week': daysOfWeek,
      if (intervalHours != null) 'interval_hours': intervalHours,
      'meal_relation': mealRelation,
      'grace_period_minutes': gracePeriodMinutes,
      'snooze_default_minutes': snoozeDefaultMinutes,
      'is_active': isActive,
    };
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return fallback;
}

List<int> _asIntList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => _asInt(item)).toList();
}
