import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:vitamate/core/notifications/notifications_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NotificationsService schedules steps reminder with expected calls',
      () async {
    // Initialize timezone to avoid tz errors.
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));

    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        calls.add(call.method);
        return null;
      },
    );

    await NotificationsService.scheduleDailyStepsReminder(
      time: DateTime(2000, 1, 1, 9, 0),
    );

    expect(calls.where((m) => m == 'cancel').isNotEmpty, isTrue);
    expect(calls.where((m) => m == 'zonedSchedule').isNotEmpty, isTrue);
    expect(calls.where((m) => m == 'show').isNotEmpty, isTrue);
  });
}
