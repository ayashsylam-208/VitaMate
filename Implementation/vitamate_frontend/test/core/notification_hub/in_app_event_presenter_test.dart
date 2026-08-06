import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/core/notification_hub/models/notification_plan_model.dart';
import 'package:vitamate/core/notification_hub/services/in_app_event_presenter.dart';
import 'package:vitamate/core/routing/app_navigator.dart';

NotificationPlanModel _event({
  required String id,
  required String category,
  required String type,
  int priority = 50,
  DateTime? expireAt,
}) {
  return NotificationPlanModel(
    planId: id,
    revision: 1,
    kind: 'intent',
    category: category,
    type: type,
    priority: priority,
    title: category == 'health_critical'
        ? 'Review health reading'
        : 'Keep going',
    body: 'A short, clear explanation.',
    route: '',
    payload: const <String, dynamic>{},
    scheduleSpec: const <String, dynamic>{},
    deliverAt: DateTime.now(),
    expireAt: expireAt ?? DateTime.now().add(const Duration(hours: 1)),
    soundProfile: category == 'health_critical'
        ? 'health_critical'
        : 'motivation',
    exactRequired: false,
    foregroundBehavior: category == 'health_critical' ? 'alert' : 'in_app_only',
    dedupeKey: id,
    status: 'planned',
  );
}

void main() {
  setUp(InAppEventPresenter.resetForTesting);

  testWidgets(
    'foreground health warning displays and is not auto-acknowledged',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: appScaffoldMessengerKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );
      expect(appNavigatorKey.currentContext, isNotNull);
      final future = InAppEventPresenter.presentAll(<NotificationPlanModel>[
        _event(
          id: 'health-visible',
          category: 'health_critical',
          type: 'health_warning',
        ),
      ]);
      await tester.pump();
      await tester.pumpAndSettle();

      if (find.text('Health alert').evaluate().isEmpty) {
        final missing = (await future).single.result;
        fail('Health dialog was not shown: ${missing.failureCode}');
      }
      expect(find.text('Health alert'), findsOneWidget);
      expect(find.text('Review health reading'), findsOneWidget);
      expect(find.text('Review now'), findsOneWidget);
      await tester.tap(find.text('Review now'));
      await tester.pumpAndSettle();
      final result = (await future).single.result;
      expect(result.outcome, InAppPresentationOutcome.presented);
      expect(result.acknowledgedAt, isNull);
    },
  );

  testWidgets('critical event without context uses local fallback', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    var fallbackCalls = 0;
    InAppEventPresenter.fallbackScheduler = (event) async {
      fallbackCalls += 1;
      return true;
    };

    final result = await InAppEventPresenter.present(
      _event(
        id: 'health-fallback',
        category: 'health_critical',
        type: 'health_warning',
      ),
    );
    expect(result.outcome, InAppPresentationOutcome.failedToPresent);
    expect(result.fallbackScheduled, isTrue);
    expect(fallbackCalls, 1);
  });

  testWidgets('expired event is not presented', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: appScaffoldMessengerKey,
        home: const Scaffold(body: Text('Home')),
      ),
    );
    final result = await InAppEventPresenter.present(
      _event(
        id: 'expired',
        category: 'celebration',
        type: 'level_up',
        expireAt: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
    );
    expect(result.outcome, InAppPresentationOutcome.expired);
    expect(find.text('Keep going'), findsNothing);
  });

  testWidgets('queue gives critical alert priority over motivation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: appScaffoldMessengerKey,
        home: const Scaffold(body: Text('Home')),
      ),
    );
    final future = InAppEventPresenter.presentAll(<NotificationPlanModel>[
      _event(
        id: 'motivation-later',
        category: 'motivation',
        type: 'nudge',
        priority: 90,
      ),
      _event(
        id: 'health-first',
        category: 'health_critical',
        type: 'health_warning',
        priority: 80,
      ),
    ]);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Health alert'), findsOneWidget);
    await tester.tap(find.text('Review now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Keep going'), findsOneWidget);
    appScaffoldMessengerKey.currentState!.hideCurrentSnackBar();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final results = await future;
    expect(results.first.event.planId, 'health-first');
    expect(results.last.event.planId, 'motivation-later');
  });
}
