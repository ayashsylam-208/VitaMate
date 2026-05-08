DateTime? _parseProfileDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

DateTime _parseProfileTime(String? value, {required DateTime fallback}) {
  if (value == null || value.isEmpty) return fallback;
  return DateTime.tryParse('2000-01-01 $value') ?? fallback;
}

class UserProfileSettings {
  const UserProfileSettings({
    required this.weight,
    required this.height,
    required this.activityLevel,
    required this.goal,
    required this.dailyStepGoal,
    required this.gender,
    required this.birthDate,
    required this.recommendedSleepHours,
    required this.targetWakeTime,
    required this.targetBedTime,
    required this.enableSleepImprovement,
    required this.preferredActivityType,
    required this.enableActivityReminders,
    required this.activityReminderIntervalHours,
    required this.activityReminderTime,
    required this.activityReminderDays,
    required this.inactiveReminderEnabled,
    required this.inactiveReminderHours,
    required this.enableWaterReminders,
    required this.waterReminderIntervalMinutes,
  });

  final double weight;
  final double height;
  final double activityLevel;
  final String goal;
  final int dailyStepGoal;
  final String gender;
  final DateTime? birthDate;
  final double recommendedSleepHours;
  final DateTime targetWakeTime;
  final DateTime targetBedTime;
  final bool enableSleepImprovement;
  final String preferredActivityType;
  final bool enableActivityReminders;
  final int activityReminderIntervalHours;
  final DateTime activityReminderTime;
  final List<int> activityReminderDays;
  final bool inactiveReminderEnabled;
  final int inactiveReminderHours;
  final bool enableWaterReminders;
  final int waterReminderIntervalMinutes;

  factory UserProfileSettings.fromJson(Map<String, dynamic> json) {
    return UserProfileSettings(
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
      activityLevel: (json['activity_level'] as num?)?.toDouble() ?? 1.2,
      goal: json['goal']?.toString() ?? 'maintain',
      dailyStepGoal: (json['daily_step_goal'] as num?)?.toInt() ?? 0,
      gender: json['gender']?.toString() ?? '',
      birthDate: _parseProfileDate(json['birth_date']?.toString()),
      recommendedSleepHours:
          (json['recommended_sleep_hours'] as num?)?.toDouble() ?? 8.0,
      targetWakeTime: _parseProfileTime(
        json['target_wake_time']?.toString(),
        fallback: DateTime(2000, 1, 1, 7),
      ),
      targetBedTime: _parseProfileTime(
        json['target_bed_time']?.toString(),
        fallback: DateTime(2000, 1, 1, 23),
      ),
      enableSleepImprovement: json['enable_sleep_improvement'] == true,
      preferredActivityType:
          json['preferred_activity_type']?.toString() ?? 'home',
      enableActivityReminders: json['enable_activity_reminders'] == true,
      activityReminderIntervalHours:
          (json['activity_reminder_interval_hours'] as num?)?.toInt() ?? 2,
      activityReminderTime: _parseProfileTime(
        json['activity_reminder_time']?.toString(),
        fallback: DateTime(2000, 1, 1, 10),
      ),
      activityReminderDays: _parseReminderDays(json['activity_reminder_days']),
      inactiveReminderEnabled: json['inactive_reminder_enabled'] == true,
      inactiveReminderHours:
          (json['inactive_reminder_hours'] as num?)?.toInt() ?? 3,
      enableWaterReminders: json['enable_water_reminders'] == true,
      waterReminderIntervalMinutes:
          (json['water_reminder_interval_minutes'] as num?)?.toInt() ?? 60,
    );
  }
}

List<int> _parseReminderDays(dynamic value) {
  if (value is List) {
    return value
        .map((item) => int.tryParse(item.toString()) ?? 0)
        .where((item) => item >= 1 && item <= 7)
        .toList(growable: false);
  }
  return const <int>[];
}
