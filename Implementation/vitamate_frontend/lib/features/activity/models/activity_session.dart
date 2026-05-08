class ActivitySession {
  const ActivitySession({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseIconKey,
    required this.status,
    required this.source,
    required this.intensity,
    required this.targetDurationSeconds,
    required this.actualDurationSeconds,
    required this.remainingDurationSeconds,
    required this.progressPercent,
    required this.metValueSnapshot,
    required this.estimatedCalories,
    required this.caloriesBurned,
    required this.startedAt,
    required this.pausedAt,
    required this.endedAt,
    required this.totalPausedSeconds,
  });

  final int id;
  final int exerciseId;
  final String exerciseName;
  final String exerciseIconKey;
  final String status;
  final String source;
  final String intensity;
  final int targetDurationSeconds;
  final int actualDurationSeconds;
  final int remainingDurationSeconds;
  final int progressPercent;
  final double metValueSnapshot;
  final int estimatedCalories;
  final int caloriesBurned;
  final DateTime startedAt;
  final DateTime? pausedAt;
  final DateTime? endedAt;
  final int totalPausedSeconds;

  bool get isRunning => status == 'running';
  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => isRunning || isPaused;

  int elapsedSecondsAt(DateTime now) {
    if (!isActive) {
      return actualDurationSeconds;
    }
    final endPoint = isPaused ? (pausedAt ?? now) : now;
    final liveSeconds =
        endPoint.difference(startedAt).inSeconds - totalPausedSeconds;
    if (liveSeconds <= 0) {
      return actualDurationSeconds;
    }
    return liveSeconds > actualDurationSeconds
        ? liveSeconds
        : actualDurationSeconds;
  }

  int remainingSecondsAt(DateTime now) {
    final remaining = targetDurationSeconds - elapsedSecondsAt(now);
    return remaining > 0 ? remaining : 0;
  }

  int progressPercentAt(DateTime now) {
    if (targetDurationSeconds <= 0) {
      return progressPercent;
    }
    final next = ((elapsedSecondsAt(now) / targetDurationSeconds) * 100)
        .clamp(0, 100)
        .round();
    return next > progressPercent ? next : progressPercent;
  }

  int caloriesBurnedAt(DateTime now, {required double userWeightKg}) {
    if (!isActive) {
      return caloriesBurned;
    }
    final elapsedMinutes = elapsedSecondsAt(now) / 60;
    final live = ((metValueSnapshot * 3.5 * userWeightKg) / 200 * elapsedMinutes)
        .round();
    return live > caloriesBurned ? live : caloriesBurned;
  }

  factory ActivitySession.fromJson(Map<String, dynamic> json) {
    return ActivitySession(
      id: (json['id'] as num).toInt(),
      exerciseId: (json['exercise'] as num).toInt(),
      exerciseName: (json['exercise_name'] ?? '').toString(),
      exerciseIconKey: (json['exercise_icon_key'] ?? 'fitness_center')
          .toString(),
      status: (json['status'] ?? '').toString(),
      source: (json['source'] ?? 'live').toString(),
      intensity: (json['intensity'] ?? 'moderate').toString(),
      targetDurationSeconds:
          (json['target_duration_seconds'] as num?)?.toInt() ?? 0,
      actualDurationSeconds:
          (json['actual_duration_seconds'] as num?)?.toInt() ?? 0,
      remainingDurationSeconds:
          (json['remaining_duration_seconds'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      metValueSnapshot: (json['met_value_snapshot'] as num?)?.toDouble() ?? 0,
      estimatedCalories: (json['estimated_calories'] as num?)?.toInt() ?? 0,
      caloriesBurned: (json['calories_burned'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.parse((json['started_at'] ?? '').toString()).toLocal(),
      pausedAt: _parseDateTime(json['paused_at']),
      endedAt: _parseDateTime(json['ended_at']),
      totalPausedSeconds: (json['total_paused_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}
