class NutritionSummary {
  final int targetCalories;
  final int consumedCalories;
  final int burnedCalories;
  final int remainingCalories;
  final int points;
  final double progressPercent;
  final String status;
  final String statusReason;
  final List<NutritionSummaryMetric> metrics;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double sugarsG;
  final double addedSugarsG;
  final double fiberG;
  final double sodiumMg;
  final double potassiumMg;
  final double calciumMg;
  final double ironMg;
  final double magnesiumMg;
  final double zincMg;
  final double phosphorusMg;
  final double vitaminAMcg;
  final double vitaminCMg;
  final double vitaminDMcg;
  final double vitaminEMg;
  final double vitaminKMcg;
  final double vitaminB1Mg;
  final double vitaminB2Mg;
  final double vitaminB3Mg;
  final double vitaminB6Mg;
  final double vitaminB12Mcg;
  final double folateMcg;
  final double caffeineMg;

  const NutritionSummary({
    required this.targetCalories,
    required this.consumedCalories,
    required this.burnedCalories,
    required this.remainingCalories,
    required this.points,
    this.progressPercent = 0,
    this.status = 'not_configured',
    this.statusReason = '',
    this.metrics = const <NutritionSummaryMetric>[],
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.sugarsG = 0,
    this.addedSugarsG = 0,
    this.fiberG = 0,
    this.sodiumMg = 0,
    this.potassiumMg = 0,
    this.calciumMg = 0,
    this.ironMg = 0,
    this.magnesiumMg = 0,
    this.zincMg = 0,
    this.phosphorusMg = 0,
    this.vitaminAMcg = 0,
    this.vitaminCMg = 0,
    this.vitaminDMcg = 0,
    this.vitaminEMg = 0,
    this.vitaminKMcg = 0,
    this.vitaminB1Mg = 0,
    this.vitaminB2Mg = 0,
    this.vitaminB3Mg = 0,
    this.vitaminB6Mg = 0,
    this.vitaminB12Mcg = 0,
    this.folateMcg = 0,
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
    sodiumMg: 0,
    potassiumMg: 0,
    calciumMg: 0,
    ironMg: 0,
    magnesiumMg: 0,
    zincMg: 0,
    phosphorusMg: 0,
    vitaminAMcg: 0,
    vitaminCMg: 0,
    vitaminDMcg: 0,
    vitaminEMg: 0,
    vitaminKMcg: 0,
    vitaminB1Mg: 0,
    vitaminB2Mg: 0,
    vitaminB3Mg: 0,
    vitaminB6Mg: 0,
    vitaminB12Mcg: 0,
    folateMcg: 0,
    caffeineMg: 0,
  );

  factory NutritionSummary.fromSummaryJson(Map<String, dynamic> json) {
    return NutritionSummary(
      targetCalories: _toInt(json['target_calories']),
      consumedCalories: _toInt(json['consumed_calories']),
      burnedCalories: _toInt(json['burned_calories']),
      remainingCalories: _toInt(json['remaining_calories']),
      points: _toInt(json['points']),
      progressPercent: _toDouble(json['progress_percent']),
      status: (json['status'] ?? 'not_configured').toString(),
      statusReason: (json['status_reason'] ?? '').toString(),
      metrics: _summaryMetrics(json['metrics']),
      proteinG: _toDouble(json['protein_g']),
      carbsG: _toDouble(json['carbs_g']),
      fatG: _toDouble(json['fat_g']),
      sugarsG: _toDouble(json['sugars_g']),
      addedSugarsG: _toDouble(json['added_sugars_g']),
      fiberG: _toDouble(json['fiber_g']),
      sodiumMg: _toDouble(json['sodium_mg']),
      potassiumMg: _toDouble(json['potassium_mg']),
      calciumMg: _toDouble(json['calcium_mg']),
      ironMg: _toDouble(json['iron_mg']),
      magnesiumMg: _toDouble(json['magnesium_mg']),
      zincMg: _toDouble(json['zinc_mg']),
      phosphorusMg: _toDouble(json['phosphorus_mg']),
      vitaminAMcg: _toDouble(json['vitamin_a_mcg']),
      vitaminCMg: _toDouble(json['vitamin_c_mg']),
      vitaminDMcg: _toDouble(json['vitamin_d_mcg']),
      vitaminEMg: _toDouble(json['vitamin_e_mg']),
      vitaminKMcg: _toDouble(json['vitamin_k_mcg']),
      vitaminB1Mg: _toDouble(json['vitamin_b1_mg']),
      vitaminB2Mg: _toDouble(json['vitamin_b2_mg']),
      vitaminB3Mg: _toDouble(json['vitamin_b3_mg']),
      vitaminB6Mg: _toDouble(json['vitamin_b6_mg']),
      vitaminB12Mcg: _toDouble(json['vitamin_b12_mcg']),
      folateMcg: _toDouble(json['folate_mcg']),
      caffeineMg: _toDouble(json['caffeine_mg']),
    );
  }

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
      progressPercent: toDouble(summary['progress_percent']),
      status: (summary['status'] ?? 'not_configured').toString(),
      statusReason: (summary['status_reason'] ?? '').toString(),
      metrics: _summaryMetrics(summary['metrics']),
      proteinG: toDouble(summary['protein_g']),
      carbsG: toDouble(summary['carbs_g']),
      fatG: toDouble(summary['fat_g']),
      sugarsG: toDouble(summary['sugars_g']),
      addedSugarsG: toDouble(summary['added_sugars_g']),
      fiberG: toDouble(summary['fiber_g']),
      sodiumMg: toDouble(summary['sodium_mg']),
      potassiumMg: toDouble(summary['potassium_mg']),
      calciumMg: toDouble(summary['calcium_mg']),
      ironMg: toDouble(summary['iron_mg']),
      magnesiumMg: toDouble(summary['magnesium_mg']),
      zincMg: toDouble(summary['zinc_mg']),
      phosphorusMg: toDouble(summary['phosphorus_mg']),
      vitaminAMcg: toDouble(summary['vitamin_a_mcg']),
      vitaminCMg: toDouble(summary['vitamin_c_mg']),
      vitaminDMcg: toDouble(summary['vitamin_d_mcg']),
      vitaminEMg: toDouble(summary['vitamin_e_mg']),
      vitaminKMcg: toDouble(summary['vitamin_k_mcg']),
      vitaminB1Mg: toDouble(summary['vitamin_b1_mg']),
      vitaminB2Mg: toDouble(summary['vitamin_b2_mg']),
      vitaminB3Mg: toDouble(summary['vitamin_b3_mg']),
      vitaminB6Mg: toDouble(summary['vitamin_b6_mg']),
      vitaminB12Mcg: toDouble(summary['vitamin_b12_mcg']),
      folateMcg: toDouble(summary['folate_mcg']),
      caffeineMg: toDouble(summary['caffeine_mg']),
    );
  }
}

