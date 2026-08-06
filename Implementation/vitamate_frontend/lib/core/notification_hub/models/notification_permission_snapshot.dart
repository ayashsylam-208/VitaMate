class NotificationPermissionSnapshot {
  const NotificationPermissionSnapshot({
    required this.notificationsAuthorized,
    required this.permissionStatus,
    required this.exactAlarmAuthorized,
    required this.notificationsEnabledSystemwide,
    required this.checkedAt,
  });

  final bool notificationsAuthorized;
  final String permissionStatus;
  final bool exactAlarmAuthorized;
  final bool notificationsEnabledSystemwide;
  final DateTime checkedAt;

  bool get canScheduleLocalNotifications =>
      notificationsAuthorized && notificationsEnabledSystemwide;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'notifications_authorized': notificationsAuthorized,
    'permission_status': permissionStatus,
    'exact_alarm_authorized': exactAlarmAuthorized,
    'notifications_enabled_systemwide': notificationsEnabledSystemwide,
    'checked_at': checkedAt.toUtc().toIso8601String(),
  };
}
