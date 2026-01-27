class FoodItem {
  final int id;
  final String name;
  final int calories100g;
  final double protein100g;
  final double carbs100g;
  final double fat100g;
  final String servingLabel;
  final int servingGrams;

  const FoodItem({
    required this.id,
    required this.name,
    required this.calories100g,
    required this.protein100g,
    required this.carbs100g,
    required this.fat100g,
    required this.servingLabel,
    required this.servingGrams,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        calories100g: (json['calories_100g'] as num).toInt(),
        protein100g: (json['protein_100g'] as num).toDouble(),
        carbs100g: (json['carbs_100g'] as num).toDouble(),
        fat100g: (json['fat_100g'] as num).toDouble(),
        servingLabel: (json['serving_label'] ?? 'Serving').toString(),
        servingGrams: (json['serving_grams'] as num).toInt(),
      );
}

