import 'package:dio/dio.dart';

import '../../config/api_endpoints.dart';
import '../../network/http_client.dart';
import '../../../shared/models/api_result.dart';

class NotificationHubApi {
  NotificationHubApi({Dio? dio}) : _dio = dio ?? HttpClient.dio;

  final Dio _dio;

  Future<Map<String, dynamic>> registerDevice(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      ApiEndpoints.notificationHubDevicesRegister,
      data: payload,
    );
    return asMap(response.data);
  }

  Future<Map<String, dynamic>> fetchPreferences() async {
    final response = await _dio.get(ApiEndpoints.notificationHubPreferences);
    return asMap(response.data);
  }

  Future<Map<String, dynamic>> patchPreferences(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch(
      ApiEndpoints.notificationHubPreferences,
      data: payload,
    );
    return asMap(response.data);
  }

  Future<ApiEnvelope<Map<String, dynamic>>> sync(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      ApiEndpoints.notificationHubSync,
      data: payload,
    );
    return ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: asMap,
      emptyData: const <String, dynamic>{},
    );
  }

  Future<ApiEnvelope<Map<String, dynamic>>> report(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      ApiEndpoints.notificationHubReport,
      data: payload,
    );
    return ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: asMap,
      emptyData: const <String, dynamic>{},
    );
  }
}
