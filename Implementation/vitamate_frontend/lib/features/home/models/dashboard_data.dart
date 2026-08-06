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

class DailyHealthSummary {
  final String date;
  final String scoreVersion;
  final int progressPercent;
  final int score;
  final int coveragePercent;
  final String completionStatus;
  final bool dailyComplete;
  final int completedEssential;
  final int totalEssential;
  final bool criticalOverdue;
  final String message;

  const DailyHealthSummary({
    required this.date,
    required this.scoreVersion,
    required this.progressPercent,
    required this.score,
    required this.coveragePercent,
    required this.completionStatus,
    required this.dailyComplete,
    required this.completedEssential,
    required this.totalEssential,
    required this.criticalOverdue,
    required this.message,
  });

  const DailyHealthSummary.empty()
    : date = '',
      scoreVersion = '',
      progressPercent = 0,
      score = 0,
      coveragePercent = 0,
      completionStatus = 'not_started',
      dailyComplete = false,
      completedEssential = 0,
      totalEssential = 0,
      criticalOverdue = false,
      message = '';

  factory DailyHealthSummary.fromJson(dynamic value) {
    final json = _dashboardMap(value);
    if (json.isEmpty) return const DailyHealthSummary.empty();
    final progress = _dashboardInt(json['progress_percent'] ?? json['score']);
    return DailyHealthSummary(
      date: _dashboardString(json['date']),
      scoreVersion: _dashboardString(json['score_version']),
      progressPercent: progress.clamp(0, 100).toInt(),
      score: _dashboardInt(json['score'] ?? progress).clamp(0, 100).toInt(),
      coveragePercent: _dashboardInt(
        json['coverage_percent'],
      ).clamp(0, 100).toInt(),
      completionStatus: _dashboardString(json['completion_status']).isEmpty
          ? 'not_started'
          : _dashboardString(json['completion_status']),
      dailyComplete: json['daily_complete'] == true,
      completedEssential: _dashboardInt(json['completed_essential']),
      totalEssential: _dashboardInt(json['total_essential']),
      criticalOverdue: json['critical_overdue'] == true,
      message: _dashboardString(json['message']),
    );
  }

  bool get hasData => scoreVersion.isNotEmpty || totalEssential > 0;
}

class HealthDomainComponent {
  final String key;
  final String label;
  final double current;
  final double target;
  final String unit;
  final int progressPercent;

  const HealthDomainComponent({
    required this.key,
    required this.label,
    required this.current,
    required this.target,
    required this.unit,
    required this.progressPercent,
  });

  factory HealthDomainComponent.fromJson(dynamic value) {
    final json = _dashboardMap(value);
    return HealthDomainComponent(
      key: _dashboardString(json['key']),
      label: _dashboardString(json['label']),
      current: _dashboardDouble(json['current']),
      target: _dashboardDouble(json['target']),
      unit: _dashboardString(json['unit']),
      progressPercent: _dashboardInt(
        json['progress_percent'],
      ).clamp(0, 100).toInt(),
    );
  }
}

class HealthDomainEvaluation {
  final String domain;
  final int score;
  final String status;
  final int dataCoverage;
  final bool isApplicable;
  final bool isEssential;
  final double weight;
  final String targetSource;
  final List<HealthDomainComponent> components;

  const HealthDomainEvaluation({
    required this.domain,
    required this.score,
    required this.status,
    required this.dataCoverage,
    required this.isApplicable,
    required this.isEssential,
    required this.weight,
    required this.targetSource,
    required this.components,
  });

  factory HealthDomainEvaluation.fromJson(dynamic value) {
    final json = _dashboardMap(value);
    return HealthDomainEvaluation(
      domain: _dashboardString(json['domain']),
      score: _dashboardInt(json['score']).clamp(0, 100).toInt(),
      status: _dashboardString(json['status']),
      dataCoverage: _dashboardInt(json['data_coverage']).clamp(0, 100).toInt(),
      isApplicable: json['is_applicable'] == true,
      isEssential: json['is_essential'] == true,
      weight: _dashboardDouble(json['weight']),
      targetSource: _dashboardString(json['target_source']),
      components: _dashboardList(json['components'])
          .map(HealthDomainComponent.fromJson)
          .toList(growable: false),
    );
  }

  HealthDomainComponent? component(String key) {
    for (final component in components) {
      if (component.key == key) return component;
    }
    return null;
  }
}

class HealthFocusAction {
  final String kind;
  final String domain;
  final String title;
  final String subtitle;
  final String route;
  final int progressPercent;

  const HealthFocusAction({
    required this.kind,
    required this.domain,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.progressPercent,
  });

  const HealthFocusAction.empty()
    : kind = '',
      domain = '',
      title = '',
      subtitle = '',
      route = '',
      progressPercent = 0;

  factory HealthFocusAction.fromJson(dynamic value) {
    final json = _dashboardMap(value);
    if (json.isEmpty) return const HealthFocusAction.empty();
    return HealthFocusAction(
      kind: _dashboardString(json['kind']),
      domain: _dashboardString(json['domain']),
      title: _dashboardString(json['title']),
      subtitle: _dashboardString(json['subtitle']),
      route: _dashboardString(json['route']),
      progressPercent: _dashboardInt(
        json['progress_percent'],
      ).clamp(0, 100).toInt(),
    );
  }

  bool get hasContent => title.isNotEmpty || subtitle.isNotEmpty;
}

