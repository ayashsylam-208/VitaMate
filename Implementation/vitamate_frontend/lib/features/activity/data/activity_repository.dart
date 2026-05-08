import '../models/activity_log.dart';
import '../models/activity_session.dart';
import '../models/activity_summary.dart';
import '../models/exercise.dart';
import 'activity_api.dart';

class ActivityRepository {
  ActivityRepository({ActivityApi? api}) : _api = api ?? ActivityApi();

  final ActivityApi _api;

  Future<ActivitySummarySnapshot> getSummary() => _api.getSummary();

  Future<List<Exercise>> listExercises() => _api.listExercises();

  Future<List<ActivityLog>> listLogs() => _api.listLogs();

  Future<ActivitySession?> getActiveSession() => _api.getActiveSession();

  Future<ActivitySession> startSession({
    required int exerciseId,
    required int targetDurationSeconds,
    required String intensity,
    String source = 'live',
  }) {
    return _api.startSession(
      exerciseId: exerciseId,
      targetDurationSeconds: targetDurationSeconds,
      intensity: intensity,
      source: source,
    );
  }

  Future<ActivitySession> pauseSession(int sessionId) =>
      _api.pauseSession(sessionId);

  Future<ActivitySession> resumeSession(int sessionId) =>
      _api.resumeSession(sessionId);

  Future<ActivitySession> editSession({
    required int sessionId,
    int? exerciseId,
    required int targetDurationSeconds,
    required String intensity,
  }) {
    return _api.editSession(
      sessionId: sessionId,
      exerciseId: exerciseId,
      targetDurationSeconds: targetDurationSeconds,
      intensity: intensity,
    );
  }

  Future<ActivitySession> finishSession({
    required int sessionId,
    required bool savePartial,
  }) {
    return _api.finishSession(
      sessionId: sessionId,
      savePartial: savePartial,
    );
  }

  Future<ActivitySession> cancelSession(int sessionId) =>
      _api.cancelSession(sessionId);

  Future<void> addActivity({
    required int exerciseId,
    required int durationMinutes,
  }) {
    return _api.addActivity(
      exerciseId: exerciseId,
      durationMinutes: durationMinutes,
    );
  }
}
