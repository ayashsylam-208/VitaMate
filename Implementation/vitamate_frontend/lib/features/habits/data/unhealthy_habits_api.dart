import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_metrics_interceptor.dart';
import '../models/unhealthy_habit.dart';

class UnhealthyHabitsApi {
  Future<UnhealthyHabitsOverview> getOverview() async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.unhealthyHabitsOverview,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'habits.unhealthy.overview',
      ),
    );
    return UnhealthyHabitsOverview.fromEnvelope(response.data);
  }

  Future<UnhealthyHabit> createHabit({
    required String habitType,
    required String goalType,
  }) async {
    final response = await HttpClient.dio.post(
      ApiEndpoints.unhealthyHabits,
      data: {'habit_type': habitType, 'goal_type': goalType},
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'habits.unhealthy.create',
      ),
    );
    return UnhealthyHabit.fromJson(response.data['data']['habit']);
  }

  Future<UnhealthyHabit> setupHabit({
    required String habitType,
    required String goalType,
    required double initialQuantity,
    required String unit,
    required String commonTrigger,
    String cutoffTime = '',
    String reminderTime = '',
  }) async {
    final response = await HttpClient.dio.post(
      ApiEndpoints.unhealthyHabitsSetup,
      data: {
        'idempotency_key':
            '$habitType:$goalType:$initialQuantity:$unit:$commonTrigger:$cutoffTime:$reminderTime',
        'habit': {'habit_type': habitType, 'goal_type': goalType},
        'baseline': {
          'initial_frequency': initialQuantity,
          'initial_quantity': initialQuantity,
          'unit': unit,
          'common_trigger': commonTrigger,
        },
        'plan': {
          'goal_type': goalType,
          if (cutoffTime.isNotEmpty) 'cutoff_time': cutoffTime,
          if (reminderTime.isNotEmpty) 'reminder_time': reminderTime,
        },
        'reminders': [
          if (reminderTime.isNotEmpty)
            {
              'time_of_day': reminderTime,
              'message': _defaultReminderMessage(habitType),
              'is_active': true,
            },
        ],
      },
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'habits.unhealthy.setup',
      ),
    );
    return UnhealthyHabit.fromJson(response.data['data']['habit']);
  }

  Future<void> saveBaseline({
    required int habitId,
    required double initialQuantity,
    required String unit,
    required String commonTrigger,
  }) async {
    await HttpClient.dio.post(
      '${ApiEndpoints.unhealthyHabits}$habitId/baseline/',
      data: {
        'initial_frequency': initialQuantity,
        'initial_quantity': initialQuantity,
        'unit': unit,
        'common_trigger': commonTrigger,
      },
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'habits.unhealthy.baseline',
      ),
    );
  }

  Future<void> savePlan({
    required int habitId,
    required String goalType,
    double? dailyLimit,
    double? weeklyLimit,
    String cutoffTime = '',
    String reminderTime = '',
  }) async {
    await HttpClient.dio.post(
      '${ApiEndpoints.unhealthyHabits}$habitId/plan/',
      data: {
        'goal_type': goalType,
        if (dailyLimit != null) 'daily_limit': dailyLimit,
        if (weeklyLimit != null) 'weekly_limit': weeklyLimit,
        if (cutoffTime.isNotEmpty) 'cutoff_time': cutoffTime,
        if (reminderTime.isNotEmpty) 'reminder_time': reminderTime,
      },
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'habits.unhealthy.plan',
      ),
    );
  }

  Future<UnhealthyHabitWriteResult> logHabit({
    required int habitId,
    required double quantity,
    required String unit,
    required String trigger,
    required String mood,
    required bool syncToTracker,
    double caffeineMg = 0,
    double caloriesKcal = 0,
    String foodName = '',
    bool healthyReplacement = false,
    String mealType = 'unknown',
    DateTime? loggedAt,
  }) async {
    final response = await HttpClient.dio.post(
      ApiEndpoints.unhealthyHabitLogs(habitId),
      data: {
        if (loggedAt != null) 'logged_at': loggedAt.toIso8601String(),
        'quantity': quantity,
        'unit': unit,
        'trigger': trigger,
        'mood': mood,
        'sync_to_tracker': syncToTracker,
        'caffeine_mg': caffeineMg,
        'calories_kcal': caloriesKcal,
        'food_name': foodName,
        'healthy_replacement': healthyReplacement,
        'meal_type': mealType,
        'idempotency_key': DateTime.now().microsecondsSinceEpoch.toString(),
      },
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'habits.unhealthy.log',
      ),
    );
    return UnhealthyHabitWriteResult.fromEnvelope(response.data);
  }

  Future<UnhealthyHabitWriteResult> dailyCheckIn({
    required int habitId,
    required bool used,
  }) async {
    final response = await HttpClient.dio.post(
      ApiEndpoints.unhealthyHabitDailyCheckIn(habitId),
      data: {
        'used': used,
        'idempotency_key': DateTime.now().toIso8601String().split('T').first,
      },
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'habits.unhealthy.daily_check_in',
      ),
    );
    return UnhealthyHabitWriteResult.fromEnvelope(response.data);
  }

  Future<UnhealthyHabit> pauseHabit({required int habitId}) async {
    final response = await HttpClient.dio.post(
      ApiEndpoints.unhealthyHabitPause(habitId),
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'habits.unhealthy.pause',
      ),
    );
    return UnhealthyHabit.fromJson(response.data['data']['habit']);
  }

  Future<UnhealthyHabit> resumeHabit({required int habitId}) async {
    final response = await HttpClient.dio.post(
      ApiEndpoints.unhealthyHabitResume(habitId),
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'habits.unhealthy.resume',
      ),
    );
    return UnhealthyHabit.fromJson(response.data['data']['habit']);
  }

  Future<void> saveReminder({
    required int habitId,
    required String timeOfDay,
    required String message,
  }) async {
    await HttpClient.dio.post(
      '${ApiEndpoints.unhealthyHabits}$habitId/reminders/',
      data: {
        'reminders': [
          {'time_of_day': timeOfDay, 'message': message, 'is_active': true},
        ],
      },
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'habits.unhealthy.reminders',
      ),
    );
  }

  String _defaultReminderMessage(String habitType) {
    if (habitType == 'caffeine') {
      return 'Check your caffeine limit before another drink.';
    }
    if (habitType == 'fast_food') {
      return 'Pause before the usual fast-food window.';
    }
    return 'Try a short replacement action before smoking.';
  }
}
