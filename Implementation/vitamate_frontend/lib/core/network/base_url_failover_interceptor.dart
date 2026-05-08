import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_endpoints.dart';

class BaseUrlFailoverInterceptor extends Interceptor {
  BaseUrlFailoverInterceptor({HttpClientAdapter? Function()? adapterProvider})
    : _adapterProvider = adapterProvider;

  static const String _retryKey = 'base_url_failover_attempted';

  final HttpClientAdapter? Function()? _adapterProvider;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    final currentBaseUrl = _baseUrlFor(err.requestOptions);
    final alternateBaseUrl =
        await ApiEndpoints.resolveAlternateReachableBaseUrl(
          currentBaseUrl: currentBaseUrl,
        );
    if (alternateBaseUrl == null || alternateBaseUrl == currentBaseUrl) {
      return handler.next(err);
    }

    if (kDebugMode) {
      debugPrint(
        'HttpClient: retrying ${err.requestOptions.path} with '
        'baseUrl=$alternateBaseUrl after failing at $currentBaseUrl',
      );
    }

    try {
      final response = await _retryRequest(
        err.requestOptions,
        alternateBaseUrl,
      );
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    } catch (retryError) {
      return handler.next(
        DioException(
          requestOptions: err.requestOptions,
          error: retryError,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  bool _shouldRetry(DioException err) {
    if (ApiEndpoints.hasConfiguredBaseUrl) {
      return false;
    }

    return (err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout) &&
        err.requestOptions.extra[_retryKey] != true;
  }

  String _baseUrlFor(RequestOptions requestOptions) {
    if (requestOptions.baseUrl.isNotEmpty) {
      return requestOptions.baseUrl;
    }
    return ApiEndpoints.baseUrl;
  }

  Future<Response<dynamic>> _retryRequest(
    RequestOptions requestOptions,
    String baseUrl,
  ) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: requestOptions.connectTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        sendTimeout: requestOptions.sendTimeout,
        headers: {'Content-Type': 'application/json'},
        validateStatus: requestOptions.validateStatus,
      ),
    );

    final adapter = _adapterProvider?.call();
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
    }

    return dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      cancelToken: requestOptions.cancelToken,
      options: Options(
        method: requestOptions.method,
        headers: Map<String, dynamic>.from(requestOptions.headers),
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        sendTimeout: requestOptions.sendTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        followRedirects: requestOptions.followRedirects,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
        validateStatus: requestOptions.validateStatus,
        listFormat: requestOptions.listFormat,
        extra: <String, dynamic>{...requestOptions.extra, _retryKey: true},
      ),
    );
  }
}
