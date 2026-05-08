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

class CountingFakeAdapter implements HttpClientAdapter {
  int loginCalls = 0;
  int meCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = "${options.method.toUpperCase()} ${options.path}";
    if (key == "POST /api/auth/login/") {
      loginCalls += 1;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return ResponseBody.fromString(
        jsonEncode({"access": "tok", "refresh": "rtok"}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (key == "GET /api/auth/me/") {
      meCalls += 1;
      return ResponseBody.fromString(
        jsonEncode({
          "username": "user1",
          "first_name": "User",
          "last_name": "One",
          "email": "user1@example.com",
          "profile": {
            "weight": 80,
            "height": 175,
            "activity_level": 1.55,
            "goal": "maintain",
            "daily_step_goal": 8000,
            "gender": "male",
            "birth_date": "2000-01-01",
            "recommended_sleep_hours": 8,
            "target_wake_time": "07:00:00",
            "target_bed_time": "23:00:00",
            "enable_sleep_improvement": true,
            "preferred_activity_type": "walking",
            "enable_activity_reminders": true,
            "activity_reminder_interval_hours": 2,
            "enable_water_reminders": true,
            "water_reminder_interval_minutes": 60,
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

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
    HttpClient.initForTesting();
    HttpClient.dio.httpClientAdapter = FakeAdapter({
      "POST /api/auth/login/": ResponseBody.fromString(
        jsonEncode({"access": "tok", "refresh": "rtok"}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
      "GET /api/auth/me/": ResponseBody.fromString(
        jsonEncode({
          "username": "user1",
          "first_name": "User",
          "last_name": "One",
          "email": "user1@example.com",
          "profile": {
            "weight": 80,
            "height": 175,
            "activity_level": 1.55,
            "goal": "maintain",
            "daily_step_goal": 8000,
            "gender": "male",
            "birth_date": "2000-01-01",
            "recommended_sleep_hours": 8,
            "target_wake_time": "07:00:00",
            "target_bed_time": "23:00:00",
            "enable_sleep_improvement": true,
            "preferred_activity_type": "walking",
            "enable_activity_reminders": true,
            "activity_reminder_interval_hours": 2,
            "enable_water_reminders": true,
            "water_reminder_interval_minutes": 60,
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
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
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    // Fill fields and login.
    await tester.enterText(find.byType(TextFormField).at(0), 'user1');
    await tester.enterText(find.byType(TextFormField).at(1), 'Secret123');
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Navigation to Home succeeded.
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Rapid repeated submits only perform one login flow', (
    tester,
  ) async {
    final adapter = CountingFakeAdapter();
    HttpClient.dio.httpClientAdapter = adapter;

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: Routes.login,
        routes: {
          Routes.login: (_) => const LoginScreen(),
          Routes.home: (_) => const Scaffold(body: Text('Home')),
        },
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'user1');
    await tester.enterText(find.byType(TextFormField).at(1), 'Secret123');
    await tester.ensureVisible(find.text('Sign In'));

    await tester.tap(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(adapter.loginCalls, 1);
    expect(adapter.meCalls, 1);
    expect(find.text('Home'), findsOneWidget);
  });
}
