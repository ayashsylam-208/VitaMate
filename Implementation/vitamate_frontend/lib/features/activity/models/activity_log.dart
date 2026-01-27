class ActivityLog {
  final int id;
  final int exerciseId;
  final String exerciseName;
  final int durationMinutes;
  final int caloriesBurned;
  final DateTime date;

  ActivityLog({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.date,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
        id: (json['id'] as num).toInt(),
        exerciseId: (json['exercise'] as num).toInt(),
        exerciseName: (json['exercise_name'] ?? '').toString(),
        durationMinutes: (json['duration_minutes'] as num).toInt(),
        caloriesBurned: (json['calories_burned'] as num).toInt(),
        date: DateTime.parse(json['date'] as String),
      );
}

