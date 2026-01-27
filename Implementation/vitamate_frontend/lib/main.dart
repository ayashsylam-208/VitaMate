import 'package:flutter/material.dart';

import 'app.dart';
import 'core/notifications/notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationsService.init();

  runApp(const VitaMateApp());
}

