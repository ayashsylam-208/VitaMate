import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../core/notifications/notifications_service.dart';
import '../models/sleep_settings.dart';

class SleepSettingsController extends ChangeNotifier {
  final AuthRepository _authRepo;

  SleepSettingsController(this._authRepo);

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
      notificationsEnabled = user.profile.enableSleepImprovement;
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

      // إذا الإشعارات مفعلة: أعد الجدولة مباشرة
      // ??? ????????? ????? ??? ????????? ???????
      if (notificationsEnabled) {
        await NotificationsService.scheduleDailyBedtime(bedTime: bedTime);
        await NotificationsService.scheduleDailyWake(wakeTime: wakeTime);
        await NotificationsService.showEnabledConfirmation();
      }
    } catch (_) {
      error = 'Failed to update sleep settings';
    } finally {
      notifyListeners();
    }
  }

  /// ✅ الآن: التفعيل/الإلغاء يحفظ فورًا + يعيد الجدولة فورًا
  Future<void> setNotificationsEnabled(bool enabled) async {
    notificationsEnabled = enabled;
    notifyListeners();

    try {
      await _authRepo.updateMe({
        'enable_sleep_improvement': enabled,
      });
    } catch (_) {
      // حتى لو فشل الحفظ، لا نكسر الواجهة
    }

    if (!enabled) {
      await NotificationsService.cancelSleep();
      return;
    }

    final s = settings;
    if (s == null) return;

    await NotificationsService.showEnabledConfirmation();

    await NotificationsService.scheduleDailyBedtime(bedTime: s.bedTime);
    await NotificationsService.scheduleDailyWake(wakeTime: s.wakeTime);
  }

  String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
