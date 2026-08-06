import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/features/motivation/data/motivation_api.dart';
import 'package:vitamate/features/motivation/data/motivation_repository.dart';
import 'package:vitamate/features/motivation/models/motivation_models.dart';
import 'package:vitamate/features/motivation/state/motivation_controller.dart';
import 'package:vitamate/shared/models/api_result.dart';

class _FakeMotivationRepository extends MotivationRepository {
  _FakeMotivationRepository() : super(api: const MotivationApi());

  final List<Completer<(MotivationOverview, ApiMeta)>> _overviewCompleters =
      <Completer<(MotivationOverview, ApiMeta)>>[];

  List<DailyMission> nextMissions = const <DailyMission>[
    DailyMission(
      id: 1,
      missionType: 'hydration_goal',
      title: 'Drink water goal',
      description: 'Reach hydration target',
      status: 'in_progress',
      targetValue: 2300,
      currentValue: 1200,
      pointsReward: 10,
      reason: 'Hydration was low yesterday.',
    ),
  ];
  MotivationPointsPayload nextPoints = const MotivationPointsPayload(
    rangeDays: 7,
    days: <PointTrendDay>[],
    transactions: <PointTransactionItem>[],
    totalInRange: 0,
  );
  List<BadgeProgress> nextBadges = const <BadgeProgress>[
    BadgeProgress(
      code: 'hydration_hero',
      name: 'Hydration Hero',
      description: 'Reach hydration goal 7 days',
      requiredValue: 7,
      progressValue: 4,
      progressPercent: 57,
      status: 'in_progress',
    ),
  ];

  void queueOverview(MotivationOverview overview, {bool isStale = false}) {
    final completer = Completer<(MotivationOverview, ApiMeta)>();
    _overviewCompleters.add(completer);
    completer.complete((
      overview,
      ApiMeta(
        isStale: isStale,
        computedAt: DateTime(2026, 5, 8),
        snapshotVersion: 1,
        requestId: 'test',
      ),
    ));
  }

  void queuePendingOverviewCompleter(Completer<(MotivationOverview, ApiMeta)> c) {
    _overviewCompleters.add(c);
  }

  @override
  Future<(MotivationOverview, ApiMeta)> getOverview({cancelToken}) async {
    if (_overviewCompleters.isEmpty) {
      return (
        MotivationOverview.empty(),
        const ApiMeta(
          isStale: false,
          computedAt: null,
          snapshotVersion: null,
          requestId: '',
        ),
      );
    }
    return _overviewCompleters.removeAt(0).future;
  }

  @override
  Future<List<DailyMission>> getMissions({cancelToken}) async => nextMissions;

  @override
  Future<MotivationPointsPayload> getPoints({
    int rangeDays = 7,
    cancelToken,
  }) async {
    return nextPoints;
  }

  @override
  Future<List<BadgeProgress>> getBadges({cancelToken}) async => nextBadges;
}

void main() {
  test('loadOverview keeps latest response only', () async {
    final repo = _FakeMotivationRepository();
    final controller = MotivationController(repository: repo);

    final first = Completer<(MotivationOverview, ApiMeta)>();
    final second = Completer<(MotivationOverview, ApiMeta)>();
    repo.queuePendingOverviewCompleter(first);
    repo.queuePendingOverviewCompleter(second);

    final call1 = controller.loadOverview();
    final call2 = controller.loadOverview();

    first.complete((
      MotivationOverview.empty(),
      const ApiMeta(
        isStale: false,
        computedAt: null,
        snapshotVersion: null,
        requestId: 'first',
      ),
    ));
    second.complete((
      MotivationOverview.fromJson(const <String, dynamic>{
        'date': '2026-05-08',
        'total_points': 1240,
        'daily_points': 40,
        'weekly_points': 180,
        'level': 3,
        'level_name': 'Consistent',
        'next_level_threshold': 2000,
        'points_to_next_level': 760,
        'missions_completed': 4,
        'missions_total': 6,
        'current_streak': 5,
        'longest_streak': 14,
        'badges_earned': 2,
        'badges_in_progress': 3,
        'insight': 'Great consistency this week.',
      }),
      ApiMeta(
        isStale: false,
        computedAt: DateTime(2026, 5, 8),
        snapshotVersion: 1,
        requestId: 'second',
      ),
    ));

    await Future.wait(<Future<void>>[call1, call2]);

    expect(controller.overview.dailyPoints, 40);
    expect(controller.overview.levelName, 'Consistent');
  });

  test('loadDetails populates missions, points, and badges', () async {
    final repo = _FakeMotivationRepository()
      ..queueOverview(
        MotivationOverview.fromJson(const <String, dynamic>{
          'date': '2026-05-08',
          'total_points': 1240,
          'daily_points': 40,
          'weekly_points': 180,
          'level': 3,
          'level_name': 'Consistent',
          'next_level_threshold': 2000,
          'points_to_next_level': 760,
          'missions_completed': 4,
          'missions_total': 6,
          'current_streak': 5,
          'longest_streak': 14,
          'badges_earned': 2,
          'badges_in_progress': 3,
          'insight': 'Great consistency this week.',
        }),
      )
      ..nextPoints = MotivationPointsPayload.fromJson(const <String, dynamic>{
        'range_days': 7,
        'total_in_range': 120,
        'days': <Map<String, dynamic>>[
          <String, dynamic>{'date': '2026-05-02', 'points': 15},
        ],
        'transactions': <Map<String, dynamic>>[],
      });

    final controller = MotivationController(repository: repo);
    await controller.loadDetails();

    expect(controller.missions, isNotEmpty);
    expect(controller.points.rangeDays, 7);
    expect(controller.badges, isNotEmpty);
  });
}
