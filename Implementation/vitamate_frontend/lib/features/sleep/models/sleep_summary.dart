class SleepSummary {
  final double goalHours;
  final double loggedHoursToday;
  final int progressPercent;
  final int sleepPoints;

  const SleepSummary({
    required this.goalHours,
    required this.loggedHoursToday,
    required this.progressPercent,
    required this.sleepPoints,
  });

  factory SleepSummary.empty() => const SleepSummary(
        goalHours: 0,
      loggedHoursToday: 0,
      progressPercent: 0,
      sleepPoints: 0,
    );

  factory SleepSummary.fromDashboard(Map<String, dynamic> d) {
    Map<String, dynamic> asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.cast<String, dynamic>();
      return <String, dynamic>{};
    }

    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse(v.toString()) ?? 0;
    }

    final sleep = asMap(d['sleep']);
    final gamification = asMap(d['gamification']);

    return SleepSummary(
      goalHours: toDouble(sleep['recommended_sleep_hours']),
      loggedHoursToday: toDouble(sleep['logged_hours_today']),
      progressPercent: toInt(sleep['progress_percent']),
      sleepPoints: toInt(d['sleep_points'] ?? d['points'] ?? gamification['points']),
    );
  }
}
