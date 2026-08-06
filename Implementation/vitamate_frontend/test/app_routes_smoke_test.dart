import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vitamate/auth/screens/signup_screen.dart';
import 'package:vitamate/core/routing/routes.dart';
import 'package:vitamate/core/testing/app_test_keys.dart';
import 'package:vitamate/features/manager/screens/goals_screen.dart';
import 'package:vitamate/features/manager/screens/my_vitamate_screen.dart';
import 'package:vitamate/features/stats/screens/stats_screen.dart';

import 'support/vitamate_test_harness.dart';

class _RouteCase {
  const _RouteCase({required this.route, required this.finder});

  final String route;
  final Finder Function() finder;
}

void main() {
  final cases = <_RouteCase>[
    _RouteCase(
      route: Routes.login,
      finder: () => find.byKey(const ValueKey(AppTestKeys.loginSubmitButton)),
    ),
    _RouteCase(route: Routes.signup, finder: () => find.byType(SignUpScreen)),
    _RouteCase(
      route: Routes.onboarding,
      finder: () => find.byKey(const ValueKey(AppTestKeys.onboardingScreen)),
    ),
    _RouteCase(
      route: Routes.home,
      finder: () => find.byKey(const ValueKey(AppTestKeys.homeScreen)),
    ),
    _RouteCase(
      route: Routes.progress,
      finder: () => find.byKey(const ValueKey(AppTestKeys.statsScreen)),
    ),
    _RouteCase(
      route: Routes.meds,
      finder: () => find.byKey(const ValueKey(AppTestKeys.medicationsScreen)),
    ),
    _RouteCase(
      route: Routes.medsAdd,
      finder: () =>
          find.byKey(const ValueKey(AppTestKeys.medicationsAddScreen)),
    ),
    _RouteCase(
      route: Routes.medsToday,
      finder: () =>
          find.byKey(const ValueKey(AppTestKeys.medicationsTodayScreen)),
    ),
    _RouteCase(
      route: Routes.sleep,
      finder: () => find.byKey(const ValueKey(AppTestKeys.sleepScreen)),
    ),
    _RouteCase(
      route: Routes.water,
      finder: () => find.byKey(const ValueKey(AppTestKeys.waterScreen)),
    ),
    _RouteCase(
      route: Routes.meals,
      finder: () => find.byKey(const ValueKey(AppTestKeys.nutritionScreen)),
    ),
    _RouteCase(
      route: Routes.activities,
      finder: () => find.byKey(const ValueKey(AppTestKeys.activityScreen)),
    ),
    _RouteCase(
      route: Routes.habits,
      finder: () => find.byKey(const ValueKey(AppTestKeys.habitsScreen)),
    ),
    _RouteCase(
      route: Routes.steps,
      finder: () => find.byKey(const ValueKey(AppTestKeys.stepsScreen)),
    ),
    _RouteCase(
      route: Routes.activityWorkouts,
      finder: () => find.text('Choose an activity'),
    ),
    _RouteCase(
      route: Routes.activitySessionSetup,
      finder: () => find.text('Session Setup'),
    ),
    _RouteCase(
      route: Routes.activitySessionLive,
      finder: () => find.text('No active session'),
    ),
    _RouteCase(
      route: Routes.activitySessionSummary,
      finder: () => find.text('No saved workout'),
    ),
    _RouteCase(
      route: Routes.activitySteps,
      finder: () => find.byKey(const ValueKey(AppTestKeys.stepsScreen)),
    ),
    _RouteCase(
      route: Routes.activityActiveTime,
      finder: () => find.text('Active Time'),
    ),
    _RouteCase(
      route: Routes.chronicConditions,
      finder: () => find.byKey(const ValueKey(AppTestKeys.chronicScreenHeader)),
    ),
    _RouteCase(
      route: Routes.goal,
      finder: () => find.byType(ManagerGoalsScreen),
    ),
    _RouteCase(
      route: Routes.score,
      finder: () => find.byType(MyVitaMateScreen),
    ),
    _RouteCase(
      route: Routes.myVitaMate,
      finder: () => find.byType(MyVitaMateScreen),
    ),
  ];

  for (final routeCase in cases) {
    testWidgets('${routeCase.route} renders and settles', (tester) async {
      final harness = VitamateTestHarness();
      await harness.bootstrap();

      await harness.pumpAppRoute(tester, initialRoute: routeCase.route);
      await harness.settleApp(tester);

      expect(routeCase.finder(), findsOneWidget);
    });
  }

  for (final route in <String>[Routes.water, Routes.meals, Routes.sleep]) {
    testWidgets('$route can navigate back to progress from bottom nav', (
      tester,
    ) async {
      final harness = VitamateTestHarness();
      await harness.bootstrap();

      await harness.pumpAppRoute(tester, initialRoute: route);
      await harness.settleApp(tester);

      await tester.tap(find.text('Progress').last);
      await harness.settleApp(tester);

      expect(
        find.byKey(const ValueKey(AppTestKeys.statsScreen)),
        findsOneWidget,
      );
    });
  }

  for (final route in <String>[Routes.activities, Routes.steps]) {
    testWidgets('$route uses the ACT activity bottom navigation', (
      tester,
    ) async {
      final harness = VitamateTestHarness();
      await harness.bootstrap();

      await harness.pumpAppRoute(tester, initialRoute: route);
      await harness.settleApp(tester);

      expect(find.text('Activity'), findsWidgets);
      expect(find.text('Meds'), findsWidgets);
      expect(find.text('Habits'), findsWidgets);

      await tester.tap(find.text('Home').last);
      await harness.settleApp(tester);

      expect(
        find.byKey(const ValueKey(AppTestKeys.homeScreen)),
        findsOneWidget,
      );
    });
  }

  testWidgets('/progress tracker card opens detail screen', (tester) async {
    final harness = VitamateTestHarness();
    await harness.bootstrap();

    await harness.pumpAppRoute(tester, initialRoute: Routes.progress);
    await harness.settleApp(tester);

    await tester.tap(find.text('Nutrition').first);
    await harness.settleApp(tester);

    expect(find.byType(ProgressDetailScreen), findsOneWidget);
  });
}
