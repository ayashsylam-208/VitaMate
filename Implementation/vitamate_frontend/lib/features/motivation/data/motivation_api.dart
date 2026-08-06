import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_metrics_interceptor.dart';
import '../../../shared/models/api_result.dart';

class MotivationApi {
  const MotivationApi();

  Future<ApiEnvelope<Map<String, dynamic>>> getOverview({
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.motivationOverview,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'motivation.overview',
      ),
    );
    return ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (raw) => asMap(raw),
      emptyData: const <String, dynamic>{},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> getMissions({
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.motivationMissions,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'motivation.missions',
      ),
    );
    return ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (raw) => asMap(raw),
      emptyData: const <String, dynamic>{},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> refreshMission({
    required int missionId,
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.post(
      ApiEndpoints.motivationMissionRefresh(missionId),
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'motivation.missionRefresh',
        method: 'POST',
      ),
    );
    return ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (raw) => asMap(raw),
      emptyData: const <String, dynamic>{},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> getPoints({
    int rangeDays = 7,
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.motivationPoints,
      queryParameters: <String, dynamic>{'range_days': rangeDays},
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'motivation.points',
      ),
    );
    return ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (raw) => asMap(raw),
      emptyData: const <String, dynamic>{},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> getBadges({
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.motivationBadges,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'motivation.badges',
      ),
    );
    return ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (raw) => asMap(raw),
      emptyData: const <String, dynamic>{},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> getFeed({
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.motivationFeed,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(tag: 'motivation.feed'),
    );
    return ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (raw) => asMap(raw),
      emptyData: const <String, dynamic>{},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> acknowledgeCelebrations({
    required List<int> ids,
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.post(
      ApiEndpoints.motivationCelebrationsAck,
      data: <String, dynamic>{'ids': ids},
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'motivation.celebrationsAck',
        method: 'POST',
      ),
    );
    return ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (raw) => asMap(raw),
      emptyData: const <String, dynamic>{},
    );
  }
}
