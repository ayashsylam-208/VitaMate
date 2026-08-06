import '../../../shared/models/api_result.dart';

class MotivationOverview {
  const MotivationOverview({
    required this.date,
    required this.totalPoints,
    required this.dailyPoints,
    required this.weeklyPoints,
    required this.level,
    required this.levelName,
    required this.nextLevelThreshold,
    required this.pointsToNextLevel,
    required this.missionsCompleted,
    required this.missionsTotal,
    required this.currentStreak,
    required this.longestStreak,
    required this.badgesEarned,
    required this.badgesInProgress,
    required this.insight,
  });

  final String date;
  final int totalPoints;
  final int dailyPoints;
  final int weeklyPoints;
  final int level;
  final String levelName;
  final int nextLevelThreshold;
  final int pointsToNextLevel;
  final int missionsCompleted;
  final int missionsTotal;
  final int currentStreak;
  final int longestStreak;
  final int badgesEarned;
  final int badgesInProgress;
  final String insight;

  factory MotivationOverview.empty() => const MotivationOverview(
    date: '',
    totalPoints: 0,
    dailyPoints: 0,
    weeklyPoints: 0,
    level: 1,
    levelName: 'Beginner',
    nextLevelThreshold: 1000,
    pointsToNextLevel: 1000,
    missionsCompleted: 0,
    missionsTotal: 0,
    currentStreak: 0,
    longestStreak: 0,
    badgesEarned: 0,
    badgesInProgress: 0,
    insight: '',
  );

  factory MotivationOverview.fromJson(Map<String, dynamic> json) {
    return MotivationOverview(
      date: (json['date'] ?? '').toString(),
      totalPoints: _int(json['total_points']),
      dailyPoints: _int(json['daily_points']),
      weeklyPoints: _int(json['weekly_points']),
      level: _int(json['level']).clamp(1, 999).toInt(),
      levelName: (json['level_name'] ?? 'Beginner').toString(),
      nextLevelThreshold: _int(json['next_level_threshold']),
      pointsToNextLevel: _int(json['points_to_next_level']),
      missionsCompleted: _int(json['missions_completed']),
      missionsTotal: _int(json['missions_total']),
      currentStreak: _int(json['current_streak']),
      longestStreak: _int(json['longest_streak']),
      badgesEarned: _int(json['badges_earned']),
      badgesInProgress: _int(json['badges_in_progress']),
      insight: (json['insight'] ?? '').toString(),
    );
  }

  bool get hasContent =>
      totalPoints > 0 ||
      dailyPoints > 0 ||
      missionsCompleted > 0 ||
      missionsTotal > 0 ||
      currentStreak > 0;
}

class DailyMission {
  const DailyMission({
    required this.id,
    required this.missionType,
    required this.title,
    required this.description,
    required this.status,
    required this.targetValue,
    required this.currentValue,
    required this.pointsReward,
    required this.reason,
  });

  final int id;
  final String missionType;
  final String title;
  final String description;
  final String status;
  final double targetValue;
  final double currentValue;
  final int pointsReward;
  final String reason;

