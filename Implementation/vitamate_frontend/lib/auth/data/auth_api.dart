import 'package:dio/dio.dart';
import '../../core/network/http_client.dart';
import '../../core/config/api_endpoints.dart';

class AuthApi {
  final Dio _dio = HttpClient.dio;

  Future<Response> register({
    required String username,
    required String password,
    required String email,
    required String firstName,
    required String lastName,
  }) {
    return _dio.post(
      ApiEndpoints.register,
      data: {
        'username': username,
        'password': password,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
      },
    );
  }

  Future<Response> login({required String username, required String password}) {
    return _dio.post(
      ApiEndpoints.login,
      data: {'username': username, 'password': password},
    );
  }

  Future<Response> me() {
    return _dio.get(ApiEndpoints.me);
  }

  Future<Response> updateMe(Map<String, dynamic> data) {
    // PATCH مناسب للأونبوردينغ (تحديث جزئي)
    return _dio.patch(ApiEndpoints.me, data: data);
  }
}
