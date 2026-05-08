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

  testWidgets('water add-beverage sheet opens and saves a catalog item', (
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

    await tester.scrollUntilVisible(find.text('Add Beverage'), 200);
    await tester.tap(
      find.byKey(const ValueKey(AppTestKeys.waterAddBeverageButton)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey(AppTestKeys.waterAddBeverageSheet)),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey(AppTestKeys.waterCatalogSaveButton)),
    );
    await tester.tap(
      find.byKey(const ValueKey(AppTestKeys.waterCatalogSaveButton)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Added to hydration and nutrition'), findsOneWidget);
    expect(harness.requestCount('POST', '/api/water/'), 1);
  });

  testWidgets('create-custom-food sheet saves and refreshes the nutrition view', (
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

    await tester.scrollUntilVisible(find.text('Create custom food'), 200);
    await tester.tap(
      find.byKey(const ValueKey(AppTestKeys.nutritionCreateFoodButton)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey(AppTestKeys.nutritionCreateFoodSheet)),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(0), 'Protein Bowl');
    await tester.enterText(find.byType(TextField).at(1), '210');
    await tester.tap(
      find.byKey(const ValueKey(AppTestKeys.nutritionSaveFoodButton)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Food added to your library'), findsOneWidget);
    expect(harness.requestCount('POST', '/api/foods/'), 1);
    expect(harness.requestCount('GET', '/api/foods/autocomplete/'), 2);
  });
}
