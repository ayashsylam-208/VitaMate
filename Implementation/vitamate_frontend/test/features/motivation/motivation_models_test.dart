import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/features/motivation/models/motivation_models.dart';

void main() {
  test('MotivationOverview parses core fields', () {
    final overview = MotivationOverview.fromJson(const <String, dynamic>{
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
    });

    expect(overview.dailyPoints, 40);
    expect(overview.level, 3);
    expect(overview.levelName, 'Consistent');
    expect(overview.missionsCompleted, 4);
    expect(overview.badgesInProgress, 3);
  });

  test('MotivationPointsPayload parses trend and transactions', () {
    final payload = MotivationPointsPayload.fromJson(const <String, dynamic>{
      'range_days': 7,
      'total_in_range': 120,
      'days': <Map<String, dynamic>>[
        <String, dynamic>{'date': '2026-05-02', 'points': 15},
        <String, dynamic>{'date': '2026-05-03', 'points': 18},
      ],
      'transactions': <Map<String, dynamic>>[
        <String, dynamic>{
          'event_date': '2026-05-03',
          'points': 10,
          'rule_code': 'WATER_GOAL_COMPLETED',
          'source_type': 'hydration',
          'reason': 'Hydration goal completed.',
        },
      ],
    });

    expect(payload.rangeDays, 7);
    expect(payload.totalInRange, 120);
    expect(payload.days.length, 2);
    expect(payload.transactions.single.ruleCode, 'WATER_GOAL_COMPLETED');
  });
}
