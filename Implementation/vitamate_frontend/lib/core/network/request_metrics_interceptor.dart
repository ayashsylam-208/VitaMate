import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class RequestMetricsInterceptor extends Interceptor {
  static const String _startedAtKey = 'metrics_started_at';
  static const String _tagKey = 'metrics_tag';

  const RequestMetricsInterceptor();

  static Options taggedOptions({required String tag, String method = 'GET'}) {
    return Options(method: method, extra: <String, dynamic>{_tagKey: tag});
  }

  static String? tagOf(RequestOptions options) {
    return options.extra[_tagKey]?.toString();
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now().microsecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log(
      options: response.requestOptions,
      statusCode: response.statusCode,
      responseBytes:
          _contentLength(response.headers) ?? _estimateBytes(response.data),
      state: 'completed',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(
      options: err.requestOptions,
      statusCode: err.response?.statusCode,
      responseBytes:
          _contentLength(err.response?.headers) ??
          _estimateBytes(err.response?.data),
      state: CancelToken.isCancel(err) ? 'canceled' : 'failed',
      errorType: err.type.name,
    );
    handler.next(err);
  }

  void _log({
    required RequestOptions options,
    required int? statusCode,
    required int responseBytes,
    required String state,
    String? errorType,
  }) {
    if (!kDebugMode) {
      return;
    }
    final startedAt = options.extra[_startedAtKey] as int?;
    final durationMs = startedAt == null
        ? null
        : ((DateTime.now().microsecondsSinceEpoch - startedAt) / 1000).round();
    final tag = tagOf(options) ?? options.path;
    debugPrint(
      jsonEncode(<String, dynamic>{
        'kind': 'http_metric',
        'tag': tag,
        'method': options.method,
        'path': options.path,
        'status_code': statusCode,
        'duration_ms': durationMs,
        'response_bytes': responseBytes,
        'state': state,
        if (errorType != null) 'error_type': errorType,
      }),
    );
  }

  int? _contentLength(Headers? headers) {
    if (headers == null) {
      return null;
    }
    return int.tryParse(headers.value(Headers.contentLengthHeader) ?? '');
  }

  int _estimateBytes(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is Uint8List) {
      return value.length;
    }
    if (value is List<int>) {
      return value.length;
    }
    if (value is String) {
      return utf8.encode(value).length;
    }
    if (value is Map || value is Iterable) {
      return -1;
    }
    return value.toString().length;
  }
}
