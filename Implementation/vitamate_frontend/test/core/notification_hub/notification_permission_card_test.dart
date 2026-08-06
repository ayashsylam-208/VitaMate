import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/core/notification_hub/widgets/notification_experience_widgets.dart';

void main() {
  testWidgets('denied permission renders one settings action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VitaNotificationPermissionCard(
            enabled: false,
            statusLabel: 'Enable notifications in Android settings.',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Notifications are off'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    expect(tapped, isTrue);
  });
}
