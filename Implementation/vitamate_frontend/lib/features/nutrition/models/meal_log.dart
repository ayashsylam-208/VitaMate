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
      return '${_formatNumber(servingsConsumed)} serving';
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
