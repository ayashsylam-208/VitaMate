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
    // Backend dashboard response is nested:
    // summary / hydration / activity / gamification
    // But we also support old/flat keys as fallback.

    final gamification = _asMap(d['gamification']);
    final activity = _asMap(d['activity']);
    final hydration = _asMap(d['hydration']);
    final summary = _asMap(d['summary']);

    final pointsRaw =
        d['points'] ?? d['score'] ?? d['user_score'] ?? d['total_points'] ?? gamification['points'];

    final stepsRaw =
        d['today_steps'] ?? d['steps'] ?? d['total_steps'] ?? activity['steps'];

    // Backend returns hydration.current in **liters** (amount_liter sum).
    // UI usually expects ml.
    final flatWaterRaw = d['water_ml'] ?? d['water'] ?? d['today_water'];
    final hydrationCurrentRaw = hydration['current'];

    final waterMl = flatWaterRaw != null
        ? _toInt(flatWaterRaw)
        : _litersToMl(hydrationCurrentRaw);

    final caloriesRaw =
        d['calories'] ?? d['consumed_calories'] ?? d['today_calories'] ?? summary['calories_consumed'];

    // Backend dashboard currently doesn't provide sleep minutes.
    // Keep fallback parsing for future.
    final sleepRaw = d['sleep_minutes'] ?? d['sleep'] ?? d['today_sleep'];

    return DashboardData(
      points: _toInt(pointsRaw),
      todaySteps: _toInt(stepsRaw),
      waterMl: waterMl,
      sleepMinutes: _toInt(sleepRaw),
      calories: _toInt(caloriesRaw),
    );
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  static int _litersToMl(dynamic liters) {
    if (liters == null) return 0;

    // If it's already a big number (e.g. 1500), assume it's ml.
    if (liters is int && liters > 50) return liters;
    if (liters is double && liters > 50) return liters.round();

    final asDouble = _toDouble(liters);
    if (asDouble == null) return 0;

    // Typical liters are 0-10. Convert to ml.
    return (asDouble * 1000).round();
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }
}
