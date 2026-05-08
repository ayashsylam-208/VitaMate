import '../../features/chronic_conditions/data/chronic_conditions_api.dart';
import '../../features/chronic_conditions/models/chronic_condition.dart';

class DiabetesSugarGuard {
  const DiabetesSugarGuard({required this.limitG, required this.source});

  final double limitG;
  final String source;
}

class DiabetesSugarWarning {
  const DiabetesSugarWarning({
    required this.limitG,
    required this.currentG,
    required this.sourceLabel,
  });

  final double limitG;
  final double currentG;
  final String sourceLabel;
}

class DiabetesSugarGuardService {
  const DiabetesSugarGuardService({ChronicConditionsApi? api})
    : _api = api ?? const ChronicConditionsApi();

  static const double fallbackDiabetesSugarLimitG = 25;
  final ChronicConditionsApi _api;

  Future<DiabetesSugarGuard?> getActiveGuard() async {
    final conditions = await _api.getOverviewConditions(guidanceOnly: true);
    for (final condition in conditions) {
      final slug = condition.conditionType.slug.trim().toLowerCase();
      final status = condition.status.trim().toLowerCase();
      if (slug != 'diabetes' || !condition.isActive || status == 'inactive') {
        continue;
      }

      final dynamicLimit = _extractAddedSugarLimit(condition);
      return DiabetesSugarGuard(
        limitG: dynamicLimit ?? fallbackDiabetesSugarLimitG,
        source: dynamicLimit != null
            ? 'condition_target'
            : 'default_diabetes_limit',
      );
    }

    return null;
  }

  double? _extractAddedSugarLimit(ChronicCondition condition) {
    final seenKeys = <String>{};
    final candidates = <ChronicTargetResult>[
      ...condition.targets,
      ...condition.evaluation.targets,
      ...(condition.summary?.targets ?? const <ChronicTargetResult>[]),
    ];
    for (final target in candidates) {
      final key = '${target.id}:${target.targetKey}:${target.metricKey}';
      if (!seenKeys.add(key)) {
        continue;
      }
      final targetKey = target.targetKey.trim();
      final metricKey = target.metricKey.trim();
      if (targetKey != 'added_sugars_g' &&
          targetKey != 'sugars_g' &&
          metricKey != 'added_sugars_g' &&
          metricKey != 'sugars_g') {
        continue;
      }
      final maxValue = target.maxValue;
      if (maxValue != null && maxValue > 0) {
        return maxValue;
      }
    }
    return null;
  }
}
