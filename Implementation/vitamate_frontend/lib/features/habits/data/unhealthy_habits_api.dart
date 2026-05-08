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

  Future<void> logHabit({
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
  }) async {
    await HttpClient.dio.post(
      '${ApiEndpoints.unhealthyHabits}$habitId/logs/',
      data: {
        'quantity': quantity,
        'unit': unit,
        'trigger': trigger,
        'mood': mood,
        'sync_to_tracker': syncToTracker,
        'caffeine_mg': caffeineMg,
        'calories_kcal': caloriesKcal,
        'food_name': foodName,
        'healthy_replacement': healthyReplacement,
      },
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'habits.unhealthy.log',
      ),
    );
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
          {
            'time_of_day': timeOfDay,
            'message': message,
            'is_active': true,
          }
        ],
      },
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'habits.unhealthy.reminders',
      ),
    );
  }
}
