import 'package:dio/dio.dart';

import '../config/api_endpoints.dart';

class NetworkErrorMapper {
  static bool isCanceled(Object error) {
    return error is DioException &&
        (error.type == DioExceptionType.cancel || CancelToken.isCancel(error));
  }

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
    final data = error.response?.data;
    final contentType =
        error.response?.headers.value(Headers.contentTypeHeader) ?? '';
    final requestPath = error.requestOptions.path;
    final htmlPayload = _looksLikeHtml(data) || contentType.contains('html');
    if (statusCode != null && statusMessages.containsKey(statusCode)) {
      return statusMessages[statusCode]!;
    }

    if (error.type == DioExceptionType.cancel || CancelToken.isCancel(error)) {
      return 'Request canceled.';
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the backend at $baseUrl. '
          '${ApiEndpoints.connectionHint(failingBaseUrl: baseUrl)}';
    }

    if (error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'The backend at $baseUrl took too long to respond.';
    }

    if (statusCode != null && statusCode >= 500) {
      final target = requestPath.isNotEmpty ? requestPath : 'the requested API';
      if (htmlPayload) {
        return 'The backend failed while handling $target. '
            'Check that the server and database are running.';
      }
      return 'The backend failed while handling $target. '
          'Check the server logs and database connection.';
    }

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
      if (htmlPayload) {
        return fallback;
      }
      return data.trim();
    }
    return fallback;
  }

  static bool _looksLikeHtml(dynamic data) {
    if (data is! String) {
      return false;
    }
    final trimmed = data.trimLeft().toLowerCase();
    return trimmed.startsWith('<!doctype html') ||
        trimmed.startsWith('<html') ||
        trimmed.contains('<title>operationalerror') ||
        trimmed.contains('<body');
  }
}
