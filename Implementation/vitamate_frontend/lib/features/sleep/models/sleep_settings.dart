import '../../../auth/models/user.dart';

class SleepSettings {
  final double goalHours;
  final DateTime wakeTime;
  final DateTime bedTime;

  SleepSettings({
    required this.goalHours,
    required this.wakeTime,
    required this.bedTime,
  });

  factory SleepSettings.fromUser(AuthUser user) {
    return SleepSettings(
      goalHours: user.profile.recommendedSleepHours,
      wakeTime: user.profile.targetWakeTime,
      bedTime: user.profile.targetBedTime,
    );
  }
}
