import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_channels.dart';
import 'notification_ids.dart';
import 'notification_messages.dart';

part 'notifications_service_sleep.dart';
part 'notifications_service_hydration.dart';
part 'notifications_service_meals_activity.dart';
part 'notifications_service_chronic.dart';
part 'notifications_service_health_alerts.dart';
part 'notifications_service_debug.dart';

class ChronicMedicationReminderPlan {
  final int scheduleId;
  final String medicationName;
  final String conditionName;
  final String dosage;
  final int hour;
  final int minute;
  final int leadMinutes;
  final List<int> recurrenceDays;

  const ChronicMedicationReminderPlan({
    required this.scheduleId,
    required this.medicationName,
    required this.conditionName,
    required this.dosage,
    required this.hour,
    required this.minute,
    required this.leadMinutes,
    required this.recurrenceDays,
  });
}

class NotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    _setLocalTzFromUtcOffset();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );

    await ensureExactAlarmPermission();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) {
      return;
    }

    for (final channel in NotificationChannels.all) {
      await android.createNotificationChannel(channel);
    }
  }

  static void _setLocalTzFromUtcOffset() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      if (offset.inMinutes % 60 != 0) {
        tz.setLocalLocation(tz.UTC);
        debugPrint('Timezone not whole-hour. Using UTC. offset=$offset');
        return;
      }

      final hours = offset.inHours;
      final sign = hours >= 0 ? '-' : '+';
      final name = 'Etc/GMT$sign${hours.abs()}';

      tz.setLocalLocation(tz.getLocation(name));
      debugPrint('Timezone set to $name (offset=$offset)');
    } catch (error) {
      tz.setLocalLocation(tz.UTC);
      debugPrint('Timezone fallback to UTC: $error');
    }
  }

  static Future<void> ensurePermission() async {
    if (!Platform.isAndroid) {
      return;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return;
    }

    await android.requestNotificationsPermission();
  }

  static Future<void> ensureExactAlarmPermission() async {
    if (!Platform.isAndroid) {
      return;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return;
    }

    final canScheduleExact = await android.canScheduleExactNotifications();
    debugPrint('NotificationsService: canScheduleExact=$canScheduleExact');
    if (canScheduleExact == false || canScheduleExact == null) {
      await android.requestExactAlarmsPermission();
      debugPrint('NotificationsService: requested exact alarms permission');
    }
  }

  static NotificationDetails _details(
    String channelId,
    String channelName, {
    String? channelDescription,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
  }

  static tz.TZDateTime _nextTimeTodayOrTomorrow({
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static tz.TZDateTime _nextWeekdayTime({
    required int weekday,
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static int _chronicRecurringNotificationId({
    required int scheduleId,
    required int weekdaySlot,
    required bool isLeadReminder,
  }) {
    return NotificationIds.chronicMedicationBase +
        (scheduleId * 20) +
        (weekdaySlot * 2) +
        (isLeadReminder ? 1 : 0);
  }

  static int _chronicSnoozeNotificationId(int scheduleId) {
    return NotificationIds.chronicMedicationSnoozeBase + scheduleId;
  }

  static String _chronicDoseBody({
    required String conditionName,
    required String dosage,
  }) {
    final dosageText = dosage.trim();
    if (dosageText.isEmpty) {
      return 'Care plan: $conditionName';
    }
    return '$dosageText · $conditionName';
  }

  static String _chronicReminderBody({
    required String medicationName,
    required String conditionName,
    required String dosage,
    required bool isLeadReminder,
  }) {
    final body = _chronicDoseBody(conditionName: conditionName, dosage: dosage);
    if (isLeadReminder) {
      return 'Upcoming dose: $medicationName. $body';
    }
    return 'Time to take $medicationName. $body';
  }

  static Future<void> _cancelPendingInRange(int fromId, int toId) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= fromId && request.id <= toId) {
        await _plugin.cancel(request.id);
      }
    }
  }

  static Future<void> scheduleDailyBedtime({required DateTime bedTime}) {
    return _scheduleDailyBedtime(bedTime: bedTime);
  }

  static Future<void> scheduleDailyWake({required DateTime wakeTime}) {
    return _scheduleDailyWake(wakeTime: wakeTime);
  }

  static Future<void> cancelSleep() {
    return _cancelSleep();
  }

  static Future<void> scheduleWaterInterval({
    required int intervalMinutes,
    int hoursAhead = 24,
  }) {
    return _scheduleWaterInterval(
      intervalMinutes: intervalMinutes,
      hoursAhead: hoursAhead,
    );
  }

  static Future<void> showWaterEnabled(int intervalMinutes) {
    return _showWaterEnabled(intervalMinutes);
  }

  static Future<void> cancelWater() {
    return _cancelWater();
  }

  static Future<void> scheduleMeals({
    required DateTime breakfast,
    required DateTime lunch,
    required DateTime dinner,
  }) {
    return _scheduleMeals(breakfast: breakfast, lunch: lunch, dinner: dinner);
  }

  static Future<void> cancelMeals() {
    return _cancelMeals();
  }

  static Future<void> scheduleActivityEveryXHours(int hours) {
    return _scheduleActivityEveryXHours(hours);
  }

  static Future<void> cancelActivity() {
    return _cancelActivity();
  }

  static Future<void> scheduleDailyActivityReminder({required DateTime time}) {
    return _scheduleDailyActivityReminder(time: time);
  }

  static Future<void> scheduleDailyStepsReminder({required DateTime time}) {
    return _scheduleDailyStepsReminder(time: time);
  }

  static Future<void> cancelStepsReminder() {
    return _cancelStepsReminder();
  }

  static Future<void> syncChronicMedicationReminders(
    List<ChronicMedicationReminderPlan> plans,
  ) {
    return _syncChronicMedicationReminders(plans);
  }

  static Future<void> syncMedicationReminders(
    List<ChronicMedicationReminderPlan> plans,
  ) {
    return _syncChronicMedicationReminders(plans);
  }

  static Future<void> scheduleChronicMedicationSnooze({
    required int scheduleId,
    required String medicationName,
    required String conditionName,
    required String dosage,
    required DateTime reminderAt,
  }) {
    return _scheduleChronicMedicationSnooze(
      scheduleId: scheduleId,
      medicationName: medicationName,
      conditionName: conditionName,
      dosage: dosage,
      reminderAt: reminderAt,
    );
  }

  static Future<void> cancelChronicMedicationSnooze(int scheduleId) {
    return _cancelChronicMedicationSnooze(scheduleId);
  }

  static Future<void> showDiabetesSugarWarning({
    required double limitG,
    required double currentG,
    required String sourceLabel,
  }) {
    return _showDiabetesSugarWarning(
      limitG: limitG,
      currentG: currentG,
      sourceLabel: sourceLabel,
    );
  }

  static Future<void> testAfterSeconds(int seconds) {
    return _testAfterSeconds(seconds);
  }

  static Future<void> logPending() {
    return _logPending();
  }

  static Future<void> showEnabledConfirmation() {
    return _showEnabledConfirmation();
  }

  static Future<void> showWelcomeBack() {
    return _showWelcomeBack();
  }

  static Future<void> showWelcomeNewUser() {
    return _showWelcomeNewUser();
  }
}
