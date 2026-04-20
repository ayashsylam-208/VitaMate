class WaterNutritionPreview {
  const WaterNutritionPreview({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.sugars = 0,
    this.caffeine = 0,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugars;
  final double caffeine;

  factory WaterNutritionPreview.fromJson(Map<String, dynamic> json) {
    return WaterNutritionPreview(
      calories: _toDouble(json['calories']),
      protein: _toDouble(json['protein']),
      carbs: _toDouble(json['carbs']),
      fat: _toDouble(json['fat']),
      sugars: _toDouble(json['sugars']),
      caffeine: _toDouble(json['caffeine']),
    );
  }
}

class WaterLog {
  const WaterLog({
    required this.id,
    required this.amountLiter,
    required this.hydrationMl,
    required this.beverageType,
    required this.beverageName,
    this.foodItemId,
    this.foodItemName = '',
    this.linkedMealLogId,
    this.nutritionPreview,
    required this.date,
  });

  final int id;
  final double amountLiter;
  final int hydrationMl;
  final String beverageType;
  final String beverageName;
  final int? foodItemId;
  final String foodItemName;
  final int? linkedMealLogId;
  final WaterNutritionPreview? nutritionPreview;
  final DateTime date;

  int get amountMl => (amountLiter * 1000).round();

  String get displayName {
    final foodName = foodItemName.trim();
    if (foodName.isNotEmpty) {
      return foodName;
    }
    final trimmed = beverageName.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    switch (beverageType) {
      case 'tea':
        return 'Tea';
      case 'coffee':
        return 'Coffee';
      case 'juice':
        return 'Juice';
      case 'smoothie':
        return 'Smoothie';
      case 'other':
        return 'Beverage';
      default:
        return 'Water';
    }
  }

  factory WaterLog.fromJson(Map<String, dynamic> json) {
    return WaterLog(
      id: (json['id'] as num).toInt(),
      amountLiter: (json['amount_liter'] as num).toDouble(),
      hydrationMl: _toNullableInt(json['hydration_ml']) ?? 0,
      beverageType: (json['beverage_type'] as String?) ?? 'water',
      beverageName: (json['beverage_name'] as String?) ?? 'Water',
      foodItemId: _toNullableInt(json['food_item']),
      foodItemName: (json['food_item_name'] ?? '').toString(),
      linkedMealLogId: _toNullableInt(json['linked_meal_log']),
      nutritionPreview: json['nutrition_preview'] is Map
          ? WaterNutritionPreview.fromJson(
              Map<String, dynamic>.from(json['nutrition_preview'] as Map),
            )
          : null,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