class XpSummary {
  final int totalPoints;
  final int dailyPoints;
  final int level;
  final String levelName;

  const XpSummary({
    required this.totalPoints,
    required this.dailyPoints,
    required this.level,
    required this.levelName,
  });

  const XpSummary.empty()
    : totalPoints = 0,
      dailyPoints = 0,
      level = 1,
      levelName = 'Beginner';

  factory XpSummary.fromJson(
    dynamic value, {
    int fallbackTotalPoints = 0,
    int fallbackDailyPoints = 0,
    int fallbackLevel = 1,
    String fallbackLevelName = 'Beginner',
  }) {
    final json = _dashboardMap(value);
    return XpSummary(
      totalPoints: _dashboardInt(json['total_points'] ?? fallbackTotalPoints),
      dailyPoints: _dashboardInt(json['daily_points'] ?? fallbackDailyPoints),
      level: _dashboardInt(json['level'] ?? fallbackLevel).clamp(1, 999).toInt(),
      levelName: _dashboardString(json['level_name']).isEmpty
          ? fallbackLevelName
          : _dashboardString(json['level_name']),
    );
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
  final int missionsCompleted;
  final int missionsTotal;
  final int currentStreak;
  final String levelName;
  final ChronicDashboardSummary chronicSummary;
  final DailyHealthSummary dailyHealth;
  final List<HealthDomainEvaluation> healthDomains;
  final HealthFocusAction healthFocus;
  final XpSummary xpSummary;

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
    this.missionsCompleted = 0,
    this.missionsTotal = 0,
    this.currentStreak = 0,
    this.levelName = 'Beginner',
    required this.chronicSummary,
    this.dailyHealth = const DailyHealthSummary.empty(),
    this.healthDomains = const [],
    this.healthFocus = const HealthFocusAction.empty(),
    this.xpSummary = const XpSummary.empty(),
  });

  factory DashboardData.empty() => const DashboardData(
    points: 0,
    level: 1,
    dailyPoints: 0,
    todaySteps: 0,
    waterMl: 0,
    sleepMinutes: 0,
    calories: 0,
    missionsCompleted: 0,
    missionsTotal: 0,
    currentStreak: 0,
    levelName: 'Beginner',
    chronicSummary: ChronicDashboardSummary.empty(),
    dailyHealth: DailyHealthSummary.empty(),
    healthDomains: [],
    healthFocus: HealthFocusAction.empty(),
    xpSummary: XpSummary.empty(),
  );

  bool get hasTrackerMetrics =>
      points != 0 ||
      todaySteps != 0 ||
      activityBurnedKcal != 0 ||
      activityMinutes != 0 ||
      waterMl != 0 ||
      sleepMinutes != 0 ||
      calories != 0 ||
      dailyHealth.hasData;

  HealthDomainEvaluation? domain(String name) {
    for (final domain in healthDomains) {
      if (domain.domain == name) return domain;
    }
    return null;
  }

  HealthDomainComponent? component(String domainName, String componentKey) {
    return domain(domainName)?.component(componentKey);
  }

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
      missionsCompleted: _dashboardInt(d['missions_completed']),
      missionsTotal: _dashboardInt(d['missions_total']),
      currentStreak: _dashboardInt(d['current_streak']),
      levelName: _dashboardString(d['level_name']).isEmpty
          ? 'Beginner'
          : _dashboardString(d['level_name']),
      chronicSummary: ChronicDashboardSummary.fromJson(d['chronic_conditions']),
      dailyHealth: DailyHealthSummary.fromJson(d['daily_health']),
      healthDomains: _dashboardList(d['domains'])
          .map(HealthDomainEvaluation.fromJson)
          .toList(growable: false),
      healthFocus: HealthFocusAction.fromJson(d['focus']),
      xpSummary: XpSummary.fromJson(
        d['xp'],
        fallbackTotalPoints: _dashboardInt(pointsRaw),
        fallbackDailyPoints: _dashboardInt(
          d['daily_points'] ??
              d['points_estimate'] ??
              historyEntry['points_estimate'],
        ),
        fallbackLevel: _dashboardInt(d['level'] ?? gamification['level']),
        fallbackLevelName: _dashboardString(d['level_name']).isEmpty
            ? 'Beginner'
            : _dashboardString(d['level_name']),
      ),
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
      missionsCompleted: _dashboardInt(d['missions_completed']),
      missionsTotal: _dashboardInt(d['missions_total']),
      currentStreak: _dashboardInt(d['current_streak']),
      levelName: _dashboardString(d['level_name']).isEmpty
          ? 'Beginner'
          : _dashboardString(d['level_name']),
      chronicSummary: ChronicDashboardSummary.fromJson(d['chronic_conditions']),
      dailyHealth: DailyHealthSummary.fromJson(d['daily_health']),
      healthDomains: _dashboardList(d['domains'])
          .map(HealthDomainEvaluation.fromJson)
          .toList(growable: false),
      healthFocus: HealthFocusAction.fromJson(d['focus']),
      xpSummary: XpSummary.fromJson(
        d['xp'],
        fallbackTotalPoints: _dashboardInt(d['points']),
        fallbackDailyPoints: _dashboardInt(d['daily_points']),
        fallbackLevel: _dashboardInt(d['level']),
        fallbackLevelName: _dashboardString(d['level_name']).isEmpty
            ? 'Beginner'
            : _dashboardString(d['level_name']),
      ),
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

List<dynamic> _dashboardList(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
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