class NutritionSummaryMetric {
  const NutritionSummaryMetric({
    required this.code,
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.progressPercent,
    required this.status,
    required this.reason,
    required this.targetKind,
  });

  final String code;
  final String label;
  final double value;
  final double target;
  final String unit;
  final double progressPercent;
  final String status;
  final String reason;
  final String targetKind;

  factory NutritionSummaryMetric.fromJson(Map<String, dynamic> json) =>
      NutritionSummaryMetric(
        code: (json['code'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        value: _toDouble(json['value']),
        target: _toDouble(json['target']),
        unit: (json['unit'] ?? '').toString(),
        progressPercent: _toDouble(json['progress_percent']),
        status: (json['status'] ?? 'not_configured').toString(),
        reason: (json['reason'] ?? '').toString(),
        targetKind: (json['target_kind'] ?? '').toString(),
      );
}

List<NutritionSummaryMetric> _summaryMetrics(dynamic value) {
  if (value is! List) return const <NutritionSummaryMetric>[];
  return value
      .whereType<Map>()
      .map(
        (item) =>
            NutritionSummaryMetric.fromJson(Map<String, dynamic>.from(item)),
      )
      .toList(growable: false);
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v.toString()) ?? 0;
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
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
  final double calciumMg;
  final double ironMg;
  final double magnesiumMg;
  final double zincMg;
  final double phosphorusMg;
  final double vitaminAMcg;
  final double vitaminCMg;
  final double vitaminDMcg;
  final double vitaminEMg;
  final double vitaminKMcg;
  final double vitaminB1Mg;
  final double vitaminB2Mg;
  final double vitaminB3Mg;
  final double vitaminB6Mg;
  final double vitaminB12Mcg;
  final double folateMcg;
  final double monounsaturatedFatG;
  final double polyunsaturatedFatG;
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
    this.calciumMg = 0,
    this.ironMg = 0,
    this.magnesiumMg = 0,
    this.zincMg = 0,
    this.phosphorusMg = 0,
    this.vitaminAMcg = 0,
    this.vitaminCMg = 0,
    this.vitaminDMcg = 0,
    this.vitaminEMg = 0,
    this.vitaminKMcg = 0,
    this.vitaminB1Mg = 0,
    this.vitaminB2Mg = 0,
    this.vitaminB3Mg = 0,
    this.vitaminB6Mg = 0,
    this.vitaminB12Mcg = 0,
    this.folateMcg = 0,
    this.monounsaturatedFatG = 0,
    this.polyunsaturatedFatG = 0,
    this.caffeineMg = 0,
  });
}
