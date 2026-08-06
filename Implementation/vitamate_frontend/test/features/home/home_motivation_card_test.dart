import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/features/chronic_conditions/state/chronic_conditions_controller.dart';
import 'package:vitamate/features/home/models/dashboard_data.dart';
import 'package:vitamate/features/home/screens/home_screen.dart';
import 'package:vitamate/features/home/state/home_controller.dart';
import 'package:vitamate/features/motivation/models/motivation_models.dart';
import 'package:vitamate/features/motivation/state/motivation_experience_controller.dart';
import 'package:vitamate/core/routing/routes.dart';

void main() {
  testWidgets('Home brief panel shows one compact focus and reward', (
    tester,
  ) async {
    final homeController = HomeController()
      ..data = const DashboardData(
        points: 900,
        level: 1,
        dailyPoints: 12,
        todaySteps: 4200,
        waterMl: 900,
        sleepMinutes: 410,
        calories: 720,
        missionsCompleted: 1,
        missionsTotal: 4,
        currentStreak: 3,
        levelName: 'Builder',
        chronicSummary: ChronicDashboardSummary.empty(),
      );
    MotivationExperienceController.instance.feed = _feedWithFocus();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          controller: homeController,
          chronicController: ChronicConditionsController(),
          autoLoad: false,
        ),
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Log 3 meals'), findsOneWidget);
    expect(find.text('+8 pts'), findsOneWidget);
    expect(find.text('Core Tracking'), findsOneWidget);
    expect(find.text('Smart Insight'), findsNothing);
    expect(find.text('Daily Health Progress'), findsNothing);
    expect(find.text('1240 total'), findsNothing);
    expect(find.text('3 day streak'), findsNothing);
  });

  testWidgets('Home brief panel falls back to level progress', (tester) async {
    final homeController = HomeController()
      ..data = const DashboardData(
        points: 450,
        level: 1,
        dailyPoints: 7,
        todaySteps: 1000,
        waterMl: 400,
        sleepMinutes: 360,
        calories: 500,
        missionsCompleted: 0,
        missionsTotal: 0,
        currentStreak: 0,
        levelName: 'Beginner',
        chronicSummary: ChronicDashboardSummary.empty(),
      );
    MotivationExperienceController.instance.feed = MotivationFeed.empty();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          controller: homeController,
          chronicController: ChronicConditionsController(),
          autoLoad: false,
        ),
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Build daily momentum'), findsOneWidget);
    expect(find.text('550 pts to L2'), findsOneWidget);
    expect(find.text('+7 pts'), findsOneWidget);
  });

  testWidgets('Core Tracking shows activity instead of a steps card', (
    tester,
  ) async {
    final homeController = HomeController()
      ..data = const DashboardData(
        points: 10,
        todaySteps: 4200,
        activityMinutes: 35,
        waterMl: 500,
        sleepMinutes: 420,
        calories: 600,
        chronicSummary: ChronicDashboardSummary.empty(),
      );

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          Routes.activities: (_) =>
              const Scaffold(body: Center(child: Text('Activity destination'))),
        },
        home: HomeScreen(
          controller: homeController,
          chronicController: ChronicConditionsController(),
          autoLoad: false,
        ),
      ),
    );

    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('35 min', findRichText: true), findsOneWidget);
    expect(find.text('Steps'), findsNothing);

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Activity destination'), findsOneWidget);
  });

  testWidgets('Daily Health Progress does not add XP to the score', (
    tester,
  ) async {
    final homeController = HomeController()
      ..data = const DashboardData(
        points: 900,
        level: 2,
        dailyPoints: 80,
        todaySteps: 0,
        waterMl: 0,
        sleepMinutes: 0,
        calories: 0,
        chronicSummary: ChronicDashboardSummary.empty(),
        dailyHealth: DailyHealthSummary(
          date: '2026-07-16',
          scoreVersion: 'daily-health-v1',
          progressPercent: 50,
          score: 50,
          coveragePercent: 60,
          completionStatus: 'in_progress',
          dailyComplete: false,
          completedEssential: 2,
          totalEssential: 5,
          criticalOverdue: false,
          message: 'Nutrition is still missing.',
        ),
        healthFocus: HealthFocusAction(
          kind: 'domain_action',
          domain: 'nutrition',
          title: 'Log dinner',
          subtitle: 'Nutrition is still missing.',
          route: '/meals',
          progressPercent: 50,
        ),
      );
    MotivationExperienceController.instance.feed = MotivationFeed.empty();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          controller: homeController,
          chronicController: ChronicConditionsController(),
          autoLoad: false,
        ),
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('+80 pts'), findsOneWidget);
    expect(find.text('Log dinner'), findsOneWidget);
    expect(find.text('100'), findsNothing);
  });

  testWidgets('Home notification bell opens notification settings', (
    tester,
  ) async {
    final homeController = HomeController()
      ..data = const DashboardData(
        points: 10,
        level: 1,
        dailyPoints: 0,
        todaySteps: 0,
        waterMl: 0,
        sleepMinutes: 0,
        calories: 0,
        chronicSummary: ChronicDashboardSummary.empty(),
      );

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          Routes.managerNotifications: (_) => const Scaffold(
            body: Center(child: Text('Notification settings')),
          ),
        },
        home: HomeScreen(
          controller: homeController,
          chronicController: ChronicConditionsController(),
          autoLoad: false,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Notification settings'), findsOneWidget);
  });
}

MotivationFeed _feedWithFocus() {
  return MotivationFeed.fromJson(const <String, dynamic>{
    'summary': <String, dynamic>{
      'date': '2026-07-16',
      'total_points': 1240,
      'daily_points': 40,
      'weekly_points': 180,
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
    'celebrations': <Map<String, dynamic>>[],
    'updated_at': '2026-07-16T08:00:00Z',
  });
}
