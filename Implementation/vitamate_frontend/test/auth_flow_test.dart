import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vitamate/auth/screens/login_screen.dart';
import 'package:vitamate/core/network/http_client.dart';
import 'package:vitamate/core/routing/routes.dart';

/// Simple fake adapter for Dio to avoid real HTTP.
class FakeAdapter implements HttpClientAdapter {
  final Map<String, ResponseBody> responses;
  FakeAdapter(this.responses);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = "${options.method.toUpperCase()} ${options.path}";
    final resp = responses[key];
    if (resp != null) return resp;
    return ResponseBody.fromString(
      '{}',
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Mock secure storage channel to avoid MissingPluginException.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );

    // Mock notifications channel to avoid plugin errors on showWelcomeBack.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => null,
    );

    // Provide fake HTTP responses for login.
    HttpClient.dio.httpClientAdapter = FakeAdapter({
      "POST /api/auth/login/": ResponseBody.fromString(
        jsonEncode({"access": "tok", "refresh": "rtok"}),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      ),
    });
  });

  testWidgets('Login validators and successful navigation', (tester) async {
    // Minimal app with login and dummy home route.
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: Routes.login,
        routes: {
          Routes.login: (_) => const LoginScreen(),
          Routes.home: (_) => const Scaffold(body: Text('Home')),
        },
      ),
    );

    // Tap login with empty fields -> validators trigger.
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    // Fill fields and login.
    await tester.enterText(find.byType(TextFormField).at(0), 'user1');
    await tester.enterText(find.byType(TextFormField).at(1), 'Secret123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Navigation to Home succeeded.
    expect(find.text('Home'), findsOneWidget);
  });
}
