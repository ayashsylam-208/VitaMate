import '../../../shared/models/api_result.dart';

class UnhealthyHabitsOverview {
  const UnhealthyHabitsOverview({
    required this.habits,
    required this.summary,
    required this.supportMessage,
    required this.meta,
  });

  final List<UnhealthyHabit> habits;
  final UnhealthyHabitSummary summary;
  final String supportMessage;
  final ApiMeta meta;

  factory UnhealthyHabitsOverview.empty() {
    return UnhealthyHabitsOverview(
      habits: UnhealthyHabit.defaultCards(),
      summary: UnhealthyHabitSummary.empty(),
      supportMessage: '',
      meta: ApiMeta.empty(),
    );
  }

  factory UnhealthyHabitsOverview.fromEnvelope(dynamic value) {
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      value,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
    final data = envelope.data;
    return UnhealthyHabitsOverview(
      habits: asMapList(data['habits'])
          .map(UnhealthyHabit.fromJson)
          .toList(growable: false),
      summary: UnhealthyHabitSummary.fromJson(data['summary']),
      supportMessage: (data['support_message'] ?? '').toString(),
      meta: envelope.meta,
    );
  }
}

class UnhealthyHabitSummary {
  const UnhealthyHabitSummary({
    required this.activeCount,
    required this.logsToday,
    required this.relapsesToday,
    required this.pointsToday,
  });

  final int activeCount;
  final int logsToday;
  final int relapsesToday;
  final int pointsToday;

  factory UnhealthyHabitSummary.empty() {
    return const UnhealthyHabitSummary(
      activeCount: 0,
      logsToday: 0,
      relapsesToday: 0,
      pointsToday: 0,
    );
  }

  factory UnhealthyHabitSummary.fromJson(dynamic value) {
    final json = asMap(value);
    return UnhealthyHabitSummary(
      activeCount: _int(json['active_count']),
      logsToday: _int(json['logs_today']),
      relapsesToday: _int(json['relapses_today']),
      pointsToday: _int(json['points_today']),
    );
  }
}

class UnhealthyHabit {
  const UnhealthyHabit({
    required this.id,
    required this.habitType,
    required this.label,
    required this.title,
    required this.goalType,
    required this.status,
    required this.isSetup,
    required this.baseline,
    required this.plan,
    required this.progress,
    required this.reminders,
  });

  final int? id;
  final String habitType;
  final String label;
  final String title;
  final String goalType;
  final String status;
  final bool isSetup;
  final UnhealthyHabitBaseline? baseline;
  final UnhealthyHabitPlan? plan;
  final UnhealthyHabitProgress progress;
  final List<UnhealthyHabitReminder> reminders;

  bool get isActive => status == 'active';

  static List<UnhealthyHabit> defaultCards() {
    return const [
      UnhealthyHabit.empty('smoking', 'Smoking'),
      UnhealthyHabit.empty('caffeine', 'Caffeine'),
      UnhealthyHabit.empty('fast_food', 'Fast food'),
    ];
  }

  const factory UnhealthyHabit.empty(String type, String label) =
      _EmptyUnhealthyHabit;

  factory UnhealthyHabit.fromJson(dynamic value) {
    final json = asMap(value);
    return UnhealthyHabit(
      id: _nullableInt(json['id']),
      habitType: (json['habit_type'] ?? '').toString(),
      label: (json['label'] ?? json['habit_type'] ?? '').toString(),
      title: (json['title'] ?? json['label'] ?? '').toString(),
      goalType: (json['goal_type'] ?? 'reduce').toString(),
      status: (json['status'] ?? 'not_started').toString(),
      isSetup: json['is_setup'] == true,
      baseline: json['baseline'] == null
          ? null
          : UnhealthyHabitBaseline.fromJson(json['baseline']),
      plan: json['plan'] == null ? null : UnhealthyHabitPlan.fromJson(json['plan']),
      progress: UnhealthyHabitProgress.fromJson(json['progress']),
      reminders: asMapList(json['reminders'])
          .map(UnhealthyHabitReminder.fromJson)
          .toList(growable: false),
    );
  }
}

class _EmptyUnhealthyHabit extends UnhealthyHabit {
  const _EmptyUnhealthyHabit(String type, String label)
      : super(
          id: null,
          habitType: type,
          label: label,
          title: label,
          goalType: 'reduce',
          status: 'not_started',
          isSetup: false,
          baseline: null,
          plan: null,
          progress: const UnhealthyHabitProgress.empty(),
          reminders: const [],
        );
}

class UnhealthyHabitBaseline {
  const UnhealthyHabitBaseline({
    required this.initialFrequency,
    required this.initialQuantity,
    required this.unit,
    required this.commonTrigger,
    required this.commonTime,
  });

  final double initialFrequency;
  final double initialQuantity;
  final String unit;
  final String commonTrigger;
  final String commonTime;

  factory UnhealthyHabitBaseline.fromJson(dynamic value) {
    final json = asMap(value);
    return UnhealthyHabitBaseline(
      initialFrequency: _double(json['initial_frequency']),
      initialQuantity: _double(json['initial_quantity']),
      unit: (json['unit'] ?? '').toString(),
      commonTrigger: (json['common_trigger'] ?? '').toString(),
      commonTime: (json['common_time'] ?? '').toString(),
    );
  }
}

