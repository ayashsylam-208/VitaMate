import '../../../auth/models/user_profile.dart';
import '../../../core/notification_hub/models/notification_preferences.dart';

class ActivityReminderSettings {
  const ActivityReminderSettings({
    required this.dailyReminderEnabled,
    required this.reminderTime,
    required this.reminderDays,
    required this.inactiveReminderEnabled,
    required this.inactiveReminderHours,
    required this.legacyIntervalHours,
  });

  final bool dailyReminderEnabled;
  final DateTime reminderTime;
  final List<int> reminderDays;
  final bool inactiveReminderEnabled;
  final int inactiveReminderHours;
  final int legacyIntervalHours;

  factory ActivityReminderSettings.defaults() {
    return ActivityReminderSettings(
      dailyReminderEnabled: false,
      reminderTime: DateTime(2000, 1, 1, 10),
      reminderDays: const <int>[1, 2, 3, 4, 5, 6, 7],
      inactiveReminderEnabled: false,
      inactiveReminderHours: 3,
      legacyIntervalHours: 2,
    );
  }

  factory ActivityReminderSettings.fromProfile(UserProfileSettings profile) {
    final days = profile.activityReminderDays.isEmpty
        ? const <int>[1, 2, 3, 4, 5, 6, 7]
        : profile.activityReminderDays;
    return ActivityReminderSettings(
      dailyReminderEnabled: profile.enableActivityReminders,
      reminderTime: profile.activityReminderTime,
      reminderDays: days,
      inactiveReminderEnabled: profile.inactiveReminderEnabled,
      inactiveReminderHours: profile.inactiveReminderHours,
      legacyIntervalHours: profile.activityReminderIntervalHours,
    );
  }

  factory ActivityReminderSettings.fromNotificationPreferences(
    NotificationPreferences preferences,
  ) {
    final days = preferences.activityReminderDays.isEmpty
        ? const <int>[1, 2, 3, 4, 5, 6, 7]
        : preferences.activityReminderDays;
    return ActivityReminderSettings(
      dailyReminderEnabled: preferences.enableActivityReminders,
      reminderTime: preferences.activityReminderTime,
      reminderDays: days,
      inactiveReminderEnabled: preferences.inactiveReminderEnabled,
      inactiveReminderHours: preferences.inactiveReminderHours,
      legacyIntervalHours: preferences.activityReminderIntervalHours,
    );
  }

  ActivityReminderSettings copyWith({
    bool? dailyReminderEnabled,
    DateTime? reminderTime,
    List<int>? reminderDays,
    bool? inactiveReminderEnabled,
    int? inactiveReminderHours,
    int? legacyIntervalHours,
  }) {
    return ActivityReminderSettings(
      dailyReminderEnabled:
          dailyReminderEnabled ?? this.dailyReminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderDays: reminderDays ?? this.reminderDays,
      inactiveReminderEnabled:
          inactiveReminderEnabled ?? this.inactiveReminderEnabled,
      inactiveReminderHours:
          inactiveReminderHours ?? this.inactiveReminderHours,
      legacyIntervalHours: legacyIntervalHours ?? this.legacyIntervalHours,
    );
  }

  Map<String, dynamic> toPatchPayload() {
    final hour = reminderTime.hour.toString().padLeft(2, '0');
    final minute = reminderTime.minute.toString().padLeft(2, '0');
    return <String, dynamic>{
      'enable_activity_reminders': dailyReminderEnabled,
      'activity_reminder_time': '$hour:$minute:00',
      'activity_reminder_days': reminderDays,
      'inactive_reminder_enabled': inactiveReminderEnabled,
      'inactive_reminder_hours': inactiveReminderHours,
      'activity_reminder_interval_hours': inactiveReminderHours,
    };
  }
}
