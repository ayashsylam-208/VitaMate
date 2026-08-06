import 'dart:async';

import 'package:flutter/material.dart';

import '../notification_hub/notification_hub.dart';
import '../routing/app_navigator.dart';
import '../routing/routes.dart';
import '../routing/vitamate_route_observer.dart';
import '../storage/secure_storage.dart';

class AuthSessionCoordinator {
  AuthSessionCoordinator._();

  static bool _handlingExpiredSession = false;

  static Future<void> handleExpiredSession() async {
    if (_handlingExpiredSession) {
      return;
    }
    _handlingExpiredSession = true;
    try {
      await SecureStorage.clear();
      try {
        await NotificationHubController.instance.clearLocalState();
      } catch (_) {
        // Auth recovery must not depend on notification plugin availability.
      }
      _redirectToLoginAfterFrame();
    } finally {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 500)).then((_) {
          _handlingExpiredSession = false;
        }),
      );
    }
  }

  static void _redirectToLoginAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentRoute = vitaMateRouteObserver.currentRouteName.value;
      if (_isAuthRoute(currentRoute)) {
        return;
      }

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        return;
      }

      navigator.pushNamedAndRemoveUntil(Routes.login, (_) => false);
      appScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Your session expired. Please sign in again.'),
          ),
        );
    });
  }

  static bool _isAuthRoute(String? route) {
    return route == Routes.login ||
        route == Routes.signup ||
        route == Routes.onboarding;
  }
}