class UnhealthyHabitPlan {
  const UnhealthyHabitPlan({
    required this.dailyLimit,
    required this.weeklyLimit,
    required this.targetQuantity,
    required this.reductionPercentage,
    required this.cutoffTime,
    required this.planStage,
    required this.healthyReplacementRequired,
    required this.reminderTime,
  });

  final double? dailyLimit;
  final double? weeklyLimit;
  final double? targetQuantity;
  final double reductionPercentage;
  final String cutoffTime;
  final String planStage;
  final bool healthyReplacementRequired;
  final String reminderTime;

  factory UnhealthyHabitPlan.fromJson(dynamic value) {
    final json = asMap(value);
    return UnhealthyHabitPlan(
      dailyLimit: _nullableDouble(json['daily_limit']),
      weeklyLimit: _nullableDouble(json['weekly_limit']),
      targetQuantity: _nullableDouble(json['target_quantity']),
      reductionPercentage: _double(json['reduction_percentage']),
      cutoffTime: (json['cutoff_time'] ?? '').toString(),
      planStage: (json['plan_stage'] ?? '').toString(),
      healthyReplacementRequired: json['healthy_replacement_required'] == true,
      reminderTime: (json['reminder_time'] ?? '').toString(),
    );
  }
}

class UnhealthyHabitProgress {
  const UnhealthyHabitProgress({
    required this.todayValue,
    required this.weekValue,
    required this.dailyLimit,
    required this.weeklyLimit,
    required this.adherencePercent,
    required this.improvementPercent,
    required this.relapseCount,
    required this.topTrigger,
    required this.riskyHour,
    required this.supportMessage,
    required this.logsToday,
  });

  final double todayValue;
  final double weekValue;
  final double? dailyLimit;
  final double? weeklyLimit;
  final int adherencePercent;
  final int improvementPercent;
  final int relapseCount;
  final String topTrigger;
  final int? riskyHour;
  final String supportMessage;
  final List<UnhealthyHabitLog> logsToday;

  const factory UnhealthyHabitProgress.empty() = _EmptyProgress;

  factory UnhealthyHabitProgress.fromJson(dynamic value) {
    final json = asMap(value);
    return UnhealthyHabitProgress(
      todayValue: _double(json['today_value']),
      weekValue: _double(json['week_value']),
      dailyLimit: _nullableDouble(json['daily_limit']),
      weeklyLimit: _nullableDouble(json['weekly_limit']),
      adherencePercent: _int(json['adherence_percent']),
      improvementPercent: _int(json['improvement_percent']),
      relapseCount: _int(json['relapse_count']),
      topTrigger: (json['top_trigger'] ?? '').toString(),
      riskyHour: _nullableInt(json['risky_hour']),
      supportMessage: (json['support_message'] ?? '').toString(),
      logsToday: asMapList(json['logs_today'])
          .map(UnhealthyHabitLog.fromJson)
          .toList(growable: false),
    );
  }
}

class _EmptyProgress extends UnhealthyHabitProgress {
  const _EmptyProgress()
      : super(
          todayValue: 0,
          weekValue: 0,
          dailyLimit: null,
          weeklyLimit: null,
          adherencePercent: 0,
          improvementPercent: 0,
          relapseCount: 0,
          topTrigger: '',
          riskyHour: null,
          supportMessage: '',
          logsToday: const [],
        );
}

class UnhealthyHabitLog {
  const UnhealthyHabitLog({
    required this.id,
    required this.loggedAt,
    required this.quantity,
    required this.unit,
    required this.trigger,
    required this.isRelapse,
    required this.isWithinLimit,
    required this.caffeineMg,
    required this.caloriesKcal,
    required this.foodName,
  });

  final int id;
  final DateTime? loggedAt;
  final double quantity;
  final String unit;
  final String trigger;
  final bool isRelapse;
  final bool isWithinLimit;
  final double caffeineMg;
  final double caloriesKcal;
  final String foodName;

  factory UnhealthyHabitLog.fromJson(dynamic value) {
    final json = asMap(value);
    return UnhealthyHabitLog(
      id: _int(json['id']),
      loggedAt: DateTime.tryParse((json['logged_at'] ?? '').toString()),
      quantity: _double(json['quantity']),
      unit: (json['unit'] ?? '').toString(),
      trigger: (json['trigger'] ?? '').toString(),
      isRelapse: json['is_relapse'] == true,
      isWithinLimit: json['is_within_limit'] != false,
      caffeineMg: _double(json['caffeine_mg']),
      caloriesKcal: _double(json['calories_kcal']),
      foodName: (json['food_name'] ?? '').toString(),
    );
  }
}

class UnhealthyHabitReminder {
  const UnhealthyHabitReminder({
    required this.id,
    required this.timeOfDay,
    required this.message,
    required this.isActive,
  });

  final int id;
  final String timeOfDay;
  final String message;
  final bool isActive;

  factory UnhealthyHabitReminder.fromJson(dynamic value) {
    final json = asMap(value);
    return UnhealthyHabitReminder(
      id: _int(json['id']),
      timeOfDay: (json['time_of_day'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      isActive: json['is_active'] != false,
    );
  }
}

int _int(dynamic value) => _nullableInt(value) ?? 0;

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

double _double(dynamic value) => _nullableDouble(value) ?? 0;

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  return double.tryParse(value.toString());
}
