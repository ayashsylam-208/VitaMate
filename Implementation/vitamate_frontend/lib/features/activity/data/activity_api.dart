import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../models/activity_log.dart';
import '../models/exercise.dart';

class ActivityApi {
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

  Future<void> addActivity({
    required int exerciseId,
    required int durationMinutes,
  }) async {
    await HttpClient.dio.post(ApiEndpoints.activities, data: {
      'exercise': exerciseId,
      'duration_minutes': durationMinutes,
    });
  }
}

