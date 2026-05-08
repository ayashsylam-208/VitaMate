import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_metrics_interceptor.dart';
import '../../../shared/models/api_result.dart';
import '../models/sleep_log.dart';
import '../models/sleep_summary.dart';

class SleepApi {
  Future<List<SleepLog>> getLogs() async {
    final res = await HttpClient.dio.get(ApiEndpoints.sleep);
    final list = (res.data as List).cast<dynamic>();

    return list
        .map((e) => SleepLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addSleep({
    required DateTime startTime,
    required DateTime endTime,
    required String quality,
  }) async {
    final payload = {
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'quality': quality,
    };

    final res = await HttpClient.dio.post(ApiEndpoints.sleep, data: payload);
    final code = res.statusCode ?? 0;

    if (code >= 400) {
      debugPrint('POST /api/sleep/ failed');
      debugPrint('Status: $code');
      debugPrint('Response: ${res.data}');
      debugPrint('Sent: $payload');
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: res.data,
      );
    }
  }

  Future<void> deleteSleep(int id) async {
    final res = await HttpClient.dio.delete('${ApiEndpoints.sleep}$id/');
    final code = res.statusCode ?? 0;

    if (code >= 400) {
      debugPrint('DELETE /api/sleep/$id/ failed');
      debugPrint('Status: $code');
      debugPrint('Response: ${res.data}');
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: res.data,
      );
    }
  }

  Future<SleepSummary> getSummary({CancelToken? cancelToken}) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.sleepSummary,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(tag: 'sleep.summary'),
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
    return SleepSummary.fromSummaryJson(envelope.data);
  }
}
