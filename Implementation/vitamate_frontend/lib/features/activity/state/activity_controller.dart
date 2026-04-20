import 'package:flutter/foundation.dart';

import '../../../core/health/chronic_target_guide.dart';
import '../data/activity_api.dart';
import '../models/activity_log.dart';
import '../models/exercise.dart';

class ActivityController extends ChangeNotifier {
  ActivityController({
    ActivityApi? api,
    ChronicTargetGuideService? chronicTargetGuideService,
  }) : _api = api ?? ActivityApi(),
       _chronicTargetGuideService =
           chronicTargetGuideService ?? const ChronicTargetGuideService();

  final ActivityApi _api;
  final ChronicTargetGuideService _chronicTargetGuideService;

  bool loading = false;
  String? error;

  List<Exercise> exercises = [];
  List<ActivityLog> logs = [];
  List<ChronicGuideCardData> chronicActivityGuides = const [];
  int activityPointsToday = 0;
  int caloriesBurnedToday = 0;

  Future<void> load() async {
    loading = true;
    error = null;
    chronicActivityGuides = const [];
    notifyListeners();
    try {
      exercises = await _api.listExercises();
      logs = await _api.listLogs();
      activityPointsToday = logs.length * 5; // backend awards 5 per log
      caloriesBurnedToday = logs.fold<int>(
        0,
        (sum, l) => sum + l.caloriesBurned,
      );
    } catch (_) {
      error = 'Failed to load activity data';
    }
    try {
      chronicActivityGuides = await _chronicTargetGuideService.loadForScope(
        ChronicGuideScope.activity,
      );
    } catch (_) {
      chronicActivityGuides = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> addActivity({
    required int exerciseId,
    required int durationMinutes,
  }) async {
    await _api.addActivity(
      exerciseId: exerciseId,
      durationMinutes: durationMinutes,
    );
    await load();
  }
}
