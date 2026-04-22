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

    await waitForText(tester, 'Daily Health Score');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey(AppTestKeys.homeConditionsCenterAddButton)),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey(AppTestKeys.homeConditionsCenterAddButton)),
      findsOneWidget,
    );
  });
}
