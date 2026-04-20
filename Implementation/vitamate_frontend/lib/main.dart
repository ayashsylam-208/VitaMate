import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/http_client.dart';
import 'core/notifications/notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationsService.init();
  await HttpClient.init();

  runApp(const VitaMateApp());
}
