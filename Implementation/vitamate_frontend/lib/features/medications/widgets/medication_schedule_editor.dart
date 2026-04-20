import 'package:flutter/material.dart';

class MedicationScheduleDraft {
  final String scheduleType;
  final TimeOfDay time;
  final List<int> daysOfWeek;
  final String mealRelation;
  final int gracePeriodMinutes;
  final int snoozeDefaultMinutes;

  const MedicationScheduleDraft({
    required this.scheduleType,
    required this.time,
    this.daysOfWeek = const [],
    this.mealRelation = 'none',
    this.gracePeriodMinutes = 60,
    this.snoozeDefaultMinutes = 15,
  });

  Map<String, dynamic> toPayload() {
    return {
      'schedule_type': scheduleType,
      'time':
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'days_of_week': daysOfWeek,
      'meal_relation': mealRelation,
      'grace_period_minutes': gracePeriodMinutes,
      'snooze_default_minutes': snoozeDefaultMinutes,
    };
  }
}
