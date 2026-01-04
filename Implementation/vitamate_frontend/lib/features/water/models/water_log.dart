class WaterLog {
  final int id;
  final double amountLiter;
  final DateTime date;

  WaterLog({required this.id, required this.amountLiter, required this.date});

  int get amountMl => (amountLiter * 1000).round();

  factory WaterLog.fromJson(Map<String, dynamic> json) {
    return WaterLog(
      id: (json['id'] as num).toInt(),
      amountLiter: (json['amount_liter'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }
}
