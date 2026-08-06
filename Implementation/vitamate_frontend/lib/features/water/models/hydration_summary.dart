class HydrationSummary {
  const HydrationSummary({
    required this.date,
    required this.consumedVolumeMl,
    required this.hydrationContributionMl,
    required this.waterContributionMl,
    required this.otherDrinksContributionMl,
    required this.baseTargetMl,
    required this.adjustedTargetMl,
    required this.activeTargetMl,
    required this.remainingMl,
    required this.progressPercent,
    required this.goalCompleted,
    required this.lastDrinkAt,
    required this.pointsEarnedToday,
    required this.adjustmentReasons,
  });

  final DateTime? date;
  final int consumedVolumeMl;
  final int hydrationContributionMl;
  final int waterContributionMl;
  final int otherDrinksContributionMl;
  final int baseTargetMl;
  final int adjustedTargetMl;
  final int activeTargetMl;
  final int remainingMl;
  final int progressPercent;
  final bool goalCompleted;
  final DateTime? lastDrinkAt;
  final int pointsEarnedToday;
  final List<String> adjustmentReasons;

  int get targetMl => activeTargetMl;
  int get consumedMl => hydrationContributionMl;
  double get progressRatio => (progressPercent / 100).clamp(0.0, 1.0);

  factory HydrationSummary.empty() {
    return const HydrationSummary(
      date: null,
      consumedVolumeMl: 0,
      hydrationContributionMl: 0,
      waterContributionMl: 0,
      otherDrinksContributionMl: 0,
      baseTargetMl: 0,
      adjustedTargetMl: 0,
      activeTargetMl: 0,
      remainingMl: 0,
      progressPercent: 0,
      goalCompleted: false,
      lastDrinkAt: null,
      pointsEarnedToday: 0,
      adjustmentReasons: <String>[],
    );
  }

  factory HydrationSummary.fromJson(Map<String, dynamic> json) {
    final activeTarget = _asInt(
      json['active_target_ml'] ?? json['target_ml'] ?? json['base_target_ml'],
    );
    final contribution = _asInt(
      json['hydration_contribution_ml'] ?? json['consumed_ml'],
    );
    return HydrationSummary(
      date: _parseDate(json['date']),
      consumedVolumeMl: _asInt(json['consumed_volume_ml'] ?? contribution),
      hydrationContributionMl: contribution,
      waterContributionMl: _asInt(json['water_contribution_ml']),
      otherDrinksContributionMl: _asInt(json['other_drinks_contribution_ml']),
      baseTargetMl: _asInt(json['base_target_ml'] ?? activeTarget),
      adjustedTargetMl: _asInt(json['adjusted_target_ml']),
      activeTargetMl: activeTarget,
      remainingMl: _asInt(
        json['remaining_ml'] ??
            (activeTarget - contribution).clamp(0, activeTarget),
      ),
      progressPercent: _asInt(json['progress_percent']).clamp(0, 100),
      goalCompleted: json['goal_completed'] == true,
      lastDrinkAt: _parseDateTime(json['last_drink_at']),
      pointsEarnedToday: _asInt(json['points_earned_today']),
      adjustmentReasons: ((json['adjustment_reasons'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _parseDate(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

DateTime? _parseDateTime(dynamic value) {
  final parsed = _parseDate(value);
  return parsed?.toLocal();
}
