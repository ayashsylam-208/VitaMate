import '../../features/chronic_conditions/data/chronic_conditions_api.dart';
import '../../features/chronic_conditions/models/chronic_condition.dart';

enum ChronicGuideScope { nutrition, hydration, activity }

class ChronicGuideCardData {
  const ChronicGuideCardData({
    required this.metricKey,
    required this.title,
    required this.badgeLabel,
    required this.valueLabel,
    this.sourceLabel = '',
    this.supportingText = '',
    this.priority = 0,
  });

  final String metricKey;
  final String title;
  final String badgeLabel;
  final String valueLabel;
  final String sourceLabel;
  final String supportingText;
  final int priority;
}

class ChronicTargetGuideService {
  const ChronicTargetGuideService({ChronicConditionsApi? api})
    : _api = api ?? const ChronicConditionsApi();

  final ChronicConditionsApi _api;

  Future<List<ChronicGuideCardData>> loadForScope(
    ChronicGuideScope scope,
  ) async {
    final conditions = await _api.getConditions();
    return ChronicTargetGuideBuilder.cardsForScope(scope, conditions);
  }
}

class ChronicTargetGuideBuilder {
  static List<ChronicGuideCardData> cardsForScope(
    ChronicGuideScope scope,
    List<ChronicCondition> conditions,
  ) {
    final activeConditions = conditions
        .where(
          (condition) => condition.isActive && condition.status != 'inactive',
        )
        .toList(growable: false);
    if (activeConditions.isEmpty) {
      return const [];
    }

    final aggregates = <String, _GuideAggregate>{};
    for (final condition in activeConditions) {
      final sourceLabel = condition.uiLabel;
      for (final target in _effectiveTargets(condition)) {
        if (!_matchesScope(scope, target)) {
          continue;
        }
        final key = _metricKey(target);
        final existing = aggregates[key];
        aggregates[key] = existing == null
            ? _GuideAggregate.fromTarget(target, sourceLabel, scope)
            : existing.mergeTarget(target, sourceLabel, scope);
      }

      if (scope == ChronicGuideScope.activity) {
        for (final impact in _trackerImpacts(condition)) {
          final key = (impact['key'] ?? '').toString().trim();
          if (key != 'exercise_intensity_mode') {
            continue;
          }
          final mode = (impact['value'] ?? '').toString().trim();
          if (mode.isEmpty || mode == 'standard') {
            continue;
          }
          final existing = aggregates[key];
          aggregates[key] = existing == null
              ? _GuideAggregate.fromImpact(
                  sourceLabel: sourceLabel,
                  mode: mode,
                  scope: scope,
                )
              : existing.mergeImpact(mode, sourceLabel, scope);
        }
      }
    }

    final items = aggregates.values
        .map((aggregate) => aggregate.toCardData())
        .where((item) => item.valueLabel.isNotEmpty)
        .toList();
    items.sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      if (byPriority != 0) {
        return byPriority;
      }
      return a.title.compareTo(b.title);
    });
    return items;
  }

  static List<ChronicGuideCardData> conditionHighlights(
    ChronicCondition condition, {
    int limit = 3,
  }) {
    final items = _effectiveTargets(condition).map((target) {
      final currentLabel = currentLabelForTarget(target);
      return ChronicGuideCardData(
        metricKey: _metricKey(target),
        title: shortTitleForTarget(target),
        badgeLabel: badgeLabelForTarget(target),
        valueLabel: valueLabelForTarget(target),
        supportingText: currentLabel.isNotEmpty
            ? currentLabel
            : target.guidance,
        priority: target.priority > 0 ? target.priority : 999,
      );
    }).toList();
    items.sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      if (byPriority != 0) {
        return byPriority;
      }
      return a.title.compareTo(b.title);
    });
    return items.take(limit).toList(growable: false);
  }

  static String shortTitleForTarget(ChronicTargetResult target) {
    switch (_metricKey(target)) {
      case 'added_sugars_g':
        return 'Added sugar';
      case 'sodium_mg':
        return 'Sodium';
      case 'activity_minutes_7d':
        return 'Weekly activity';
      case 'water_liters':
        return 'Water';
      case 'fiber_per_1000_kcal':
        return 'Fiber density';
      case 'saturated_fat_pct_kcal':
        return 'Saturated fat';
      case 'trans_fat_g':
        return 'Trans fat';
      case 'cholesterol_mg':
        return 'Cholesterol';
      case 'ldl_cholesterol':
        return 'LDL cholesterol';
      case 'hdl_cholesterol':
        return 'HDL cholesterol';
      case 'fasting_glucose':
        return 'Fasting glucose';
      case 'postprandial_glucose':
        return 'Post-meal glucose';
      default:
        return target.targetName.isNotEmpty
            ? target.targetName
            : target.targetKey;
    }
  }

  static String badgeLabelForTarget(ChronicTargetResult target) {
    if (target.minValue != null && target.maxValue != null) {
      return 'Target';
    }
    if (target.maxValue != null) {
      return 'Limit';
    }
    if (target.minValue != null) {
      return 'Goal';
    }
    return 'Guide';
  }

  static String valueLabelForTarget(ChronicTargetResult target) {
    return _valueLabel(
      minValue: target.minValue,
      maxValue: target.maxValue,
      unit: target.unit,
      evaluationMode: target.evaluationMode,
    );
  }

  static String currentLabelForTarget(ChronicTargetResult target) {
    if (target.currentValue == null) {
      return '';
    }
    final unitPart = target.unit.isEmpty ? '' : ' ${target.unit}';
    return 'Current ${_numberLabel(target.currentValue)}$unitPart'.trim();
  }

  static List<ChronicTargetResult> _effectiveTargets(
    ChronicCondition condition,
  ) {
    final directTargets = condition.targets;
    if (directTargets.isNotEmpty) {
      return [...directTargets]
        ..sort((a, b) => a.priority.compareTo(b.priority));
    }
    final summaryTargets =
        condition.summary?.targets ?? const <ChronicTargetResult>[];
    return [...summaryTargets]
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  static List<Map<String, dynamic>> _trackerImpacts(
    ChronicCondition condition,
  ) {
    return <Map<String, dynamic>>[
      ...condition.evaluation.trackerImpacts,
      ...(condition.summary?.trackerImpacts ?? const []),
    ];
  }

  static bool _matchesScope(
    ChronicGuideScope scope,
    ChronicTargetResult target,
  ) {
    final metricKey = _metricKey(target);
    switch (scope) {
      case ChronicGuideScope.nutrition:
        return _nutritionMetrics.contains(metricKey);
      case ChronicGuideScope.hydration:
        return _hydrationMetrics.contains(metricKey);
      case ChronicGuideScope.activity:
        return _activityMetrics.contains(metricKey);
    }
  }
}

