// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:vitamate/app.dart';
import 'package:vitamate/auth/screens/login_screen.dart';
import 'package:vitamate/core/network/http_client.dart';

void main() {
  setUpAll(() {
    HttpClient.initForTesting();
  });

  testWidgets('App starts on login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VitaMateApp());

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
  });
}
