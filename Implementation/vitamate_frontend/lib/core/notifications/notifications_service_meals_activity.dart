part of 'notifications_service.dart';

Future<void> _scheduleMeals({
  required DateTime breakfast,
  required DateTime lunch,
  required DateTime dinner,
}) async {
  await NotificationsService.ensurePermission();
  await NotificationsService.ensureExactAlarmPermission();

  await _scheduleDaily(
    id: NotificationIds.mealBreakfast,
    when: breakfast,
    title: NotificationMessages.breakfastTitle(),
    body: NotificationMessages.breakfastBody(),
    channelId: NotificationChannels.mealsId,
    channelName: NotificationChannels.mealsName,
    channelDesc: NotificationChannels.mealsDesc,
  );

  await _scheduleDaily(
    id: NotificationIds.mealLunch,
    when: lunch,
    title: NotificationMessages.lunchTitle(),
    body: NotificationMessages.lunchBody(),
    channelId: NotificationChannels.mealsId,
    channelName: NotificationChannels.mealsName,
    channelDesc: NotificationChannels.mealsDesc,
  );

  await _scheduleDaily(
    id: NotificationIds.mealDinner,
    when: dinner,
    title: NotificationMessages.dinnerTitle(),
    body: NotificationMessages.dinnerBody(),
    channelId: NotificationChannels.mealsId,
    channelName: NotificationChannels.mealsName,
    channelDesc: NotificationChannels.mealsDesc,
  );

  await NotificationsService._plugin.show(
    788,
    'Meal reminders on',
    'Breakfast, lunch, and dinner reminders have been scheduled.',
    NotificationsService._details(
      NotificationChannels.mealsId,
      NotificationChannels.mealsName,
      channelDescription: NotificationChannels.mealsDesc,
    ),
  );
}

Future<void> _scheduleDaily({
  required int id,
  required DateTime when,
  required String title,
  required String body,
  required String channelId,
  required String channelName,
  required String channelDesc,
}) async {
  final scheduled = NotificationsService._nextTimeTodayOrTomorrow(
    hour: when.hour,
    minute: when.minute,
  );

  await NotificationsService._plugin.zonedSchedule(
    id,
    title,
    body,
    scheduled,
    NotificationsService._details(
      channelId,
      channelName,
      channelDescription: channelDesc,
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

Future<void> _cancelMeals() async {
  await NotificationsService._plugin.cancel(NotificationIds.mealBreakfast);
  await NotificationsService._plugin.cancel(NotificationIds.mealLunch);
  await NotificationsService._plugin.cancel(NotificationIds.mealDinner);
}

Future<void> _scheduleActivityEveryXHours(int hours) async {
  await NotificationsService.ensurePermission();
  await NotificationsService.ensureExactAlarmPermission();
  await _cancelActivityIntervals();

  final now = tz.TZDateTime.now(tz.local);
  for (int i = 1; i <= 8; i++) {
    final scheduled = now.add(Duration(hours: hours * i));
    await NotificationsService._plugin.zonedSchedule(
      NotificationIds.activityBase + i,
      NotificationMessages.activityTitle(),
      NotificationMessages.activityBody(),
      scheduled,
      NotificationsService._details(
        NotificationChannels.activityId,
        NotificationChannels.activityName,
        channelDescription: NotificationChannels.activityDesc,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

Future<void> _cancelActivityIntervals() async {
  for (int i = 1; i <= 100; i++) {
    await NotificationsService._plugin.cancel(NotificationIds.activityBase + i);
  }
}

Future<void> _cancelDailyActivityReminder() async {
  await NotificationsService._plugin.cancel(NotificationIds.activityDaily);
}

Future<void> _cancelActivity() async {
  await _cancelActivityIntervals();
  await _cancelDailyActivityReminder();
}

Future<void> _scheduleDailyActivityReminder({required DateTime time}) async {
  await NotificationsService.ensurePermission();
  await NotificationsService.ensureExactAlarmPermission();
  await _cancelDailyActivityReminder();

  final scheduled = NotificationsService._nextTimeTodayOrTomorrow(
    hour: time.hour,
    minute: time.minute,
  );

  await NotificationsService._plugin.zonedSchedule(
    NotificationIds.activityDaily,
    NotificationMessages.activityTitle(),
    NotificationMessages.activityBody(),
    scheduled,
    NotificationsService._details(
      NotificationChannels.activityId,
      NotificationChannels.activityName,
      channelDescription: NotificationChannels.activityDesc,
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );

  final hour = scheduled.hour.toString().padLeft(2, '0');
  final minute = scheduled.minute.toString().padLeft(2, '0');
  await NotificationsService._plugin.show(
    889,
    'Activity reminder on',
    'Daily activity reminder scheduled at $hour:$minute',
    NotificationsService._details(
      NotificationChannels.activityId,
      NotificationChannels.activityName,
      channelDescription: NotificationChannels.activityDesc,
    ),
  );
}

Future<void> _scheduleDailyStepsReminder({required DateTime time}) async {
  await NotificationsService.ensurePermission();
  await NotificationsService.ensureExactAlarmPermission();

  await NotificationsService._plugin.cancel(NotificationIds.stepsDaily);

  final scheduled = NotificationsService._nextTimeTodayOrTomorrow(
    hour: time.hour,
    minute: time.minute,
  );

  await NotificationsService._plugin.zonedSchedule(
    NotificationIds.stepsDaily,
    NotificationMessages.stepsTitle(),
    NotificationMessages.stepsBody(),
    scheduled,
    NotificationsService._details(
      NotificationChannels.activityId,
      NotificationChannels.activityName,
      channelDescription: NotificationChannels.activityDesc,
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );

  final hour = scheduled.hour.toString().padLeft(2, '0');
  final minute = scheduled.minute.toString().padLeft(2, '0');
  await NotificationsService._plugin.show(
    898,
    'Steps reminder on',
    'Daily steps reminder scheduled at $hour:$minute',
    NotificationsService._details(
      NotificationChannels.activityId,
      NotificationChannels.activityName,
      channelDescription: NotificationChannels.activityDesc,
    ),
  );
}

Future<void> _cancelStepsReminder() async {
  await NotificationsService._plugin.cancel(NotificationIds.stepsDaily);
}
