import 'package:dio/dio.dart';
import '../config/api_endpoints.dart';
import 'auth_interceptor.dart';

class HttpClient {
  HttpClient._();

  static final Dio dio =
      Dio(
          BaseOptions(
            baseUrl: ApiEndpoints.baseUrl,
            connectTimeout: const Duration(seconds: 30), // ✅ كان 10
            receiveTimeout: const Duration(seconds: 30), // ✅ كان 10
            headers: {'Content-Type': 'application/json'},
            validateStatus: (status) => status != null && status < 500,
            // ✅ هيك حتى لو 400/401 رح يرجع Response بدل ما يعتبرها crash صامت
          ),
        )
        ..interceptors.add(AuthInterceptor())
        ..interceptors.add(
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
