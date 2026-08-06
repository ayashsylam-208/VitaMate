import 'day_stat.dart';

class ProgressOverview {
  const ProgressOverview({
    required this.overallScore,
    required this.points,
    required this.level,
    required this.weeklyConsistency,
    required this.trackerCards,
    required this.timeline,
    required this.insight,
  });

  final int overallScore;
  final int points;
  final int level;
  final ProgressWeeklyConsistency weeklyConsistency;
  final List<ProgressTrackerCard> trackerCards;
  final List<ProgressTimelineDay> timeline;
  final ProgressInsight insight;

  factory ProgressOverview.empty() => const ProgressOverview(
    overallScore: 0,
    points: 0,
    level: 1,
    weeklyConsistency: ProgressWeeklyConsistency.empty(),
    trackerCards: <ProgressTrackerCard>[],
    timeline: <ProgressTimelineDay>[],
    insight: ProgressInsight(title: 'Insight', message: ''),
  );

  factory ProgressOverview.fromJson(
    Map<String, dynamic> json, {
    List<DayStat> fallbackHistory = const <DayStat>[],
  }) {
    final cards = _list(json['tracker_cards'])
        .map((item) => ProgressTrackerCard.fromJson(_map(item)))
        .toList(growable: false);
    final timeline = _list(json['timeline_7d'])
        .map((item) => ProgressTimelineDay.fromJson(_map(item)))
        .toList(growable: false);
    final fallbackCards = cards.isEmpty ? _cardsFromLegacy(json) : cards;
    final fallbackTimeline = timeline.isEmpty
        ? fallbackHistory
              .map(
                (day) => ProgressTimelineDay(
                  date: day.date,
                  score: _dayScore(day),
                  points: day.pointsEstimate,
                  complete: _dayScore(day) >= 60,
                ),
              )
              .toList(growable: false)
        : timeline;
    final score = _toInt(json['overall_score']);
    return ProgressOverview(
      overallScore: score > 0 ? score : _weightedScore(fallbackCards),
      points: _toInt(json['points'] ?? _map(json['gamification'])['points']),
      level: _toInt(
        json['level'] ?? _map(json['gamification'])['level'],
      ).clamp(1, 999).toInt(),
      weeklyConsistency: ProgressWeeklyConsistency.fromJson(
        _map(json['weekly_consistency']),
        fallbackTimeline,
      ),
      trackerCards: fallbackCards,
      timeline: fallbackTimeline,
      insight: ProgressInsight.fromJson(_map(json['insight'])),
    );
  }
}

class ProgressTrackerCard {
  const ProgressTrackerCard({
    required this.code,
    required this.title,
    required this.icon,
    required this.percent,
    required this.current,
    required this.target,
    required this.unit,
    required this.active,
    required this.status,
    required this.summary,
    required this.detailEndpoint,
  });

  final String code;
  final String title;
  final String icon;
  final int percent;
  final double current;
  final double? target;
  final String unit;
  final bool active;
  final String status;
  final String summary;
  final String detailEndpoint;

  factory ProgressTrackerCard.fromJson(Map<String, dynamic> json) {
    return ProgressTrackerCard(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      percent: _toInt(json['percent']).clamp(0, 100).toInt(),
      current: _toDouble(json['current']),
      target: json.containsKey('target') && json['target'] != null
          ? _toDouble(json['target'])
          : null,
      unit: json['unit']?.toString() ?? '',
      active: json['active'] == true,
      status: json['status']?.toString() ?? 'Needs attention',
      summary: json['summary']?.toString() ?? '',
      detailEndpoint: json['detail_endpoint']?.toString() ?? '',
    );
  }
}

class ProgressWeeklyConsistency {
  const ProgressWeeklyConsistency({
    required this.daysMet,
    required this.totalDays,
    required this.percent,
  });

  const ProgressWeeklyConsistency.empty()
    : daysMet = 0,
      totalDays = 7,
      percent = 0;

  final int daysMet;
  final int totalDays;
  final int percent;

