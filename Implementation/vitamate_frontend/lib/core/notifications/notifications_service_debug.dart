part of 'notifications_service.dart';

Future<void> _testAfterSeconds(int seconds) async {
  await NotificationsService.ensurePermission();
  await NotificationsService.ensureExactAlarmPermission();

  final scheduled = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
  debugPrint('NotificationsService: scheduling test at $scheduled');

  await NotificationsService._plugin.zonedSchedule(
    999,
    'Test notification',
    'If you see this, scheduling works.',
    scheduled,
    NotificationsService._details(
      NotificationChannels.debugId,
      NotificationChannels.debugName,
      channelDescription: NotificationChannels.debugDesc,
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

Future<void> _logPending() async {
  final pending = await NotificationsService._plugin
      .pendingNotificationRequests();
  debugPrint(
    'NotificationsService: pending notifications count=${pending.length}',
  );
  for (final item in pending) {
    debugPrint('Pending notification -> id=${item.id} title=${item.title}');
  }
}

Future<void> _showEnabledConfirmation() async {
  await NotificationsService.ensurePermission();
  await NotificationsService._plugin.show(
    777,
    'Notifications enabled',
    'Sleep reminders are now active.',
    NotificationsService._details(
      NotificationChannels.sleepId,
      NotificationChannels.sleepName,
      channelDescription: NotificationChannels.sleepDesc,
    ),
  );
}

Future<void> _showWelcomeBack() async {
  await NotificationsService.ensurePermission();
  await NotificationsService._plugin.show(
    NotificationIds.welcomeBack,
    'Welcome back!',
    'Good to see you again. Keep pushing toward your goals.',
    NotificationsService._details(
      NotificationChannels.debugId,
      NotificationChannels.debugName,
      channelDescription: NotificationChannels.debugDesc,
    ),
  );
}

Future<void> _showWelcomeNewUser() async {
  await NotificationsService.ensurePermission();
  await NotificationsService._plugin.show(
    NotificationIds.welcomeNew,
    'Welcome to VitaMate',
    'Your journey to a better life starts now. Let us get moving!',
    NotificationsService._details(
      NotificationChannels.debugId,
      NotificationChannels.debugName,
      channelDescription: NotificationChannels.debugDesc,
    ),
  );
}
