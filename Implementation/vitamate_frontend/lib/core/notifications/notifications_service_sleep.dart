part of 'notifications_service.dart';

Future<void> _scheduleDailyBedtime({required DateTime bedTime}) async {
  await NotificationsService.ensurePermission();
  await NotificationsService.ensureExactAlarmPermission();

  final scheduled = NotificationsService._nextTimeTodayOrTomorrow(
    hour: bedTime.hour,
    minute: bedTime.minute,
  );

  await NotificationsService._plugin.zonedSchedule(
    NotificationIds.sleepBed,
    NotificationMessages.sleepBedTitle(),
    NotificationMessages.sleepBedBody(),
    scheduled,
    NotificationsService._details(
      NotificationChannels.sleepId,
      NotificationChannels.sleepName,
      channelDescription: NotificationChannels.sleepDesc,
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

Future<void> _scheduleDailyWake({required DateTime wakeTime}) async {
  await NotificationsService.ensurePermission();
  await NotificationsService.ensureExactAlarmPermission();

  final scheduled = NotificationsService._nextTimeTodayOrTomorrow(
    hour: wakeTime.hour,
    minute: wakeTime.minute,
  );

  await NotificationsService._plugin.zonedSchedule(
    NotificationIds.sleepWake,
    NotificationMessages.sleepWakeTitle(),
    NotificationMessages.sleepWakeBody(),
    scheduled,
    NotificationsService._details(
      NotificationChannels.sleepId,
      NotificationChannels.sleepName,
      channelDescription: NotificationChannels.sleepDesc,
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

Future<void> _scheduleSleepCoachWake({required DateTime wakeTime}) async {
  await NotificationsService.ensurePermission();
  await NotificationsService.ensureExactAlarmPermission();
  await NotificationsService._plugin.cancel(NotificationIds.sleepCoachWake);

  var scheduled = tz.TZDateTime(
    tz.local,
    wakeTime.year,
    wakeTime.month,
    wakeTime.day,
    wakeTime.hour,
    wakeTime.minute,
  );
  if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
    scheduled = scheduled.add(const Duration(days: 1));
  }

  await NotificationsService._plugin.zonedSchedule(
    NotificationIds.sleepCoachWake,
    'Smart wake reminder',
    'Your planned wake window is here. This is a reminder, not a guaranteed alarm.',
    scheduled,
    NotificationsService._details(
      NotificationChannels.sleepId,
      NotificationChannels.sleepName,
      channelDescription: NotificationChannels.sleepDesc,
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

Future<void> _cancelSleepCoachWake() async {
  await NotificationsService._plugin.cancel(NotificationIds.sleepCoachWake);
}

Future<void> _cancelSleep() async {
  await NotificationsService._plugin.cancel(NotificationIds.sleepBed);
  await NotificationsService._plugin.cancel(NotificationIds.sleepWake);
  await NotificationsService._plugin.cancel(NotificationIds.sleepCoachWake);
}
