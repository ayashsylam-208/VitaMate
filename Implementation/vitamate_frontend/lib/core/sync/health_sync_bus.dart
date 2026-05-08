import 'dart:async';

import 'package:flutter/foundation.dart';

enum HealthSyncScope {
  nutrition,
  hydration,
  sleep,
  steps,
  activity,
  medication,
  chronic,
  habits,
  homeOverview,
  progressHistory,
}

class HealthSyncBus extends ChangeNotifier {
  HealthSyncBus._();

  static final HealthSyncBus instance = HealthSyncBus._();

  static const Duration _coalesceWindow = Duration(milliseconds: 120);

  final Set<HealthSyncScope> _pendingScopes = <HealthSyncScope>{};
  Set<HealthSyncScope> _lastPublishedScopes = <HealthSyncScope>{};
  Timer? _flushTimer;

  Set<HealthSyncScope> get lastPublishedScopes =>
      Set<HealthSyncScope>.unmodifiable(_lastPublishedScopes);

  bool affects(Set<HealthSyncScope> watchedScopes) {
    for (final scope in watchedScopes) {
      if (_lastPublishedScopes.contains(scope)) {
        return true;
      }
    }
    return false;
  }

  void publish(Iterable<HealthSyncScope> scopes) {
    _pendingScopes.addAll(scopes);
    _flushTimer ??= Timer(_coalesceWindow, _flushPending);
  }

  void publishScope(HealthSyncScope scope) {
    publish(<HealthSyncScope>{scope});
  }

  void notifyTrackerDataChanged() {
    publish(HealthSyncScope.values);
  }

  void _flushPending() {
    _flushTimer = null;
    if (_pendingScopes.isEmpty) {
      return;
    }
    _lastPublishedScopes = Set<HealthSyncScope>.from(_pendingScopes);
    _pendingScopes.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }
}
