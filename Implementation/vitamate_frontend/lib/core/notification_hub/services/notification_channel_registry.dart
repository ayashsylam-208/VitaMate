import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../state/notification_hub_controller.dart';
import '../models/notification_permission_snapshot.dart';

class NotificationChannelRegistry {
  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static const int channelsVersion = 3;
  static const String healthCriticalChannelId = 'health_critical_v3';
  static const String routineChannelId = 'routine_v3';
  static const String motivationChannelId = 'motivation_v3';
  static const String systemStatusChannelId = 'system_status_v3';
  static const String _permissionRequestedKey =
      'notification_hub.permission_requested';
  static const MethodChannel _settingsChannel = MethodChannel(
    'vitamate/notification_settings',
  );

  static bool _initialized = false;
  static NotificationPermissionSnapshot? lastPermissionSnapshot;

  static Future<void> init() async {
    if (_initialized) {
      return;
    }
    tzdata.initializeTimeZones();
    _setLocalTzFromUtcOffset();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload?.trim() ?? '';
        if (payload.isEmpty) {
          return;
        }
        await NotificationHubController.instance.handleNotificationPayload(
          payload,
        );
      },
    );
    await _createChannels();
    _initialized = true;
  }

  static Future<Map<String, dynamic>> permissionSnapshot() async {
    final snapshot = await readPermissionSnapshot();
    return snapshot.toJson();
  }

  static Future<NotificationPermissionSnapshot> readPermissionSnapshot() async {
    final checkedAt = DateTime.now();
    if (!Platform.isAndroid) {
      final snapshot = NotificationPermissionSnapshot(
        notificationsAuthorized: false,
        permissionStatus: 'unavailable',
        exactAlarmAuthorized: false,
        notificationsEnabledSystemwide: false,
        checkedAt: checkedAt,
      );
      lastPermissionSnapshot = snapshot;
      return snapshot;
    }
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final enabled = await android?.areNotificationsEnabled();
    final exact = await android?.canScheduleExactNotifications();
    final prefs = await SharedPreferences.getInstance();
    final requested = prefs.getBool(_permissionRequestedKey) == true;
    final status = enabled == true
        ? 'authorized'
        : requested
        ? 'denied'
        : 'not_determined';
    final snapshot = NotificationPermissionSnapshot(
      notificationsAuthorized: enabled == true,
      permissionStatus: status,
      exactAlarmAuthorized: exact == true,
      notificationsEnabledSystemwide: enabled == true,
      checkedAt: checkedAt,
    );
    lastPermissionSnapshot = snapshot;
    return snapshot;
  }

  static Future<NotificationPermissionSnapshot> requestPermissions({
    bool requestExactAlarm = false,
  }) async {
    if (!Platform.isAndroid) {
      return readPermissionSnapshot();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionRequestedKey, true);
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    if (requestExactAlarm &&
        await android?.canScheduleExactNotifications() != true) {
      await android?.requestExactAlarmsPermission();
    }
    return readPermissionSnapshot();
  }

  static Future<void> openSystemSettings() async {
    if (!Platform.isAndroid) return;
    await _settingsChannel.invokeMethod<void>('openNotificationSettings');
  }

  static AndroidNotificationChannel channelForCategory(String category) {
    switch (category) {
      case 'health_critical':
        return const AndroidNotificationChannel(
          healthCriticalChannelId,
          'Health Critical',
          description: 'Medication and critical health alerts.',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );
      case 'motivation':
      case 'celebration':
        return const AndroidNotificationChannel(
          motivationChannelId,
          'Motivation',
          description: 'Rewards, streaks, and progress nudges.',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.notification,
        );
      case 'system':
        return const AndroidNotificationChannel(
          systemStatusChannelId,
          'System Status',
          description: 'Permission and sync status notices.',
          importance: Importance.defaultImportance,
          playSound: false,
          enableVibration: false,
        );
      default:
        return const AndroidNotificationChannel(
          routineChannelId,
          'Routine Reminders',
          description: 'Meals, water, activity, sleep, and habit reminders.',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.notification,
        );
    }
  }

  static NotificationDetails detailsForCategory(
    String category, {
    String soundProfile = '',
  }) {
    final channel = channelForCategory(category);
    final audioUsage =
        soundProfile == 'health_critical' || category == 'health_critical'
        ? AudioAttributesUsage.alarm
        : AudioAttributesUsage.notification;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: channel.importance == Importance.max
            ? Priority.max
            : Priority.high,
        playSound: channel.playSound,
        enableVibration: channel.enableVibration,
        silent: !channel.playSound,
        audioAttributesUsage: audioUsage,
      ),
    );
  }

  static String payloadFor({
    required String route,
    required String planId,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) {
    return jsonEncode(<String, dynamic>{
      'route': route,
      'plan_id': planId,
      ...extra,
    });
  }

  static void _setLocalTzFromUtcOffset() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      if (offset.inMinutes % 60 != 0) {
        tz.setLocalLocation(tz.UTC);
        return;
      }
      final hours = offset.inHours;
      final sign = hours >= 0 ? '-' : '+';
      tz.setLocalLocation(tz.getLocation('Etc/GMT$sign${hours.abs()}'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  static Future<void> _createChannels() async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return;
    }
    for (final channel in <AndroidNotificationChannel>[
      channelForCategory('health_critical'),
      channelForCategory('routine'),
      channelForCategory('motivation'),
      channelForCategory('system'),
    ]) {
      await android.createNotificationChannel(channel);
    }
  }
}
