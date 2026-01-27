import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';

class StepsApi {
  Future<Map<String, dynamic>> getDashboard() async {
    final Response res = await HttpClient.dio.get(ApiEndpoints.dashboard);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<void> logSteps({
    required int stepsCount,
    double distanceKm = 0,
  }) async {
    await HttpClient.dio.post(ApiEndpoints.steps, data: {
      'steps_count': stepsCount,
      'distance_km': distanceKm,
    });
  }
}

