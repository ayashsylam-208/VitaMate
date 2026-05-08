import 'chronic_target_guide.dart';

class ConditionLimitWarning {
  const ConditionLimitWarning({
    required this.metricKey,
    required this.metricLabel,
    required this.limitValue,
    required this.currentValue,
    required this.unit,
    required this.sourceLabel,
    required this.conditionLabel,
  });

  final String metricKey;
  final String metricLabel;
  final double limitValue;
  final double currentValue;
  final String unit;
  final String sourceLabel;
  final String conditionLabel;
}

class ConditionLimitAlertEvaluator {
  const ConditionLimitAlertEvaluator();

  List<ConditionLimitWarning> evaluate({
    required List<ChronicGuideCardData> guides,
    required Map<String, double> beforeValues,
    required Map<String, double> afterValues,
    required String sourceLabel,
    Set<String> excludedMetricKeys = const <String>{},
  }) {
    final warnings = <ConditionLimitWarning>[];
    for (final guide in guides) {
      final metricKey = guide.metricKey.trim();
      final maxValue = guide.maxValue;
      if (metricKey.isEmpty ||
          excludedMetricKeys.contains(metricKey) ||
          maxValue == null ||
          maxValue <= 0) {
        continue;
      }
      final before = beforeValues[metricKey] ?? 0;
      final after = afterValues[metricKey] ?? 0;
      if (before <= maxValue && after > maxValue) {
        warnings.add(
          ConditionLimitWarning(
            metricKey: metricKey,
            metricLabel: guide.title,
            limitValue: maxValue,
            currentValue: after,
            unit: guide.unit,
            sourceLabel: sourceLabel,
            conditionLabel: guide.sourceLabel,
          ),
        );
      }
    }
    return warnings;
  }
}
