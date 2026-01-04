class DashboardData {
  final int points;

  final int todaySteps;
  final int waterMl;
  final int sleepMinutes;
  final int calories;

  const DashboardData({
    required this.points,
    required this.todaySteps,
    required this.waterMl,
    required this.sleepMinutes,
    required this.calories,
  });

  factory DashboardData.empty() => const DashboardData(
        points: 0,
        todaySteps: 0,
        waterMl: 0,
        sleepMinutes: 0,
        calories: 0,
      );

  factory DashboardData.fromDashboard(Map<String, dynamic> d) {
    return DashboardData(
      // ✅ assume dashboard includes points/score in its unified report (FR-36)
      points: _toInt(d['points'] ?? d['score'] ?? d['user_score'] ?? d['total_points']),
      todaySteps: _toInt(d['today_steps'] ?? d['steps'] ?? d['total_steps']),
      waterMl: _toInt(d['water_ml'] ?? d['water'] ?? d['today_water']),
      sleepMinutes: _toInt(d['sleep_minutes'] ?? d['sleep'] ?? d['today_sleep']),
      calories: _toInt(d['calories'] ?? d['consumed_calories'] ?? d['today_calories']),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }
}
