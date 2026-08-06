import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> pushAppRoute(String route) async {
  final trimmed = route.trim();
  if (trimmed.isEmpty) {
    return;
  }
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) {
    return;
  }
  await navigator.pushNamed(trimmed);
}
