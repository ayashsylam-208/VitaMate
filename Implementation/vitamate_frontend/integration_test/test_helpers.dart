import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vitamate/bootstrap.dart';
import 'package:vitamate/core/testing/app_test_keys.dart';

Future<void> launchIntegrationApp(WidgetTester tester) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  await runVitaMateApp(enableNotifications: false);
  await tester.pump();
}

Future<void> waitForFinder(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  throw TestFailure('Timed out waiting for finder: $finder');
}

Future<void> waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  await waitForFinder(tester, find.text(text), timeout: timeout);
}

Future<void> tapByKey(
  WidgetTester tester,
  String key, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final finder = find.byKey(ValueKey(key));
  await waitForFinder(tester, finder, timeout: timeout);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> enterTextByKey(
  WidgetTester tester,
  String key,
  String value, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final finder = find.byKey(ValueKey(key));
  await waitForFinder(tester, finder, timeout: timeout);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.enterText(finder, value);
  await tester.pump();
}

Future<void> loginAsChronicUser(WidgetTester tester) async {
  await waitForFinder(
    tester,
    find.byKey(const ValueKey(AppTestKeys.loginUsernameField)),
  );
  await enterTextByKey(
    tester,
    AppTestKeys.loginUsernameField,
    'e2e_chronic',
  );
  await enterTextByKey(
    tester,
    AppTestKeys.loginPasswordField,
    'Pass123!',
  );
  await tapByKey(tester, AppTestKeys.loginSubmitButton);
}

Future<void> waitForHomeScreen(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  await waitForText(tester, 'Daily Health Score', timeout: timeout);
  await tester.pump(const Duration(milliseconds: 500));
}
