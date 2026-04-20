class FoodItem {
  final int id;
  final String name;
  final String itemType;
  final String category;
  final String primaryCategoryCode;
  final int calories100g;
  final double protein100g;
  final double carbs100g;
  final double fat100g;
  final double sugars100g;
  final double fiber100g;
  final double sodiumMg100g;
  final double waterGPer100Unit;
  final double caffeineMg;
  final double defaultServingSize;
  final String defaultServingUnit;
  final String servingLabel;
  final int servingGrams;
  final bool isUserOwned;
  final bool containsCaffeine;
  final bool isHydrationTrackable;

  const FoodItem({
    required this.id,
    required this.name,
    this.itemType = 'food',
    this.category = '',
    this.primaryCategoryCode = '',
    required this.calories100g,
    required this.protein100g,
    required this.carbs100g,
    required this.fat100g,
    this.sugars100g = 0,
    this.fiber100g = 0,
    this.sodiumMg100g = 0,
    this.waterGPer100Unit = 0,
    this.caffeineMg = 0,
    this.defaultServingSize = 100,
    this.defaultServingUnit = 'g',
    required this.servingLabel,
    required this.servingGrams,
    this.isUserOwned = false,
    this.containsCaffeine = false,
    this.isHydrationTrackable = false,
  });

  bool get isBeverage => itemType == 'beverage' || itemType == 'drink';
  double? get hydrationRatio {
    if (waterGPer100Unit > 0) {
      return (waterGPer100Unit / 100).clamp(0.0, 1.0);
    }
    return null;
  }

  int? hydrationContributionMl(int amountMl) {
    final ratio = hydrationRatio;
    if (ratio == null || amountMl <= 0) {
      return null;
    }
    return (amountMl * ratio).round();
  }

  String get supportingLabel {
    if (category.trim().isNotEmpty) {
      return category.trim();
    }
    return isBeverage ? 'Beverage' : 'Food';
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    id: (json['id'] as num).toInt(),
    name: (json['name'] ?? '').toString(),
    itemType: (json['item_type'] ?? 'food').toString(),
    category: _categoryLabel(json),
    primaryCategoryCode: _categoryCode(json),
    calories100g: _toInt(json['calories_100g']),
    protein100g: _toDouble(json['protein_100g']),
    carbs100g: _toDouble(json['carbs_100g']),
    fat100g: _toDouble(json['fat_100g']),
    sugars100g: _factsDouble(json, 'sugars_g', fallbackKey: 'sugar_100g'),
    fiber100g: _factsDouble(json, 'fiber_g', fallbackKey: 'fiber_100g'),
    sodiumMg100g: _factsDouble(
      json,
      'sodium_mg',
      fallbackKey: 'sodium_mg_100g',
    ),
    waterGPer100Unit: _factsDouble(json, 'water_g'),
    caffeineMg: _factsDouble(json, 'caffeine_mg'),
    defaultServingSize: _toDouble(json['default_serving_size']),
    defaultServingUnit: (json['default_serving_unit'] ?? 'g').toString(),
    servingLabel: (json['serving_label'] ?? 'Serving').toString(),
    servingGrams: _toInt(json['serving_grams'], fallback: 100),
    isUserOwned: json['created_by'] != null,
    isHydrationTrackable: json['is_hydration_trackable'] == true,
    containsCaffeine:
        json['contains_caffeine'] == true ||
        _factsDouble(json, 'caffeine_mg') > 0,
  );
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double _factsDouble(
  Map<String, dynamic> json,
  String key, {
  String? fallbackKey,
}) {
  final facts = json['nutrition_facts'];
  if (facts is Map && facts[key] != null) return _toDouble(facts[key]);
  if (fallbackKey != null) return _toDouble(json[fallbackKey]);
  return _toDouble(json[key]);
}

String _categoryLabel(Map<String, dynamic> json) {
  final category = (json['category'] ?? '').toString().trim();
  if (category.isNotEmpty) return category;
  final primary = json['primary_category'];
  if (primary is Map && primary['name'] != null) {
    return primary['name'].toString();
  }
  return '';
}

String _categoryCode(Map<String, dynamic> json) {
  final primary = json['primary_category'];
  if (primary is Map && primary['code'] != null) {
    return primary['code'].toString();
  }
  return '';
}
