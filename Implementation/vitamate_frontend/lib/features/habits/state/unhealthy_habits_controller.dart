import 'package:flutter/foundation.dart';

import '../../../core/network/network_error_mapper.dart';
import '../../../core/notification_hub/notification_hub.dart';
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
      await _repository.setupHabit(
        habitType: habitType,
        goalType: goalType,
        initialQuantity: initialQuantity,
        unit: unit,
        commonTrigger: commonTrigger,
        cutoffTime: cutoffTime,
        reminderTime: reminderTime,
      );
      await load(silent: true);
      _publishHabitScopes(habitType, syncToTracker: false);
      await NotificationHubController.instance.syncNow(reason: 'habit_setup');
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
    String? mealType,
    DateTime? loggedAt,
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
      final result = await _repository.logHabit(
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
        mealType: mealType ?? _defaultMealType(habit.habitType),
        loggedAt: loggedAt,
      );
      await load(silent: true);
      _publishHabitScopes(habit.habitType, syncToTracker: syncToTracker);
      await _presentBackendEvents(result.inAppEvents);
      await NotificationHubController.instance.syncNow(reason: 'habit_log');
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(e, fallback: 'Could not log habit.');
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> dailyCheckIn({
    required UnhealthyHabit habit,
    required bool used,
  }) async {
    final habitId = habit.id;
    if (habitId == null) {
      error = 'Set up this habit before checking in.';
      notifyListeners();
      return false;
    }
    saving = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repository.dailyCheckIn(
        habitId: habitId,
        used: used,
      );
      await load(silent: true);
      _publishHabitScopes(habit.habitType, syncToTracker: false);
      await _presentBackendEvents(result.inAppEvents);
      await NotificationHubController.instance.syncNow(
        reason: 'habit_check_in',
      );
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not save habit check-in.',
      );
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> togglePaused(UnhealthyHabit habit) async {
    final habitId = habit.id;
    if (habitId == null) {
      return false;
    }
    saving = true;
    error = null;
    notifyListeners();
    try {
      if (habit.isActive) {
        await _repository.pauseHabit(habitId: habitId);
      } else {
        await _repository.resumeHabit(habitId: habitId);
      }
      await load(silent: true);
      _publishHabitScopes(habit.habitType, syncToTracker: false);
      await NotificationHubController.instance.syncNow(
        reason: habit.isActive ? 'habit_pause' : 'habit_resume',
      );
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not update habit status.',
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

  Future<void> _presentBackendEvents(List<Map<String, dynamic>> events) async {
    for (final event in events) {
      await InAppEventPresenter.present(
        NotificationPlanModel(
          planId: (event['id'] ?? event['type'] ?? 'habit-event').toString(),
          kind: 'in_app',
          category: (event['category'] ?? 'motivation').toString(),
          type: (event['type'] ?? 'habit_event').toString(),
          priority: int.tryParse((event['priority'] ?? '50').toString()) ?? 50,
          title: (event['title'] ?? 'Habit updated').toString(),
          body: (event['body'] ?? '').toString(),
          route: (event['route'] ?? '/habits').toString(),
          payload: Map<String, dynamic>.from(event),
          scheduleSpec: const <String, dynamic>{},
          deliverAt: null,
          expireAt: null,
          soundProfile: '',
          exactRequired: false,
          foregroundBehavior: 'banner',
          dedupeKey: (event['dedupe_key'] ?? event['type'] ?? 'habit-event')
              .toString(),
          status: 'presented',
        ),
      );
    }
  }

  String _defaultMealType(String habitType) {
    if (habitType == 'caffeine') {
      return 'drink';
    }
    if (habitType == 'fast_food') {
      return 'unknown';
    }
    return 'unknown';
  }
}
