import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vitamate/core/testing/app_test_keys.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hypertension chronic flow updates condition detail and home', (
    WidgetTester tester,
  ) async {
    await launchIntegrationApp(tester);
    await loginAsChronicUser(tester);
    await waitForHomeScreen(tester);

    final homeAddButtonFinder = find.byKey(
      const ValueKey(AppTestKeys.homeConditionsCenterAddButton),
    );
    await tester.scrollUntilVisible(
      homeAddButtonFinder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(homeAddButtonFinder);
    await tester.pump();
    await waitForFinder(
      tester,
      find.byKey(const ValueKey(AppTestKeys.chronicScreenHeader)),
    );

    final addHypertensionFinder = find
        .byKey(ValueKey(AppTestKeys.chronicSupportedAddButton('hypertension')))
        .first;
    await waitForFinder(tester, addHypertensionFinder);
    await tester.ensureVisible(addHypertensionFinder);
    await tester.tap(addHypertensionFinder);
    await tester.pump();

    await enterTextByKey(
      tester,
      AppTestKeys.chronicCreateField(
        slug: 'hypertension',
        field: 'systolicField',
      ),
      '138',
    );
    await enterTextByKey(
      tester,
      AppTestKeys.chronicCreateField(
        slug: 'hypertension',
        field: 'diastolicField',
      ),
      '88',
    );
    await enterTextByKey(
      tester,
      AppTestKeys.chronicCreateField(slug: 'hypertension', field: 'pulseField'),
      '72',
    );
    await tapByKey(tester, AppTestKeys.chronicCreateSaveButton);

    await waitForFinder(
      tester,
      find.byKey(const ValueKey(AppTestKeys.chronicDetailAddReadingButton)),
      timeout: const Duration(seconds: 30),
    );

    await tapByKey(tester, AppTestKeys.chronicDetailAddReadingButton);
    await enterTextByKey(
      tester,
      AppTestKeys.chronicReadingField(
        slug: 'hypertension',
        field: 'systolicField',
      ),
      '145',
    );
    await enterTextByKey(
      tester,
      AppTestKeys.chronicReadingField(
        slug: 'hypertension',
        field: 'diastolicField',
      ),
      '92',
    );
    await enterTextByKey(
      tester,
      AppTestKeys.chronicReadingField(
        slug: 'hypertension',
        field: 'pulseField',
      ),
      '84',
    );
    await tapByKey(tester, AppTestKeys.chronicReadingSaveButton);

    await waitForFinder(
      tester,
      find.byKey(const ValueKey(AppTestKeys.chronicDetailSummaryCard)),
      timeout: const Duration(seconds: 30),
    );
    await waitForText(tester, 'High');
    final readingsListFinder = find.byKey(
      const ValueKey(AppTestKeys.chronicDetailReadingsList),
    );
    await scrollUntilFinderVisible(
      tester,
      readingsListFinder,
      timeout: const Duration(seconds: 30),
    );
    await waitForFinder(
      tester,
      readingsListFinder,
      timeout: const Duration(seconds: 30),
    );
    await waitForFinder(tester, find.textContaining('145/92'));

    await tapByKey(tester, AppTestKeys.chronicDetailBackButton);
    await waitForFinder(
      tester,
      find.byKey(const ValueKey(AppTestKeys.chronicScreenHeader)),
    );
    await tester.pageBack();
    await tester.pump();
    await waitForHomeScreen(tester);

    final homeConditionCardFinder = find.byKey(
      ValueKey(AppTestKeys.homeConditionCard('hypertension')),
    );
    await tester.scrollUntilVisible(
      homeConditionCardFinder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(homeConditionCardFinder, findsOneWidget);
    expect(find.text('No chronic conditions added yet'), findsNothing);
  });
}
