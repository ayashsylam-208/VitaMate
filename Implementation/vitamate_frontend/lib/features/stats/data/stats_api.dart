import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_metrics_interceptor.dart';
import '../../../shared/models/api_result.dart';

class StatsApi {
  Future<ApiEnvelope<Map<String, dynamic>>> getOverview({
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.progressOverview,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'progress.overview',
      ),
    );
    return ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
  }

  Future<ApiEnvelope<List<dynamic>>> getHistory({
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.progressHistory,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(tag: 'progress.history'),
    );
    return ApiEnvelope<List<dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) {
        final map = asMap(rawData);
        final history = map['history'];
        if (history is List) {
          return List<dynamic>.from(history);
        }
        return const <dynamic>[];
      },
      emptyData: const <dynamic>[],
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> getDetail({
    required String tracker,
    int rangeDays = 7,
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.progressDetail(tracker),
      queryParameters: <String, dynamic>{'range_days': rangeDays},
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'progress.detail.$tracker',
      ),
    );
    return ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
  }

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
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'sleep.log',
        method: 'POST',
      ),
    );
  }
}
