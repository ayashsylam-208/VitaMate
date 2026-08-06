DateTime _parseTimeOfDay(String? value, {required DateTime fallback}) {
  if (value == null || value.isEmpty) {
    return fallback;
  }
  return DateTime.tryParse('2000-01-01 $value') ?? fallback;
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.enableRoutineReminders,
    required this.enableMotivationReminders,
    required this.enableHealthAlerts,
    required this.enableMedicationReminders,
    required this.enableSleepReminders,
    required this.enableWaterReminders,
    required this.enableMealReminders,
    required this.enableActivityReminders,
    required this.enableStepReminders,
    required this.enableHabitReminders,
    required this.quietHoursEnabled,
    required this.quietStart,
    required this.quietEnd,
    required this.motivationMaxPerDay,
    required this.motivationTypeCooldownHours,
    required this.criticalBypassQuietHours,
    required this.breakfastReminderTime,
    required this.lunchReminderTime,
    required this.dinnerReminderTime,
    required this.stepsReminderTime,
    required this.dailyWaterTargetMl,
    required this.waterReminderIntervalMinutes,
    required this.waterReminderStartTime,
    required this.waterReminderEndTime,
    required this.activityReminderIntervalHours,
    required this.activityReminderTime,
    required this.activityReminderDays,
    required this.inactiveReminderEnabled,
    required this.inactiveReminderHours,
    required this.targetWakeTime,
    required this.targetBedTime,
    required this.updatedAt,
  });

  final bool enableRoutineReminders;
  final bool enableMotivationReminders;
  final bool enableHealthAlerts;
  final bool enableMedicationReminders;
  final bool enableSleepReminders;
  final bool enableWaterReminders;
  final bool enableMealReminders;
  final bool enableActivityReminders;
  final bool enableStepReminders;
  final bool enableHabitReminders;
  final bool quietHoursEnabled;
  final DateTime? quietStart;
  final DateTime? quietEnd;
  final int motivationMaxPerDay;
  final int motivationTypeCooldownHours;
  final bool criticalBypassQuietHours;
  final DateTime breakfastReminderTime;
  final DateTime lunchReminderTime;
  final DateTime dinnerReminderTime;
  final DateTime stepsReminderTime;
  final int dailyWaterTargetMl;
  final int waterReminderIntervalMinutes;
  final DateTime waterReminderStartTime;
  final DateTime waterReminderEndTime;
  final int activityReminderIntervalHours;
  final DateTime activityReminderTime;
  final List<int> activityReminderDays;
  final bool inactiveReminderEnabled;
  final int inactiveReminderHours;
  final DateTime targetWakeTime;
  final DateTime? targetBedTime;
  final DateTime? updatedAt;

  factory NotificationPreferences.defaults() {
    return NotificationPreferences.fromJson(const <String, dynamic>{});
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      enableRoutineReminders: json['enable_routine_reminders'] != false,
      enableMotivationReminders: json['enable_motivation_reminders'] != false,
      enableHealthAlerts: json['enable_health_alerts'] != false,
      enableMedicationReminders: json['enable_medication_reminders'] != false,
      enableSleepReminders: json['enable_sleep_reminders'] == true,
      enableWaterReminders: json['enable_water_reminders'] != false,
      enableMealReminders: json['enable_meal_reminders'] == true,
      enableActivityReminders: json['enable_activity_reminders'] != false,
      enableStepReminders: json['enable_step_reminders'] == true,
      enableHabitReminders: json['enable_habit_reminders'] != false,
      quietHoursEnabled: json['quiet_hours_enabled'] == true,
      quietStart: json['quiet_start'] == null
          ? null
          : _parseTimeOfDay(
              json['quiet_start']?.toString(),
              fallback: DateTime(2000, 1, 1, 22),
            ),
      quietEnd: json['quiet_end'] == null
          ? null
          : _parseTimeOfDay(
              json['quiet_end']?.toString(),
              fallback: DateTime(2000, 1, 1, 7),
            ),
      motivationMaxPerDay:
          int.tryParse((json['motivation_max_per_day'] ?? '2').toString()) ?? 2,
      motivationTypeCooldownHours:
          int.tryParse(
            (json['motivation_type_cooldown_hours'] ?? '6').toString(),
          ) ??
          6,
      criticalBypassQuietHours: json['critical_bypass_quiet_hours'] != false,
      breakfastReminderTime: _parseTimeOfDay(
        json['breakfast_reminder_time']?.toString(),
        fallback: DateTime(2000, 1, 1, 9),
      ),
      lunchReminderTime: _parseTimeOfDay(
        json['lunch_reminder_time']?.toString(),
        fallback: DateTime(2000, 1, 1, 13),
      ),
      dinnerReminderTime: _parseTimeOfDay(
        json['dinner_reminder_time']?.toString(),
        fallback: DateTime(2000, 1, 1, 20),
      ),
      stepsReminderTime: _parseTimeOfDay(
        json['steps_reminder_time']?.toString(),
        fallback: DateTime(2000, 1, 1, 11),
      ),
      dailyWaterTargetMl:
          int.tryParse((json['daily_water_target_ml'] ?? '0').toString()) ?? 0,
      waterReminderIntervalMinutes:
          int.tryParse(
            (json['water_reminder_interval_minutes'] ?? '60').toString(),
          ) ??
          60,
      waterReminderStartTime: _parseTimeOfDay(
        json['water_reminder_start_time']?.toString(),
        fallback: DateTime(2000, 1, 1, 9),
      ),
      waterReminderEndTime: _parseTimeOfDay(
        json['water_reminder_end_time']?.toString(),
        fallback: DateTime(2000, 1, 1, 21),
      ),
      activityReminderIntervalHours:
          int.tryParse(
            (json['activity_reminder_interval_hours'] ?? '2').toString(),
          ) ??
          2,
      activityReminderTime: _parseTimeOfDay(
        json['activity_reminder_time']?.toString(),
        fallback: DateTime(2000, 1, 1, 10),
      ),
      activityReminderDays:
          ((json['activity_reminder_days'] as List?) ?? const [])
              .map((item) => int.tryParse(item.toString()) ?? 0)
              .where((item) => item >= 1 && item <= 7)
              .toList(growable: false),
      inactiveReminderEnabled: json['inactive_reminder_enabled'] == true,
      inactiveReminderHours:
          int.tryParse((json['inactive_reminder_hours'] ?? '3').toString()) ??
          3,
      targetWakeTime: _parseTimeOfDay(
        json['target_wake_time']?.toString(),
        fallback: DateTime(2000, 1, 1, 7),
      ),
      targetBedTime: json['target_bed_time'] == null
          ? null
          : _parseTimeOfDay(
              json['target_bed_time']?.toString(),
              fallback: DateTime(2000, 1, 1, 23),
            ),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enable_routine_reminders': enableRoutineReminders,
      'enable_motivation_reminders': enableMotivationReminders,
      'enable_health_alerts': enableHealthAlerts,
      'enable_medication_reminders': enableMedicationReminders,
      'enable_sleep_reminders': enableSleepReminders,
      'enable_water_reminders': enableWaterReminders,
      'enable_meal_reminders': enableMealReminders,
      'enable_activity_reminders': enableActivityReminders,
      'enable_step_reminders': enableStepReminders,
      'enable_habit_reminders': enableHabitReminders,
      'quiet_hours_enabled': quietHoursEnabled,
      'quiet_start': quietStart == null
          ? null
          : '${quietStart!.hour.toString().padLeft(2, '0')}:${quietStart!.minute.toString().padLeft(2, '0')}:00',
      'quiet_end': quietEnd == null
          ? null
          : '${quietEnd!.hour.toString().padLeft(2, '0')}:${quietEnd!.minute.toString().padLeft(2, '0')}:00',
      'motivation_max_per_day': motivationMaxPerDay,
      'motivation_type_cooldown_hours': motivationTypeCooldownHours,
      'critical_bypass_quiet_hours': criticalBypassQuietHours,
      'breakfast_reminder_time':
          '${breakfastReminderTime.hour.toString().padLeft(2, '0')}:${breakfastReminderTime.minute.toString().padLeft(2, '0')}:00',
      'lunch_reminder_time':
          '${lunchReminderTime.hour.toString().padLeft(2, '0')}:${lunchReminderTime.minute.toString().padLeft(2, '0')}:00',
      'dinner_reminder_time':
          '${dinnerReminderTime.hour.toString().padLeft(2, '0')}:${dinnerReminderTime.minute.toString().padLeft(2, '0')}:00',
      'steps_reminder_time':
          '${stepsReminderTime.hour.toString().padLeft(2, '0')}:${stepsReminderTime.minute.toString().padLeft(2, '0')}:00',
      'daily_water_target_ml': dailyWaterTargetMl,
      'water_reminder_interval_minutes': waterReminderIntervalMinutes,
      'water_reminder_start_time':
          '${waterReminderStartTime.hour.toString().padLeft(2, '0')}:${waterReminderStartTime.minute.toString().padLeft(2, '0')}:00',
      'water_reminder_end_time':
          '${waterReminderEndTime.hour.toString().padLeft(2, '0')}:${waterReminderEndTime.minute.toString().padLeft(2, '0')}:00',
      'activity_reminder_interval_hours': activityReminderIntervalHours,
      'activity_reminder_time':
          '${activityReminderTime.hour.toString().padLeft(2, '0')}:${activityReminderTime.minute.toString().padLeft(2, '0')}:00',
      'activity_reminder_days': activityReminderDays,
      'inactive_reminder_enabled': inactiveReminderEnabled,
      'inactive_reminder_hours': inactiveReminderHours,
      'target_wake_time':
          '${targetWakeTime.hour.toString().padLeft(2, '0')}:${targetWakeTime.minute.toString().padLeft(2, '0')}:00',
      'target_bed_time': targetBedTime == null
          ? null
          : '${targetBedTime!.hour.toString().padLeft(2, '0')}:${targetBedTime!.minute.toString().padLeft(2, '0')}:00',
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
