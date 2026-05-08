import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/core/config/api_endpoints.dart';
import 'package:vitamate/core/network/network_error_mapper.dart';

void main() {
  test('maps HTML 500 responses to a friendly backend message', () {
    final request = RequestOptions(path: '/api/meals/');
    final error = DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 500,
        headers: Headers.fromMap(const {
          Headers.contentTypeHeader: ['text/html; charset=utf-8'],
        }),
        data:
            '<!DOCTYPE html><html><title>OperationalError at /api/meals/</title></html>',
      ),
      type: DioExceptionType.badResponse,
    );

    final message = NetworkErrorMapper.toMessage(
      error,
      fallback: 'Failed to load nutrition data.',
    );

    expect(message, contains('/api/meals/'));
    expect(message, contains('server and database'));
    expect(message, isNot(contains('<!DOCTYPE html>')));
  });

  test('maps connection timeouts to an Android-specific backend hint', () {
    ApiEndpoints.setResolvedBaseUrlForTesting('http://10.0.2.2:8000');
    final request = RequestOptions(
      path: '/api/auth/login/',
      baseUrl: 'http://10.0.2.2:8000',
    );
    final error = DioException(
      requestOptions: request,
      type: DioExceptionType.connectionTimeout,
    );

    final message = NetworkErrorMapper.toMessage(
      error,
      fallback: 'Login failed.',
    );

    expect(message, contains('http://10.0.2.2:8000'));
    expect(message, contains('Android emulator uses http://10.0.2.2:8000'));
    expect(message, contains('adb reverse'));
  });
}
