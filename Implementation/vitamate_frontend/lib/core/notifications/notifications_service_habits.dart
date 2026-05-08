part of 'notifications_service.dart';

Future<void> _syncUnhealthyHabitReminders(
  List<UnhealthyHabitReminderPlan> plans,
) async {
  await NotificationsService.ensurePermission();
  await NotificationsService.ensureExactAlarmPermission();
  await _cancelUnhealthyHabitReminders();

  for (final plan in plans) {
    final scheduled = NotificationsService._nextTimeTodayOrTomorrow(
      hour: plan.hour,
      minute: plan.minute,
    );
    await NotificationsService._plugin.zonedSchedule(
      NotificationIds.unhealthyHabitBase + plan.reminderId,
      NotificationMessages.habitSupportTitle(plan.habitLabel),
      plan.message.trim().isEmpty
          ? NotificationMessages.habitSupportBody()
          : plan.message.trim(),
      scheduled,
      NotificationsService._details(
        NotificationChannels.unhealthyHabitsId,
        NotificationChannels.unhealthyHabitsName,
        channelDescription: NotificationChannels.unhealthyHabitsDesc,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

Future<void> _cancelUnhealthyHabitReminders() async {
  await NotificationsService._cancelPendingInRange(
    NotificationIds.unhealthyHabitBase,
    NotificationIds.unhealthyHabitRangeEnd,
  );
}

Future<void> _showCaffeineCutoffWarning() async {
  await NotificationsService.ensurePermission();
  await NotificationsService._plugin.show(
    NotificationIds.caffeineCutoffWarning,
    NotificationMessages.caffeineCutoffTitle(),
    NotificationMessages.caffeineCutoffBody(),
    NotificationsService._details(
      NotificationChannels.unhealthyHabitsId,
      NotificationChannels.unhealthyHabitsName,
      channelDescription: NotificationChannels.unhealthyHabitsDesc,
    ),
  );
}

Future<void> _showFastFoodLimitWarning() async {
  await NotificationsService.ensurePermission();
  await NotificationsService._plugin.show(
    NotificationIds.fastFoodLimitWarning,
    NotificationMessages.fastFoodLimitTitle(),
    NotificationMessages.fastFoodLimitBody(),
    NotificationsService._details(
      NotificationChannels.unhealthyHabitsId,
      NotificationChannels.unhealthyHabitsName,
      channelDescription: NotificationChannels.unhealthyHabitsDesc,
    ),
  );
}
