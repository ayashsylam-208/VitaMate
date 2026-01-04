import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';
import '../config/api_endpoints.dart';

class AuthInterceptor extends Interceptor {
  static const List<String> _publicPaths = [
    '/api/auth/register/',
    '/api/auth/login/',
    '/api/auth/refresh/',
  ];

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

    return handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    // ✅ If unauthorized -> try refresh once
    if (err.response?.statusCode == 401 &&
        !_isPublic(err.requestOptions.path)) {
      final refresh = await SecureStorage.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        return handler.next(err);
      }

      try {
        final dio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));

        final refreshRes = await dio.post(
          ApiEndpoints.refresh,
          data: {'refresh': refresh},
          options: Options(headers: {'Content-Type': 'application/json'}),
        );

        final newAccess = refreshRes.data['access']?.toString();
        if (newAccess == null || newAccess.isEmpty) {
          return handler.next(err);
        }

        // ✅ save new access (keep same refresh)
        await SecureStorage.saveTokens(access: newAccess, refresh: refresh);

        // ✅ retry original request with new token
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newAccess';

        final retryRes = await dio.request(
          opts.path,
          data: opts.data,
          queryParameters: opts.queryParameters,
          options: Options(method: opts.method, headers: opts.headers),
        );

        return handler.resolve(retryRes);
      } catch (_) {
        return handler.next(err);
      }
    }

    return handler.next(err);
  }
}
