import 'package:flutter/foundation.dart';
import '../data/water_api.dart';
import '../models/water_log.dart';

class WaterController extends ChangeNotifier {
  WaterController({WaterApi? api}) : _api = api ?? WaterApi();

  final WaterApi _api;

  bool loading = false;
  String? error;

  List<WaterLog> logs = [];

  int targetMl = 0; // from backend (dashboard) converted to ml
  int consumedMl = 0;
  int waterPointsToday = 0;

  int get remainingMl => (targetMl - consumedMl).clamp(0, targetMl);
  double get progress => targetMl == 0 ? 0 : (consumedMl / targetMl).clamp(0, 1);

  Future<void> load({required int targetMlFromBackend}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      targetMl = targetMlFromBackend;

      logs = await _api.getTodayLogs();
      consumedMl = logs.fold<int>(0, (sum, e) => sum + e.amountMl);
      waterPointsToday = logs.length * 5; // backend awards 5 pts per log

      loading = false;
      notifyListeners();
    } catch (_) {
      loading = false;
      error = 'Failed to load water logs.';
      notifyListeners();
    }
  }

  Future<void> drink(int amountMl) async {
    try {
      await _api.addWaterMl(amountMl);
      // reload logs after POST (backend adds points automatically)
      await load(targetMlFromBackend: targetMl);
    } catch (_) {
      error = 'Could not save water log.';
      notifyListeners();
    }
  }
}
