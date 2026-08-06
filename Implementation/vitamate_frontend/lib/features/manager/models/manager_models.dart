Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
}

String _string(dynamic value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _int(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _double(dynamic value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _bool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  return fallback;
}

DateTime? _date(dynamic value) => DateTime.tryParse(value?.toString() ?? '');

class ManagerOverview {
  const ManagerOverview({
    required this.user,
    required this.profile,
    required this.myDay,
    required this.motivation,
    required this.goalsPreview,
    required this.notifications,
    required this.medical,
    required this.privacy,
    required this.quickActions,
    required this.updatedAt,
  });

  final ManagerUser user;
  final ManagerHealthProfile profile;
  final ManagerDay myDay;
  final ManagerMotivation motivation;
  final List<ManagerGoal> goalsPreview;
  final ManagerNotificationSummary notifications;
  final ManagerMedicalSummary medical;
  final ManagerPrivacySummary privacy;
  final List<ManagerQuickAction> quickActions;
  final DateTime? updatedAt;

  factory ManagerOverview.fromJson(Map<String, dynamic> json) {
    final data = _map(json['data'] ?? json);
    return ManagerOverview(
      user: ManagerUser.fromJson(_map(data['user'])),
      profile: ManagerHealthProfile.fromJson(_map(data['profile'])),
      myDay: ManagerDay.fromJson(_map(data['my_day'])),
      motivation: ManagerMotivation.fromJson(_map(data['motivation'])),
      goalsPreview: _list(
        data['goals_preview'],
      ).map((item) => ManagerGoal.fromJson(_map(item))).toList(growable: false),
      notifications: ManagerNotificationSummary.fromJson(
        _map(data['notifications']),
      ),
      medical: ManagerMedicalSummary.fromJson(_map(data['medical'])),
      privacy: ManagerPrivacySummary.fromJson(_map(data['privacy'])),
      quickActions: _list(data['quick_actions'])
          .map((item) => ManagerQuickAction.fromJson(_map(item)))
          .toList(growable: false),
      updatedAt: _date(data['updated_at']),
    );
  }
}

class ManagerUser {
  const ManagerUser({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.pendingEmail,
    required this.emailVerified,
    required this.avatarUrl,
    required this.preferredLanguage,
    required this.region,
  });

  final String username;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String pendingEmail;
  final bool emailVerified;
  final String avatarUrl;
  final String preferredLanguage;
  final String region;

  factory ManagerUser.fromJson(Map<String, dynamic> json) {
    return ManagerUser(
      username: _string(json['username']),
      firstName: _string(json['first_name']),
      lastName: _string(json['last_name']),
      fullName: _string(json['full_name'], _string(json['username'], 'User')),
      email: _string(json['email']),
      pendingEmail: _string(json['pending_email']),
      emailVerified: _bool(json['email_verified']),
      avatarUrl: _string(json['avatar_url']),
      preferredLanguage: _string(json['preferred_language'], 'English'),
      region: _string(json['region'], 'Romania'),
    );
  }

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    final value = '$first$last'.trim();
    if (value.isNotEmpty) return value.toUpperCase();
    return username.isEmpty ? 'V' : username[0].toUpperCase();
  }
}

class ManagerHealthProfile {
  const ManagerHealthProfile({
    required this.birthDate,
    required this.gender,
    required this.genderConfirmed,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.goal,
    required this.bmi,
    required this.bmr,
    required this.dailyCalorieTarget,
    required this.dailyWaterTargetMl,
    required this.dailyStepGoal,
    required this.recommendedSleepHours,
  });

  final DateTime? birthDate;
  final String gender;
  final bool genderConfirmed;
  final double height;
  final double weight;
  final double activityLevel;
  final String goal;
  final double bmi;
  final int bmr;
  final int dailyCalorieTarget;
  final int dailyWaterTargetMl;
  final int dailyStepGoal;
  final double recommendedSleepHours;

  factory ManagerHealthProfile.fromJson(Map<String, dynamic> json) {
    return ManagerHealthProfile(
      birthDate: _date(json['birth_date']),
      gender: _string(json['gender'], 'M'),
      genderConfirmed: _bool(json['gender_confirmed']),
      height: _double(json['height']),
      weight: _double(json['weight']),
      activityLevel: _double(json['activity_level'], 1.2),
      goal: _string(json['goal'], 'maintain'),
      bmi: _double(json['bmi']),
      bmr: _int(json['bmr']),
      dailyCalorieTarget: _int(json['daily_calorie_target']),
      dailyWaterTargetMl: _int(json['daily_water_target_ml']),
      dailyStepGoal: _int(json['daily_step_goal']),
      recommendedSleepHours: _double(json['recommended_sleep_hours'], 8),
    );
  }
}

class ManagerDay {
  const ManagerDay({
    required this.score,
    required this.progressPercent,
    required this.completedGoals,
    required this.totalGoals,
    required this.message,
    required this.focus,
  });

  final int score;
  final int progressPercent;
  final int completedGoals;
  final int totalGoals;
  final String message;
  final ManagerFocus focus;

  factory ManagerDay.fromJson(Map<String, dynamic> json) {
    return ManagerDay(
      score: _int(json['score']).clamp(0, 100).toInt(),
      progressPercent: _int(json['progress_percent']).clamp(0, 100).toInt(),
      completedGoals: _int(json['completed_goals']),
      totalGoals: _int(json['total_goals']),
      message: _string(json['message'], 'Keep your day balanced.'),
      focus: ManagerFocus.fromJson(_map(json['focus'])),
    );
  }
}

class ManagerFocus {
  const ManagerFocus({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.progressPercent,
    required this.rewardPoints,
    required this.route,
  });

  final String kind;
  final String title;
  final String subtitle;
  final int progressPercent;
  final int rewardPoints;
  final String route;

  factory ManagerFocus.fromJson(Map<String, dynamic> json) {
    return ManagerFocus(
      kind: _string(json['kind']),
      title: _string(json['title'], 'Choose one healthy action'),
      subtitle: _string(
        json['subtitle'],
        'Small progress keeps your plan moving.',
      ),
      progressPercent: _int(json['progress_percent']).clamp(0, 100).toInt(),
      rewardPoints: _int(json['reward_points']),
      route: _string(json['route']),
    );
  }
}

class ManagerMotivation {
  const ManagerMotivation({
    required this.totalPoints,
    required this.dailyPoints,
    required this.level,
    required this.levelName,
    required this.currentStreak,
    required this.missionsCompleted,
    required this.missionsTotal,
  });

  final int totalPoints;
  final int dailyPoints;
  final int level;
  final String levelName;
  final int currentStreak;
  final int missionsCompleted;
  final int missionsTotal;

  factory ManagerMotivation.fromJson(Map<String, dynamic> json) {
    return ManagerMotivation(
      totalPoints: _int(json['total_points']),
      dailyPoints: _int(json['daily_points']),
      level: _int(json['level'], 1).clamp(1, 999).toInt(),
      levelName: _string(json['level_name'], 'Beginner'),
      currentStreak: _int(json['current_streak']),
      missionsCompleted: _int(json['missions_completed']),
      missionsTotal: _int(json['missions_total']),
    );
  }

  int get levelProgressPercent {
    final levelFloor = (level - 1) * 1000;
    final withinLevel = totalPoints - levelFloor;
    return ((withinLevel.clamp(0, 1000) / 1000) * 100).round();
  }
}

class ManagerGoal {
  const ManagerGoal({
    required this.key,
    required this.label,
    required this.icon,
    required this.category,
    required this.route,
    required this.unit,
    required this.currentValue,
    required this.recommendedValue,
    required this.customValue,
    required this.effectiveValue,
    required this.source,
    required this.sourceLabel,
    required this.progressPercent,
    required this.isComplete,
  });

  final String key;
  final String label;
  final String icon;
  final String category;
  final String route;
  final String unit;
  final double currentValue;
  final double recommendedValue;
  final double? customValue;
  final double effectiveValue;
  final String source;
  final String sourceLabel;
  final int progressPercent;
  final bool isComplete;

  factory ManagerGoal.fromJson(Map<String, dynamic> json) {
    return ManagerGoal(
      key: _string(json['key']),
      label: _string(json['label']),
      icon: _string(json['icon']),
      category: _string(json['category']),
      route: _string(json['route']),
      unit: _string(json['unit']),
      currentValue: _double(json['current_value']),
      recommendedValue: _double(json['recommended_value']),
      customValue: json['custom_value'] == null
          ? null
          : _double(json['custom_value']),
      effectiveValue: _double(json['effective_value']),
      source: _string(json['source']),
      sourceLabel: _string(json['source_label']),
      progressPercent: _int(json['progress_percent']).clamp(0, 100).toInt(),
      isComplete: _bool(json['is_complete']),
    );
  }

  String get valueLabel {
    final value = effectiveValue % 1 == 0
        ? effectiveValue.round().toString()
        : effectiveValue.toStringAsFixed(1);
    return '$value $unit';
  }

  String get progressLabel {
    final current = currentValue % 1 == 0
        ? currentValue.round().toString()
        : currentValue.toStringAsFixed(1);
    final target = effectiveValue % 1 == 0
        ? effectiveValue.round().toString()
        : effectiveValue.toStringAsFixed(1);
    return '$current / $target $unit';
  }
}

class ManagerNotificationSummary {
  const ManagerNotificationSummary({
    required this.enabled,
    required this.quietHoursEnabled,
    required this.activeDevices,
    required this.preferences,
  });

  final bool enabled;
  final bool quietHoursEnabled;
  final int activeDevices;
  final Map<String, dynamic> preferences;

  factory ManagerNotificationSummary.fromJson(Map<String, dynamic> json) {
    return ManagerNotificationSummary(
      enabled: _bool(json['enabled']),
      quietHoursEnabled: _bool(json['quiet_hours_enabled']),
      activeDevices: _int(json['active_devices']),
      preferences: _map(json['preferences']),
    );
  }
}

class ManagerMedicalSummary {
  const ManagerMedicalSummary({
    required this.activeConditions,
    required this.activeMedications,
    required this.healthIndicators,
    required this.manualMedications,
    required this.conditionLabels,
  });

  final int activeConditions;
  final int activeMedications;
  final int healthIndicators;
  final int manualMedications;
  final List<String> conditionLabels;

  factory ManagerMedicalSummary.fromJson(Map<String, dynamic> json) {
    return ManagerMedicalSummary(
      activeConditions: _int(json['active_conditions']),
      activeMedications: _int(json['active_medications']),
      healthIndicators: _int(json['health_indicators']),
      manualMedications: _int(json['manual_medications']),
      conditionLabels: _list(
        json['condition_labels'],
      ).map((item) => item.toString()).toList(growable: false),
    );
  }
}

class ManagerPrivacySummary {
  const ManagerPrivacySummary({
    required this.permissions,
    required this.latestExport,
    required this.accountDeletion,
  });

  final Map<String, dynamic> permissions;
  final Map<String, dynamic>? latestExport;
  final Map<String, dynamic>? accountDeletion;

  factory ManagerPrivacySummary.fromJson(Map<String, dynamic> json) {
    final export = _map(json['latest_export']);
    final deletion = _map(json['account_deletion']);
    return ManagerPrivacySummary(
      permissions: _map(json['permissions']),
      latestExport: export.isEmpty ? null : export,
      accountDeletion: deletion.isEmpty ? null : deletion,
    );
  }
}

class ManagerQuickAction {
  const ManagerQuickAction({
    required this.key,
    required this.title,
    required this.route,
    required this.icon,
  });

  final String key;
  final String title;
  final String route;
  final String icon;

  factory ManagerQuickAction.fromJson(Map<String, dynamic> json) {
    return ManagerQuickAction(
      key: _string(json['key']),
      title: _string(json['title']),
      route: _string(json['route']),
      icon: _string(json['icon']),
    );
  }
}

class ManagerDevice {
  const ManagerDevice({
    required this.id,
    required this.platform,
    required this.timezone,
    required this.appVersion,
    required this.isPrimary,
    required this.notificationsAuthorized,
    required this.lastSeenAt,
  });

  final int id;
  final String platform;
  final String timezone;
  final String appVersion;
  final bool isPrimary;
  final bool notificationsAuthorized;
  final DateTime? lastSeenAt;

  factory ManagerDevice.fromJson(Map<String, dynamic> json) {
    return ManagerDevice(
      id: _int(json['id']),
      platform: _string(json['platform'], 'android'),
      timezone: _string(json['timezone']),
      appVersion: _string(json['app_version']),
      isPrimary: _bool(json['is_primary']),
      notificationsAuthorized: _bool(json['notifications_authorized']),
      lastSeenAt: _date(json['last_seen_at']),
    );
  }
}

class ManagerSecurity {
  const ManagerSecurity({
    required this.email,
    required this.pendingEmail,
    required this.emailVerified,
    required this.activeSessions,
    required this.devices,
  });

  final String email;
  final String pendingEmail;
  final bool emailVerified;
  final int activeSessions;
  final List<ManagerDevice> devices;

  factory ManagerSecurity.fromJson(Map<String, dynamic> json) {
    final data = _map(json['data'] ?? json);
    return ManagerSecurity(
      email: _string(data['email']),
      pendingEmail: _string(data['pending_email']),
      emailVerified: _bool(data['email_verified']),
      activeSessions: _int(data['active_sessions'], 1),
      devices: _list(data['devices'])
          .map((item) => ManagerDevice.fromJson(_map(item)))
          .toList(growable: false),
    );
  }
}
