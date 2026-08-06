import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_plan_model.dart';
import 'notification_channel_registry.dart';

abstract class LocalNotificationScheduler {
  Future<void> schedule({
    required int id,
    required NotificationPlanModel plan,
    required DateTime at,
  });

  Future<void> showImmediate({
    required int id,
    required NotificationPlanModel plan,
  });

  Future<void> cancel(int id);
}

class PluginLocalNotificationScheduler implements LocalNotificationScheduler {
  const PluginLocalNotificationScheduler();

  @override
  Future<void> schedule({
    required int id,
    required NotificationPlanModel plan,
    required DateTime at,
  }) {
    return NotificationChannelRegistry.plugin.zonedSchedule(
      id,
      plan.title,
      plan.body,
      tz.TZDateTime.from(at, tz.local),
      NotificationChannelRegistry.detailsForCategory(
        plan.category,
        soundProfile: plan.soundProfile,
      ),
      androidScheduleMode: plan.exactRequired
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: NotificationChannelRegistry.payloadFor(
        route: plan.route,
        planId: plan.planId,
        extra: <String, dynamic>{'type': plan.type, 'revision': plan.revision},
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> showImmediate({
    required int id,
    required NotificationPlanModel plan,
  }) {
    return NotificationChannelRegistry.plugin.show(
      id,
      plan.title,
      plan.body,
      NotificationChannelRegistry.detailsForCategory(
        plan.category,
        soundProfile: plan.soundProfile,
      ),
      payload: NotificationChannelRegistry.payloadFor(
        route: plan.route,
        planId: plan.planId,
        extra: <String, dynamic>{
          'type': plan.type,
          'revision': plan.revision,
          'fallback': true,
        },
      ),
    );
  }

  @override
  Future<void> cancel(int id) => NotificationChannelRegistry.plugin.cancel(id);
}

class LocalPlanExecutor {
  static const String _registryKey = 'notification_hub.plan_registry.v3';
  static const String _standaloneIdsPrefix = 'notification_hub.standalone_ids.';
  static const LocalNotificationScheduler _defaultScheduler =
      PluginLocalNotificationScheduler();

  static Future<List<Map<String, dynamic>>> reconcile({
    required List<NotificationPlanModel> plans,
    required List<String> cancelPlanIds,
    required int horizonHours,
    bool deliveryEnabled = true,
    bool permissionAuthorized = true,
    bool cancelAllLocalPlans = false,
    LocalNotificationScheduler scheduler = _defaultScheduler,
  }) async {
    final events = <Map<String, dynamic>>[];
    final prefs = await SharedPreferences.getInstance();
    final registry = _loadRegistry(prefs);
    if (!deliveryEnabled || !permissionAuthorized || cancelAllLocalPlans) {
      await _cancelRecords(registry.values, scheduler: scheduler);
      await prefs.remove(_registryKey);
      return events;
    }

    final desiredIds = plans.map((plan) => plan.planId).toSet();
    final removals = <String>{
      ...cancelPlanIds,
      ...registry.keys.where((planId) => !desiredIds.contains(planId)),
    };
    for (final planId in removals) {
      final record = registry.remove(planId);
      if (record != null) {
        await _cancelRecord(record, scheduler: scheduler);
      }
    }

    for (final plan in plans) {
      final fingerprint = jsonEncode(plan.schedulingFingerprint());
      final previous = registry[plan.planId];
      if (previous != null &&
          previous.revision == plan.revision &&
          previous.fingerprint == fingerprint) {
        continue;
      }
      if (previous != null) {
        await _cancelRecord(previous, scheduler: scheduler);
      }
      final scheduleIds = <int>[];
      final occurrences = _occurrences(plan: plan, horizonHours: horizonHours);
      for (final at in occurrences) {
        final notificationId = _notificationId(plan.planId, at);
        try {
          await scheduler.schedule(id: notificationId, plan: plan, at: at);
          scheduleIds.add(notificationId);
        } catch (error) {
          events.add(<String, dynamic>{
            'event_id': 'delivery-failed:${plan.planId}:${plan.revision}',
            'plan_id': plan.planId,
            'revision': plan.revision,
            'outcome': 'delivery_failed',
            'occurred_at': DateTime.now().toUtc().toIso8601String(),
            'failure_code': 'local_schedule_failed',
            'metadata': <String, dynamic>{'error': error.toString()},
          });
        }
      }
      if (scheduleIds.isNotEmpty) {
        registry[plan.planId] = _LocalPlanRecord(
          planId: plan.planId,
          revision: plan.revision,
          fingerprint: fingerprint,
          notificationIds: scheduleIds,
          scheduledAt: occurrences.first.toUtc(),
        );
        events.add(<String, dynamic>{
          'event_id': 'scheduled:${plan.planId}:${plan.revision}',
          'plan_id': plan.planId,
          'revision': plan.revision,
          'outcome': 'scheduled_local',
          'occurred_at': DateTime.now().toUtc().toIso8601String(),
          'metadata': <String, dynamic>{'occurrence_count': scheduleIds.length},
        });
      } else {
        registry.remove(plan.planId);
      }
    }
    await _saveRegistry(prefs, registry);
    return events;
  }

  static Future<List<String>> activePlanIds() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadRegistry(prefs).keys.toList(growable: false);
  }

  static Future<void> clearAll({
    LocalNotificationScheduler scheduler = _defaultScheduler,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final registry = _loadRegistry(prefs);
    await _cancelRecords(registry.values, scheduler: scheduler);
    await prefs.remove(_registryKey);
  }

  static Future<void> cancelPlans(
    List<String> planIds, {
    required List<Map<String, dynamic>> events,
    LocalNotificationScheduler scheduler = _defaultScheduler,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final registry = _loadRegistry(prefs);
    for (final planId in planIds) {
      final record = registry.remove(planId);
      if (record != null) {
        await _cancelRecord(record, scheduler: scheduler);
      }
    }
    await _saveRegistry(prefs, registry);
  }

  static Future<bool> showImmediateFallback(
    NotificationPlanModel plan, {
    LocalNotificationScheduler scheduler = _defaultScheduler,
  }) async {
    try {
      await scheduler.showImmediate(
        id: _stableId('fallback:${plan.planId}'),
        plan: plan,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> scheduleStandaloneOneOff({
    required String key,
    required String title,
    required String body,
    required DateTime when,
    required String category,
    required String route,
    bool exactRequired = false,
  }) async {
    final notificationId = _notificationId(key, when);
    await NotificationChannelRegistry.plugin.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      NotificationChannelRegistry.detailsForCategory(category),
      androidScheduleMode: exactRequired
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: NotificationChannelRegistry.payloadFor(
        route: route,
        planId: key,
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_standaloneIdsPrefix$key', <String>[
      notificationId.toString(),
    ]);
  }

  static Future<void> cancelStandalone(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final rawIds =
        prefs.getStringList('$_standaloneIdsPrefix$key') ?? const <String>[];
    for (final raw in rawIds) {
      final id = int.tryParse(raw);
      if (id != null) await _defaultScheduler.cancel(id);
    }
    await prefs.remove('$_standaloneIdsPrefix$key');
  }

  static Future<void> _cancelRecords(
    Iterable<_LocalPlanRecord> records, {
    required LocalNotificationScheduler scheduler,
  }) async {
    for (final record in records) {
      await _cancelRecord(record, scheduler: scheduler);
    }
  }

  static Future<void> _cancelRecord(
    _LocalPlanRecord record, {
    required LocalNotificationScheduler scheduler,
  }) async {
    for (final id in record.notificationIds) {
      await scheduler.cancel(id);
    }
  }

  static Map<String, _LocalPlanRecord> _loadRegistry(SharedPreferences prefs) {
    final raw = prefs.getString(_registryKey);
    if (raw == null || raw.isEmpty) return <String, _LocalPlanRecord>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          _LocalPlanRecord.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      );
    } catch (_) {
      return <String, _LocalPlanRecord>{};
    }
  }

  static Future<void> _saveRegistry(
    SharedPreferences prefs,
    Map<String, _LocalPlanRecord> registry,
  ) {
    return prefs.setString(
      _registryKey,
      jsonEncode(registry.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  static List<DateTime> _occurrences({
    required NotificationPlanModel plan,
    required int horizonHours,
  }) {
    final now = DateTime.now();
    final horizon = now.add(Duration(hours: horizonHours));
    final expireAt = plan.expireAt;
    if (plan.scheduleSpec.isEmpty) {
      final when = plan.deliverAt;
      if (when == null || when.isBefore(now)) {
        return const <DateTime>[];
      }
      if (expireAt != null && when.isAfter(expireAt)) {
        return const <DateTime>[];
      }
      return <DateTime>[when];
    }

    final kind = (plan.scheduleSpec['kind'] ?? '').toString();
    final notBefore = _parseDateTime(plan.scheduleSpec['not_before']);
    switch (kind) {
      case 'daily_time':
        return _dailyOccurrences(
          hour:
              int.tryParse((plan.scheduleSpec['hour'] ?? '0').toString()) ?? 0,
          minute:
              int.tryParse((plan.scheduleSpec['minute'] ?? '0').toString()) ??
              0,
          now: now,
          horizon: horizon,
          expireAt: expireAt,
          notBefore: notBefore,
        );
      case 'weekly_time':
        return _weeklyOccurrences(
          hour:
              int.tryParse((plan.scheduleSpec['hour'] ?? '0').toString()) ?? 0,
          minute:
              int.tryParse((plan.scheduleSpec['minute'] ?? '0').toString()) ??
              0,
          daysOfWeek: ((plan.scheduleSpec['days_of_week'] as List?) ?? const [])
              .map((item) => int.tryParse(item.toString()) ?? 0)
              .where((item) => item >= 1 && item <= 7)
              .toList(growable: false),
          now: now,
          horizon: horizon,
          expireAt: expireAt,
          notBefore: notBefore,
        );
      case 'interval_window':
        return _intervalOccurrences(
          intervalMinutes:
              int.tryParse(
                (plan.scheduleSpec['interval_minutes'] ?? '60').toString(),
              ) ??
              60,
          startTime: (plan.scheduleSpec['start_time'] ?? '09:00:00').toString(),
          endTime: (plan.scheduleSpec['end_time'] ?? '21:00:00').toString(),
          now: now,
          horizon: horizon,
          expireAt: expireAt,
          notBefore: notBefore,
        );
      default:
        return const <DateTime>[];
    }
  }

  static List<DateTime> _dailyOccurrences({
    required int hour,
    required int minute,
    required DateTime now,
    required DateTime horizon,
    required DateTime? expireAt,
    required DateTime? notBefore,
  }) {
    final rows = <DateTime>[];
    var cursor = DateTime(now.year, now.month, now.day, hour, minute);
    if (!cursor.isAfter(now)) {
      cursor = cursor.add(const Duration(days: 1));
    }
    while (!cursor.isAfter(horizon)) {
      if ((notBefore == null || !cursor.isBefore(notBefore)) &&
          (expireAt == null || !cursor.isAfter(expireAt))) {
        rows.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return rows;
  }

  static List<DateTime> _weeklyOccurrences({
    required int hour,
    required int minute,
    required List<int> daysOfWeek,
    required DateTime now,
    required DateTime horizon,
    required DateTime? expireAt,
    required DateTime? notBefore,
  }) {
    final allowed = daysOfWeek.isEmpty
        ? <int>{1, 2, 3, 4, 5, 6, 7}
        : daysOfWeek.toSet();
    final rows = <DateTime>[];
    for (
      var cursor = DateTime(now.year, now.month, now.day);
      !cursor.isAfter(horizon);
      cursor = cursor.add(const Duration(days: 1))
    ) {
      if (!allowed.contains(cursor.weekday)) {
        continue;
      }
      final at = DateTime(cursor.year, cursor.month, cursor.day, hour, minute);
      if (!at.isAfter(now)) {
        continue;
      }
      if (notBefore != null && at.isBefore(notBefore)) {
        continue;
      }
      if (expireAt != null && at.isAfter(expireAt)) {
        continue;
      }
      rows.add(at);
    }
    return rows;
  }

  static List<DateTime> _intervalOccurrences({
    required int intervalMinutes,
    required String startTime,
    required String endTime,
    required DateTime now,
    required DateTime horizon,
    required DateTime? expireAt,
    required DateTime? notBefore,
  }) {
    final rows = <DateTime>[];
    final startParts = _parseClock(startTime);
    final endParts = _parseClock(endTime);
    for (
      var day = DateTime(now.year, now.month, now.day);
      !day.isAfter(horizon);
      day = day.add(const Duration(days: 1))
    ) {
      var cursor = DateTime(
        day.year,
        day.month,
        day.day,
        startParts.$1,
        startParts.$2,
      );
      final end = DateTime(
        day.year,
        day.month,
        day.day,
        endParts.$1,
        endParts.$2,
      );
      while (!cursor.isAfter(end)) {
        if (cursor.isAfter(now) &&
            (notBefore == null || !cursor.isBefore(notBefore)) &&
            (expireAt == null || !cursor.isAfter(expireAt)) &&
            !cursor.isAfter(horizon)) {
          rows.add(cursor);
        }
        cursor = cursor.add(Duration(minutes: intervalMinutes));
      }
    }
    return rows;
  }

  static (int, int) _parseClock(String raw) {
    final parts = raw.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (hour.clamp(0, 23), minute.clamp(0, 59));
  }

  static DateTime? _parseDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }

  static int _notificationId(String seed, DateTime at) {
    return _stableId('$seed:${at.toIso8601String()}');
  }

  static int _stableId(String text) {
    var hash = 5381;
    for (final unit in utf8.encode(text)) {
      hash = ((hash << 5) + hash) + unit;
      hash &= 0x7fffffff;
    }
    return hash;
  }
}

class _LocalPlanRecord {
  const _LocalPlanRecord({
    required this.planId,
    required this.revision,
    required this.fingerprint,
    required this.notificationIds,
    required this.scheduledAt,
  });

  final String planId;
  final int revision;
  final String fingerprint;
  final List<int> notificationIds;
  final DateTime scheduledAt;

  factory _LocalPlanRecord.fromJson(Map<String, dynamic> json) {
    return _LocalPlanRecord(
      planId: (json['plan_id'] ?? '').toString(),
      revision: int.tryParse((json['revision'] ?? '1').toString()) ?? 1,
      fingerprint: (json['fingerprint'] ?? '').toString(),
      notificationIds: ((json['notification_ids'] as List?) ?? const [])
          .map((value) => int.tryParse(value.toString()))
          .whereType<int>()
          .toList(growable: false),
      scheduledAt:
          DateTime.tryParse((json['scheduled_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'plan_id': planId,
    'revision': revision,
    'fingerprint': fingerprint,
    'notification_ids': notificationIds,
    'scheduled_at': scheduledAt.toUtc().toIso8601String(),
  };
}
