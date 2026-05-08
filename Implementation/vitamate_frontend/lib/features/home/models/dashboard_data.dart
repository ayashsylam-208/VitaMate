class ChronicDashboardSummary {
  final int count;
  final List<String> labels;
  final double adherencePercent;
  final int activeMedicationsToday;
  final int pendingDosesToday;
  final List<String> appliedSummaries;
  final String disclaimer;

  const ChronicDashboardSummary({
    required this.count,
    required this.labels,
    required this.adherencePercent,
    required this.activeMedicationsToday,
    required this.pendingDosesToday,
    required this.appliedSummaries,
    required this.disclaimer,
  });

  const ChronicDashboardSummary.empty()
    : count = 0,
      labels = const [],
      adherencePercent = 0,
      activeMedicationsToday = 0,
      pendingDosesToday = 0,
      appliedSummaries = const [],
      disclaimer = '';

  factory ChronicDashboardSummary.fromJson(dynamic value) {
    final json = _dashboardMap(value);
    return ChronicDashboardSummary(
      count: _dashboardInt(json['count']),
      labels: _dashboardStringList(json['labels']),
      adherencePercent: _dashboardDouble(json['adherence_percent']),
      activeMedicationsToday: _dashboardInt(json['active_medications_today']),
      pendingDosesToday: _dashboardInt(json['pending_doses_today']),
      appliedSummaries: _dashboardStringList(json['applied_summaries']),
      disclaimer: _dashboardString(json['disclaimer']),
    );
  }

  bool get hasAny => count > 0;

  String get labelsSummary {
    if (labels.isEmpty) return 'No chronic conditions added';
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels.first} + ${labels.last}';
    return '${labels.first} + ${labels.length - 1} more';
  }
}

class DashboardData {
  final int points;
  final int level;
  final int dailyPoints;
  final int todaySteps;
  final int stepTarget;
  final int activityBurnedKcal;
  final int activityMinutes;
  final int burnTargetKcal;
  final int waterMl;
  final int sleepMinutes;
  final int calories;
  final ChronicDashboardSummary chronicSummary;

  const DashboardData({
    required this.points,
    this.level = 1,
    this.dailyPoints = 0,
    required this.todaySteps,
    this.stepTarget = 0,
    this.activityBurnedKcal = 0,
    this.activityMinutes = 0,
    this.burnTargetKcal = 0,
    required this.waterMl,
    required this.sleepMinutes,
    required this.calories,
    required this.chronicSummary,
  });

  factory DashboardData.empty() => const DashboardData(
    points: 0,
    level: 1,
    dailyPoints: 0,
    todaySteps: 0,
    waterMl: 0,
    sleepMinutes: 0,
    calories: 0,
    chronicSummary: ChronicDashboardSummary.empty(),
  );

  bool get hasTrackerMetrics =>
      points != 0 ||
      todaySteps != 0 ||
      activityBurnedKcal != 0 ||
      activityMinutes != 0 ||
      waterMl != 0 ||
      sleepMinutes != 0 ||
      calories != 0;

  factory DashboardData.fromDashboard(Map<String, dynamic> d) {
    final gamification = _dashboardMap(d['gamification']);
    final activity = _dashboardMap(d['activity']);
    final hydration = _dashboardMap(d['hydration']);
    final sleep = _dashboardMap(d['sleep']);
    final summary = _dashboardMap(d['summary']);
    final historyEntry = _dashboardMap(d['history_entry']);

    final pointsRaw =
        d['points'] ??
        d['score'] ??
        d['user_score'] ??
        d['total_points'] ??
        gamification['points'];

    final stepsRaw =
        d['today_steps'] ?? d['steps'] ?? d['total_steps'] ?? activity['steps'];

    final flatWaterRaw = d['water_ml'] ?? d['water'] ?? d['today_water'];
    final hydrationCurrentRaw = hydration['current'];
    final waterMl = flatWaterRaw != null
        ? _dashboardInt(flatWaterRaw)
        : _litersToMl(hydrationCurrentRaw);

    final caloriesRaw =
        d['calories'] ??
        d['consumed_calories'] ??
        d['today_calories'] ??
        summary['calories_consumed'];
    final rawSleep = d['sleep'];
    final sleepRaw =
        d['sleep_minutes'] ??
        (rawSleep is Map ? null : rawSleep) ??
        d['today_sleep'];
    final sleepMinutes = sleepRaw != null
        ? _dashboardInt(sleepRaw)
        : _hoursToMinutes(sleep['logged_hours_today']);

    return DashboardData(
      points: _dashboardInt(pointsRaw),
      level: _dashboardInt(
        d['level'] ?? gamification['level'],
      ).clamp(1, 999).toInt(),
      dailyPoints: _dashboardInt(
        d['daily_points'] ??
            d['points_estimate'] ??
            historyEntry['points_estimate'],
      ),
      todaySteps: _dashboardInt(stepsRaw),
      stepTarget: _dashboardInt(d['step_target'] ?? activity['steps_target']),
      activityBurnedKcal: _dashboardInt(
        d['activity_burned_kcal'] ?? summary['calories_burned'],
      ),
      activityMinutes: _dashboardInt(
        d['activity_minutes'] ?? historyEntry['exercise_minutes'],
      ),
      burnTargetKcal: _dashboardInt(
        d['burn_target_kcal'] ?? summary['burn_target'],
      ),
      waterMl: waterMl,
      sleepMinutes: sleepMinutes,
      calories: _dashboardInt(caloriesRaw),
      chronicSummary: ChronicDashboardSummary.fromJson(d['chronic_conditions']),
    );
  }

  factory DashboardData.fromOverview(Map<String, dynamic> d) {
    return DashboardData(
      points: _dashboardInt(d['points']),
      level: _dashboardInt(d['level']).clamp(1, 999).toInt(),
      dailyPoints: _dashboardInt(d['daily_points']),
      todaySteps: _dashboardInt(d['today_steps']),
      stepTarget: _dashboardInt(d['step_target']),
      activityBurnedKcal: _dashboardInt(d['activity_burned_kcal']),
      activityMinutes: _dashboardInt(d['activity_minutes']),
      burnTargetKcal: _dashboardInt(d['burn_target_kcal']),
      waterMl: _dashboardInt(d['water_ml']),
      sleepMinutes: _dashboardInt(d['sleep_minutes']),
      calories: _dashboardInt(d['calories']),
      chronicSummary: ChronicDashboardSummary.fromJson(d['chronic_conditions']),
    );
  }

  static int _litersToMl(dynamic liters) {
    if (liters == null) return 0;
    if (liters is int && liters > 50) return liters;
    if (liters is double && liters > 50) return liters.round();

    final asDouble = _dashboardNullableDouble(liters);
    if (asDouble == null) return 0;
    return (asDouble * 1000).round();
  }

  static int _hoursToMinutes(dynamic hours) {
    final asDouble = _dashboardNullableDouble(hours);
    if (asDouble == null) return 0;
    return (asDouble * 60).round();
  }
}

Map<String, dynamic> _dashboardMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.cast<String, dynamic>();
  return <String, dynamic>{};
}

List<String> _dashboardStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const <String>[];
}

String _dashboardString(dynamic value) => value?.toString() ?? '';

double? _dashboardNullableDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString());
}

double _dashboardDouble(dynamic v) => _dashboardNullableDouble(v) ?? 0;

int _dashboardInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v.toString()) ?? 0;
}
