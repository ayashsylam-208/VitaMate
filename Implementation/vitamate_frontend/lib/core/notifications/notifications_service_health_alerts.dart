part of 'notifications_service.dart';

Future<void> _showDiabetesSugarWarning({
  required double limitG,
  required double currentG,
  required String sourceLabel,
}) async {
  await NotificationsService.ensurePermission();

  final normalizedSource = sourceLabel.trim();
  final title = 'Diabetes sugar warning';
  final body = normalizedSource.isEmpty
      ? 'Today\'s sugar reached ${currentG.round()} g and is above your limit of ${limitG.round()} g.'
      : '$normalizedSource pushed today\'s sugar to ${currentG.round()} g, above your limit of ${limitG.round()} g.';

  await NotificationsService._plugin.show(
    NotificationIds.diabetesSugarWarning,
    title,
    body,
    NotificationsService._details(
      NotificationChannels.chronicAlertsId,
      NotificationChannels.chronicAlertsName,
      channelDescription: NotificationChannels.chronicAlertsDesc,
    ),
  );
}
