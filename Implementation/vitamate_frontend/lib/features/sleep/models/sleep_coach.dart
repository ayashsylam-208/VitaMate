import '../../../shared/models/api_result.dart';

class SleepCoachOverview {
  const SleepCoachOverview({
    this.plan,
    this.feedbackPrompt = false,
    this.learningSummary = const SleepLearningSummary(),
    this.latestTrackerFactors = const <String, dynamic>{},
    this.disclaimer = '',
  });

  final SleepPlan? plan;
  final bool feedbackPrompt;
  final SleepLearningSummary learningSummary;
  final Map<String, dynamic> latestTrackerFactors;
  final String disclaimer;

  factory SleepCoachOverview.empty() => const SleepCoachOverview();

  factory SleepCoachOverview.fromJson(Map<String, dynamic> json) {
    final planJson = asMap(json['plan']);
    return SleepCoachOverview(
      plan: planJson.isEmpty ? null : SleepPlan.fromJson(planJson),
      feedbackPrompt: json['feedback_prompt'] == true,
      learningSummary: SleepLearningSummary.fromJson(
        asMap(json['learning_summary']),
      ),
      latestTrackerFactors: asMap(json['latest_tracker_factors']),
      disclaimer: (json['disclaimer'] ?? '').toString(),
    );
  }
}

class SleepPlan {
  const SleepPlan({
    required this.id,
    required this.status,
    required this.plannedBedTime,
    required this.latestWakeTime,
    required this.flexibilityMinutes,
    required this.wakeWindowStart,
    required this.wakeWindowEnd,
    required this.estimatedSleepStart,
    required this.wakeOptions,
    required this.selectedWakeTime,
    required this.recommendationReason,
    required this.primaryNegativeFactor,
    required this.nightTip,
    required this.hasFeedback,
    required this.disclaimer,
    this.trackerFactors = const <String, dynamic>{},
  });

  final int id;
  final String status;
  final DateTime plannedBedTime;
  final DateTime latestWakeTime;
  final int flexibilityMinutes;
  final DateTime wakeWindowStart;
  final DateTime wakeWindowEnd;
  final DateTime estimatedSleepStart;
  final List<SleepWakeOption> wakeOptions;
  final DateTime? selectedWakeTime;
  final String recommendationReason;
  final String primaryNegativeFactor;
  final String nightTip;
  final bool hasFeedback;
  final String disclaimer;
  final Map<String, dynamic> trackerFactors;

  SleepWakeOption? get recommendedOption {
    for (final option in wakeOptions) {
      if (option.isRecommended) return option;
    }
    return wakeOptions.isEmpty ? null : wakeOptions.first;
  }

  factory SleepPlan.fromJson(Map<String, dynamic> json) {
    return SleepPlan(
      id: _toInt(json['id']),
      status: (json['status'] ?? '').toString(),
      plannedBedTime: _date(json['planned_bed_time']),
      latestWakeTime: _date(json['latest_wake_time']),
      flexibilityMinutes: _toInt(json['flexibility_minutes']),
      wakeWindowStart: _date(json['wake_window_start']),
      wakeWindowEnd: _date(json['wake_window_end']),
      estimatedSleepStart: _date(json['estimated_sleep_start']),
      wakeOptions: asMapList(json['wake_options'])
          .map(SleepWakeOption.fromJson)
          .toList(growable: false),
      selectedWakeTime: _nullableDate(json['selected_wake_time']),
      recommendationReason: (json['recommendation_reason'] ?? '').toString(),
      primaryNegativeFactor: (json['primary_negative_factor'] ?? 'none')
          .toString(),
      nightTip: (json['night_tip'] ?? '').toString(),
      hasFeedback: json['has_feedback'] == true,
      disclaimer: (json['disclaimer'] ?? '').toString(),
      trackerFactors: asMap(json['tracker_factors']),
    );
  }
}

class SleepWakeOption {
  const SleepWakeOption({
    required this.kind,
    required this.wakeTime,
    this.cycles,
    this.sleepDurationMinutes = 0,
    this.isRecommended = false,
    this.isFallback = false,
    this.warning = '',
  });

  final String kind;
  final DateTime wakeTime;
  final int? cycles;
  final int sleepDurationMinutes;
  final bool isRecommended;
  final bool isFallback;
  final String warning;

  factory SleepWakeOption.fromJson(Map<String, dynamic> json) {
    return SleepWakeOption(
      kind: (json['kind'] ?? '').toString(),
      wakeTime: _date(json['wake_time']),
      cycles: _nullableInt(json['cycles']),
      sleepDurationMinutes: _toInt(json['sleep_duration_minutes']),
      isRecommended: json['is_recommended'] == true,
      isFallback: json['is_fallback'] == true,
      warning: (json['warning'] ?? '').toString(),
    );
  }
}

class SleepLearningSummary {
  const SleepLearningSummary({
    this.sampleSize = 0,
    this.averageQuality = 0,
    this.insights = const <String>[],
    this.bestSleepDurationRange = '',
    this.topNegativeFactor = 'none',
  });

  final int sampleSize;
  final double averageQuality;
  final List<String> insights;
  final String bestSleepDurationRange;
  final String topNegativeFactor;

  factory SleepLearningSummary.fromJson(Map<String, dynamic> json) {
    return SleepLearningSummary(
      sampleSize: _toInt(json['sample_size']),
      averageQuality: _toDouble(json['average_quality']),
      insights: (json['insights'] is List)
          ? (json['insights'] as List).map((item) => item.toString()).toList()
          : const <String>[],
      bestSleepDurationRange: (json['best_sleep_duration_range'] ?? '')
          .toString(),
      topNegativeFactor: (json['top_negative_factor'] ?? 'none').toString(),
    );
  }
}

class SleepFeedbackResult {
  const SleepFeedbackResult({
    required this.feedbackId,
    required this.planId,
    required this.learningSummary,
  });

  final int feedbackId;
  final int planId;
  final SleepLearningSummary learningSummary;

  factory SleepFeedbackResult.fromJson(Map<String, dynamic> json) {
    final feedback = asMap(json['feedback']);
    return SleepFeedbackResult(
      feedbackId: _toInt(feedback['id']),
      planId: _toInt(feedback['plan_id']),
      learningSummary: SleepLearningSummary.fromJson(
        asMap(json['learning_summary']),
      ),
    );
  }
}

DateTime _date(dynamic value) {
  return _nullableDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _nullableDate(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null || value == '') return null;
  return _toInt(value);
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