const Set<String> _nutritionMetrics = <String>{
  'added_sugars_g',
  'sodium_mg',
  'fiber_per_1000_kcal',
  'saturated_fat_pct_kcal',
  'trans_fat_g',
  'cholesterol_mg',
};

const Set<String> _hydrationMetrics = <String>{'water_liters'};

const Set<String> _activityMetrics = <String>{'activity_minutes_7d'};

class _GuideAggregate {
  const _GuideAggregate({
    required this.metricKey,
    required this.title,
    required this.badgeLabel,
    required this.sourceLabels,
    required this.priority,
    this.minValue,
    this.maxValue,
    this.unit = '',
    this.evaluationMode = '',
    this.supportingText = '',
    this.intensityMode,
  });

  factory _GuideAggregate.fromTarget(
    ChronicTargetResult target,
    String sourceLabel,
    ChronicGuideScope scope,
  ) {
    return _GuideAggregate(
      metricKey: _metricKey(target),
      title: ChronicTargetGuideBuilder.shortTitleForTarget(target),
      badgeLabel: ChronicTargetGuideBuilder.badgeLabelForTarget(target),
      minValue: target.minValue,
      maxValue: target.maxValue,
      unit: target.unit,
      evaluationMode: target.evaluationMode,
      sourceLabels: <String>{sourceLabel},
      supportingText: target.guidance,
      priority: _scopePriority(scope, _metricKey(target), target.priority),
    );
  }

  factory _GuideAggregate.fromImpact({
    required String sourceLabel,
    required String mode,
    required ChronicGuideScope scope,
  }) {
    return _GuideAggregate(
      metricKey: 'exercise_intensity_mode',
      title: 'Exercise intensity',
      badgeLabel: 'Limit',
      sourceLabels: <String>{sourceLabel},
      intensityMode: mode,
      priority: _scopePriority(scope, 'exercise_intensity_mode', 0),
    );
  }

  final String metricKey;
  final String title;
  final String badgeLabel;
  final double? minValue;
  final double? maxValue;
  final String unit;
  final String evaluationMode;
  final Set<String> sourceLabels;
  final String supportingText;
  final int priority;
  final String? intensityMode;

  _GuideAggregate mergeTarget(
    ChronicTargetResult target,
    String sourceLabel,
    ChronicGuideScope scope,
  ) {
    final mergedMin = _mergedMinValue(minValue, target.minValue);
    final mergedMax = _mergedMaxValue(maxValue, target.maxValue);
    return _GuideAggregate(
      metricKey: metricKey,
      title: title,
      badgeLabel: _badgeLabel(minValue: mergedMin, maxValue: mergedMax),
      minValue: mergedMin,
      maxValue: mergedMax,
      unit: unit.isNotEmpty ? unit : target.unit,
      evaluationMode: evaluationMode.isNotEmpty
          ? evaluationMode
          : target.evaluationMode,
      sourceLabels: {...sourceLabels, sourceLabel},
      supportingText: supportingText.isNotEmpty
          ? supportingText
          : target.guidance,
      priority: _mergedPriority(
        priority,
        _scopePriority(scope, _metricKey(target), target.priority),
      ),
      intensityMode: intensityMode,
    );
  }