  factory DailyMission.fromJson(Map<String, dynamic> json) {
    return DailyMission(
      id: _int(json['id']),
      missionType: (json['mission_type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      targetValue: _double(json['target_value']),
      currentValue: _double(json['current_value']),
      pointsReward: _int(json['points_reward']),
      reason: (json['reason'] ?? '').toString(),
    );
  }

  int get progressPercent {
    if (targetValue <= 0) {
      return status == 'completed' ? 100 : 0;
    }
    return ((_double(currentValue) / _double(targetValue)) * 100)
        .clamp(0, 100)
        .round();
  }
}

class PointTrendDay {
  const PointTrendDay({required this.date, required this.points});

  final DateTime date;
  final int points;

  factory PointTrendDay.fromJson(Map<String, dynamic> json) {
    return PointTrendDay(
      date:
          DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      points: _int(json['points']),
    );
  }
}

class PointTransactionItem {
  const PointTransactionItem({
    required this.eventDate,
    required this.points,
    required this.ruleCode,
    required this.sourceType,
    required this.reason,
  });

  final DateTime eventDate;
  final int points;
  final String ruleCode;
  final String sourceType;
  final String reason;

  factory PointTransactionItem.fromJson(Map<String, dynamic> json) {
    return PointTransactionItem(
      eventDate:
          DateTime.tryParse((json['event_date'] ?? '').toString()) ??
          DateTime.now(),
      points: _int(json['points']),
      ruleCode: (json['rule_code'] ?? '').toString(),
      sourceType: (json['source_type'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
    );
  }
}

class BadgeProgress {
  const BadgeProgress({
    required this.code,
    required this.name,
    required this.description,
    required this.requiredValue,
    required this.progressValue,
    required this.progressPercent,
    required this.status,
  });

  final String code;
  final String name;
  final String description;
  final int requiredValue;
  final int progressValue;
  final int progressPercent;
  final String status;

  factory BadgeProgress.fromJson(Map<String, dynamic> json) {
    return BadgeProgress(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      requiredValue: _int(json['required_value']),
      progressValue: _int(json['progress_value']),
      progressPercent: _int(json['progress_percent']).clamp(0, 100).toInt(),
      status: (json['status'] ?? 'in_progress').toString(),
    );
  }

  bool get earned => status == 'earned';
}

class MotivationPointsPayload {
  const MotivationPointsPayload({
    required this.rangeDays,
    required this.days,
    required this.transactions,
    required this.totalInRange,
  });

  final int rangeDays;
  final List<PointTrendDay> days;
  final List<PointTransactionItem> transactions;
  final int totalInRange;

  factory MotivationPointsPayload.empty() => const MotivationPointsPayload(
    rangeDays: 7,
    days: <PointTrendDay>[],
    transactions: <PointTransactionItem>[],
    totalInRange: 0,
  );

  factory MotivationPointsPayload.fromJson(Map<String, dynamic> json) {
    return MotivationPointsPayload(
      rangeDays: _int(json['range_days']).clamp(7, 30).toInt(),
      days: asMapList(
        json['days'],
      ).map(PointTrendDay.fromJson).toList(growable: false),
      transactions: asMapList(
        json['transactions'],
      ).map(PointTransactionItem.fromJson).toList(growable: false),
      totalInRange: _int(json['total_in_range']),
    );
  }
}

class MotivationFocus {
  const MotivationFocus({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.progressPercent,
    required this.rewardPoints,
    required this.route,
  });

  final String kind;
  final String title;
  final String subtitle;
  final int progressPercent;
  final int rewardPoints;
  final String route;

  factory MotivationFocus.empty() => const MotivationFocus(
    kind: '',
    title: '',
    subtitle: '',
    progressPercent: 0,
    rewardPoints: 0,
    route: '',
  );

  factory MotivationFocus.fromJson(Map<String, dynamic> json) {
    return MotivationFocus(
      kind: (json['kind'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      progressPercent: _int(json['progress_percent']).clamp(0, 100).toInt(),
      rewardPoints: _int(json['reward_points']),
      route: (json['route'] ?? '').toString(),
    );
  }

  bool get hasContent => title.isNotEmpty;
}

class MotivationCelebration {
  const MotivationCelebration({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.pointsDelta,
    required this.animation,
    required this.route,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String subtitle;
  final int pointsDelta;
  final String animation;
  final String route;
  final DateTime? createdAt;

  factory MotivationCelebration.fromJson(Map<String, dynamic> json) {
    return MotivationCelebration(
      id: _int(json['id']),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      pointsDelta: _int(json['points_delta']),
      animation: (json['animation'] ?? '').toString(),
      route: (json['route'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}

class MotivationFeed {
  const MotivationFeed({
    required this.summary,
    required this.focus,
    required this.celebrations,
    required this.updatedAt,
  });

  final MotivationOverview summary;
  final MotivationFocus focus;
  final List<MotivationCelebration> celebrations;
  final DateTime? updatedAt;

  factory MotivationFeed.empty() => MotivationFeed(
    summary: MotivationOverview.empty(),
    focus: MotivationFocus.empty(),
    celebrations: const <MotivationCelebration>[],
    updatedAt: null,
  );

  factory MotivationFeed.fromJson(Map<String, dynamic> json) {
    return MotivationFeed(
      summary: MotivationOverview.fromJson(asMap(json['summary'])),
      focus: MotivationFocus.fromJson(asMap(json['focus'])),
      celebrations: asMapList(
        json['celebrations'],
      ).map(MotivationCelebration.fromJson).toList(growable: false),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
