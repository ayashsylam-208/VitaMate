import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/core/routing/app_navigator.dart';
import 'package:vitamate/core/routing/routes.dart';
import 'package:vitamate/features/motivation/models/motivation_models.dart';
import 'package:vitamate/features/motivation/screens/motivation_experience_host.dart';

void main() {
  testWidgets('MotivationStatusPill shows level daily points and streak', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        routes: <String, WidgetBuilder>{
          '/': (_) => Scaffold(body: MotivationStatusPill(feed: _feed())),
          Routes.score: (_) => const Scaffold(body: Text('Score route')),
        },
      ),
    );

    expect(find.text('L3'), findsOneWidget);
    expect(find.text('+40'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.byType(MotivationStatusPill));
    await tester.pumpAndSettle();

    expect(find.text('Score route'), findsOneWidget);
  });
}

MotivationFeed _feed() {
  return MotivationFeed.fromJson(const <String, dynamic>{
    'summary': <String, dynamic>{
      'date': '2026-07-16',
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
    },
    'focus': <String, dynamic>{
      'kind': 'mission',
      'title': 'Log 3 meals',
      'subtitle': 'One more meal closes this mission.',
      'progress_percent': 67,
      'reward_points': 8,
      'route': '/meals',
    },
    'celebrations': <Map<String, dynamic>>[],
    'updated_at': '2026-07-16T08:00:00Z',
  });
}
