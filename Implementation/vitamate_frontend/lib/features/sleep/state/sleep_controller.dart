import 'package:flutter/foundation.dart';
import 'package:vitamate/auth/data/auth_repository.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../data/sleep_repository.dart';
import '../models/sleep_log.dart';
import '../models/sleep_summary.dart';

class SleepController extends ChangeNotifier {
  SleepController(AuthRepository repo, {SleepRepository? repository})
    : _repository = repository ?? SleepRepository();

  final SleepRepository _repository;

  bool loading = false;
  String? error;

  List<SleepLog> logs = [];
  SleepSummary summary = SleepSummary.empty();
  int sleepPointsToday = 0;

  Future<void> loadAll() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await Future.wait([_loadSummary(), _loadLogs()]);
      _computeTodaySleepPoints();
    } catch (_) {
      error = 'Could not load sleep data.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadLogs() async {
    logs = await _repository.getLogs();
  }

  Future<void> _loadSummary() async {
    summary = await _repository.getSummary();
  }

  void _computeTodaySleepPoints() {
    if (logs.isEmpty) {
      sleepPointsToday = 0;
      return;
    }
    final today = DateTime.now();
    final pointsFromTodayLogs = logs
        .where(
          (log) =>
              log.date.year == today.year &&
              log.date.month == today.month &&
              log.date.day == today.day,
        )
        .fold(0, (sum, log) => sum + log.pointsEarned);
    sleepPointsToday = pointsFromTodayLogs > 0
        ? pointsFromTodayLogs
        : summary.sleepPoints;
  }

  Future<void> add({
    required DateTime startTime,
    required DateTime endTime,
    required String quality,
  }) async {
    error = null;
    notifyListeners();

    try {
      await _repository.addSleep(
        startTime: startTime,
        endTime: endTime,
        quality: quality,
      );
      await loadAll();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.sleep,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
    } catch (_) {
      error = 'Could not save sleep log.';
      notifyListeners();
    }
  }

  Future<void> remove(int id) async {
    error = null;
    notifyListeners();

    try {
      await _repository.deleteSleep(id);
      logs.removeWhere((e) => e.id == id);
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.sleep,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
      notifyListeners();
    } catch (_) {
      error = 'Could not delete sleep log.';
      notifyListeners();
    }
  }
}
