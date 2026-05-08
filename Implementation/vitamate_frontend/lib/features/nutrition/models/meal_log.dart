class MealLog {
  final int id;
  final int foodId;
  final String foodName;
  final String mealType;
  final double quantityGrams;
  final double quantity;
  final String unit;
  final double millilitersConsumed;
  final double servingsConsumed;
  final int? servingOptionId;
  final String servingOptionName;
  final String servingLabelSnapshot;
  final DateTime? consumedAt;
  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double sugarsG;
  final double fiberG;
  final double sodiumMg;
  final double saturatedFatG;
  final double transFatG;
  final double cholesterolMg;
  final double potassiumMg;
  final double addedSugarsG;
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

  MealLog({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.mealType,
    required this.quantityGrams,
    required this.quantity,
    required this.unit,
    this.millilitersConsumed = 0,
    this.servingsConsumed = 0,
    this.servingOptionId,
    this.servingOptionName = '',
    this.servingLabelSnapshot = '',
    this.consumedAt,
    this.caloriesKcal = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.sugarsG = 0,
    this.fiberG = 0,
    this.sodiumMg = 0,
    this.saturatedFatG = 0,
    this.transFatG = 0,
    this.cholesterolMg = 0,
    this.potassiumMg = 0,
    this.addedSugarsG = 0,
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

  bool get isDrink => mealType == 'drink';

  String get mealTypeLabel {
    switch (mealType) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      case 'dessert':
        return 'Dessert';
      default:
        return 'Drink';
    }
  }

  String get amountLabel {
    if (millilitersConsumed > 0) {
      return '${_formatNumber(millilitersConsumed)} ml';
    }
    if (servingsConsumed > 0) {
      final label = servingLabelSnapshot.trim().isNotEmpty
          ? servingLabelSnapshot.trim().toLowerCase()
          : servingOptionName.trim().isNotEmpty
          ? servingOptionName.trim().toLowerCase()
          : 'serving';
      return '${_formatNumber(servingsConsumed)} $label';
    }
    return '${_formatNumber(quantityGrams)} g';
  }

  factory MealLog.fromJson(Map<String, dynamic> json) {
    return MealLog(
      id: (json['id'] as num).toInt(),
      foodId: _toInt(json['food'] ?? json['food_item']),
      foodName: (json['food_name'] ?? '').toString(),
      mealType: (json['meal_type'] ?? '').toString(),
      quantityGrams: _toDouble(json['quantity_grams']),
      quantity: _toDouble(json['quantity']),
      unit: (json['unit'] ?? '').toString(),
      millilitersConsumed: _toDouble(json['milliliters_consumed']),
      servingsConsumed: _toDouble(json['servings_consumed']),
      servingOptionId: _nullableInt(json['serving_option']),
      servingOptionName: (json['serving_option_name'] ?? '').toString(),
      servingLabelSnapshot: (json['serving_label_snapshot'] ?? '').toString(),
      consumedAt: _parseDateTime(json['consumed_at']),
      caloriesKcal: _toDouble(
        json['snapshot_calories_kcal'] ?? json['total_calories'],
      ),
      proteinG: _toDouble(json['snapshot_protein_g']),
      carbsG: _toDouble(json['snapshot_carbohydrates_g']),
      fatG: _toDouble(json['snapshot_fat_g']),
      sugarsG: _toDouble(json['snapshot_sugars_g']),
      fiberG: _toDouble(json['snapshot_fiber_g']),
      sodiumMg: _toDouble(json['snapshot_sodium_mg']),
      saturatedFatG: _toDouble(json['snapshot_saturated_fat_g']),
      transFatG: _toDouble(json['snapshot_trans_fat_g']),
      cholesterolMg: _toDouble(json['snapshot_cholesterol_mg']),
      potassiumMg: _toDouble(json['snapshot_potassium_mg']),
      addedSugarsG: _toDouble(json['snapshot_added_sugars_g']),
      calciumMg: _toDouble(json['snapshot_calcium_mg']),
      ironMg: _toDouble(json['snapshot_iron_mg']),
      magnesiumMg: _toDouble(json['snapshot_magnesium_mg']),
      zincMg: _toDouble(json['snapshot_zinc_mg']),
      phosphorusMg: _toDouble(json['snapshot_phosphorus_mg']),
      vitaminAMcg: _toDouble(json['snapshot_vitamin_a_mcg']),
      vitaminCMg: _toDouble(json['snapshot_vitamin_c_mg']),
      vitaminDMcg: _toDouble(json['snapshot_vitamin_d_mcg']),
      vitaminEMg: _toDouble(json['snapshot_vitamin_e_mg']),
      vitaminKMcg: _toDouble(json['snapshot_vitamin_k_mcg']),
      vitaminB1Mg: _toDouble(json['snapshot_vitamin_b1_mg']),
      vitaminB2Mg: _toDouble(json['snapshot_vitamin_b2_mg']),
      vitaminB3Mg: _toDouble(json['snapshot_vitamin_b3_mg']),
      vitaminB6Mg: _toDouble(json['snapshot_vitamin_b6_mg']),
      vitaminB12Mcg: _toDouble(json['snapshot_vitamin_b12_mcg']),
      folateMcg: _toDouble(json['snapshot_folate_mcg']),
      monounsaturatedFatG: _toDouble(json['snapshot_monounsaturated_fat_g']),
      polyunsaturatedFatG: _toDouble(json['snapshot_polyunsaturated_fat_g']),
      caffeineMg: _toDouble(json['snapshot_caffeine_mg']),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null || value == '') {
    return null;
  }
  return _toInt(value);
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _parseDateTime(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
