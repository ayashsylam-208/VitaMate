import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:vitamate/auth/data/auth_api.dart';
import 'package:vitamate/auth/data/auth_repository.dart';
import 'package:vitamate/auth/models/user.dart';
import 'package:vitamate/auth/models/user_profile.dart';
import 'package:vitamate/features/activity/data/activity_repository.dart';
import 'package:vitamate/features/activity/models/activity_log.dart';
import 'package:vitamate/features/activity/models/activity_session.dart';
import 'package:vitamate/features/activity/models/activity_summary.dart';
import 'package:vitamate/features/activity/models/exercise.dart';
import 'package:vitamate/features/activity/state/activity_controller.dart';
import 'package:vitamate/features/chronic_conditions/models/chronic_condition.dart';
import 'package:vitamate/features/home/data/home_repository.dart';
import 'package:vitamate/features/home/models/dashboard_data.dart';
import 'package:vitamate/features/home/models/home_overview.dart';
import 'package:vitamate/features/home/state/home_controller.dart';
import 'package:vitamate/features/sleep/data/sleep_repository.dart';
import 'package:vitamate/features/sleep/models/sleep_log.dart';
import 'package:vitamate/features/sleep/models/sleep_summary.dart';
import 'package:vitamate/features/sleep/state/sleep_controller.dart';
import 'package:vitamate/features/sleep/state/sleep_settings_controller.dart';
import 'package:vitamate/features/stats/data/stats_repository.dart';
import 'package:vitamate/features/stats/models/day_stat.dart';
import 'package:vitamate/features/stats/state/stats_controller.dart';
import 'package:vitamate/features/steps/data/steps_repository.dart';
import 'package:vitamate/features/steps/state/steps_controller.dart';
import 'package:vitamate/shared/models/api_result.dart';
import '../support/vitamate_test_harness.dart';

class _FakeHomeRepository extends HomeRepository {
  @override
  Future<HomeOverview> getOverview({cancelToken}) async {
    return HomeOverview(
      dashboard: const DashboardData(
        points: 120,
        todaySteps: 5200,
        waterMl: 1200,
        sleepMinutes: 430,
        calories: 780,
        chronicSummary: ChronicDashboardSummary(
          count: 1,
          labels: <String>['Diabetes'],
          adherencePercent: 92,
          activeMedicationsToday: 1,
          pendingDosesToday: 1,
          appliedSummaries: <String>['Keep added sugar under 25 g/day.'],
          disclaimer: 'Supportive self-management only.',
        ),
      ),
      conditionsCenter: <ChronicCondition>[_sampleCompactCondition()],
      meta: ApiMeta.empty(),
    );
  }
}

class _FakeActivityRepository extends ActivityRepository {
  @override
  Future<ActivitySummarySnapshot> getSummary() async =>
      ActivitySummarySnapshot(
        burnTarget: 320,
        burnCurrent: 210,
        exerciseMinutes: 30,
        pointsEstimate: 15,
        todaySummary: const ActivityTodaySummary(
          steps: 4200,
          stepsTarget: 8000,
          activeMinutes: 30,
          caloriesBurned: 210,
          burnTarget: 320,
          goalProgressPercent: 66,
          burnProgressPercent: 66,
          stepsProgressPercent: 52,
          message: 'Good progress today.',
        ),
        weeklySummary: const ActivityWeeklySummary(
          weekStart: null,
          weekEnd: null,
          activeDays: 2,
          weeklyMinutes: 80,
          weeklyKcal: 480,
          goalTargetMinutes: 150,
          goalAchievementRate: 53,
          remainingMinutes: 70,
          bestActivity: 'Walk',
        ),
        activeSession: null,
        suggestions: const <ActivitySuggestion>[
          ActivitySuggestion(
            exerciseId: 1,
            exerciseName: 'Walk',
            iconKey: 'directions_walk',
            intensity: 'moderate',
            recommendedDurationMinutes: 30,
            estimatedCalories: 140,
            reason: 'Good balance for today.',
          ),
        ],
        meta: ApiMeta.empty(),
      );

