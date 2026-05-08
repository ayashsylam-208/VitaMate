import '../../../shared/models/api_result.dart';
import 'activity_session.dart';

class ActivitySuggestion {
  const ActivitySuggestion({
    required this.exerciseId,
    required this.exerciseName,
    required this.iconKey,
    required this.intensity,
    required this.recommendedDurationMinutes,
    required this.estimatedCalories,
    required this.reason,
  });

  final int exerciseId;
  final String exerciseName;
  final String iconKey;
  final String intensity;
  final int recommendedDurationMinutes;
  final int estimatedCalories;
  final String reason;

  factory ActivitySuggestion.fromJson(Map<String, dynamic> json) {
    return ActivitySuggestion(
      exerciseId: (json['exercise'] as num).toInt(),
      exerciseName: (json['exercise_name'] ?? '').toString(),
      iconKey: (json['icon_key'] ?? 'fitness_center').toString(),
      intensity: (json['intensity'] ?? 'moderate').toString(),
      recommendedDurationMinutes:
          (json['recommended_duration_minutes'] as num?)?.toInt() ?? 0,
      estimatedCalories: (json['estimated_calories'] as num?)?.toInt() ?? 0,
      reason: (json['reason'] ?? '').toString(),
    );
  }
}

class ActivityTodaySummary {
  const ActivityTodaySummary({
    required this.steps,
    required this.stepsTarget,
    required this.activeMinutes,
    required this.caloriesBurned,
    required this.burnTarget,
    required this.goalProgressPercent,
    required this.burnProgressPercent,
    required this.stepsProgressPercent,
    required this.message,
  });

  final int steps;
  final int stepsTarget;
  final int activeMinutes;
  final int caloriesBurned;
  final int burnTarget;
  final int goalProgressPercent;
  final int burnProgressPercent;
  final int stepsProgressPercent;
  final String message;

  factory ActivityTodaySummary.empty() {
    return const ActivityTodaySummary(
      steps: 0,
      stepsTarget: 0,
      activeMinutes: 0,
      caloriesBurned: 0,
      burnTarget: 0,
      goalProgressPercent: 0,
      burnProgressPercent: 0,
      stepsProgressPercent: 0,
      message: '',
    );
  }

  factory ActivityTodaySummary.fromJson(Map<String, dynamic> json) {
    return ActivityTodaySummary(
      steps: _toInt(json['steps']),
      stepsTarget: _toInt(json['steps_target']),
      activeMinutes: _toInt(json['active_minutes']),
      caloriesBurned: _toInt(json['calories_burned']),
      burnTarget: _toInt(json['burn_target']),
      goalProgressPercent: _toInt(json['goal_progress_percent']),
      burnProgressPercent: _toInt(json['burn_progress_percent']),
      stepsProgressPercent: _toInt(json['steps_progress_percent']),
      message: (json['message'] ?? '').toString(),
    );
  }
}

class ActivityWeeklySummary {
  const ActivityWeeklySummary({
    required this.weekStart,
    required this.weekEnd,
    required this.activeDays,
    required this.weeklyMinutes,
    required this.weeklyKcal,
    required this.goalTargetMinutes,
    required this.goalAchievementRate,
    required this.remainingMinutes,
    required this.bestActivity,
  });

  final DateTime? weekStart;
  final DateTime? weekEnd;
  final int activeDays;
  final int weeklyMinutes;
  final int weeklyKcal;
  final int goalTargetMinutes;
  final int goalAchievementRate;
  final int remainingMinutes;
  final String bestActivity;

  factory ActivityWeeklySummary.empty() {
    return const ActivityWeeklySummary(
      weekStart: null,
      weekEnd: null,
      activeDays: 0,
      weeklyMinutes: 0,
      weeklyKcal: 0,
      goalTargetMinutes: 0,
      goalAchievementRate: 0,
      remainingMinutes: 0,
      bestActivity: '',
    );
  }

  factory ActivityWeeklySummary.fromJson(Map<String, dynamic> json) {
    return ActivityWeeklySummary(
      weekStart: DateTime.tryParse((json['week_start'] ?? '').toString()),
      weekEnd: DateTime.tryParse((json['week_end'] ?? '').toString()),
      activeDays: _toInt(json['active_days']),
      weeklyMinutes: _toInt(json['weekly_minutes']),
      weeklyKcal: _toInt(json['weekly_kcal']),
      goalTargetMinutes: _toInt(json['goal_target_minutes']),
      goalAchievementRate: _toInt(json['goal_achievement_rate']),
      remainingMinutes: _toInt(json['remaining_minutes']),
      bestActivity: (json['best_activity'] ?? '').toString(),
    );
  }
}

class ActivitySummarySnapshot {
  const ActivitySummarySnapshot({
    required this.burnTarget,
    required this.burnCurrent,
    required this.exerciseMinutes,
    required this.pointsEstimate,
    required this.todaySummary,
    required this.weeklySummary,
    required this.activeSession,
    required this.suggestions,
    required this.meta,
  });

  final int burnTarget;
  final int burnCurrent;
  final int exerciseMinutes;
  final int pointsEstimate;
  final ActivityTodaySummary todaySummary;
  final ActivityWeeklySummary weeklySummary;
  final ActivitySession? activeSession;
  final List<ActivitySuggestion> suggestions;
  final ApiMeta meta;

  factory ActivitySummarySnapshot.empty() {
    return ActivitySummarySnapshot(
      burnTarget: 0,
      burnCurrent: 0,
      exerciseMinutes: 0,
      pointsEstimate: 0,
      todaySummary: ActivityTodaySummary.empty(),
      weeklySummary: ActivityWeeklySummary.empty(),
      activeSession: null,
      suggestions: const <ActivitySuggestion>[],
      meta: ApiMeta.empty(),
    );
  }

  factory ActivitySummarySnapshot.fromEnvelope(dynamic value) {
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      value,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
    final data = envelope.data;
    return ActivitySummarySnapshot(
      burnTarget: _toInt(data['burn_target']),
      burnCurrent: _toInt(data['burn_current']),
      exerciseMinutes: _toInt(data['exercise_minutes']),
      pointsEstimate: _toInt(data['points_estimate']),
      todaySummary: ActivityTodaySummary.fromJson(
        asMap(data['today_summary']),
      ),
      weeklySummary: ActivityWeeklySummary.fromJson(
        asMap(data['weekly_summary']),
      ),
      activeSession: asMap(data['active_session']).isEmpty
          ? null
          : ActivitySession.fromJson(asMap(data['active_session'])),
      suggestions: asMapList(data['suggestions'])
          .map(ActivitySuggestion.fromJson)
          .toList(growable: false),
      meta: envelope.meta,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
