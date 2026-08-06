import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../sync/health_sync_bus.dart';
import '../../time/local_timezone.dart';
import '../data/notification_hub_api.dart';
import '../models/device_registration_result.dart';
import '../models/notification_preferences.dart';
import '../models/notification_permission_snapshot.dart';
import '../models/notification_sync_payload.dart';
import '../services/device_identity_service.dart';
import '../services/in_app_event_presenter.dart';
import '../services/local_plan_executor.dart';
import '../services/notification_channel_registry.dart';
import '../services/notification_deep_link_router.dart';

class NotificationHubController extends ChangeNotifier
    with WidgetsBindingObserver {
  NotificationHubController({NotificationHubApi? api}) : _api = api;

  static final NotificationHubController instance = NotificationHubController();

  NotificationHubApi? _api;

  NotificationPreferences preferences = NotificationPreferences.defaults();
  DeviceRegistrationResult? registration;
  bool _started = false;
  bool _syncing = false;
  bool _resyncRequested = false;
  bool _authenticated = false;
  DateTime? _lastSyncAt;
  Timer? _resumeDebounce;
  NotificationPermissionSnapshot? permissionState;
  String? error;

  bool get isStarted => _started;

  NotificationHubApi get _client => _api ??= NotificationHubApi();

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    HealthSyncBus.instance.addListener(_handleHealthSync);
    unawaited(NotificationChannelRegistry.init());
  }

  Future<void> onAuthenticated() async {
    _authenticated = true;
    await refreshPreferences();
    await syncNow(reason: 'authenticated');
  }

  Future<void> clearLocalState() async {
    _authenticated = false;
    await LocalPlanExecutor.clearAll();
    preferences = NotificationPreferences.defaults();
    registration = null;
    permissionState = null;
    _lastSyncAt = null;
    notifyListeners();
  }

  Future<void> refreshPreferences() async {
    if (!_authenticated) {
      return;
    }
    try {
      preferences = NotificationPreferences.fromJson(
        await _client.fetchPreferences(),
      );
      notifyListeners();
    } catch (_) {
      // Keep the last known preferences and retry on next sync.
    }
  }

  Future<NotificationPreferences> updatePreferences(
    Map<String, dynamic> payload,
  ) async {
    if (!_authenticated) {
      preferences = NotificationPreferences.fromJson(<String, dynamic>{
        ...preferences.toJson(),
        ...payload,
      });
      notifyListeners();
      return preferences;
    }
    final raw = await _client.patchPreferences(payload);
    preferences = NotificationPreferences.fromJson(raw);
    notifyListeners();
    await syncNow(reason: 'preferences');
    return preferences;
  }

  Future<NotificationPermissionSnapshot> refreshPermissionState({
    bool request = false,
  }) async {
    permissionState = request
        ? await NotificationChannelRegistry.requestPermissions()
        : await NotificationChannelRegistry.readPermissionSnapshot();
    notifyListeners();
    if (_authenticated) {
      await syncNow(
        reason: request ? 'permission-request' : 'permission-check',
      );
    }
    return permissionState!;
  }

  Future<void> syncNow({String reason = 'manual'}) async {
    if (!_authenticated) {
      return;
    }
    if (_syncing) {
      _resyncRequested = true;
      return;
    }
    if (reason == 'resume' &&
        _lastSyncAt != null &&
        DateTime.now().difference(_lastSyncAt!) < const Duration(seconds: 8)) {
      return;
    }
    _syncing = true;
    error = null;
    notifyListeners();
    try {
      final installationId = await DeviceIdentityService.installationId();
      permissionState =
          await NotificationChannelRegistry.readPermissionSnapshot();
      final permissionSnapshot = permissionState!.toJson();
      final device = await _client.registerDevice(<String, dynamic>{
        'installation_id': installationId,
        'platform': defaultTargetPlatform.name,
        'timezone': LocalTimezone.ianaName,
        'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
        'app_version': '1.0.0',
        'notifications_authorized':
            permissionSnapshot['notifications_authorized'] == true,
        'exact_alarm_authorized':
            permissionSnapshot['exact_alarm_authorized'] == true,
        'permission_status': permissionSnapshot['permission_status'],
        'notifications_enabled_systemwide':
            permissionSnapshot['notifications_enabled_systemwide'] == true,
        'checked_at': permissionSnapshot['checked_at'],
      });
      registration = DeviceRegistrationResult.fromJson(device);

      final lastKnownPlanIds = await LocalPlanExecutor.activePlanIds();
      final envelope = await _client.sync(<String, dynamic>{
        'installation_id': installationId,
        'last_known_plan_ids': lastKnownPlanIds,
        'foreground_state': _isForeground ? 'foreground' : 'background',
        'timezone': LocalTimezone.ianaName,
        'permission_snapshot': permissionSnapshot,
        'reason': reason,
      });
      final payload = NotificationSyncPayload.fromJson(envelope.data);
      final reportEvents = <Map<String, dynamic>>[];
      final presentations = await InAppEventPresenter.presentAll(
        payload.inAppEvents,
      );
      for (final presentation in presentations) {
        reportEvents.addAll(_presentationReports(presentation));
      }
      reportEvents.addAll(
        await LocalPlanExecutor.reconcile(
          plans: payload.plans,
          cancelPlanIds: payload.cancelPlanIds,
          horizonHours: payload.horizonHours,
          deliveryEnabled: payload.deliveryEnabled,
          permissionAuthorized:
              permissionState?.canScheduleLocalNotifications == true,
          cancelAllLocalPlans: payload.cancelAllLocalPlans,
        ),
      );
      if (reportEvents.isNotEmpty) {
        await _client.report(<String, dynamic>{
          'installation_id': installationId,
          'events': reportEvents,
        });
      }
      _lastSyncAt = DateTime.now();
    } catch (e) {
      error = e.toString();
    } finally {
      _syncing = false;
      notifyListeners();
      if (_resyncRequested) {
        _resyncRequested = false;
        unawaited(syncNow(reason: 'coalesced'));
      }
    }
  }

  Future<void> handleNotificationPayload(String payload) async {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final route = (json['route'] ?? '').toString().trim();
    final planId = (json['plan_id'] ?? '').toString().trim();
    final revision = int.tryParse((json['revision'] ?? '1').toString()) ?? 1;
    if (route.isNotEmpty) {
      await NotificationDeepLinkRouter.open(route);
    }
    if (!_authenticated || planId.isEmpty) {
      return;
    }
    final installationId = await DeviceIdentityService.installationId();
    await _client.report(<String, dynamic>{
      'installation_id': installationId,
      'events': <Map<String, dynamic>>[
        <String, dynamic>{
          'event_id':
              'opened:$planId:$revision:${DateTime.now().millisecondsSinceEpoch}',
          'plan_id': planId,
          'revision': revision,
          'outcome': 'opened',
          'occurred_at': DateTime.now().toUtc().toIso8601String(),
        },
      ],
    });
  }

  bool get _isForeground =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void _handleHealthSync() {
    if (!_authenticated) {
      return;
    }
    unawaited(syncNow(reason: 'health-sync'));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_authenticated) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _resumeDebounce?.cancel();
      _resumeDebounce = Timer(
        const Duration(milliseconds: 500),
        () => unawaited(syncNow(reason: 'resume')),
      );
    }
  }

  @override
  void dispose() {
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      HealthSyncBus.instance.removeListener(_handleHealthSync);
    }
    _resumeDebounce?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _presentationReports(
    InAppEventPresentation presentation,
  ) {
    final event = presentation.event;
    final result = presentation.result;
    final rows = <Map<String, dynamic>>[];
    Map<String, dynamic> report(
      String outcome, {
      DateTime? occurredAt,
      String? failureCode,
    }) => <String, dynamic>{
      'event_id': '$outcome:${event.planId}:${event.revision}',
      'plan_id': event.planId,
      'revision': event.revision,
      'outcome': outcome,
      'occurred_at': (occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
      if (failureCode != null) 'failure_code': failureCode,
    };

    if (result.presentedAt != null) {
      rows.add(report('presented_in_app', occurredAt: result.presentedAt));
    }
    switch (result.outcome) {
      case InAppPresentationOutcome.acknowledged:
        rows.add(report('acknowledged', occurredAt: result.acknowledgedAt));
      case InAppPresentationOutcome.dismissed:
        rows.add(report('dismissed'));
      case InAppPresentationOutcome.failedToPresent:
        rows.add(
          report(
            'delivery_failed',
            failureCode: result.failureCode ?? 'in_app_presentation_failed',
          ),
        );
        if (result.fallbackScheduled) {
          rows.add(report('scheduled_local'));
        }
      case InAppPresentationOutcome.expired:
        rows.add(report('expired'));
      case InAppPresentationOutcome.suppressedByPolicy:
        rows.add(<String, dynamic>{
          ...report('suppressed_by_policy'),
          'suppression_reason':
              result.suppressionReason ?? 'presentation_policy',
        });
      case InAppPresentationOutcome.presented:
        break;
    }
    return rows;
  }
}
