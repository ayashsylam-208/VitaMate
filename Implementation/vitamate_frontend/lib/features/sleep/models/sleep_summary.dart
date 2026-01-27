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
    Map<String, dynamic> _asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.cast<String, dynamic>();
      return <String, dynamic>{};
    }

    double _toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse(v.toString()) ?? 0;
    }

    final sleep = _asMap(d['sleep']);
    final gamification = _asMap(d['gamification']);

    return SleepSummary(
      goalHours: _toDouble(sleep['recommended_sleep_hours']),
      loggedHoursToday: _toDouble(sleep['logged_hours_today']),
      progressPercent: _toInt(sleep['progress_percent']),
      sleepPoints: _toInt(d['sleep_points'] ?? d['points'] ?? gamification['points']),
    );
  }
}
