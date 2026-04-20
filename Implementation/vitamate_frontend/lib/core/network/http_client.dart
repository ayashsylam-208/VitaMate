import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_endpoints.dart';
import 'auth_interceptor.dart';

class HttpClient {
  HttpClient._();

  static late Dio dio;
  static bool _initialized = false;
  static HttpClientAdapter? _testingAdapter;

  static BaseOptions _baseOptions(String baseUrl) {
    return BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 400,
    );
  }

  static Dio _buildClient({
    required String baseUrl,
    bool withLogging = false,
  }) {
    final client = Dio(_baseOptions(baseUrl))..interceptors.add(AuthInterceptor());

    if (_testingAdapter != null) {
      client.httpClientAdapter = _testingAdapter!;
    }

    if (withLogging) {
      client.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
          responseBody: true,
          error: true,
        ),
      );
    }

    return client;
  }

  static Future<void> init() async {
    if (_initialized) return;

    final baseUrl = await ApiEndpoints.resolveReachableBaseUrl();
    debugPrint('HttpClient: initialized with baseUrl=$baseUrl');

    dio = _buildClient(baseUrl: baseUrl, withLogging: true);

    _initialized = true;
  }

  static void initForTesting({String baseUrl = 'http://testserver'}) {
    ApiEndpoints.setResolvedBaseUrlForTesting(baseUrl);
    dio = _buildClient(baseUrl: baseUrl);
    if (_testingAdapter != null) {
      AuthInterceptor.testAdapter = _testingAdapter;
    }
    _initialized = true;
  }

  static void setTestAdapter(HttpClientAdapter adapter) {
    _testingAdapter = adapter;
    AuthInterceptor.testAdapter = adapter;
    if (_initialized) {
      dio.httpClientAdapter = adapter;
    }
  }
}
