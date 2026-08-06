import '../models/unhealthy_habit.dart';
import 'unhealthy_habits_api.dart';

class UnhealthyHabitsRepository {
  UnhealthyHabitsRepository({UnhealthyHabitsApi? api})
    : _api = api ?? UnhealthyHabitsApi();

  final UnhealthyHabitsApi _api;

  Future<UnhealthyHabitsOverview> getOverview() => _api.getOverview();

  Future<UnhealthyHabit> createHabit({
    required String habitType,
    required String goalType,
  }) => _api.createHabit(habitType: habitType, goalType: goalType);

  Future<UnhealthyHabit> setupHabit({
    required String habitType,
    required String goalType,
    required double initialQuantity,
    required String unit,
    required String commonTrigger,
    String cutoffTime = '',
    String reminderTime = '',
  }) {
    return _api.setupHabit(
      habitType: habitType,
      goalType: goalType,
      initialQuantity: initialQuantity,
      unit: unit,
      commonTrigger: commonTrigger,
      cutoffTime: cutoffTime,
      reminderTime: reminderTime,
    );
  }

  Future<void> saveBaseline({
    required int habitId,
    required double initialQuantity,
    required String unit,
    required String commonTrigger,
  }) {
    return _api.saveBaseline(
      habitId: habitId,
      initialQuantity: initialQuantity,
      unit: unit,
      commonTrigger: commonTrigger,
    );
  }

  Future<void> savePlan({
    required int habitId,
    required String goalType,
    double? dailyLimit,
    double? weeklyLimit,
    String cutoffTime = '',
    String reminderTime = '',
  }) {
    return _api.savePlan(
      habitId: habitId,
      goalType: goalType,
      dailyLimit: dailyLimit,
      weeklyLimit: weeklyLimit,
      cutoffTime: cutoffTime,
      reminderTime: reminderTime,
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
  }) {
    return _api.logHabit(
      habitId: habitId,
      quantity: quantity,
      unit: unit,
      trigger: trigger,
      mood: mood,
      syncToTracker: syncToTracker,
      caffeineMg: caffeineMg,
      caloriesKcal: caloriesKcal,
      foodName: foodName,
      healthyReplacement: healthyReplacement,
      mealType: mealType,
      loggedAt: loggedAt,
    );
  }

  Future<UnhealthyHabitWriteResult> dailyCheckIn({
    required int habitId,
    required bool used,
  }) {
    return _api.dailyCheckIn(habitId: habitId, used: used);
  }

  Future<UnhealthyHabit> pauseHabit({required int habitId}) {
    return _api.pauseHabit(habitId: habitId);
  }

  Future<UnhealthyHabit> resumeHabit({required int habitId}) {
    return _api.resumeHabit(habitId: habitId);
  }

  Future<void> saveReminder({
    required int habitId,
    required String timeOfDay,
    required String message,
  }) {
    return _api.saveReminder(
      habitId: habitId,
      timeOfDay: timeOfDay,
      message: message,
    );
  }
}
