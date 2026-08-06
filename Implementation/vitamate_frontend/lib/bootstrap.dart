import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/network/http_client.dart';
import 'core/notification_hub/notification_hub.dart';
import 'core/routing/routes.dart';
import 'core/runtime/app_runtime.dart';
import 'core/storage/secure_storage.dart';

Future<void> runVitaMateApp({bool enableNotifications = true}) async {
  WidgetsFlutterBinding.ensureInitialized();
  _installGlobalErrorHandlers();

  AppRuntime.configure(enableNotifications: enableNotifications);

  if (AppRuntime.notificationsEnabled) {
    await NotificationHubBootstrapCoordinator.instance.initialize();
  }

  await HttpClient.init();

  final hasStoredSession = await _hasStoredSession();
  final initialRoute = hasStoredSession ? Routes.home : Routes.login;

  runApp(VitaMateApp(initialRoute: initialRoute));

  if (hasStoredSession && AppRuntime.notificationsEnabled) {
    NotificationHubBootstrapCoordinator.instance.onAppReady(
      authenticated: true,
    );
  }
}

Future<bool> _hasStoredSession() async {
  try {
    final access = (await SecureStorage.readAccessToken())?.trim() ?? '';
    final refresh = (await SecureStorage.readRefreshToken())?.trim() ?? '';
    return access.isNotEmpty || refresh.isNotEmpty;
  } catch (e) {
    debugPrint('Unable to read stored auth session: $e');
    return false;
  }
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    if (_isIgnorableClipboardDeadSystemError(
      details.exception,
      details.stack,
    )) {
      debugPrint(
        'Ignored clipboard DeadSystemException after Android system death.',
      );
      return;
    }
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (_isIgnorableClipboardDeadSystemError(error, stack)) {
      debugPrint(
        'Ignored platform clipboard DeadSystemException after Android system death.',
      );
      return true;
    }
    return false;
  };
}

bool _isIgnorableClipboardDeadSystemError(Object error, StackTrace? stack) {
  if (error is! PlatformException) {
    return false;
  }
  final stackText = stack?.toString() ?? '';
  final messageText = '${error.code} ${error.message} ${error.details}'
      .toLowerCase();
  final isDeadSystem = messageText.contains('deadsystemexception');
  final isClipboard =
      messageText.contains('clipboard') ||
      stackText.contains('Clipboard.hasStrings') ||
      stackText.contains('ClipboardStatusNotifier.update');
  return isDeadSystem && isClipboard;
}
