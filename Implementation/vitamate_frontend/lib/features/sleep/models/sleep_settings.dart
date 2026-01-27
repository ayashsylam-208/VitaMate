class SleepSettings {
  final double goalHours;
  final DateTime wakeTime;
  final DateTime bedTime;

  SleepSettings({
    required this.goalHours,
    required this.wakeTime,
    required this.bedTime,
  });

  factory SleepSettings.fromMe(Map<String, dynamic> json) {
    final goal =
        (json['recommended_sleep_hours'] as num?)?.toDouble() ?? 8.0;

    final wakeStr = json['target_wake_time'] as String?;
    final bedStr = json['target_bed_time'] as String?;

    final wakeTime = wakeStr != null
        ? DateTime.parse('2000-01-01 $wakeStr')
        : DateTime(2000, 1, 1, 7, 0);

    final bedTime = bedStr != null
        ? DateTime.parse('2000-01-01 $bedStr')
        : DateTime(2000, 1, 1, 23, 0);

    return SleepSettings(
      goalHours: goal,
      wakeTime: wakeTime,
      bedTime: bedTime,
    );
  }
}


