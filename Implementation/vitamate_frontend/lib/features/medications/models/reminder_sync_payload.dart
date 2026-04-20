class ReminderSyncPayload {
  final List<ReminderSyncItem> items;

  const ReminderSyncPayload({required this.items});

  factory ReminderSyncPayload.empty() => const ReminderSyncPayload(items: []);

  factory ReminderSyncPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (item) =>
                    ReminderSyncItem.fromJson(item.cast<String, dynamic>()),
              )
              .toList()
        : <ReminderSyncItem>[];
    return ReminderSyncPayload(items: items);
  }
}

class ReminderSyncItem {
  final int medicationId;
  final int scheduleId;
  final String displayName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String timezone;
  final List<String> scheduledTimes;
  final List<int> daysOfWeek;
  final String mealRelation;
  final int snoozeDefaultMinutes;
  final int reminderLeadMinutes;
  final String? linkedConditionName;

  const ReminderSyncItem({
    required this.medicationId,
    required this.scheduleId,
    required this.displayName,
    required this.startDate,
    required this.endDate,
    required this.timezone,
    required this.scheduledTimes,
    required this.daysOfWeek,
    required this.mealRelation,
    required this.snoozeDefaultMinutes,
    required this.reminderLeadMinutes,
    required this.linkedConditionName,
  });

  factory ReminderSyncItem.fromJson(Map<String, dynamic> json) {
    final linked = _asMap(json['linked_condition']);
    return ReminderSyncItem(
      medicationId: _asInt(json['medication_id']),
      scheduleId: _asInt(json['schedule_id']),
      displayName: (json['display_name'] ?? '').toString(),
      startDate: DateTime.tryParse((json['start_date'] ?? '').toString()),
      endDate: DateTime.tryParse((json['end_date'] ?? '').toString()),
      timezone: (json['timezone'] ?? 'UTC').toString(),
      scheduledTimes: _asStringList(json['scheduled_times']),
      daysOfWeek: _asIntList(json['days_of_week']),
      mealRelation: (json['meal_relation'] ?? 'none').toString(),
      snoozeDefaultMinutes: _asInt(
        json['snooze_default_minutes'],
        fallback: 15,
      ),
      reminderLeadMinutes: _asInt(json['reminder_lead_minutes'], fallback: 15),
      linkedConditionName: linked['name']?.toString(),
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}

List<int> _asIntList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => _asInt(item)).toList();
}
