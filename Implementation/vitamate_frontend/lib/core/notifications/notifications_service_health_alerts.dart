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

Future<void> _showConditionLimitWarning({
  required String metricKey,
  required String metricLabel,
  required double limitValue,
  required double currentValue,
  required String unit,
  required String sourceLabel,
  required String conditionLabel,
}) async {
  await NotificationsService.ensurePermission();

  final unitPart = unit.trim().isEmpty ? '' : ' $unit';
  final title = '$metricLabel limit exceeded';
  final source = sourceLabel.trim().isEmpty ? 'This item' : sourceLabel.trim();
  final condition = conditionLabel.trim().isEmpty
      ? 'your condition limit'
      : conditionLabel.trim();
  final body =
      '$source pushed $metricLabel to ${_healthAlertNumber(currentValue)}$unitPart, '
      'above ${_healthAlertNumber(limitValue)}$unitPart for $condition.';

  await NotificationsService._plugin.show(
    _conditionLimitNotificationId(metricKey),
    title,
    body,
    NotificationsService._details(
      NotificationChannels.chronicAlertsId,
      NotificationChannels.chronicAlertsName,
      channelDescription: NotificationChannels.chronicAlertsDesc,
    ),
  );
}

int _conditionLimitNotificationId(String metricKey) {
  return switch (metricKey) {
    'added_sugars_g' || 'sugars_g' => NotificationIds.diabetesSugarWarning,
    'sodium_mg' => NotificationIds.conditionLimitWarningBase + 1,
    'saturated_fat_pct_kcal' => NotificationIds.conditionLimitWarningBase + 2,
    'trans_fat_g' => NotificationIds.conditionLimitWarningBase + 3,
    'cholesterol_mg' => NotificationIds.conditionLimitWarningBase + 4,
    _ => NotificationIds.conditionLimitWarningBase + 20,
  };
}

String _healthAlertNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(value.abs() < 10 ? 1 : 0);
}
