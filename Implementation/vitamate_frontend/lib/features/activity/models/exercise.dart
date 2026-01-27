class Exercise {
  final int id;
  final String name;
  final double metValue;

  Exercise({required this.id, required this.name, required this.metValue});

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: (json['id'] as num).toInt(),
        name: (json['name'] ?? '').toString(),
        metValue: (json['met_value'] as num).toDouble(),
      );
}

