import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';

class StatsApi {
  Future<Map<String, dynamic>> getDashboard() async {
    final Response res = await HttpClient.dio.get(ApiEndpoints.dashboard);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<List<dynamic>> getHistory() async {
    final Response res = await HttpClient.dio.get(ApiEndpoints.history);
    final data = res.data;
    if (data is Map && data['history'] is List) {
      return List<dynamic>.from(data['history']);
    }
    if (data is List) return data;
    return <dynamic>[];
  }

  /// يسجّل جلسة نوم يدوية بتاريخ اليوم.
  Future<void> logSleep({
    required DateTime start,
    required DateTime end,
    String quality = 'Deep',
  }) async {
    await HttpClient.dio.post(
      ApiEndpoints.sleep,
      data: {
        'start_time': start.toIso8601String(),
        'end_time': end.toIso8601String(),
        'quality': quality,
      },
    );
  }
}