  @override
  Future<List<Exercise>> listExercises() async => <Exercise>[
    Exercise(id: 1, name: 'Walk', metValue: 4.3),
  ];

  @override
  Future<List<ActivityLog>> listLogs() async => <ActivityLog>[
    ActivityLog(
      id: 1,
      exerciseId: 1,
      exerciseName: 'Walk',
      durationMinutes: 30,
      caloriesBurned: 140,
      date: DateTime.parse('2026-04-28T09:00:00Z'),
    ),
  ];

  @override
  Future<ActivitySession?> getActiveSession() async => null;
}

class _FakeStatsRepository extends StatsRepository {
  @override
  Future<ProgressSnapshot> getProgress({
    overviewCancelToken,
    historyCancelToken,
  }) async {
    return ProgressSnapshot(
      overview: <String, dynamic>{
        'summary': <String, dynamic>{
          'calories_target': 2100,
          'calories_consumed': 780,
          'calories_remaining': 1320,
          'calories_burned': 320,
          'protein_g': 62,
          'carbs_g': 88,
          'fat_g': 28,
          'sugars_g': 12,
          'fiber_g': 18,
          'caffeine_mg': 75,
          'burn_target': 500,
        },
        'hydration': <String, dynamic>{'target': 2.3, 'current': 1.2},
        'sleep': <String, dynamic>{
          'recommended_sleep_hours': 8.0,
          'logged_hours_today': 7.25,
        },
        'activity': <String, dynamic>{'steps_target': 8000, 'steps': 5200},
        'gamification': <String, dynamic>{'points': 120, 'level': 3},
        'chronic_conditions': <String, dynamic>{
          'count': 1,
          'pending_doses_today': 1,
          'adherence_percent': 92,
          'applied_summaries': <String>['Hydration and sugar limits active'],
          'disclaimer': 'Supportive self-management only.',
        },
      },
      history: <DayStat>[
        DayStat(
          date: DateTime.parse('2026-04-27'),
          waterCurrent: 1.8,
          waterTarget: 2.3,
          steps: 7200,
          stepsTarget: 8000,
          distanceKm: 5.4,
          caloriesIn: 1800,
          caloriesTarget: 2100,
          caloriesBurned: 340,
          proteinG: 95,
          carbsG: 175,
          fatG: 58,
          sugarsG: 22,
          fiberG: 26,
          caffeineMg: 90,
          burnTarget: 500,
          sleepHours: 7.5,
          sleepTarget: 8.0,
          exerciseMinutes: 35,
          pointsEstimate: 120,
          conditionAdherencePercent: 92,
          pendingConditionDoses: 1,
        ),
      ],
      isStale: false,
    );
  }
}

class _FakeSleepRepository extends SleepRepository {
  final List<SleepLog> _logs = <SleepLog>[
    SleepLog(
      id: 1,
      startTime: DateTime.parse('2026-04-27T22:30:00Z'),
      endTime: DateTime.parse('2026-04-28T06:00:00Z'),
      quality: 'Deep',
      date: DateTime.parse('2026-04-28'),
      durationHours: 7.5,
      pointsEarned: 10,
    ),
  ];

  @override
  Future<List<SleepLog>> getLogs() async => List<SleepLog>.from(_logs);

  @override
  Future<SleepSummary> getSummary({cancelToken}) async => const SleepSummary(
    goalHours: 8.0,
    loggedHoursToday: 7.5,
    progressPercent: 94,
    sleepPoints: 10,
  );
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(AuthApi());

