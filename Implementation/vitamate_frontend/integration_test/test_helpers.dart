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

Future<Finder> waitForAnyFinder(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    for (final finder in finders) {
      if (finder.evaluate().isNotEmpty) {
        return finder;
      }
    }
  }

  throw TestFailure('Timed out waiting for any finder: $finders');
}

Future<Finder> scrollUntilAnyFinderVisible(
  WidgetTester tester,
  List<Finder> finders, {
  Finder? scrollable,
  double delta = 250,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    for (final finder in finders) {
      if (finder.evaluate().isNotEmpty) {
        return finder;
      }
    }

    final scrollableFinder = scrollable ?? find.byType(Scrollable).first;
    if (scrollableFinder.evaluate().isEmpty) {
      break;
    }

    await tester.drag(scrollableFinder, Offset(0, -delta), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
  }

  throw TestFailure('Timed out scrolling to any finder: $finders');
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

Future<void> scrollUntilFinderVisible(
  WidgetTester tester,
  Finder target, {
  Finder? scrollable,
  double delta = 250,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (target.evaluate().isNotEmpty) {
      return;
    }

    final scrollableFinder = scrollable ?? find.byType(Scrollable).first;
    if (scrollableFinder.evaluate().isEmpty) {
      break;
    }

    await tester.drag(scrollableFinder, Offset(0, -delta), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
  }

  throw TestFailure('Timed out scrolling to finder: $target');
}

Future<void> loginAsChronicUser(WidgetTester tester) async {
  await waitForFinder(
    tester,
    find.byKey(const ValueKey(AppTestKeys.loginUsernameField)),
  );
  await enterTextByKey(tester, AppTestKeys.loginUsernameField, 'e2e_chronic');
  await enterTextByKey(tester, AppTestKeys.loginPasswordField, 'Pass123!');
  await tapByKey(tester, AppTestKeys.loginSubmitButton);
}

Future<void> waitForHomeScreen(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  await waitForText(tester, 'Daily Health Score', timeout: timeout);
  await tester.pump(const Duration(milliseconds: 500));
}
