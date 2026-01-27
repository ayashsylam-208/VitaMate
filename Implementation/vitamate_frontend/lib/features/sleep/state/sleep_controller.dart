import 'package:flutter/foundation.dart';
import 'package:vitamate/auth/data/auth_repository.dart';
import '../data/sleep_api.dart';
import '../models/sleep_log.dart';
import '../models/sleep_summary.dart';

class SleepController extends ChangeNotifier {
  SleepController(AuthRepository repo, {SleepApi? api}) : _api = api ?? SleepApi();

  final SleepApi _api;

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
    logs = await _api.getLogs();
  }

  Future<void> _loadSummary() async {
    summary = await _api.getSummary();
  }

  void _computeTodaySleepPoints() {
    if (logs.isEmpty) {
      sleepPointsToday = 0;
      return;
    }
    final today = DateTime.now();
    sleepPointsToday = logs
        .where((log) =>
            log.date.year == today.year &&
            log.date.month == today.month &&
            log.date.day == today.day)
        .fold(0, (sum, log) => sum + log.pointsEarned);
  }

  Future<void> add({
    required DateTime startTime,
    required DateTime endTime,
    required String quality,
  }) async {
    error = null;
    notifyListeners();

    try {
      await _api.addSleep(startTime: startTime, endTime: endTime, quality: quality);
      await loadAll();
    } catch (_) {
      error = 'Could not save sleep log.';
      notifyListeners();
    }
  }

  Future<void> remove(int id) async {
    error = null;
    notifyListeners();

    try {
      await _api.deleteSleep(id);
      logs.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (_) {
      error = 'Could not delete sleep log.';
      notifyListeners();
    }
  }
}
