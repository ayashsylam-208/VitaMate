import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_endpoints.dart';
import 'auth_interceptor.dart';
import 'base_url_failover_interceptor.dart';
import 'request_metrics_interceptor.dart';

class HttpClient {
  HttpClient._();

  static late Dio dio;
  static bool _initialized = false;
  static HttpClientAdapter? _testingAdapter;

  static BaseOptions _baseOptions(String baseUrl) {
    return BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 400,
    );
  }

  static Dio _buildClient({required String baseUrl}) {
    final client = Dio(_baseOptions(baseUrl))
      ..interceptors.add(
        BaseUrlFailoverInterceptor(adapterProvider: () => _testingAdapter),
      )
      ..interceptors.add(AuthInterceptor())
      ..interceptors.add(const RequestMetricsInterceptor());

    if (_testingAdapter != null) {
      client.httpClientAdapter = _testingAdapter!;
    }

    return client;
  }

  static Future<void> init() async {
    if (_initialized) return;

    final baseUrl = await ApiEndpoints.resolveReachableBaseUrl();
    debugPrint('HttpClient: initialized with baseUrl=$baseUrl');

    dio = _buildClient(baseUrl: baseUrl);

    _initialized = true;
  }

  static void initForTesting({String baseUrl = 'http://testserver'}) {
    ApiEndpoints.setResolvedBaseUrlForTesting(baseUrl);
    ApiEndpoints.setProbeAdapterForTesting(_testingAdapter);
    dio = _buildClient(baseUrl: baseUrl);
    if (_testingAdapter != null) {
      AuthInterceptor.testAdapter = _testingAdapter;
    }
    _initialized = true;
  }

  static void setTestAdapter(HttpClientAdapter adapter) {
    _testingAdapter = adapter;
    ApiEndpoints.setProbeAdapterForTesting(adapter);
    AuthInterceptor.testAdapter = adapter;
    if (_initialized) {
      dio.httpClientAdapter = adapter;
    }
  }
}
