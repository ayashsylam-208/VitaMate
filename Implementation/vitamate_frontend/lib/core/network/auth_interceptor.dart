import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/session_expiry_coordinator.dart';
import '../config/api_endpoints.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends QueuedInterceptor {
  static const List<String> _publicPaths = [
    '/api/auth/register/',
    '/api/auth/login/',
    '/api/auth/refresh/',
  ];
  static const String _retryKey = 'auth_retry_attempted';

  static HttpClientAdapter? testAdapter;

  Future<String?>? _refreshFuture;

  bool _isPublic(String path) => _publicPaths.any(path.contains);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublic(options.path)) {
      options.headers.remove('Authorization');
      return handler.next(options);
    }

    final token = await SecureStorage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      options.headers.remove('Authorization');
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRefresh(err)) {
      return handler.next(err);
    }

    final newAccess = await _refreshAccessToken(
      baseUrl: _baseUrlFor(err.requestOptions),
    );
    if (newAccess == null || newAccess.isEmpty) {
      await AuthSessionCoordinator.handleExpiredSession();
      return handler.next(err);
    }

    try {
      final response = await _retryRequest(err.requestOptions, newAccess);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      if (retryError.response?.statusCode == 401) {
        await AuthSessionCoordinator.handleExpiredSession();
      }
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

  bool _shouldRefresh(DioException err) {
    final request = err.requestOptions;
    return err.response?.statusCode == 401 &&
        !_isPublic(request.path) &&
        request.extra[_retryKey] != true;
  }

  String _baseUrlFor(RequestOptions requestOptions) {
    if (requestOptions.baseUrl.isNotEmpty) {
      return requestOptions.baseUrl;
    }
    return ApiEndpoints.baseUrl;
  }

  Future<String?> _refreshAccessToken({required String baseUrl}) {
    final pendingRefresh = _refreshFuture;
    if (pendingRefresh != null) {
      return pendingRefresh;
    }

    final completer = Completer<String?>();
    _refreshFuture = completer.future;

    () async {
      try {
        final refresh = await SecureStorage.readRefreshToken();
        if (refresh == null || refresh.trim().isEmpty) {
          await SecureStorage.clear();
          completer.complete(null);
          return;
        }

        final dio = _rawDio(baseUrl);
        final refreshRes = await dio.post(
          ApiEndpoints.refresh,
          data: {'refresh': refresh},
        );
        final payload = _asMap(refreshRes.data);
        final newAccess = payload['access']?.toString().trim() ?? '';
        final rotatedRefresh = payload['refresh']?.toString().trim();

        if (newAccess.isEmpty) {
          await SecureStorage.clear();
          completer.complete(null);
          return;
        }

        await SecureStorage.saveTokens(
          access: newAccess,
          refresh: rotatedRefresh != null && rotatedRefresh.isNotEmpty
              ? rotatedRefresh
              : refresh,
        );
        completer.complete(newAccess);
      } catch (_) {
        await SecureStorage.clear();
        completer.complete(null);
      } finally {
        _refreshFuture = null;
      }
    }();

    return completer.future;
  }

  Future<Response<dynamic>> _retryRequest(
    RequestOptions requestOptions,
    String accessToken,
  ) async {
    final dio = _rawDio(_baseUrlFor(requestOptions));
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    headers['Authorization'] = 'Bearer $accessToken';

    return dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      cancelToken: requestOptions.cancelToken,
      options: Options(
        method: requestOptions.method,
        headers: headers,
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        sendTimeout: requestOptions.sendTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        followRedirects: requestOptions.followRedirects,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
        validateStatus: requestOptions.validateStatus,
        listFormat: requestOptions.listFormat,
        extra: {...requestOptions.extra, _retryKey: true},
      ),
    );
  }

  Dio _rawDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    if (testAdapter != null) {
      dio.httpClientAdapter = testAdapter!;
    }
    return dio;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }
}
