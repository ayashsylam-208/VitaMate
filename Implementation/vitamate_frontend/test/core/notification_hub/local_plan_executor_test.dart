import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitamate/core/notification_hub/models/notification_plan_model.dart';
import 'package:vitamate/core/notification_hub/services/local_plan_executor.dart';

class _FakeScheduler implements LocalNotificationScheduler {
  final List<int> scheduled = <int>[];
  final List<int> cancelled = <int>[];
  final List<int> shown = <int>[];

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> schedule({
    required int id,
    required NotificationPlanModel plan,
    required DateTime at,
  }) async => scheduled.add(id);

  @override
  Future<void> showImmediate({
    required int id,
    required NotificationPlanModel plan,
  }) async => shown.add(id);
}

NotificationPlanModel _plan({int revision = 1, String title = 'Drink water'}) {
  return NotificationPlanModel(
    planId: 'water-plan',
    revision: revision,
    kind: 'rule',
    category: 'routine',
    type: 'water_interval',
    priority: 60,
    title: title,
    body: 'A glass keeps your hydration moving.',
    route: '/water',
    payload: const <String, dynamic>{},
    scheduleSpec: const <String, dynamic>{},
    deliverAt: DateTime.now().add(const Duration(hours: 1)),
    expireAt: DateTime.now().add(const Duration(hours: 2)),
    soundProfile: 'routine',
    exactRequired: false,
    foregroundBehavior: 'banner',
    dedupeKey: 'routine:water',
    status: 'planned',
    channelId: 'routine_v3',
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('identical second sync neither cancels nor reschedules', () async {
    final scheduler = _FakeScheduler();
    final plan = _plan();
    final first = await LocalPlanExecutor.reconcile(
      plans: <NotificationPlanModel>[plan],
      cancelPlanIds: const <String>[],
      horizonHours: 72,
      scheduler: scheduler,
    );
    final second = await LocalPlanExecutor.reconcile(
      plans: <NotificationPlanModel>[plan],
      cancelPlanIds: const <String>[],
      horizonHours: 72,
      scheduler: scheduler,
    );

    expect(first.single['outcome'], 'scheduled_local');
    expect(second, isEmpty);
    expect(scheduler.scheduled, hasLength(1));
    expect(scheduler.cancelled, isEmpty);
    expect(await LocalPlanExecutor.activePlanIds(), <String>['water-plan']);
  });

  test('new revision cancels old IDs and schedules replacement once', () async {
    final scheduler = _FakeScheduler();
    await LocalPlanExecutor.reconcile(
      plans: <NotificationPlanModel>[_plan()],
      cancelPlanIds: const <String>[],
      horizonHours: 72,
      scheduler: scheduler,
    );
    final events = await LocalPlanExecutor.reconcile(
      plans: <NotificationPlanModel>[
        _plan(revision: 2, title: 'Updated hydration reminder'),
      ],
      cancelPlanIds: const <String>[],
      horizonHours: 72,
      scheduler: scheduler,
    );

    expect(scheduler.cancelled, hasLength(1));
    expect(scheduler.scheduled, hasLength(2));
    expect(events.single['event_id'], 'scheduled:water-plan:2');
  });

  test(
    'permission denial cancels registry and reports no scheduling success',
    () async {
      final scheduler = _FakeScheduler();
      await LocalPlanExecutor.reconcile(
        plans: <NotificationPlanModel>[_plan()],
        cancelPlanIds: const <String>[],
        horizonHours: 72,
        scheduler: scheduler,
      );
      final events = await LocalPlanExecutor.reconcile(
        plans: <NotificationPlanModel>[_plan()],
        cancelPlanIds: const <String>[],
        horizonHours: 72,
        deliveryEnabled: false,
        permissionAuthorized: false,
        cancelAllLocalPlans: true,
        scheduler: scheduler,
      );

      expect(events, isEmpty);
      expect(scheduler.cancelled, hasLength(1));
      expect(await LocalPlanExecutor.activePlanIds(), isEmpty);
    },
  );
}
