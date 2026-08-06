import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vitamate/core/routing/routes.dart';
import 'package:vitamate/core/testing/app_test_keys.dart';

import 'support/vitamate_test_harness.dart';

void _usePhoneViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1080, 2200);
}

void main() {
  testWidgets('onboarding transitions through every step and reaches home', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final harness = VitamateTestHarness();
    await harness.bootstrap();

    await harness.pumpAppRoute(tester, initialRoute: Routes.onboarding);
    await harness.settleApp(tester);

    await tester.tap(find.text('Male'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), '26');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), '178');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(2), '78');
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey(AppTestKeys.onboardingContinueButton)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activity Level'), findsOneWidget);
    await tester.tap(find.text('Moderately Active'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey(AppTestKeys.onboardingContinueButton)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal Goal'), findsOneWidget);
    await tester.tap(find.text('Maintain Weight'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey(AppTestKeys.onboardingContinueButton)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey(AppTestKeys.onboardingContinueButton)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey(AppTestKeys.homeScreen)),
      findsOneWidget,
    );
    expect(harness.requestCount('PATCH', '/api/auth/me/'), 1);
  });

  testWidgets('water log-drink flow opens and saves a hydration entry', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final harness = VitamateTestHarness();
    await harness.bootstrap();

    await harness.pumpAppRoute(tester, initialRoute: Routes.water);
    await harness.settleApp(tester);

    await tester.tap(find.text('Log any drink'));
    await tester.pumpAndSettle();

    expect(find.text('Log Drink'), findsOneWidget);
    await tester.tap(find.text('Save Drink'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey(AppTestKeys.waterScreen)), findsOneWidget);
    expect(harness.requestCount('POST', '/api/hydration/logs/'), 1);
    expect(find.text('Water'), findsWidgets);
  });

  testWidgets('log-meal flow returns a selected food from the library', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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

    await tester.tap(
      find.byKey(const ValueKey('nutrition-open-food-library')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Food library'), findsOneWidget);
    await tester.tap(find.byTooltip('Choose quantity').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this amount'));
    await tester.pumpAndSettle();

    expect(find.text('Overnight Oats'), findsOneWidget);
    final review = find.byKey(
      const ValueKey(AppTestKeys.nutritionSaveMealButton),
    );
    expect(tester.widget<FilledButton>(review).onPressed, isNotNull);
    expect(
      harness.requestCount('GET', '/api/foods/autocomplete/'),
      greaterThanOrEqualTo(1),
    );
  });
}
