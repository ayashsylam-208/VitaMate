import 'package:flutter/foundation.dart';

import '../../../core/network/network_error_mapper.dart';
import '../../../core/notifications/notifications_service.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../data/unhealthy_habits_repository.dart';
import '../models/unhealthy_habit.dart';

class UnhealthyHabitsController extends ChangeNotifier {
  UnhealthyHabitsController({UnhealthyHabitsRepository? repository})
      : _repository = repository ?? UnhealthyHabitsRepository();

  final UnhealthyHabitsRepository _repository;

  bool loading = false;
  bool saving = false;
  String? error;
  UnhealthyHabitsOverview overview = UnhealthyHabitsOverview.empty();

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    error = null;
    try {
      overview = await _repository.getOverview();
      try {
        await _syncReminders();
      } catch (notificationError) {
        debugPrint(
          'UnhealthyHabitsController: reminder sync failed: $notificationError',
        );
      }
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not load habits.',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<UnhealthyHabit?> setupHabit({
    required String habitType,
    required String goalType,
    required double initialQuantity,
    required String unit,
    required String commonTrigger,
    String cutoffTime = '',
    String reminderTime = '',
  }) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      var habit = _findHabit(habitType);
      if (habit == null || habit.id == null) {
        habit = await _repository.createHabit(
          habitType: habitType,
          goalType: goalType,
        );
      }
      final habitId = habit.id;
      if (habitId == null) {
        throw StateError('Habit setup did not return an id.');
      }
      await _repository.saveBaseline(
        habitId: habitId,
        initialQuantity: initialQuantity,
        unit: unit,
        commonTrigger: commonTrigger,
      );
      await _repository.savePlan(
        habitId: habitId,
        goalType: goalType,
        cutoffTime: cutoffTime,
        reminderTime: reminderTime,
      );
      if (reminderTime.isNotEmpty) {
        await _repository.saveReminder(
          habitId: habitId,
          timeOfDay: reminderTime,
          message: _defaultReminderMessage(habitType),
        );
      }
      await load(silent: true);
      _publishHabitScopes(habitType, syncToTracker: false);
      return _findHabit(habitType);
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not save habit setup.',
      );
      return null;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> logHabit({
    required UnhealthyHabit habit,
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
    final habitId = habit.id;
    if (habitId == null) {
      error = 'Set up this habit before logging.';
      notifyListeners();
      return false;
    }
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _repository.logHabit(
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
      );
      await load(silent: true);
      _publishHabitScopes(habit.habitType, syncToTracker: syncToTracker);
      await _showSupportWarningIfNeeded(habit.habitType);
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not log habit.',
      );
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  UnhealthyHabit? _findHabit(String habitType) {
    for (final habit in overview.habits) {
      if (habit.habitType == habitType) {
        return habit;
      }
    }
    return null;
  }

  void _publishHabitScopes(String habitType, {required bool syncToTracker}) {
    final scopes = <HealthSyncScope>{
      HealthSyncScope.habits,
      HealthSyncScope.homeOverview,
      HealthSyncScope.progressHistory,
    };
    if (syncToTracker) {
      if (habitType == 'caffeine') {
        scopes.addAll({HealthSyncScope.nutrition, HealthSyncScope.hydration});
      }
      if (habitType == 'fast_food') {
        scopes.add(HealthSyncScope.nutrition);
      }
    }
    if (habitType == 'caffeine' || habitType == 'smoking') {
      scopes.add(HealthSyncScope.sleep);
    }
    HealthSyncBus.instance.publish(scopes);
  }

  Future<void> _syncReminders() async {
    final plans = <UnhealthyHabitReminderPlan>[];
    for (final habit in overview.habits) {
      for (final reminder in habit.reminders) {
        if (!reminder.isActive) continue;
        final parts = reminder.timeOfDay.split(':');
        if (parts.length < 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;
        plans.add(
          UnhealthyHabitReminderPlan(
            habitId: habit.id ?? 0,
            reminderId: reminder.id,
            habitLabel: habit.label,
            message: reminder.message,
            hour: hour,
            minute: minute,
          ),
        );
      }
    }
    await NotificationsService.syncUnhealthyHabitReminders(plans);
  }

  Future<void> _showSupportWarningIfNeeded(String habitType) async {
    if (habitType == 'caffeine') {
      await NotificationsService.showCaffeineCutoffWarning();
    } else if (habitType == 'fast_food') {
      await NotificationsService.showFastFoodLimitWarning();
    }
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
