import 'package:flutter_test/flutter_test.dart';

import 'package:vitamate/core/routing/routes.dart';

import 'support/vitamate_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Activity screen asks for activity recognition when denied', (
    tester,
  ) async {
    final harness = VitamateTestHarness();
    await harness.bootstrap(stepsPermissionGranted: false);

    await harness.pumpAppRoute(tester, initialRoute: Routes.activities);
    await harness.settleApp(tester);

    expect(find.textContaining('Grant activity recognition'), findsOneWidget);
    expect(find.text('Manual fallback'), findsOneWidget);
  });
}
