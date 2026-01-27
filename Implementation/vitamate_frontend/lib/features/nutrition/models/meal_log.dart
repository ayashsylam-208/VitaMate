class MealLog {
  final int id;
  final int foodId;
  final String mealType;
  final double quantityGrams;

  MealLog({
    required this.id,
    required this.foodId,
    required this.mealType,
    required this.quantityGrams,
  });

  factory MealLog.fromJson(Map<String, dynamic> json) {
    return MealLog(
      id: (json['id'] as num).toInt(),
      foodId: (json['food'] as num).toInt(),
      mealType: (json['meal_type'] ?? '').toString(),
      quantityGrams: (json['quantity_grams'] as num).toDouble(),
    );
  }
}

