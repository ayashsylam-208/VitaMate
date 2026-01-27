class SleepLog {
  final int id;
  final DateTime startTime;
  final DateTime endTime;
  final String quality; // Deep / Light / Interrupted
  final DateTime date;
  final double durationHours;
  final int pointsEarned;

  SleepLog({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.quality,
    required this.date,
    required this.durationHours,
    required this.pointsEarned,
  });

  int get durationMinutes => (durationHours * 60).round();

  factory SleepLog.fromJson(Map<String, dynamic> json) {
    return SleepLog(
      id: (json['id'] as num).toInt(),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      quality: (json['quality'] ?? '').toString(),
      date: DateTime.parse(json['date'] as String),
      durationHours: (json['duration_hours'] as num).toDouble(),
      pointsEarned: (json['points_earned'] as num?)?.toInt() ?? 0,
    );
  }
}