  factory ProgressWeeklyConsistency.fromJson(
    Map<String, dynamic> json,
    List<ProgressTimelineDay> fallbackTimeline,
  ) {
    if (json.isEmpty) {
      final met = fallbackTimeline.where((day) => day.complete).length;
      final total = fallbackTimeline.isEmpty ? 7 : fallbackTimeline.length;
      return ProgressWeeklyConsistency(
        daysMet: met,
        totalDays: total,
        percent: total == 0 ? 0 : ((met / total) * 100).round(),
      );
    }
    return ProgressWeeklyConsistency(
      daysMet: _toInt(json['days_met']),
      totalDays: _toInt(json['total_days']).clamp(1, 30).toInt(),
      percent: _toInt(json['percent']).clamp(0, 100).toInt(),
    );
  }
}

class ProgressTimelineDay {
  const ProgressTimelineDay({
    required this.date,
    required this.score,
    required this.points,
    required this.complete,
  });

  final DateTime date;
  final int score;
  final int points;
  final bool complete;

  factory ProgressTimelineDay.fromJson(Map<String, dynamic> json) {
    return ProgressTimelineDay(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      score: _toInt(json['score']).clamp(0, 100).toInt(),
      points: _toInt(json['points']),
      complete: json['complete'] == true,
    );
  }
}

class ProgressInsight {
  const ProgressInsight({required this.title, required this.message});

  final String title;
  final String message;

  factory ProgressInsight.fromJson(Map<String, dynamic> json) {
    return ProgressInsight(
      title: json['title']?.toString() ?? 'Insight',
      message:
          json['message']?.toString() ??
          'Start with one tracker update and the rest will follow.',
    );
  }
}

class ProgressDetailPayload {
  const ProgressDetailPayload({
    required this.tracker,
    required this.title,
    required this.score,
    required this.status,
    required this.rangeDays,
    required this.summaryCards,
    required this.metrics,
    required this.trend,
    required this.sections,
    required this.insight,
  });

  final String tracker;
  final String title;
  final int score;
  final String status;
  final int rangeDays;
  final List<ProgressSummaryCard> summaryCards;
  final List<ProgressMetric> metrics;
  final List<ProgressTrendPoint> trend;
  final List<ProgressDetailSection> sections;
  final String insight;

  factory ProgressDetailPayload.empty(String tracker) => ProgressDetailPayload(
    tracker: tracker,
    title: tracker,
    score: 0,
    status: 'Needs attention',
    rangeDays: 7,
    summaryCards: const <ProgressSummaryCard>[],
    metrics: const <ProgressMetric>[],
    trend: const <ProgressTrendPoint>[],
    sections: const <ProgressDetailSection>[],
    insight: '',
  );

  factory ProgressDetailPayload.fromJson(Map<String, dynamic> json) {
    return ProgressDetailPayload(
      tracker: json['tracker']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      score: _toInt(json['score']).clamp(0, 100).toInt(),
      status: json['status']?.toString() ?? 'Needs attention',
      rangeDays: _toInt(json['range_days']).clamp(7, 30).toInt(),
      summaryCards: _list(json['summary_cards'])
          .map((item) => ProgressSummaryCard.fromJson(_map(item)))
          .toList(growable: false),
      metrics: _list(json['metrics'])
          .map((item) => ProgressMetric.fromJson(_map(item)))
          .toList(growable: false),
      trend: _list(json['trend'])
          .map((item) => ProgressTrendPoint.fromJson(_map(item)))
          .toList(growable: false),
      sections: _list(json['sections'])
          .map((item) => ProgressDetailSection.fromJson(_map(item)))
          .toList(growable: false),
      insight: json['insight']?.toString() ?? '',
    );
  }
}

class ProgressSummaryCard {
  const ProgressSummaryCard({
    required this.label,
    required this.current,
    required this.target,
    required this.unit,
    required this.percent,
  });

  final String label;
  final double current;
  final double? target;
  final String unit;
  final int percent;

  factory ProgressSummaryCard.fromJson(Map<String, dynamic> json) {
    return ProgressSummaryCard(
      label: json['label']?.toString() ?? '',
      current: _toDouble(json['current']),
      target: json['target'] == null ? null : _toDouble(json['target']),
      unit: json['unit']?.toString() ?? '',
      percent: _toInt(json['percent']).clamp(0, 100).toInt(),
    );
  }
}

class ProgressMetric extends ProgressSummaryCard {
  const ProgressMetric({
    required super.label,
    required super.current,
    required super.target,
    required super.unit,
    required super.percent,
    required this.limit,
    required this.status,
  });

