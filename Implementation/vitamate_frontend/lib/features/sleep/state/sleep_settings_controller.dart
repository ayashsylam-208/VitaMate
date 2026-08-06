import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../core/notification_hub/notification_hub.dart';
import '../models/sleep_settings.dart';

class SleepSettingsController extends ChangeNotifier {
  SleepSettingsController(this._authRepo);

  final AuthRepository _authRepo;

  SleepSettings? settings;
  bool notificationsEnabled = false;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final user = await _authRepo.getMe();
      settings = SleepSettings.fromUser(user);
      notificationsEnabled =
          NotificationHubController.instance.preferences.enableSleepReminders;
    } catch (_) {
      error = 'Failed to load sleep settings';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> update({
    required double goalHours,
    required DateTime wakeTime,
    required DateTime bedTime,
  }) async {
    error = null;
    notifyListeners();

    try {
      await _authRepo.updateMe({
        'recommended_sleep_hours': goalHours,
        'target_wake_time': _fmtTime(wakeTime),
        'target_bed_time': _fmtTime(bedTime),
      });

      settings = SleepSettings(
        goalHours: goalHours,
        wakeTime: wakeTime,
        bedTime: bedTime,
      );
      await NotificationHubController.instance.updatePreferences({
        'target_wake_time': _fmtTime(wakeTime),
        'target_bed_time': _fmtTime(bedTime),
      });
    } catch (_) {
      error = 'Failed to update sleep settings';
    } finally {
      notifyListeners();
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    notificationsEnabled = enabled;
    notifyListeners();

    try {
      await NotificationHubController.instance.updatePreferences({
        'enable_sleep_reminders': enabled,
      });
    } catch (_) {
      // Keep optimistic UI; next load will reconcile from backend.
    }
  }

  String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
