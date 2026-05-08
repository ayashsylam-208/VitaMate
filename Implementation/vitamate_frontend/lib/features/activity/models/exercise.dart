class Exercise {
  final int id;
  final String name;
  final double metValue;
  final String iconKey;
  final int defaultDurationMinutes;
  final double metLight;
  final double metModerate;
  final double metIntense;
  final bool isFeatured;
  final int sortOrder;

  Exercise({
    required this.id,
    required this.name,
    required this.metValue,
    this.iconKey = 'fitness_center',
    this.defaultDurationMinutes = 30,
    double? metLight,
    double? metModerate,
    double? metIntense,
    this.isFeatured = true,
    this.sortOrder = 0,
  }) : metLight = metLight ?? metValue,
       metModerate = metModerate ?? metValue,
       metIntense = metIntense ?? metValue;

  double metForIntensity(String intensity) {
    switch (intensity) {
      case 'light':
        return metLight;
      case 'intense':
        return metIntense;
      default:
        return metModerate;
    }
  }

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: (json['id'] as num).toInt(),
    name: (json['name'] ?? '').toString(),
    metValue: (json['met_value'] as num).toDouble(),
    iconKey: (json['icon_key'] ?? 'fitness_center').toString(),
    defaultDurationMinutes:
        (json['default_duration_minutes'] as num?)?.toInt() ?? 30,
    metLight: (json['met_light'] as num?)?.toDouble(),
    metModerate: (json['met_moderate'] as num?)?.toDouble(),
    metIntense: (json['met_intense'] as num?)?.toDouble(),
    isFeatured: json['is_featured'] != false,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Exercise && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