  final bool limit;
  final String status;

  factory ProgressMetric.fromJson(Map<String, dynamic> json) {
    return ProgressMetric(
      label: json['label']?.toString() ?? '',
      current: _toDouble(json['current']),
      target: json['target'] == null ? null : _toDouble(json['target']),
      unit: json['unit']?.toString() ?? '',
      percent: _toInt(json['percent']).clamp(0, 100).toInt(),
      limit: json['limit'] == true,
      status: json['status']?.toString() ?? 'Needs attention',
    );
  }
}

class ProgressTrendPoint {
  const ProgressTrendPoint({
    required this.date,
    required this.value,
    required this.target,
    required this.percent,
    required this.points,
  });

  final DateTime date;
  final double value;
  final double? target;
  final int percent;
  final int points;

  factory ProgressTrendPoint.fromJson(Map<String, dynamic> json) {
    return ProgressTrendPoint(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      value: _toDouble(json['value']),
      target: json['target'] == null ? null : _toDouble(json['target']),
      percent: _toInt(json['percent']).clamp(0, 100).toInt(),
      points: _toInt(json['points']),
    );
  }
}

class ProgressDetailSection {
  const ProgressDetailSection({required this.title, required this.items});

  final String title;
  final List<Map<String, dynamic>> items;

  factory ProgressDetailSection.fromJson(Map<String, dynamic> json) {
    return ProgressDetailSection(
      title: json['title']?.toString() ?? '',
      items: _list(
        json['items'],
      ).map((item) => _map(item)).toList(growable: false),
    );
  }
}

List<ProgressTrackerCard> _cardsFromLegacy(Map<String, dynamic> json) {
  final summary = _map(json['summary']);
  final hydration = _map(json['hydration']);
  final sleep = _map(json['sleep']);
  final chronic = _map(json['chronic_conditions']);
  return <ProgressTrackerCard>[
    _legacyCard(
      'nutrition',
      'Nutrition',
      _toDouble(summary['calories_consumed']),
      _toDouble(summary['calories_target']),
      'kcal',
      'Meal quality and nutrient balance',
    ),
    _legacyCard(
      'hydration',
      'Water',
      _toDouble(hydration['current']),
      _toDouble(hydration['target']),
      'L',
      'Hydration and beverage consistency',
    ),
    _legacyCard(
      'activity',
      'Activity / Movement',
      _toDouble(summary['calories_burned']),
      _toDouble(summary['burn_target']),
      'kcal',
      'Calories burned, active minutes, and steps',
    ),
    _legacyCard(
      'sleep',
      'Sleep',
      _toDouble(sleep['logged_hours_today']),
      _toDouble(sleep['recommended_sleep_hours']),
      'h',
      'Duration and consistency',
    ),
    _legacyCard(
      'chronic',
      'Chronic conditions',
      _toDouble(chronic['adherence_percent']),
      100,
      '%',
      'Care plans and guardrails',
    ),
  ];
}

ProgressTrackerCard _legacyCard(
  String code,
  String title,
  double current,
  double target,
  String unit,
  String summary,
) {
  final percent = target <= 0 ? 0 : ((current / target) * 100).round();
  return ProgressTrackerCard(
    code: code,
    title: title,
    icon: code,
    percent: percent.clamp(0, 100).toInt(),
    current: current,
    target: target,
    unit: unit,
    active: target > 0,
    status: percent >= 85
        ? 'Great'
        : percent >= 70
        ? 'Good'
        : percent >= 45
        ? 'Improving'
        : 'Needs attention',
    summary: summary,
    detailEndpoint: '/api/progress/details/$code/',
  );
}

int _weightedScore(List<ProgressTrackerCard> cards) {
  final active = cards.where((card) => card.active).toList(growable: false);
  if (active.isEmpty) return 0;
  return (active.fold<double>(0, (sum, card) => sum + card.percent) /
          active.length)
      .round();
}

int _dayScore(DayStat day) {
  final values = <double>[
    day.waterProgress,
    day.stepsProgress,
    day.burnProgress,
    day.sleepProgress,
    day.caloriesProgress.clamp(0.0, 1.0).toDouble(),
  ].where((value) => value > 0).toList(growable: false);
  if (values.isEmpty) return 0;
  return ((values.reduce((a, b) => a + b) / values.length) * 100).round();
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
