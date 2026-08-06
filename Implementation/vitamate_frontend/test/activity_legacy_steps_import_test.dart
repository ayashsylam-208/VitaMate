import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy steps controller and screen are not imported by app code', () {
    final root = Directory('lib');
    final offenders = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final content = entity.readAsStringSync();
      if (content.contains('features/steps/state/steps_controller.dart') ||
          content.contains('features/steps/screens/steps_screen.dart') ||
          content.contains('StepsController') ||
          content.contains('StepsScreen')) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty);
  });
}
