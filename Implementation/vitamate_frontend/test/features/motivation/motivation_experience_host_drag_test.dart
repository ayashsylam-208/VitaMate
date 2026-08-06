import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitamate/features/motivation/models/motivation_models.dart';
import 'package:vitamate/features/motivation/screens/motivation_experience_host.dart';
import 'package:vitamate/features/motivation/state/motivation_experience_controller.dart';

void main() {
  final controller = MotivationExperienceController.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    controller.feed = _feed();
    controller.presentationEnabled = true;
  });

  tearDown(controller.resetPresentation);

  testWidgets('status pill can be dragged and keeps its selected position', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    final pill = find.byType(MotivationStatusPill);
    final originalPosition = tester.getTopLeft(pill);

    await tester.drag(pill, const Offset(-170, -220));
    await tester.pumpAndSettle();
    final movedPosition = tester.getTopLeft(pill);

    expect(movedPosition.dx, lessThan(originalPosition.dx));
    expect(movedPosition.dy, lessThan(originalPosition.dy));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final restoredPosition = tester.getTopLeft(pill);
    expect(restoredPosition.dx, closeTo(movedPosition.dx, 1));
    expect(restoredPosition.dy, closeTo(movedPosition.dy, 1));
  });

  testWidgets('status pill remains inside safe screen bounds', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    final pill = find.byType(MotivationStatusPill);
    await tester.drag(pill, const Offset(-5000, -5000));
    await tester.pumpAndSettle();

    final position = tester.getTopLeft(pill);
    expect(position.dx, greaterThanOrEqualTo(8));
    expect(position.dy, greaterThanOrEqualTo(8));
  });
}

Widget _host() {
  return const MaterialApp(
    home: MotivationExperienceHost(child: Scaffold(body: SizedBox.expand())),
  );
}

MotivationFeed _feed() {
  return MotivationFeed.fromJson(const <String, dynamic>{
    'summary': <String, dynamic>{
      'total_points': 1240,
      'daily_points': 40,
      'level': 3,
      'next_level_threshold': 2000,
      'current_streak': 5,
    },
    'celebrations': <Map<String, dynamic>>[],
    'updated_at': '2026-08-05T10:00:00Z',
  });
}
