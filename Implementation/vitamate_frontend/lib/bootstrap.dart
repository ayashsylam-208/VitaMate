import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/http_client.dart';
import 'core/notifications/notifications_service.dart';
import 'core/runtime/app_runtime.dart';

Future<void> runVitaMateApp({bool enableNotifications = true}) async {
  WidgetsFlutterBinding.ensureInitialized();

  AppRuntime.configure(enableNotifications: enableNotifications);

  if (AppRuntime.notificationsEnabled) {
    await NotificationsService.init();
  }

  await HttpClient.init();

  runApp(const VitaMateApp());
}
