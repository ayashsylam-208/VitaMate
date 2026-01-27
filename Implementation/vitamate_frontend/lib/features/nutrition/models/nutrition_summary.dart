class NutritionSummary {
  final int targetCalories;
  final int consumedCalories;
  final int burnedCalories;
  final int remainingCalories;
  final int points;

  const NutritionSummary({
    required this.targetCalories,
    required this.consumedCalories,
    required this.burnedCalories,
    required this.remainingCalories,
    required this.points,
  });

  factory NutritionSummary.empty() => const NutritionSummary(
        targetCalories: 0,
        consumedCalories: 0,
        burnedCalories: 0,
        remainingCalories: 0,
        points: 0,
      );

  factory NutritionSummary.fromDashboard(Map<String, dynamic> d) {
    Map<String, dynamic> asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.cast<String, dynamic>();
      return <String, dynamic>{};
    }

    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse(v.toString()) ?? 0;
    }

    final summary = asMap(d['summary']);
    final gamification = asMap(d['gamification']);

    return NutritionSummary(
      targetCalories: toInt(summary['calories_target']),
      consumedCalories: toInt(summary['calories_consumed']),
      burnedCalories: toInt(summary['calories_burned']),
      remainingCalories: toInt(summary['calories_remaining']),
      points: toInt(d['points'] ?? gamification['points']),
    );
  }
}

