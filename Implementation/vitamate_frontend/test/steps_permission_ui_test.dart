import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vitamate/core/network/http_client.dart';
import 'package:vitamate/core/routing/routes.dart';
import 'package:vitamate/features/steps/screens/steps_screen.dart';

class FakeAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Default stub: empty 200 response.
    return ResponseBody.fromString(
      jsonEncode({"activity": {}}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Mock SharedPreferences.
    SharedPreferences.setMockInitialValues({});
    // Mock permission_handler channel: return denied for status & request.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async {
        switch (call.method) {
          case 'checkPermissionStatus':
          case 'requestPermissions':
            // 0 = denied
            return call.method == 'checkPermissionStatus' ? 0 : {call.arguments.first: 0};
          default:
            return null;
        }
      },
    );

    // Stub pedometer event channel to avoid errors.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.flutter.pedometer.event',
      (message) async => null,
    );

    // Use fake dio adapter to avoid network.
    HttpClient.initForTesting();
    HttpClient.dio.httpClientAdapter = FakeAdapter();
  });

  testWidgets('Steps screen shows permission request message when denied',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: Routes.steps,
        routes: {Routes.steps: (_) => const StepsScreen()},
      ),
    );

    // Allow init to run.
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Activity recognition permission is required'),
      findsOneWidget,
    );
  });
}
