import '../../../core/network/request_metrics_interceptor.dart';
import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../models/activity_log.dart';
import '../models/activity_session.dart';
import '../models/activity_summary.dart';
import '../models/exercise.dart';

class ActivityApi {
  Future<ActivitySummarySnapshot> getSummary() async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.activitySummary,
      options: RequestMetricsInterceptor.taggedOptions(tag: 'activity.summary'),
    );
    return ActivitySummarySnapshot.fromEnvelope(response.data);
  }

  Future<List<Exercise>> listExercises() async {
    final res = await HttpClient.dio.get(ApiEndpoints.exercises);
    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ActivityLog>> listLogs() async {
    final res = await HttpClient.dio.get(ApiEndpoints.activities);
    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => ActivityLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ActivitySession?> getActiveSession() async {
    final res = await HttpClient.dio.get(ApiEndpoints.activitySessionsActive);
    if (res.data == null) {
      return null;
    }
    return ActivitySession.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<ActivitySession> startSession({
    required int exerciseId,
    required int targetDurationSeconds,
    required String intensity,
    String source = 'live',
  }) async {
    final res = await HttpClient.dio.post(
      ApiEndpoints.activitySessions,
      data: {
        'exercise': exerciseId,
        'target_duration_seconds': targetDurationSeconds,
        'intensity': intensity,
        'source': source,
      },
    );
    return ActivitySession.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<ActivitySession> pauseSession(int sessionId) async {
    final res = await HttpClient.dio.patch(
      ApiEndpoints.activitySessionPause(sessionId),
    );
    return ActivitySession.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<ActivitySession> resumeSession(int sessionId) async {
    final res = await HttpClient.dio.patch(
      ApiEndpoints.activitySessionResume(sessionId),
    );
    return ActivitySession.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<ActivitySession> editSession({
    required int sessionId,
    int? exerciseId,
    required int targetDurationSeconds,
    required String intensity,
  }) async {
    final data = <String, dynamic>{
      'target_duration_seconds': targetDurationSeconds,
      'intensity': intensity,
    };
    if (exerciseId != null) {
      data['exercise'] = exerciseId;
    }
    final res = await HttpClient.dio.patch(
      ApiEndpoints.activitySessionEdit(sessionId),
      data: data,
    );
    return ActivitySession.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<ActivitySession> finishSession({
    required int sessionId,
    required bool savePartial,
  }) async {
    final res = await HttpClient.dio.post(
      ApiEndpoints.activitySessionFinish(sessionId),
      data: {'save_partial': savePartial},
    );
    return ActivitySession.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<ActivitySession> cancelSession(int sessionId) async {
    final res = await HttpClient.dio.post(
      ApiEndpoints.activitySessionCancel(sessionId),
      data: const <String, dynamic>{},
    );
    return ActivitySession.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> addActivity({
    required int exerciseId,
    required int durationMinutes,
  }) async {
    await HttpClient.dio.post(
      ApiEndpoints.activities,
      data: {'exercise': exerciseId, 'duration_minutes': durationMinutes},
    );
  }
}
