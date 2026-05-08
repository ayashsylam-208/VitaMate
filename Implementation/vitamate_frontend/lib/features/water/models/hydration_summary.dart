class HydrationSummary {
  const HydrationSummary({
    required this.targetMl,
    required this.consumedMl,
    required this.remainingMl,
    required this.progressPercent,
  });

  final int targetMl;
  final int consumedMl;
  final int remainingMl;
  final int progressPercent;

  factory HydrationSummary.empty() {
    return const HydrationSummary(
      targetMl: 0,
      consumedMl: 0,
      remainingMl: 0,
      progressPercent: 0,
    );
  }

  factory HydrationSummary.fromJson(Map<String, dynamic> json) {
    return HydrationSummary(
      targetMl: _asInt(json['target_ml']),
      consumedMl: _asInt(json['consumed_ml']),
      remainingMl: _asInt(json['remaining_ml']),
      progressPercent: _asInt(json['progress_percent']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
