import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/features/motivation/data/motivation_api.dart';
import 'package:vitamate/features/motivation/data/motivation_repository.dart';
import 'package:vitamate/features/motivation/models/motivation_models.dart';
import 'package:vitamate/features/motivation/state/motivation_experience_controller.dart';

class _FakeExperienceRepository extends MotivationRepository {
  _FakeExperienceRepository() : super(api: const MotivationApi());

  MotivationFeed nextFeed = MotivationFeed.fromJson(const <String, dynamic>{
    'summary': <String, dynamic>{
      'date': '2026-07-06',
      'total_points': 1240,
      'daily_points': 22,
      'weekly_points': 140,
      'level': 2,
      'level_name': 'Builder',
      'next_level_threshold': 2000,
      'points_to_next_level': 760,
      'missions_completed': 2,
      'missions_total': 4,
      'current_streak': 3,
      'longest_streak': 8,
      'badges_earned': 1,
      'badges_in_progress': 2,
      'insight': 'Keep going.',
    },
    'focus': <String, dynamic>{
      'kind': 'mission',
      'title': 'Log 3 meals',
      'subtitle': 'One more meal closes this mission.',
      'progress_percent': 67,
      'reward_points': 8,
      'route': '/meals',
    },
    'celebrations': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 901,
        'type': 'points_awarded',
        'title': '+5 points',
        'subtitle': 'Logged a meal',
        'points_delta': 5,
        'animation': 'burst',
        'route': '/meals',
        'created_at': '2026-07-06T12:00:00Z',
      },
    ],
    'updated_at': '2026-07-06T12:00:00Z',
  });
  List<int> acknowledged = <int>[];

  @override
  Future<MotivationFeed> getFeed({cancelToken}) async => nextFeed;

  @override
  Future<List<int>> acknowledgeCelebrations({
    required List<int> ids,
    cancelToken,
  }) async {
    acknowledged = ids;
    return ids;
  }
}

void main() {
  test('load promotes a celebration and stores feed', () async {
    final repository = _FakeExperienceRepository();
    final controller = MotivationExperienceController(repository: repository);

    await controller.load();

    expect(controller.feed.focus.title, 'Log 3 meals');
    expect(controller.activeCelebration?.id, 901);
  });

  test('dismiss acknowledges the active celebration', () async {
    final repository = _FakeExperienceRepository();
    final controller = MotivationExperienceController(repository: repository);

    await controller.load();
    await controller.dismissActiveCelebration();

    expect(repository.acknowledged, <int>[901]);
    expect(controller.activeCelebration, isNull);
  });
}
