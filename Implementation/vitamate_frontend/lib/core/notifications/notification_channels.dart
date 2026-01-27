import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationChannels {
  static const debugId = 'debug_channel';
  static const debugName = 'Debug';
  static const debugDesc = 'Test notifications';

  static const sleepId = 'sleep_channel';
  static const sleepName = 'Sleep';
  static const sleepDesc = 'Sleep reminders (bedtime & wake-up)';

  static const waterId = 'water_channel';
  static const waterName = 'Water';
  static const waterDesc = 'Hydration reminders';

  static const mealsId = 'meals_channel';
  static const mealsName = 'Meals';
  static const mealsDesc = 'Meal reminders (breakfast/lunch/dinner)';

  static const activityId = 'activity_channel';
  static const activityName = 'Activity';
  static const activityDesc = 'Activity reminders';

  static const all = <AndroidNotificationChannel>[
    AndroidNotificationChannel(debugId, debugName,
        description: debugDesc, importance: Importance.max),
    AndroidNotificationChannel(sleepId, sleepName,
        description: sleepDesc, importance: Importance.max),
    AndroidNotificationChannel(waterId, waterName,
        description: waterDesc, importance: Importance.max),
    AndroidNotificationChannel(mealsId, mealsName,
        description: mealsDesc, importance: Importance.max),
    AndroidNotificationChannel(activityId, activityName,
        description: activityDesc, importance: Importance.max),
  ];
}