  AuthUser _user = AuthUser(
    username: 'user1',
    firstName: 'Salam',
    lastName: 'Ayash',
    email: 'salam@example.com',
    profile: UserProfileSettings(
      weight: 80,
      height: 175,
      activityLevel: 1.55,
      goal: 'maintain',
      dailyStepGoal: 8000,
      gender: 'male',
      birthDate: DateTime.parse('2000-01-01'),
      recommendedSleepHours: 8,
      targetWakeTime: DateTime(2000, 1, 1, 7),
      targetBedTime: DateTime(2000, 1, 1, 23),
      enableSleepImprovement: true,
      preferredActivityType: 'walking',
      enableActivityReminders: true,
      activityReminderIntervalHours: 2,
      activityReminderTime: DateTime(2000, 1, 1, 10),
      activityReminderDays: const <int>[1, 2, 3, 4, 5, 6, 7],
      inactiveReminderEnabled: false,
      inactiveReminderHours: 3,
      enableWaterReminders: true,
      waterReminderIntervalMinutes: 60,
    ),
  );

  @override
  Future<AuthUser> getMe() async => _user;

  @override
  Future<AuthUser> updateMe(Map<String, dynamic> data) async {
    _user = AuthUser(
      username: _user.username,
      firstName: _user.firstName,
      lastName: _user.lastName,
      email: _user.email,
      profile: UserProfileSettings(
        weight: _user.profile.weight,
        height: _user.profile.height,
        activityLevel: _user.profile.activityLevel,
        goal: _user.profile.goal,
        dailyStepGoal: _user.profile.dailyStepGoal,
        gender: _user.profile.gender,
        birthDate: _user.profile.birthDate,
        recommendedSleepHours:
            (data['recommended_sleep_hours'] as num?)?.toDouble() ??
            _user.profile.recommendedSleepHours,
        targetWakeTime: data['target_wake_time'] != null
            ? DateTime.parse('2000-01-01 ${data['target_wake_time']}')
            : _user.profile.targetWakeTime,
        targetBedTime: data['target_bed_time'] != null
            ? DateTime.parse('2000-01-01 ${data['target_bed_time']}')
            : _user.profile.targetBedTime,
        enableSleepImprovement:
            data['enable_sleep_improvement'] as bool? ??
            _user.profile.enableSleepImprovement,
        preferredActivityType: _user.profile.preferredActivityType,
        enableActivityReminders: _user.profile.enableActivityReminders,
        activityReminderIntervalHours:
            _user.profile.activityReminderIntervalHours,
        activityReminderTime:
            data['activity_reminder_time'] != null
            ? DateTime.parse('2000-01-01 ${data['activity_reminder_time']}')
            : _user.profile.activityReminderTime,
        activityReminderDays:
            (data['activity_reminder_days'] as List?)
                ?.map((item) => int.tryParse(item.toString()) ?? 0)
                .where((item) => item >= 1 && item <= 7)
                .toList(growable: false) ??
            _user.profile.activityReminderDays,
        inactiveReminderEnabled:
            data['inactive_reminder_enabled'] as bool? ??
            _user.profile.inactiveReminderEnabled,
        inactiveReminderHours:
            (data['inactive_reminder_hours'] as num?)?.toInt() ??
            _user.profile.inactiveReminderHours,
        enableWaterReminders: _user.profile.enableWaterReminders,
        waterReminderIntervalMinutes:
            _user.profile.waterReminderIntervalMinutes,
      ),
    );
    return _user;
  }
}

class _FakeStepsRepository extends StepsRepository {
  @override
  Future<Map<String, dynamic>> getSummary({cancelToken}) async {
    return <String, dynamic>{
      'target_steps': 8000,
      'steps_today': 4200,
      'distance_km': 3.2,
      'calories_burned': 170,
      'burn_rate_kcal_per_km': 53.1,
      'points': 20,
    };
  }

