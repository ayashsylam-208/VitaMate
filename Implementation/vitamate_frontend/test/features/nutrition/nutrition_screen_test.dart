import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vitamate/core/routing/routes.dart';
import 'package:vitamate/core/testing/app_test_keys.dart';

import '../../support/vitamate_test_harness.dart';

void main() {
  testWidgets('log meal requires a food selection before review', (
    tester,
  ) async {
    final harness = VitamateTestHarness();
    await harness.bootstrap();

    await harness.pumpAppRoute(tester, initialRoute: Routes.meals);
    await harness.settleApp(tester);
    await tester.tap(
      find.byKey(const ValueKey(AppTestKeys.nutritionLogMealButton)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey(AppTestKeys.nutritionLogMealSheet)),
      findsOneWidget,
    );
    final review = find.byKey(
      const ValueKey(AppTestKeys.nutritionSaveMealButton),
    );
    expect(tester.widget<FilledButton>(review).onPressed, isNull);
    expect(find.text('Nutrition and points will be calculated'), findsNothing);
  });

  testWidgets('manual flow selects an amount and saves exactly once', (
    tester,
  ) async {
    final harness = VitamateTestHarness();
    await harness.bootstrap();

    await harness.pumpAppRoute(tester, initialRoute: Routes.meals);
    await harness.settleApp(tester);
    await tester.tap(
      find.byKey(const ValueKey(AppTestKeys.nutritionLogMealButton)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nutrition-open-food-library')));
    await tester.pumpAndSettle();

    expect(find.text('Food library'), findsOneWidget);
    expect(find.byTooltip('Choose quantity'), findsWidgets);
    await tester.tap(find.byTooltip('Choose quantity').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this amount'));
    await tester.pumpAndSettle();

    final review = find.byKey(
      const ValueKey(AppTestKeys.nutritionSaveMealButton),
    );
    expect(tester.widget<FilledButton>(review).onPressed, isNotNull);
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(find.text('Review meal'), findsWidgets);
    expect(
      find.text(
        'Nutrition and points will be calculated by VitaMate after saving.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirm and save'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey(AppTestKeys.nutritionScreen)),
      findsOneWidget,
    );
    expect(find.text('Meal logged'), findsWidgets);
    expect(harness.requestCount('POST', '/api/meals/'), 1);
  });

  testWidgets('food library debounces fast typing', (tester) async {
    final harness = VitamateTestHarness();
    await harness.bootstrap();

    await harness.pumpAppRoute(tester, initialRoute: Routes.meals);
    await harness.settleApp(tester);
    await tester.tap(
      find.byKey(const ValueKey(AppTestKeys.nutritionLogMealButton)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nutrition-open-food-library')));
    await tester.pumpAndSettle();

    final before = harness.requestCount('GET', '/api/foods/autocomplete/');
    final search = find.byKey(const ValueKey(AppTestKeys.nutritionSearchField));
    await tester.enterText(search, 'c');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(search, 'ch');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(search, 'chi');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final after = harness.requestCount('GET', '/api/foods/autocomplete/');
    expect(after - before, 1);
  });
}
