import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_metrics_interceptor.dart';
import '../../../shared/models/api_result.dart';

class StepsApi {
  Future<Map<String, dynamic>> getSummary({CancelToken? cancelToken}) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.stepsSummary,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(tag: 'steps.summary'),
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
    return envelope.data;
  }

  Future<void> logSteps({
    required int stepsCount,
    double distanceKm = 0,
  }) async {
    await HttpClient.dio.post(
      ApiEndpoints.steps,
      data: {'steps_count': stepsCount, 'distance_km': distanceKm},
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'steps.log',
        method: 'POST',
      ),
    );
  }
}
