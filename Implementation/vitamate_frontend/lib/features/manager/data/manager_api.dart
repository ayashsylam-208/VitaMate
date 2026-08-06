import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_metrics_interceptor.dart';

class ManagerApi {
  ManagerApi({Dio? dio}) : _dio = dio ?? HttpClient.dio;

  final Dio _dio;

  Future<Map<String, dynamic>> overview() async {
    final response = await _dio.get(
      ApiEndpoints.managerOverview,
      options: RequestMetricsInterceptor.taggedOptions(tag: 'manager.overview'),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> goals() async {
    final response = await _dio.get(ApiEndpoints.managerGoals);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> updateGoal(
    String key,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch(
      ApiEndpoints.managerGoal(key),
      data: payload,
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> resetGoals() async {
    final response = await _dio.post(ApiEndpoints.managerGoalsReset);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> notifications() async {
    final response = await _dio.get(ApiEndpoints.managerNotifications);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> updateNotifications(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch(
      ApiEndpoints.managerNotifications,
      data: payload,
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> security() async {
    final response = await _dio.get(ApiEndpoints.managerSecurity);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    final response = await _dio.post(
      ApiEndpoints.managerAvatar,
      data: FormData.fromMap(<String, dynamic>{
        'avatar': await MultipartFile.fromFile(filePath),
      }),
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'manager.avatarUpload',
        method: 'POST',
      ),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> deleteAvatar() async {
    final response = await _dio.delete(
      ApiEndpoints.managerAvatar,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'manager.avatarDelete',
        method: 'DELETE',
      ),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> changePassword(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      ApiEndpoints.managerChangePassword,
      data: payload,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'manager.changePassword',
        method: 'POST',
      ),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> logoutAll() async {
    final response = await _dio.post(ApiEndpoints.managerLogoutAll);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> privacy() async {
    final response = await _dio.get(ApiEndpoints.managerPrivacy);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> requestExport() async {
    final response = await _dio.post(ApiEndpoints.managerPrivacyExport);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> requestAccountDeletion({
    String reason = '',
  }) async {
    final response = await _dio.post(
      ApiEndpoints.managerAccountDeletion,
      data: <String, dynamic>{'reason': reason},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> cancelAccountDeletion() async {
    final response = await _dio.delete(ApiEndpoints.managerAccountDeletion);
    return _asMap(response.data);
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}