  _GuideAggregate mergeImpact(
    String mode,
    String sourceLabel,
    ChronicGuideScope scope,
  ) {
    return _GuideAggregate(
      metricKey: metricKey,
      title: title,
      badgeLabel: badgeLabel,
      minValue: minValue,
      maxValue: maxValue,
      unit: unit,
      evaluationMode: evaluationMode,
      sourceLabels: {...sourceLabels, sourceLabel},
      supportingText: supportingText,
      priority: _mergedPriority(priority, _scopePriority(scope, metricKey, 0)),
      intensityMode: _moreRestrictiveIntensity(intensityMode, mode),
    );
  }

  ChronicGuideCardData toCardData() {
    return ChronicGuideCardData(
      metricKey: metricKey,
      title: title,
      badgeLabel: badgeLabel,
      valueLabel: intensityMode == null
          ? _valueLabel(
              minValue: minValue,
              maxValue: maxValue,
              unit: unit,
              evaluationMode: evaluationMode,
            )
          : _intensityValueLabel(intensityMode!),
      sourceLabel: _sourceSummary(sourceLabels.toList()),
      supportingText: supportingText,
      priority: priority,
    );
  }
}

String _metricKey(ChronicTargetResult target) {
  if (target.metricKey.isNotEmpty) {
    return target.metricKey;
  }
  return target.targetKey;
}

int _scopePriority(
  ChronicGuideScope scope,
  String metricKey,
  int explicitPriority,
) {
  if (explicitPriority > 0) {
    return explicitPriority;
  }
  switch (scope) {
    case ChronicGuideScope.nutrition:
      return switch (metricKey) {
        'added_sugars_g' => 0,
        'sodium_mg' => 1,
        'saturated_fat_pct_kcal' => 2,
        'trans_fat_g' => 3,
        'cholesterol_mg' => 4,
        'fiber_per_1000_kcal' => 5,
        _ => 99,
      };
    case ChronicGuideScope.hydration:
      return metricKey == 'water_liters' ? 0 : 99;
    case ChronicGuideScope.activity:
      return switch (metricKey) {
        'activity_minutes_7d' => 0,
        'exercise_intensity_mode' => 1,
        _ => 99,
      };
  }
}

String _badgeLabel({double? minValue, double? maxValue}) {
  if (minValue != null && maxValue != null) {
    return 'Target';
  }
  if (maxValue != null) {
    return 'Limit';
  }
  if (minValue != null) {
    return 'Goal';
  }
  return 'Guide';
}

double? _mergedMinValue(double? current, double? next) {
  if (current == null) {
    return next;
  }
  if (next == null) {
    return current;
  }
  return current > next ? current : next;
}

double? _mergedMaxValue(double? current, double? next) {
  if (current == null) {
    return next;
  }
  if (next == null) {
    return current;
  }
  return current < next ? current : next;
}

int _mergedPriority(int current, int next) {
  if (current <= 0) {
    return next;
  }
  if (next <= 0) {
    return current;
  }
  return current < next ? current : next;
}

String _sourceSummary(List<String> labels) {
  if (labels.isEmpty) {
    return '';
  }
  if (labels.length == 1) {
    return labels.first;
  }
  if (labels.length == 2) {
    return '${labels.first} + ${labels.last}';
  }
  return '${labels.first} + ${labels.length - 1} more';
}

String _valueLabel({
  required double? minValue,
  required double? maxValue,
  required String unit,
  required String evaluationMode,
}) {
  if (minValue != null && maxValue != null) {
    final unitPart = unit.isEmpty ? '' : ' $unit';
    return '${_numberLabel(minValue)}-${_numberLabel(maxValue)}$unitPart'
        .trim();
  }
  final unitPart = unit.isEmpty ? '' : ' $unit';
  final cadence = _cadenceSuffix(evaluationMode);
  if (maxValue != null) {
    return 'Up to ${_numberLabel(maxValue)}$unitPart$cadence'.trim();
  }
  if (minValue != null) {
    return 'At least ${_numberLabel(minValue)}$unitPart$cadence'.trim();
  }
  return '';
}

String _cadenceSuffix(String evaluationMode) {
  switch (evaluationMode) {
    case 'daily_total':
    case 'daily_average':
      return '/day';
    case 'weekly_total':
    case 'weekly_average':
      return '/week';
    default:
      return '';
  }
}

String _numberLabel(double? value) {
  if (value == null) {
    return '';
  }
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _intensityValueLabel(String mode) {
  switch (mode) {
    case 'conservative':
      return 'Conservative only';
    case 'moderate':
      return 'Moderate only';
    default:
      return mode.replaceAll('_', ' ');
  }
}

String _moreRestrictiveIntensity(String? current, String next) {
  const rank = <String, int>{'standard': 0, 'moderate': 1, 'conservative': 2};
  final currentValue = current ?? 'standard';
  return (rank[next] ?? 0) > (rank[currentValue] ?? 0) ? next : currentValue;
}
