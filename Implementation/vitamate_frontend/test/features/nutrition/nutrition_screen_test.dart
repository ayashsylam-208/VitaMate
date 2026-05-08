import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vitamate/core/routing/routes.dart';
import 'package:vitamate/core/testing/app_test_keys.dart';

import '../../support/vitamate_test_harness.dart';

void main() {
  testWidgets(
    'nutrition screen and log-meal sheet settle with keyboard focus',
    (tester) async {
      final harness = VitamateTestHarness();
      await harness.bootstrap();

      await harness.pumpAppRoute(tester, initialRoute: Routes.meals);
      await harness.settleApp(tester);

      expect(
        find.byKey(const ValueKey(AppTestKeys.nutritionScreen)),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey(AppTestKeys.nutritionLogMealButton)),
      );
      await tester.pumpAndSettle();

      final searchField = find.byKey(
        const ValueKey(AppTestKeys.nutritionSearchField),
      );
      await tester.tap(searchField);
      await tester.showKeyboard(searchField);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey(AppTestKeys.nutritionLogMealSheet)),
        findsOneWidget,
      );
      expect(searchField, findsOneWidget);
    },
  );

  testWidgets('fast typing keeps autocomplete traffic bounded', (tester) async {
    final harness = VitamateTestHarness();
    await harness.bootstrap();

    await harness.pumpAppRoute(tester, initialRoute: Routes.meals);
    await harness.settleApp(tester);

    await tester.tap(
      find.byKey(const ValueKey(AppTestKeys.nutritionLogMealButton)),
    );
    await tester.pumpAndSettle();

    final searchField = find.byKey(
      const ValueKey(AppTestKeys.nutritionSearchField),
    );
    await tester.enterText(searchField, 'c');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.enterText(searchField, 'ch');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.enterText(searchField, 'chi');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('Chicken Rice Bowl'), findsOneWidget);
    expect(
      harness.requestCount('GET', '/api/foods/autocomplete/'),
      lessThanOrEqualTo(3),
    );
  });

  testWidgets('meal type chips filter default food suggestions', (
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

    expect(find.text('Overnight Oats'), findsOneWidget);
    expect(find.text('Chicken Rice Bowl'), findsNothing);

    final lunchChip = find.text('Lunch');
    await tester.ensureVisible(lunchChip);
    await tester.tap(lunchChip);
    await tester.pumpAndSettle();

    expect(find.text('Chicken Rice Bowl'), findsOneWidget);
    expect(find.text('Overnight Oats'), findsNothing);
  });

  testWidgets('meal type search falls back outside selected meal category', (
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

    final dinnerChip = find.text('Dinner');
    await tester.ensureVisible(dinnerChip);
    await tester.tap(dinnerChip);
    await tester.pumpAndSettle();

    final searchField = find.byKey(
      const ValueKey(AppTestKeys.nutritionSearchField),
    );
    await tester.enterText(searchField, 'chicken');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('Similar outside selected category'), findsOneWidget);
    expect(find.text('Chicken Rice Bowl'), findsOneWidget);
  });

  testWidgets('meal-type and category changes do not trigger request churn', (
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

    final searchField = find.byKey(
      const ValueKey(AppTestKeys.nutritionSearchField),
    );
    await tester.enterText(searchField, 'co');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.text('Drink'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee').last);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('Cold Brew'), findsOneWidget);
    expect(
      harness.requestCount('GET', '/api/foods/autocomplete/'),
      lessThanOrEqualTo(4),
    );
  });

  testWidgets(
    'category fallback shows similar foods outside selected category',
    (tester) async {
      final harness = VitamateTestHarness();
      await harness.bootstrap();

      await harness.pumpAppRoute(tester, initialRoute: Routes.meals);
      await harness.settleApp(tester);

      await tester.tap(
        find.byKey(const ValueKey(AppTestKeys.nutritionLogMealButton)),
      );
      await tester.pumpAndSettle();

      final searchField = find.byKey(
        const ValueKey(AppTestKeys.nutritionSearchField),
      );
      await tester.enterText(searchField, 'co');
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.text('Drink'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juice').last);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(find.text('Similar outside selected category'), findsOneWidget);
      expect(find.text('Cold Brew'), findsOneWidget);

      await tester.tap(find.text('Cold Brew'));
      await tester.pumpAndSettle();

      expect(find.text('Caffeine 95 mg'), findsOneWidget);
      final saveButton = find.byKey(
        const ValueKey(AppTestKeys.nutritionSaveMealButton),
      );
      await tester.ensureVisible(saveButton);
      expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNotNull);
    },
  );

  testWidgets('health badges warn without blocking meal logging', (
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

    final searchField = find.byKey(
      const ValueKey(AppTestKeys.nutritionSearchField),
    );
    await tester.enterText(searchField, 'orange');
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.text('Drink'));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('Orange Juice'), findsOneWidget);
    expect(find.text('Sugar watch'), findsWidgets);

    await tester.tap(find.text('Orange Juice'));
    await tester.pumpAndSettle();

    final saveButton = find.byKey(
      const ValueKey(AppTestKeys.nutritionSaveMealButton),
    );
    await tester.ensureVisible(saveButton);
    expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNotNull);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Meal logged'), findsOneWidget);
    expect(harness.requestCount('POST', '/api/meals/'), 1);
  });

  testWidgets(
    'saving a selected meal reloads once and reuses chronic guidance',
    (tester) async {
      final harness = VitamateTestHarness();
      await harness.bootstrap();

      await harness.pumpAppRoute(tester, initialRoute: Routes.meals);
      await harness.settleApp(tester);

      await tester.tap(
        find.byKey(const ValueKey(AppTestKeys.nutritionLogMealButton)),
      );
      await tester.pumpAndSettle();

      final searchField = find.byKey(
        const ValueKey(AppTestKeys.nutritionSearchField),
      );
      await tester.enterText(searchField, 'chicken');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chicken Rice Bowl'));
      await tester.pumpAndSettle();
      final saveButton = find.byKey(
        const ValueKey(AppTestKeys.nutritionSaveMealButton),
      );
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Meal logged'), findsOneWidget);
      expect(harness.requestCount('POST', '/api/meals/'), 1);
      expect(harness.requestCount('GET', '/api/nutrition/summary/'), 2);
      expect(
        harness.requestCount('GET', '/api/chronic/overview/?view=guidance'),
        1,
      );
    },
  );

  testWidgets('progress tab stays reachable after logging from nutrition', (
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

    final searchField = find.byKey(
      const ValueKey(AppTestKeys.nutritionSearchField),
    );
    await tester.enterText(searchField, 'chicken');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chicken Rice Bowl'));
    await tester.pumpAndSettle();
    final saveButton = find.byKey(
      const ValueKey(AppTestKeys.nutritionSaveMealButton),
    );
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey(AppTestKeys.nutritionScreen)),
      findsOneWidget,
    );
    expect(harness.requestCount('GET', '/api/progress/overview/'), 0);

    await tester.tap(find.text('Progress').last);
    await harness.settleApp(tester);

    expect(find.byKey(const ValueKey(AppTestKeys.statsScreen)), findsOneWidget);
    expect(harness.requestCount('GET', '/api/progress/overview/'), 1);
  });
}
