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
  final int todaySteps;
  final int waterMl;
  final int sleepMinutes;
  final int calories;
  final ChronicDashboardSummary chronicSummary;

  const DashboardData({
    required this.points,
    required this.todaySteps,
    required this.waterMl,
    required this.sleepMinutes,
    required this.calories,
    required this.chronicSummary,
  });

  factory DashboardData.empty() => const DashboardData(
        points: 0,
        todaySteps: 0,
        waterMl: 0,
        sleepMinutes: 0,
        calories: 0,
        chronicSummary: ChronicDashboardSummary.empty(),
      );

  factory DashboardData.fromDashboard(Map<String, dynamic> d) {
    final gamification = _dashboardMap(d['gamification']);
    final activity = _dashboardMap(d['activity']);
    final hydration = _dashboardMap(d['hydration']);
    final summary = _dashboardMap(d['summary']);

    final pointsRaw = d['points'] ??
        d['score'] ??
        d['user_score'] ??
        d['total_points'] ??
        gamification['points'];

    final stepsRaw =
        d['today_steps'] ?? d['steps'] ?? d['total_steps'] ?? activity['steps'];

    final flatWaterRaw = d['water_ml'] ?? d['water'] ?? d['today_water'];
    final hydrationCurrentRaw = hydration['current'];
    final waterMl =
        flatWaterRaw != null ? _dashboardInt(flatWaterRaw) : _litersToMl(hydrationCurrentRaw);

    final caloriesRaw = d['calories'] ??
        d['consumed_calories'] ??
        d['today_calories'] ??
        summary['calories_consumed'];
    final sleepRaw = d['sleep_minutes'] ?? d['sleep'] ?? d['today_sleep'];

    return DashboardData(
      points: _dashboardInt(pointsRaw),
      todaySteps: _dashboardInt(stepsRaw),
      waterMl: waterMl,
      sleepMinutes: _dashboardInt(sleepRaw),
      calories: _dashboardInt(caloriesRaw),
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
