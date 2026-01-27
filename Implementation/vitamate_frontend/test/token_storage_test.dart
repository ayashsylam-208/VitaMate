import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vitamate/core/storage/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SecureStorage save/read/clear calls underlying channel', () async {
    final calls = <String, Map<String, dynamic>>{};
    final store = <String, String>{};

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        calls[call.method] = Map<String, dynamic>.from(call.arguments ?? {});
        switch (call.method) {
          case 'write':
            store[call.arguments['key'] as String] =
                call.arguments['value'] as String;
            return null;
          case 'read':
            return store[call.arguments['key'] as String];
          case 'delete':
            store.remove(call.arguments['key'] as String);
            return null;
          default:
            return null;
        }
      },
    );

    await SecureStorage.saveTokens(access: 'a1', refresh: 'r1');
    expect(store['access_token'], 'a1');
    expect(store['refresh_token'], 'r1');
    expect(calls.containsKey('write'), isTrue);

    final access = await SecureStorage.readAccessToken();
    expect(access, 'a1');
    expect(calls.containsKey('read'), isTrue);

    await SecureStorage.clear();
    expect(store, isEmpty);
    expect(calls.containsKey('delete'), isTrue);
  });
}
