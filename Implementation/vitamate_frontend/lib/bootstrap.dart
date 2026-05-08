import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/network/http_client.dart';
import 'core/notifications/notifications_service.dart';
import 'core/runtime/app_runtime.dart';

Future<void> runVitaMateApp({bool enableNotifications = true}) async {
  WidgetsFlutterBinding.ensureInitialized();
  _installGlobalErrorHandlers();

  AppRuntime.configure(enableNotifications: enableNotifications);

  if (AppRuntime.notificationsEnabled) {
    await NotificationsService.init();
  }

  await HttpClient.init();

  runApp(const VitaMateApp());
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
