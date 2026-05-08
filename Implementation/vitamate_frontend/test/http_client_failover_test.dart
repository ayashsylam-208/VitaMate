import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/core/config/api_endpoints.dart';
import 'package:vitamate/core/network/http_client.dart';

class _FailoverAdapter implements HttpClientAdapter {
  int primaryLoginCalls = 0;
  int fallbackLoginCalls = 0;
  int fallbackHealthCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri.toString();

    if (uri == 'http://127.0.0.1:8000/api/health/') {
      fallbackHealthCalls += 1;
      return _json(200, const {'status': 'ok'});
    }

    if (options.method == 'POST' && options.path == ApiEndpoints.login) {
      if (options.baseUrl == 'http://10.0.2.2:8000') {
        primaryLoginCalls += 1;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );
      }

      if (options.baseUrl == 'http://127.0.0.1:8000') {
        fallbackLoginCalls += 1;
        return _json(200, const {
          'access': 'access-token',
          'refresh': 'refresh-token',
        });
      }
    }

    return _json(404, const {});
  }

  ResponseBody _json(int statusCode, Object data) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

void main() {
  test('retries login against the alternate local Android base URL', () async {
    HttpClient.initForTesting(baseUrl: 'http://10.0.2.2:8000');

    final adapter = _FailoverAdapter();
    HttpClient.setTestAdapter(adapter);

    final response = await HttpClient.dio.post(
      ApiEndpoints.login,
      data: const {'username': 'salam', 'password': 'Secret123'},
    );

    expect(response.statusCode, 200);
    expect(adapter.primaryLoginCalls, 1);
    expect(adapter.fallbackHealthCalls, 1);
    expect(adapter.fallbackLoginCalls, 1);
    expect(ApiEndpoints.baseUrl, 'http://127.0.0.1:8000');
  });
}
