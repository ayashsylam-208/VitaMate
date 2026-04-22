import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vitamate/core/testing/app_test_keys.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke login reaches home and loads key sections', (
    WidgetTester tester,
  ) async {
    await launchIntegrationApp(tester);
    await loginAsChronicUser(tester);

    await waitForHomeScreen(tester);

    final homeAddButtonFinder = find.byKey(
      const ValueKey(AppTestKeys.homeConditionsCenterAddButton),
    );
    final homeOpenButtonFinder = find.byKey(
      const ValueKey(AppTestKeys.homeConditionsCenterOpenButton),
    );

    final homeConditionsActionFinder = await scrollUntilAnyFinderVisible(
      tester,
      [homeAddButtonFinder, homeOpenButtonFinder],
      timeout: const Duration(seconds: 30),
    );

    expect(homeConditionsActionFinder, findsOneWidget);
  });
}
