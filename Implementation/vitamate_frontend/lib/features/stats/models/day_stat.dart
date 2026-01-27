class DayStat {
  final DateTime date;
  final double waterCurrent;
  final double waterTarget;
  final int steps;
  final int stepsTarget;
  final double distanceKm;
  final int caloriesIn;
  final int caloriesTarget;
  final int caloriesBurned;
  final int burnTarget;
  final double sleepHours;
  final double sleepTarget;
  final int exerciseMinutes;
  final int pointsEstimate;

  DayStat({
    required this.date,
    required this.waterCurrent,
    required this.waterTarget,
    required this.steps,
    required this.stepsTarget,
    required this.distanceKm,
    required this.caloriesIn,
    required this.caloriesTarget,
    required this.caloriesBurned,
    required this.burnTarget,
    required this.sleepHours,
    required this.sleepTarget,
    required this.exerciseMinutes,
    required this.pointsEstimate,
  });

  factory DayStat.fromJson(Map<String, dynamic> json) {
    return DayStat(
      date: DateTime.parse(json['date']),
      waterCurrent: _toDouble(json['water_current']),
      waterTarget: _toDouble(json['water_target']),
      steps: _toInt(json['steps']),
      stepsTarget: _toInt(json['steps_target']),
      distanceKm: _toDouble(json['distance_km']),
      caloriesIn: _toInt(json['calories_in']),
      caloriesTarget: _toInt(json['calories_target']),
      caloriesBurned: _toInt(json['calories_burned']),
      burnTarget: _toInt(json['burn_target']),
      sleepHours: _toDouble(json['sleep_hours']),
      sleepTarget: _toDouble(json['sleep_target']),
      exerciseMinutes: _toInt(json['exercise_minutes']),
      pointsEstimate: _toInt(json['points_estimate']),
    );
  }

  double progress(double current, double target) {
    if (target <= 0) return 0;
    return (current / target).clamp(0, 1);
  }

  double get waterProgress => progress(waterCurrent, waterTarget);
  double get stepsProgress => progress(steps.toDouble(), stepsTarget.toDouble());
  double get caloriesProgress =>
      caloriesTarget <= 0 ? 0 : (caloriesIn / caloriesTarget).clamp(0, 2); // allow >100%
  double get sleepProgress => progress(sleepHours, sleepTarget);
  double get burnProgress => progress(caloriesBurned.toDouble(), burnTarget.toDouble());

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
