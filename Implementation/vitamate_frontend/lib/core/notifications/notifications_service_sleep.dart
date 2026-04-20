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

Future<void> _cancelSleep() async {
  await NotificationsService._plugin.cancel(NotificationIds.sleepBed);
  await NotificationsService._plugin.cancel(NotificationIds.sleepWake);
}
