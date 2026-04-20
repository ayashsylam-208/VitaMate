class NutritionSummary {
  final int targetCalories;
  final int consumedCalories;
  final int burnedCalories;
  final int remainingCalories;
  final int points;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double sugarsG;
  final double addedSugarsG;
  final double fiberG;
  final double caffeineMg;

  const NutritionSummary({
    required this.targetCalories,
    required this.consumedCalories,
    required this.burnedCalories,
    required this.remainingCalories,
    required this.points,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.sugarsG = 0,
    this.addedSugarsG = 0,
    this.fiberG = 0,
    this.caffeineMg = 0,
  });

  factory NutritionSummary.empty() => const NutritionSummary(
    targetCalories: 0,
    consumedCalories: 0,
    burnedCalories: 0,
    remainingCalories: 0,
    points: 0,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    sugarsG: 0,
    addedSugarsG: 0,
    fiberG: 0,
    caffeineMg: 0,
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

    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final summary = asMap(d['summary']);
    final gamification = asMap(d['gamification']);

    return NutritionSummary(
      targetCalories: toInt(summary['calories_target']),
      consumedCalories: toInt(summary['calories_consumed']),
      burnedCalories: toInt(summary['calories_burned']),
      remainingCalories: toInt(summary['calories_remaining']),
      points: toInt(d['points'] ?? gamification['points']),
      proteinG: toDouble(summary['protein_g']),
      carbsG: toDouble(summary['carbs_g']),
      fatG: toDouble(summary['fat_g']),
      sugarsG: toDouble(summary['sugars_g']),
      addedSugarsG: toDouble(summary['added_sugars_g']),
      fiberG: toDouble(summary['fiber_g']),
      caffeineMg: toDouble(summary['caffeine_mg']),
    );
  }
}

class NutritionDetailBreakdown {
  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double sugarsG;
  final double addedSugarsG;
  final double fiberG;
  final double sodiumMg;
  final double saturatedFatG;
  final double transFatG;
  final double cholesterolMg;
  final double potassiumMg;
  final double caffeineMg;

  const NutritionDetailBreakdown({
    this.caloriesKcal = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.sugarsG = 0,
    this.addedSugarsG = 0,
    this.fiberG = 0,
    this.sodiumMg = 0,
    this.saturatedFatG = 0,
    this.transFatG = 0,
    this.cholesterolMg = 0,
    this.potassiumMg = 0,
    this.caffeineMg = 0,
  });
}
