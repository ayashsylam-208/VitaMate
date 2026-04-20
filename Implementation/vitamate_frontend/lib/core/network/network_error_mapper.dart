import 'package:dio/dio.dart';

import '../config/api_endpoints.dart';

class NetworkErrorMapper {
  static String toMessage(
    Object error, {
    required String fallback,
    Map<int, String> statusMessages = const {},
  }) {
    if (error is DioException) {
      return mapDioException(
        error,
        fallback: fallback,
        statusMessages: statusMessages,
      );
    }
    return fallback;
  }

  static String mapDioException(
    DioException error, {
    required String fallback,
    Map<int, String> statusMessages = const {},
  }) {
    final baseUrl = error.requestOptions.baseUrl.isNotEmpty
        ? error.requestOptions.baseUrl
        : ApiEndpoints.baseUrl;
    final statusCode = error.response?.statusCode;
    if (statusCode != null && statusMessages.containsKey(statusCode)) {
      return statusMessages[statusCode]!;
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the backend at $baseUrl. '
          'Check that the server is running and that API_BASE_URL points '
          'to your host machine.';
    }

    if (error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'The backend at $baseUrl took too long to respond.';
    }

    final data = error.response?.data;
    if (data is Map) {
      final code = data['code']?.toString();
      if (statusCode == 401 && code == 'token_not_valid') {
        return 'Your session expired. Please sign in again.';
      }
      final firstValue = data.values.isNotEmpty ? data.values.first : null;
      if (firstValue is List && firstValue.isNotEmpty) {
        return firstValue.first.toString();
      }
      if (firstValue != null) {
        return firstValue.toString();
      }
    }
    if (data is List && data.isNotEmpty) {
      return data.first.toString();
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return fallback;
  }
}
