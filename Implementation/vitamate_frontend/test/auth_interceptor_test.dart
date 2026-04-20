import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/core/config/api_endpoints.dart';
import 'package:vitamate/core/network/http_client.dart';
import 'package:vitamate/core/storage/secure_storage.dart';

class _AuthAdapter implements HttpClientAdapter {
  _AuthAdapter({required this.refreshSucceeds});

  final bool refreshSucceeds;
  int refreshCalls = 0;
  int protectedCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET' && options.path == ApiEndpoints.water) {
      protectedCalls += 1;
      final authHeader = options.headers['Authorization']?.toString();
      if (authHeader == 'Bearer fresh-access') {
        return _json(200, const []);
      }
      return _json(401, {
        'detail': 'Given token not valid for any token type',
        'code': 'token_not_valid',
      });
    }

    if (options.method == 'POST' && options.path == ApiEndpoints.refresh) {
      refreshCalls += 1;
      final refresh = (options.data as Map?)?['refresh']?.toString();
      if (refreshSucceeds && refresh == 'refresh-token') {
        return _json(200, {'access': 'fresh-access'});
      }
      return _json(401, {
        'detail': 'Token is invalid or expired',
        'code': 'token_not_valid',
      });
    }

    return _json(404, const {});
  }

  ResponseBody _json(int statusCode, Object data) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> store;

  setUp(() async {
    store = <String, String>{};

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = Map<String, dynamic>.from(call.arguments ?? {});
            final key = args['key']?.toString();
            switch (call.method) {
              case 'write':
                if (key != null) {
                  store[key] = args['value']?.toString() ?? '';
                }
                return null;
              case 'read':
                return key == null ? null : store[key];
              case 'delete':
                if (key != null) {
                  store.remove(key);
                }
                return null;
              default:
                return null;
            }
          },
        );

    HttpClient.initForTesting();
    await SecureStorage.clear();
  });

  test('refreshes expired access token and retries the request once', () async {
    final adapter = _AuthAdapter(refreshSucceeds: true);
    HttpClient.setTestAdapter(adapter);
    await SecureStorage.saveTokens(
      access: 'expired-access',
      refresh: 'refresh-token',
    );

    final response = await HttpClient.dio.get(ApiEndpoints.water);

    expect(response.statusCode, 200);
    expect(adapter.refreshCalls, 1);
    expect(adapter.protectedCalls, 2);
    expect(await SecureStorage.readAccessToken(), 'fresh-access');
    expect(await SecureStorage.readRefreshToken(), 'refresh-token');
  });

  test('clears stored tokens when refresh also expires', () async {
    final adapter = _AuthAdapter(refreshSucceeds: false);
    HttpClient.setTestAdapter(adapter);
    await SecureStorage.saveTokens(
      access: 'expired-access',
      refresh: 'refresh-token',
    );

    await expectLater(
      HttpClient.dio.get(ApiEndpoints.water),
      throwsA(isA<DioException>()),
    );

    expect(adapter.refreshCalls, 1);
    expect(await SecureStorage.readAccessToken(), isNull);
    expect(await SecureStorage.readRefreshToken(), isNull);
  });
}
