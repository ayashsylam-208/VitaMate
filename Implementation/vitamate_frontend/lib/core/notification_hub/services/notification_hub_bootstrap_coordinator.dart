import 'dart:async';

import 'package:flutter/widgets.dart';

import '../state/notification_hub_controller.dart';
import 'notification_channel_registry.dart';

class NotificationHubBootstrapCoordinator {
  NotificationHubBootstrapCoordinator._();

  static final NotificationHubBootstrapCoordinator instance =
      NotificationHubBootstrapCoordinator._();

  Future<void>? _initialization;

  Future<void> initialize() {
    return _initialization ??= _initializeOnce();
  }

  Future<void> _initializeOnce() async {
    await NotificationChannelRegistry.init();
    NotificationHubController.instance.start();
    await NotificationChannelRegistry.readPermissionSnapshot();
  }

  void onAppReady({required bool authenticated}) {
    if (!authenticated) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(onAuthenticated());
    });
  }

  Future<void> onAuthenticated() async {
    await initialize();
    await NotificationHubController.instance.onAuthenticated();
  }

  Future<void> onLogout() =>
      NotificationHubController.instance.clearLocalState();
}