  @override
  Future<void> logSteps({required int stepsCount, double distanceKm = 0}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VitamateTestHarness harness;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  setUp(() async {
    harness = VitamateTestHarness();
    await harness.bootstrap();
  });

  test('home controller loads overview data with conditions center', () async {
    final controller = HomeController(repository: _FakeHomeRepository());

    await controller.load();

    expect(controller.data.points, 120);
    expect(controller.conditionsCenter, hasLength(1));
    expect(controller.error, isNull);
  });

  test('home controller falls back when overview snapshot is stale and empty', () async {
    final staleHarness = VitamateTestHarness(staleEmptyHomeOverview: true);
    await staleHarness.bootstrap();
    final controller = HomeController(repository: HomeRepository());

    await controller.load();

    expect(controller.error, isNull);
    expect(controller.isStale, isTrue);
    expect(controller.data.points, 130);
    expect(controller.data.todaySteps, 5120);
    expect(controller.data.waterMl, 1200);
    expect(controller.data.sleepMinutes, 435);
    expect(staleHarness.requestCount('GET', '/api/home/overview/'), 1);
    expect(staleHarness.requestCount('GET', '/api/dashboard/'), 1);
  });

  test('activity controller loads summary, logs, and guides safely', () async {
    final controller = ActivityController(
      repository: _FakeActivityRepository(),
      authRepository: _FakeAuthRepository(),
    );

    await controller.load();

    expect(controller.activityPointsToday, 15);
    expect(controller.caloriesBurnedToday, 210);
    expect(controller.exercises.single.name, 'Walk');
    expect(controller.logs.single.durationMinutes, 30);
  });

  test('stats controller parses the progress snapshot', () async {
    final controller = StatsController(repository: _FakeStatsRepository());

    await controller.load();

    expect(controller.pointsTotal, 120);
    expect(controller.stepsCurrent, 5200);
    expect(controller.history, hasLength(1));
    expect(controller.error, isNull);
  });

  test('sleep controller loads summary and logs', () async {
    final controller = SleepController(
      _FakeAuthRepository(),
      repository: _FakeSleepRepository(),
    );

    await controller.loadAll();

    expect(controller.summary.goalHours, 8);
    expect(controller.logs.single.pointsEarned, 10);
    expect(controller.sleepPointsToday, 10);
  });

  test('sleep settings controller loads and updates profile settings', () async {
    final controller = SleepSettingsController(_FakeAuthRepository());

    await controller.load();
    await controller.update(
      goalHours: 7.5,
      wakeTime: DateTime(2000, 1, 1, 6, 30),
      bedTime: DateTime(2000, 1, 1, 22, 30),
    );

    expect(controller.settings?.goalHours, 7.5);
    expect(controller.settings?.wakeTime.hour, 6);
    expect(controller.error, isNull);
  });

  test('steps controller initializes from mocked permission and summary', () async {
    final controller = StepsController(repository: _FakeStepsRepository());

    await controller.init();

    expect(controller.permissionGranted, isTrue);
    expect(controller.stepsToday, 4200);
    expect(controller.pointsToday, 20);
  });
}

ChronicCondition _sampleCompactCondition() {
  return ChronicCondition.fromJson({
    'view': 'compact',
    'id': 4,
    'condition_type': {
      'id': 1,
      'code': 'diabetes',
      'slug': 'diabetes',
      'name': 'Diabetes',
      'display_name': 'Diabetes',
      'description': 'Sample condition type',
      'can_add': false,
      'is_active_for_user': true,
      'setup_fields': const [],
      'measurement_types': const ['glucose'],
      'supports_direct_daily_reading': true,
      'severity_options': const [
        {
          'code': 'diabetes_managed',
          'label': 'Managed diabetes',
          'description': 'Sample severity',
        },
      ],
      'restrictions': const [],
      'rule_profiles': const [],
    },
    'diagnosis_date': '2026-04-11',
    'condition_status': 'active',
    'severity': 'diabetes_managed',
    'notes': 'Clinician approved current plan.',
    'profile_data': const {'glucose_target': 110},
    'is_active': true,
    'daily_medication_count': 1,
    'daily_pending_doses': 1,
    'open_alerts_count': 0,
    'evaluation_status': 'stable',
    'summary_status_label': 'In range',
    'summary_subtitle': 'Latest fasting glucose recorded',
    'summary_line': '110 mg/dL',
    'secondary_summary_line': 'Open tracking for targets and medications.',
    'latest_recorded_at': '2026-04-11T08:30:00Z',
  });
}
