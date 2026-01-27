import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_channels.dart';
import 'notification_ids.dart';
import 'notification_messages.dart';

class NotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // =========================
  // Init
  // =========================
  static Future<void> init() async {
    // Timezone init (NO flutter_timezone)
    tzdata.initializeTimeZones();
    _setLocalTzFromUtcOffset();

    // Plugin init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );

    await ensureExactAlarmPermission();

    // Create channels
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      for (final c in NotificationChannels.all) {
        await android.createNotificationChannel(c);
      }
    }
  }

  // Sets tz.local using UTC offset -> Etc/GMT±X
  // Works well for offsets that are whole hours (e.g., +2, +3)
  static void _setLocalTzFromUtcOffset() {
    try {
      final offset = DateTime.now().timeZoneOffset;

      // If not whole-hour offset, fallback to UTC (safe)
      if (offset.inMinutes % 60 != 0) {
        tz.setLocalLocation(tz.UTC);
        debugPrint('Timezone not whole-hour. Using UTC. offset=$offset');
        return;
      }

      final hours = offset.inHours;

      // Etc/GMT has reversed sign:
      // UTC+3 => Etc/GMT-3
      // UTC-2 => Etc/GMT+2
      final sign = hours >= 0 ? '-' : '+';
      final name = 'Etc/GMT$sign${hours.abs()}';

      tz.setLocalLocation(tz.getLocation(name));
      debugPrint('Timezone set to $name (offset=$offset)');
    } catch (e) {
      tz.setLocalLocation(tz.UTC);
      debugPrint('Timezone fallback to UTC: $e');
    }
  }

  // =========================
  // Permissions (Android 13+)
  // =========================
  static Future<void> ensurePermission() async {
    if (!Platform.isAndroid) return;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    await android.requestNotificationsPermission();
  }

  // =========================
  // Exact alarms (Android 12+)
  // =========================
  static Future<void> ensureExactAlarmPermission() async {
    if (!Platform.isAndroid) return;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    final canScheduleExact = await android.canScheduleExactNotifications();
    debugPrint('NotificationsService: canScheduleExact=$canScheduleExact');
    if (canScheduleExact == false || canScheduleExact == null) {
      await android.requestExactAlarmsPermission();
      debugPrint('NotificationsService: requested exact alarms permission');
    }
  }

  // =========================
  // Internal helpers
  // =========================
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
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  // =========================
  // Sleep (daily bedtime + wake)
  // =========================
  static Future<void> scheduleDailyBedtime({required DateTime bedTime}) async {
    await ensurePermission();
    await ensureExactAlarmPermission();

    final scheduled = _nextTimeTodayOrTomorrow(
      hour: bedTime.hour,
      minute: bedTime.minute,
    );

    await _plugin.zonedSchedule(
      NotificationIds.sleepBed,
      '🛌 ${NotificationMessages.sleepBedTitle()}',
      NotificationMessages.sleepBedBody(),
      scheduled,
      _details(
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

  static Future<void> scheduleDailyWake({required DateTime wakeTime}) async {
    await ensurePermission();
    await ensureExactAlarmPermission();

    final scheduled = _nextTimeTodayOrTomorrow(
      hour: wakeTime.hour,
      minute: wakeTime.minute,
    );

    await _plugin.zonedSchedule(
      NotificationIds.sleepWake,
      '🌅 ${NotificationMessages.sleepWakeTitle()}',
      NotificationMessages.sleepWakeBody(),
      scheduled,
      _details(
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

  static Future<void> cancelSleep() async {
    await _plugin.cancel(NotificationIds.sleepBed);
    await _plugin.cancel(NotificationIds.sleepWake);
  }

  // =========================
  // Water (interval minutes)
  // Strategy: schedule ahead for a window (default 24h),
  // and call again daily or when user opens app.
  // =========================
  static Future<void> scheduleWaterInterval({
    required int intervalMinutes,
    int hoursAhead = 24,
  }) async {
    await ensurePermission();
    await ensureExactAlarmPermission();
    await cancelWater();

    final now = tz.TZDateTime.now(tz.local);
    final count = ((hoursAhead * 60) / intervalMinutes).floor();

    for (int i = 1; i <= count; i++) {
      final t = now.add(Duration(minutes: intervalMinutes * i));

      await _plugin.zonedSchedule(
        NotificationIds.waterBase + i,
        '💧 ${NotificationMessages.waterTitle()}',
        NotificationMessages.waterBody(),
        t,
        _details(
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

  static Future<void> showWaterEnabled(int intervalMinutes) async {
    await ensurePermission();
    await _plugin.show(
      778,
      'Water reminders on',
      'Hydration alerts every $intervalMinutes minutes are now active.',
      _details(
        NotificationChannels.waterId,
        NotificationChannels.waterName,
        channelDescription: NotificationChannels.waterDesc,
      ),
    );
  }

  static Future<void> cancelWater() async {
    // cancel a safe range
    for (int i = 1; i <= 250; i++) {
      await _plugin.cancel(NotificationIds.waterBase + i);
    }
  }

  // =========================
  // Meals (daily 3 times)
  // =========================
  static Future<void> scheduleMeals({
    required DateTime breakfast,
    required DateTime lunch,
    required DateTime dinner,
  }) async {
    await ensurePermission();
    await ensureExactAlarmPermission();

    await _scheduleDaily(
      id: NotificationIds.mealBreakfast,
      when: breakfast,
      title: '🍳 ${NotificationMessages.breakfastTitle()}',
      body: NotificationMessages.breakfastBody(),
      channelId: NotificationChannels.mealsId,
      channelName: NotificationChannels.mealsName,
      channelDesc: NotificationChannels.mealsDesc,
    );

    await _scheduleDaily(
      id: NotificationIds.mealLunch,
      when: lunch,
      title: '🍲 ${NotificationMessages.lunchTitle()}',
      body: NotificationMessages.lunchBody(),
      channelId: NotificationChannels.mealsId,
      channelName: NotificationChannels.mealsName,
      channelDesc: NotificationChannels.mealsDesc,
    );

    await _scheduleDaily(
      id: NotificationIds.mealDinner,
      when: dinner,
      title: '🥗 ${NotificationMessages.dinnerTitle()}',
      body: NotificationMessages.dinnerBody(),
      channelId: NotificationChannels.mealsId,
      channelName: NotificationChannels.mealsName,
      channelDesc: NotificationChannels.mealsDesc,
    );

    await _plugin.show(
      788,
      'Meal reminders on',
      'Breakfast, lunch, and dinner reminders have been scheduled.',
      _details(
        NotificationChannels.mealsId,
        NotificationChannels.mealsName,
        channelDescription: NotificationChannels.mealsDesc,
      ),
    );
  }

  static Future<void> _scheduleDaily({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDesc,
  }) async {
    final scheduled = _nextTimeTodayOrTomorrow(
      hour: when.hour,
      minute: when.minute,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _details(channelId, channelName, channelDescription: channelDesc),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelMeals() async {
    await _plugin.cancel(NotificationIds.mealBreakfast);
    await _plugin.cancel(NotificationIds.mealLunch);
    await _plugin.cancel(NotificationIds.mealDinner);
  }

  // =========================
  // Activity reminders
  // Strategy: schedule a few ahead
  // =========================
  static Future<void> scheduleActivityEveryXHours(int hours) async {
    await ensurePermission();
    await ensureExactAlarmPermission();
    await cancelActivity();

    final now = tz.TZDateTime.now(tz.local);
    for (int i = 1; i <= 8; i++) {
      final t = now.add(Duration(hours: hours * i));

      await _plugin.zonedSchedule(
        NotificationIds.activityBase + i,
        '🏃 ${NotificationMessages.activityTitle()}',
        NotificationMessages.activityBody(),
        t,
        _details(
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

  static Future<void> cancelActivity() async {
    for (int i = 1; i <= 100; i++) {
      await _plugin.cancel(NotificationIds.activityBase + i);
    }
    await _plugin.cancel(NotificationIds.activityDaily);
  }

  static Future<void> scheduleDailyActivityReminder({required DateTime time}) async {
    await ensurePermission();
    await ensureExactAlarmPermission();
    await cancelActivity();

    final scheduled = _nextTimeTodayOrTomorrow(
      hour: time.hour,
      minute: time.minute,
    );

    await _plugin.zonedSchedule(
      NotificationIds.activityDaily,
      NotificationMessages.activityTitle(),
      NotificationMessages.activityBody(),
      scheduled,
      _details(
        NotificationChannels.activityId,
        NotificationChannels.activityName,
        channelDescription: NotificationChannels.activityDesc,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    await _plugin.show(
      889,
      'Activity reminder on',
      'Daily activity reminder scheduled at ${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}',
      _details(
        NotificationChannels.activityId,
        NotificationChannels.activityName,
        channelDescription: NotificationChannels.activityDesc,
      ),
    );
  }

  // =========================
  // Steps reminder (daily at a fixed time)
  // =========================
  static Future<void> scheduleDailyStepsReminder({required DateTime time}) async {
    await ensurePermission();
    await ensureExactAlarmPermission();

    // Only replace the steps reminder, not activity ones.
    await _plugin.cancel(NotificationIds.stepsDaily);

    final scheduled = _nextTimeTodayOrTomorrow(
      hour: time.hour,
      minute: time.minute,
    );

    await _plugin.zonedSchedule(
      NotificationIds.stepsDaily,
      NotificationMessages.stepsTitle(),
      NotificationMessages.stepsBody(),
      scheduled,
      _details(
        NotificationChannels.activityId,
        NotificationChannels.activityName,
        channelDescription: NotificationChannels.activityDesc,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    final hh = scheduled.hour.toString().padLeft(2, '0');
    final mm = scheduled.minute.toString().padLeft(2, '0');
    await _plugin.show(
      898,
      'Steps reminder on',
      'Daily steps reminder scheduled at $hh:$mm',
      _details(
        NotificationChannels.activityId,
        NotificationChannels.activityName,
        channelDescription: NotificationChannels.activityDesc,
      ),
    );
  }

  static Future<void> cancelStepsReminder() async {
    await _plugin.cancel(NotificationIds.stepsDaily);
  }

  // =========================
  // Debug test
  // =========================
  static Future<void> testAfterSeconds(int seconds) async {
    await ensurePermission();
    await ensureExactAlarmPermission();

    final scheduledFor =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    debugPrint('NotificationsService: scheduling test at $scheduledFor');

    await _plugin.zonedSchedule(
      999,
      'Test notification',
      'If you see this, scheduling works ✅',
      scheduledFor,
      _details(
        NotificationChannels.debugId,
        NotificationChannels.debugName,
        channelDescription: NotificationChannels.debugDesc,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Debug helper: log pending scheduled notifications
  static Future<void> logPending() async {
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint(
        'NotificationsService: pending notifications count=${pending.length}');
    for (final p in pending) {
      debugPrint('Pending notification -> id=${p.id} title=${p.title}');
    }
  }

  // =========================
  // Instant confirmation notification
  // =========================
  static Future<void> showEnabledConfirmation() async {
    await ensurePermission();

    await _plugin.show(
      777,
      'Notifications enabled 🔔',
      'Sleep reminders are now active.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.sleepId,
          NotificationChannels.sleepName,
          channelDescription: NotificationChannels.sleepDesc,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  // =========================
  // Welcome notifications
  // =========================
  static Future<void> showWelcomeBack() async {
    await ensurePermission();
    await _plugin.show(
      NotificationIds.welcomeBack,
      'Welcome back!',
      'Good to see you again. Keep pushing toward your goals.',
      _details(
        NotificationChannels.debugId,
        NotificationChannels.debugName,
        channelDescription: NotificationChannels.debugDesc,
      ),
    );
  }

  static Future<void> showWelcomeNewUser() async {
    await ensurePermission();
    await _plugin.show(
      NotificationIds.welcomeNew,
      'Welcome to VitaMate',
      'Your journey to a better life starts now. Let\'s get moving!',
      _details(
        NotificationChannels.debugId,
        NotificationChannels.debugName,
        channelDescription: NotificationChannels.debugDesc,
      ),
    );
  }
}
