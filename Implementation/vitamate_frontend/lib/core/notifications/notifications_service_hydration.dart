part of 'notifications_service.dart';

Future<void> _scheduleWaterInterval({
  required int intervalMinutes,
  int hoursAhead = 24,
}) async {
  await NotificationsService.ensurePermission();
  await NotificationsService.ensureExactAlarmPermission();
  await _cancelWater();

  final now = tz.TZDateTime.now(tz.local);
  final count = ((hoursAhead * 60) / intervalMinutes).floor();

  for (int i = 1; i <= count; i++) {
    final scheduled = now.add(Duration(minutes: intervalMinutes * i));
    await NotificationsService._plugin.zonedSchedule(
      NotificationIds.waterBase + i,
      NotificationMessages.waterTitle(),
      NotificationMessages.waterBody(),
      scheduled,
      NotificationsService._details(
        NotificationChannels.waterId,
        NotificationChannels.waterName,
        channelDescription: NotificationChannels.waterDesc,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

Future<void> _showWaterEnabled(int intervalMinutes) async {
  await NotificationsService.ensurePermission();
  await NotificationsService._plugin.show(
    778,
    'Water reminders on',
    'Hydration alerts every $intervalMinutes minutes are now active.',
    NotificationsService._details(
      NotificationChannels.waterId,
      NotificationChannels.waterName,
      channelDescription: NotificationChannels.waterDesc,
    ),
  );
}

Future<void> _showPostWorkoutHydrationNudge({
  required String activityName,
  required int durationMinutes,
}) async {
  await NotificationsService.ensurePermission();
  await NotificationsService._plugin.show(
    779,
    'Hydrate after your workout',
    'You completed $activityName for $durationMinutes min. Remember to drink water.',
    NotificationsService._details(
      NotificationChannels.waterId,
      NotificationChannels.waterName,
      channelDescription: NotificationChannels.waterDesc,
    ),
  );
}

Future<void> _cancelWater() async {
  for (int i = 1; i <= 250; i++) {
    await NotificationsService._plugin.cancel(NotificationIds.waterBase + i);
  }
}
