import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_metrics_interceptor.dart';
import '../../../shared/models/api_result.dart';

class HomeApi {
  const HomeApi();

  Future<ApiEnvelope<Map<String, dynamic>>> getOverview({
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.homeOverview,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(tag: 'home.overview'),
    );
    return ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> getDashboardFallback({
    CancelToken? cancelToken,
  }) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.dashboard,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'home.dashboardFallback',
      ),
    );
    return asMap(response.data);
  }
}
