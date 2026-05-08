class ConditionSeverityOption {
  final String code;
  final String label;
  final String description;

  const ConditionSeverityOption({
    required this.code,
    required this.label,
    required this.description,
  });

  factory ConditionSeverityOption.fromJson(Map<String, dynamic> json) {
    return ConditionSeverityOption(
      code: _asString(json['code']),
      label: _asString(json['label']),
      description: _asString(json['description']),
    );
  }
}

class ConditionSetupField {
  final String key;
  final String label;
  final String type;
  final String unit;
  final bool required;

  const ConditionSetupField({
    required this.key,
    required this.label,
    required this.type,
    required this.unit,
    required this.required,
  });

  factory ConditionSetupField.fromJson(Map<String, dynamic> json) {
    return ConditionSetupField(
      key: _asString(json['key']),
      label: _asString(json['label']),
      type: _asString(json['type']),
      unit: _asString(json['unit']),
      required: _asBool(json['required']),
    );
  }
}

class ConditionRestriction {
  final int id;
  final String severityCode;
  final String title;
  final String category;
  final String metricKey;
  final String evaluationMode;
  final String unit;
  final double? minRequiredValue;
  final double? maxAllowedValue;
  final String guidance;
  final String evidenceSource;

  const ConditionRestriction({
    required this.id,
    required this.severityCode,
    required this.title,
    required this.category,
    required this.metricKey,
    required this.evaluationMode,
    required this.unit,
    required this.minRequiredValue,
    required this.maxAllowedValue,
    required this.guidance,
    required this.evidenceSource,
  });

  factory ConditionRestriction.fromJson(Map<String, dynamic> json) {
    return ConditionRestriction(
      id: _asInt(json['id']),
      severityCode: _asString(json['severity_code']),
      title: _asString(json['title']),
      category: _asString(json['category']),
      metricKey: _asString(json['metric_key']),
      evaluationMode: _asString(json['evaluation_mode']),
      unit: _asString(json['unit']),
      minRequiredValue: _asNullableDouble(json['min_required_value']),
      maxAllowedValue: _asNullableDouble(json['max_allowed_value']),
      guidance: _asString(json['guidance']),
      evidenceSource: _asString(json['evidence_source']),
    );
  }
}

class ConditionRuleProfile {
  final int id;
  final String severityCode;
  final String ruleKey;
  final String ruleValue;
  final String ruleUnit;
  final String sourceLabel;
  final String sourceVersion;

  const ConditionRuleProfile({
    required this.id,
    required this.severityCode,
    required this.ruleKey,
    required this.ruleValue,
    required this.ruleUnit,
    required this.sourceLabel,
    required this.sourceVersion,
  });

  factory ConditionRuleProfile.fromJson(Map<String, dynamic> json) {
    return ConditionRuleProfile(
      id: _asInt(json['id']),
      severityCode: _asString(json['severity_code']),
      ruleKey: _asString(json['rule_key']),
      ruleValue: _asString(json['rule_value']),
      ruleUnit: _asString(json['rule_unit']),
      sourceLabel: _asString(json['source_label']),
      sourceVersion: _asString(json['source_version']),
    );
  }
}

class ChronicConditionType {
  final int id;
  final String code;
  final String slug;
  final String name;
  final String displayName;
  final String description;
  final bool canAdd;
  final bool isActiveForUser;
  final List<ConditionSeverityOption> severityOptions;
  final List<ConditionRestriction> restrictions;
  final List<ConditionRuleProfile> ruleProfiles;
  final List<ConditionSetupField> setupFields;
  final List<String> measurementTypes;
  final bool supportsDirectDailyReading;

  const ChronicConditionType({
    required this.id,
    required this.code,
    required this.slug,
    required this.name,
    required this.displayName,
    required this.description,
    required this.canAdd,
    required this.isActiveForUser,
    required this.severityOptions,
    required this.restrictions,
    required this.ruleProfiles,
    required this.setupFields,
    required this.measurementTypes,
    required this.supportsDirectDailyReading,
  });

  factory ChronicConditionType.fromJson(Map<String, dynamic> json) {
    final setupSchema = _asMap(json['setup_schema']);
    return ChronicConditionType(
      id: _asInt(json['id']),
      code: _asString(json['code']),
      slug: _asString(json['slug']).isNotEmpty
          ? _asString(json['slug'])
          : _asString(json['code']),
      name: _asString(json['name']).isNotEmpty
          ? _asString(json['name'])
          : _asString(json['display_name']),
      displayName: _asString(json['display_name']).isNotEmpty
          ? _asString(json['display_name'])
          : _asString(json['name']),
      description: _asString(json['description']),
      canAdd: _asBool(json['can_add'], fallback: true),
      isActiveForUser: _asBool(json['is_active_for_user']),
      severityOptions: _asMapList(
        json['severity_options'],
      ).map(ConditionSeverityOption.fromJson).toList(),
      restrictions: _asMapList(
        json['restrictions'],
      ).map(ConditionRestriction.fromJson).toList(),
      ruleProfiles: _asMapList(
        json['rule_profiles'],
      ).map(ConditionRuleProfile.fromJson).toList(),
      setupFields:
          (_asMapList(json['setup_fields']).isNotEmpty
                  ? _asMapList(json['setup_fields'])
                  : _asMapList(setupSchema['setup_fields']))
              .map(ConditionSetupField.fromJson)
              .toList(),
      measurementTypes: _asStringList(
        (json['measurement_types'] is List &&
                (json['measurement_types'] as List).isNotEmpty)
            ? json['measurement_types']
            : setupSchema['measurement_types'],
      ),
      supportsDirectDailyReading: _asBool(
        json['supports_direct_daily_reading'],
        fallback: _asBool(setupSchema['supports_direct_daily_reading']),
      ),
    );
  }

  String get label => displayName.isNotEmpty ? displayName : name;
  String get uiLabel {
    if (slug == 'dyslipidemia' || code == 'hyperlipidemia') {
      return 'Cholesterol';
    }
    return label;
  }

  String labelForSeverity(String severityCode) {
    for (final option in severityOptions) {
      if (option.code == severityCode) return option.label;
    }
    return severityCode;
  }
}

class ChronicTargetResult {
  final int id;
  final String targetKey;
  final String targetName;
  final String category;
  final String metricKey;
  final String evaluationMode;
  final String status;
  final String unit;
  final double? minValue;
  final double? maxValue;
  final double? currentValue;
  final String sourceType;
  final int priority;
  final String guidance;
  final String evidenceSource;
  final bool isScored;

  const ChronicTargetResult({
    required this.id,
    required this.targetKey,
    required this.targetName,
    required this.category,
    required this.metricKey,
    required this.evaluationMode,
    required this.status,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    required this.currentValue,
    required this.sourceType,
    required this.priority,
    required this.guidance,
    required this.evidenceSource,
    required this.isScored,
  });

  factory ChronicTargetResult.fromJson(Map<String, dynamic> json) {
    return ChronicTargetResult(
      id: _asInt(json['id']),
      targetKey: _asString(json['target_key']),
      targetName: _asString(json['target_name']),
      category: _asString(json['category']),
      metricKey: _asString(json['metric_key']),
      evaluationMode: _asString(json['evaluation_mode']),
      status: _asString(json['status']),
      unit: _asString(json['unit']),
      minValue: _asNullableDouble(json['min_value']),
      maxValue: _asNullableDouble(json['max_value']),
      currentValue: _asNullableDouble(
        json['current_value'] ?? json['last_evaluated_value'],
      ),
      sourceType: _asString(json['source_type']),
      priority: _asInt(json['priority']),
      guidance: _asString(json['guidance']),
      evidenceSource: _asString(json['evidence_source']),
      isScored: _asBool(json['is_scored']),
    );
  }

  bool get needsAttention => status != 'within_target';
}

class ConditionRecommendation {
  final String code;
  final String message;

  const ConditionRecommendation({required this.code, required this.message});

  factory ConditionRecommendation.fromJson(Map<String, dynamic> json) {
    return ConditionRecommendation(
      code: _asString(json['code']),
      message: _asString(json['message']),
    );
  }
}

class ChronicEvaluation {
  final String evaluationDate;
  final String status;
  final List<String> riskFlags;
  final double medicationAdherencePercent;
  final double restrictionAdherencePercent;
  final int pointsDelta;
  final int streakBonus;
  final String latestRecordedAt;
  final List<ConditionRecommendation> recommendations;
  final List<Map<String, dynamic>> trackerImpacts;
  final List<ChronicTargetResult> targets;

  const ChronicEvaluation({
    required this.evaluationDate,
    required this.status,
    required this.riskFlags,
    required this.medicationAdherencePercent,
    required this.restrictionAdherencePercent,
    required this.pointsDelta,
    required this.streakBonus,
    required this.latestRecordedAt,
    required this.recommendations,
    required this.trackerImpacts,
    required this.targets,
  });

  factory ChronicEvaluation.fromJson(Map<String, dynamic> json) {
    return ChronicEvaluation(
      evaluationDate: _asString(json['evaluation_date']),
      status: _asString(json['status']),
      riskFlags: _asStringList(json['risk_flags']),
      medicationAdherencePercent: _asDouble(
        json['medication_adherence_percent'],
      ),
      restrictionAdherencePercent: _asDouble(
        json['restriction_adherence_percent'],
      ),
      pointsDelta: _asInt(json['points_delta']),
      streakBonus: _asInt(json['streak_bonus']),
      latestRecordedAt: _asString(json['latest_recorded_at']),
      recommendations: _asMapList(
        json['recommendations'],
      ).map(ConditionRecommendation.fromJson).toList(),
      trackerImpacts: _asMapList(json['tracker_impacts']),
      targets: _asMapList(
        json['targets'],
      ).map(ChronicTargetResult.fromJson).toList(),
    );
  }
}

class MedicationSchedule {
  final int id;
  final String timeOfDay;
  final String todayStatus;
  final String takenAt;
  final String scheduledFor;
  final String skipReason;
  final bool reminderEnabled;
  final int reminderLeadMinutes;
  final List<int> recurrenceDays;
  final bool isScheduledToday;

  const MedicationSchedule({
    required this.id,
    required this.timeOfDay,
    required this.todayStatus,
    required this.takenAt,
    required this.scheduledFor,
    required this.skipReason,
    required this.reminderEnabled,
    required this.reminderLeadMinutes,
    required this.recurrenceDays,
    required this.isScheduledToday,
  });

  factory MedicationSchedule.fromJson(Map<String, dynamic> json) {
    return MedicationSchedule(
      id: _asInt(json['id']),
      timeOfDay: _asString(json['time_of_day']),
      todayStatus: _asString(json['today_status']),
      takenAt: _asString(json['taken_at']),
      scheduledFor: _asString(json['scheduled_for']),
      skipReason: _asString(json['skip_reason']),
      reminderEnabled: _asBool(json['reminder_enabled'], fallback: true),
      reminderLeadMinutes: _asInt(json['reminder_lead_minutes']),
      recurrenceDays: _asIntList(json['recurrence_days']),
      isScheduledToday: _asBool(json['is_scheduled_today'], fallback: true),
    );
  }

  bool get isPending => todayStatus == 'pending';
  bool get isSnoozed => todayStatus == 'snoozed';
}

class ChronicMedication {
  final int id;
  final String name;
  final String scientificName;
  final String dosage;
  final String dosageAmount;
  final String dosageUnit;
  final String instructions;
  final String relationToMeal;
  final List<int> recurrencePattern;
  final String startDate;
  final String endDate;
  final bool isActive;
  final bool reminderEnabled;
  final int reminderLeadMinutes;
  final List<MedicationSchedule> schedules;

  const ChronicMedication({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.dosage,
    required this.dosageAmount,
    required this.dosageUnit,
    required this.instructions,
    required this.relationToMeal,
    required this.recurrencePattern,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.reminderEnabled,
    required this.reminderLeadMinutes,
    required this.schedules,
  });

  factory ChronicMedication.fromJson(Map<String, dynamic> json) {
    return ChronicMedication(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      scientificName: _asString(json['scientific_name']),
      dosage: _asString(json['dosage']),
      dosageAmount: _asString(json['dosage_amount']),
      dosageUnit: _asString(json['dosage_unit']),
      instructions: _asString(json['instructions']),
      relationToMeal: _asString(json['relation_to_meal']),
      recurrencePattern: _asIntList(json['recurrence_pattern']),
      startDate: _asString(json['start_date']),
      endDate: _asString(json['end_date']),
      isActive: _asBool(json['is_active'], fallback: true),
      reminderEnabled: _asBool(json['reminder_enabled'], fallback: true),
      reminderLeadMinutes: _asInt(json['reminder_lead_minutes']),
      schedules: _asMapList(
        json['schedules'],
      ).map(MedicationSchedule.fromJson).toList(),
    );
  }

  int get pendingScheduleCount => schedules
      .where((schedule) => schedule.isScheduledToday && schedule.isPending)
      .length;

  String get dosageLabel {
    if (dosage.isNotEmpty) return dosage;
    final parts = <String>[
      if (dosageAmount.isNotEmpty) dosageAmount,
      if (dosageUnit.isNotEmpty) dosageUnit,
    ];
    return parts.join(' ').trim();
  }
}

class ConditionAlertItem {
  final int id;
  final String code;
  final String level;
  final String message;
  final String alertType;
  final String status;
  final String createdAt;

  const ConditionAlertItem({
    required this.id,
    required this.code,
    required this.level,
    required this.message,
    required this.alertType,
    required this.status,
    required this.createdAt,
  });

  factory ConditionAlertItem.fromJson(Map<String, dynamic> json) {
    return ConditionAlertItem(
      id: _asInt(json['id']),
      code: _asString(json['code']),
      level: _asString(json['level']),
      message: _asString(json['message']),
      alertType: _asString(json['alert_type']),
      status: _asString(json['status']),
      createdAt: _asString(json['created_at']),
    );
  }
}

class ConditionIndicatorRecord {
  final int id;
  final String indicatorName;
  final String indicatorType;
  final double value;
  final double value1;
  final double value2;
  final double value3;
  final String unit;
  final String readingContext;
  final Map<String, dynamic> payload;
  final String classification;
  final String riskLevel;
  final String recordedAt;

  const ConditionIndicatorRecord({
    required this.id,
    required this.indicatorName,
    required this.indicatorType,
    required this.value,
    required this.value1,
    required this.value2,
    required this.value3,
    required this.unit,
    required this.readingContext,
    required this.payload,
    required this.classification,
    required this.riskLevel,
    required this.recordedAt,
  });

  factory ConditionIndicatorRecord.fromJson(Map<String, dynamic> json) {
    return ConditionIndicatorRecord(
      id: _asInt(json['id']),
      indicatorName: _asString(json['indicator_name']),
      indicatorType: _asString(json['indicator_type']).isNotEmpty
          ? _asString(json['indicator_type'])
          : _asString(json['indicator_name']),
      value: _asDouble(json['value']),
      value1: _asDouble(json['value_1'] ?? json['value']),
      value2: _asDouble(json['value_2']),
      value3: _asDouble(json['value_3']),
      unit: _asString(json['unit']),
      readingContext: _asString(json['reading_context']),
      payload: _asMap(json['payload']),
      classification: _asString(json['classification']),
      riskLevel: _asString(json['risk_level']),
      recordedAt: _asString(json['recorded_at']),
    );
  }

  String get title {
    switch (indicatorType) {
      case 'glucose':
        return 'Glucose';
      case 'blood_pressure':
        return 'Blood pressure';
      case 'lipid_panel':
        return 'Cholesterol follow-up';
      default:
        return indicatorName;
    }
  }

  String get primaryValueLabel {
    if (indicatorType == 'blood_pressure') {
      final systolic = value1.toStringAsFixed(
        value1 == value1.roundToDouble() ? 0 : 1,
      );
      final diastolic = value2.toStringAsFixed(
        value2 == value2.roundToDouble() ? 0 : 1,
      );
      return '$systolic/$diastolic $unit'.trim();
    }
    if (indicatorType == 'lipid_panel') {
      final ldl = _asNullableDouble(payload['ldl']) ?? value1;
      return 'LDL ${ldl.toStringAsFixed(ldl == ldl.roundToDouble() ? 0 : 1)} $unit'
          .trim();
    }
    return '${value1.toStringAsFixed(value1 == value1.roundToDouble() ? 0 : 1)} $unit'
        .trim();
  }

  String get classificationLabel {
    switch (classification) {
      case 'in_range':
        return 'In range';
      case 'normal':
        return 'Normal';
      case 'controlled':
        return 'Controlled';
      case 'elevated':
        return 'Elevated';
      case 'high':
        return 'High';
      case 'low':
        return 'Low';
      case 'on_track':
        return 'On track';
      case 'needs_attention':
        return 'Needs attention';
      default:
        return classification.replaceAll('_', ' ');
    }
  }
}

class ConditionSummary {
  final int conditionId;
  final String status;
  final List<String> riskFlags;
  final String latestRecordedAt;
  final List<ConditionRecommendation> recommendations;
  final List<Map<String, dynamic>> trackerImpacts;
  final ConditionIndicatorRecord? latestReading;
  final List<ConditionAlertItem> alerts;
  final List<ChronicTargetResult> targets;

  const ConditionSummary({
    required this.conditionId,
    required this.status,
    required this.riskFlags,
    required this.latestRecordedAt,
    required this.recommendations,
    required this.trackerImpacts,
    required this.latestReading,
    required this.alerts,
    required this.targets,
  });

  factory ConditionSummary.fromJson(Map<String, dynamic> json) {
    final latestReadingMap = _asMap(json['latest_reading']);
    return ConditionSummary(
      conditionId: _asInt(json['condition_id']),
      status: _asString(json['status']),
      riskFlags: _asStringList(json['risk_flags']),
      latestRecordedAt: _asString(json['latest_recorded_at']),
      recommendations: _asMapList(
        json['recommendations'],
      ).map(ConditionRecommendation.fromJson).toList(),
      trackerImpacts: _asMapList(json['tracker_impacts']),
      latestReading: latestReadingMap.isEmpty
          ? null
          : ConditionIndicatorRecord.fromJson(latestReadingMap),
      alerts: _asMapList(
        json['alerts'],
      ).map(ConditionAlertItem.fromJson).toList(),
      targets: _asMapList(
        json['targets'],
      ).map(ChronicTargetResult.fromJson).toList(),
    );
  }
}

class ChronicCondition {
  final int id;
  final ChronicConditionType conditionType;
  final String diagnosisDate;
  final String status;
  final String severityCode;
  final String notes;
  final bool isActive;
  final bool hasDetailPayload;
  final Map<String, dynamic> profileData;
  final List<ChronicTargetResult> targets;
  final ChronicEvaluation evaluation;
  final List<ChronicMedication> medications;
  final List<ConditionIndicatorRecord> indicatorRecords;
  final List<ConditionAlertItem> alerts;
  final ConditionSummary? summary;
  final List<String> constraintSummary;
  final int dailyMedicationCount;
  final int dailyPendingDoses;
  final int openAlertsCountSnapshot;
  final ConditionIndicatorRecord? latestReadingSnapshot;
  final String latestRecordedAtSnapshot;
  final String summaryStatusLabelSnapshot;
  final String summarySubtitleSnapshot;
  final String summaryLineSnapshot;
  final String secondarySummaryLineSnapshot;
  final String disclaimer;

  const ChronicCondition({
    required this.id,
    required this.conditionType,
    required this.diagnosisDate,
    required this.status,
    required this.severityCode,
    required this.notes,
    required this.isActive,
    required this.hasDetailPayload,
    required this.profileData,
    required this.targets,
    required this.evaluation,
    required this.medications,
    required this.indicatorRecords,
    required this.alerts,
    required this.summary,
    required this.constraintSummary,
    required this.dailyMedicationCount,
    required this.dailyPendingDoses,
    required this.openAlertsCountSnapshot,
    required this.latestReadingSnapshot,
    required this.latestRecordedAtSnapshot,
    required this.summaryStatusLabelSnapshot,
    required this.summarySubtitleSnapshot,
    required this.summaryLineSnapshot,
    required this.secondarySummaryLineSnapshot,
    required this.disclaimer,
  });

  factory ChronicCondition.fromJson(Map<String, dynamic> json) {
    final summaryMap = _asMap(json['summary']);
    final latestReadingMap = _asMap(json['latest_reading']);
    final isCompact = _asString(json['view']) == 'compact';
    return ChronicCondition(
      id: _asInt(json['id']),
      conditionType: ChronicConditionType.fromJson(
        _asMap(json['condition_type']),
      ),
      diagnosisDate: _asString(json['diagnosis_date']),
      status: _asString(json['condition_status']).isNotEmpty
          ? _asString(json['condition_status'])
          : _asString(json['status']),
      severityCode: _asString(json['severity']).isNotEmpty
          ? _asString(json['severity'])
          : _asString(json['severity_code']),
      notes: _asString(json['notes']),
      isActive: _asBool(json['is_active'], fallback: true),
      hasDetailPayload: !isCompact,
      profileData: _asMap(json['profile_data']),
      targets: _asMapList(
        json['targets'],
      ).map(ChronicTargetResult.fromJson).toList(),
      evaluation: ChronicEvaluation.fromJson({
        ..._asMap(json['evaluation']),
        if (_asMap(json['evaluation']).isEmpty &&
            _asString(json['evaluation_status']).isNotEmpty)
          'status': _asString(json['evaluation_status']),
        if (_asMap(json['evaluation']).isEmpty &&
            _asString(json['latest_recorded_at']).isNotEmpty)
          'latest_recorded_at': _asString(json['latest_recorded_at']),
      }),
      medications: _asMapList(
        json['medications'],
      ).map(ChronicMedication.fromJson).toList(),
      indicatorRecords: _asMapList(
        json['indicator_records'],
      ).map(ConditionIndicatorRecord.fromJson).toList(),
      alerts: _asMapList(
        json['alerts'],
      ).map(ConditionAlertItem.fromJson).toList(),
      summary: summaryMap.isEmpty
          ? null
          : ConditionSummary.fromJson(summaryMap),
      constraintSummary: _asStringList(json['constraint_summary']),
      dailyMedicationCount: _asInt(json['daily_medication_count']),
      dailyPendingDoses: _asInt(json['daily_pending_doses']),
      openAlertsCountSnapshot: _asInt(json['open_alerts_count']),
      latestReadingSnapshot: latestReadingMap.isEmpty
          ? null
          : ConditionIndicatorRecord.fromJson(latestReadingMap),
      latestRecordedAtSnapshot: _asString(json['latest_recorded_at']),
      summaryStatusLabelSnapshot: _asString(json['summary_status_label']),
      summarySubtitleSnapshot: _asString(json['summary_subtitle']),
      summaryLineSnapshot: _asString(json['summary_line']),
      secondarySummaryLineSnapshot: _asString(
        json['secondary_summary_line'],
      ),
      disclaimer: _asString(json['disclaimer']),
    );
  }

  String get severityLabel => conditionType.labelForSeverity(severityCode);

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Active';
      case 'controlled':
        return 'Controlled';
      case 'needs_attention':
        return 'Needs attention';
      case 'inactive':
        return 'Inactive';
      default:
        return status;
    }
  }

  int get pendingMedicationCount => medications.fold<int>(
    0,
    (sum, medication) => sum + medication.pendingScheduleCount,
  );

  int get openAlertsCount {
    if (alerts.isNotEmpty) {
      return alerts.where((alert) => alert.status == 'open').length;
    }
    return openAlertsCountSnapshot;
  }

  bool get needsAttention =>
      evaluation.status == 'attention_needed' ||
      evaluation.status == 'critical' ||
      {
        'needs attention',
        'high',
        'low',
        'elevated',
      }.contains(summaryStatusLabelSnapshot.toLowerCase());

  ConditionIndicatorRecord? get latestReading {
    final summaryReading = summary?.latestReading;
    if (summaryReading != null) {
      return summaryReading;
    }
    if (indicatorRecords.isNotEmpty) {
      return indicatorRecords.first;
    }
    if (latestReadingSnapshot != null) {
      return latestReadingSnapshot;
    }
    return null;
  }

  String get uiLabel => conditionType.uiLabel;

  String get summaryStatusLabel {
    if (summaryStatusLabelSnapshot.isNotEmpty) {
      return summaryStatusLabelSnapshot;
    }
    final latest = latestReading;
    if (latest != null && latest.classification.isNotEmpty) {
      if (conditionType.slug == 'hypertension') {
        switch (latest.classification) {
          case 'in_range':
          case 'controlled':
            return 'Controlled';
          case 'elevated':
            return 'Elevated';
          case 'high':
          case 'critical':
            return 'High';
        }
      }
      if (conditionType.slug == 'diabetes') {
        switch (latest.classification) {
          case 'in_range':
          case 'normal':
            return 'In range';
          case 'low':
            return 'Low';
          case 'high':
          case 'elevated':
          case 'critical':
            return 'High';
        }
      }
      if (conditionType.slug == 'dyslipidemia') {
        switch (latest.classification) {
          case 'in_range':
          case 'normal':
          case 'controlled':
          case 'on_track':
            return 'On track';
          default:
            return 'Needs attention';
        }
      }
      return latest.classificationLabel;
    }

    if (conditionType.slug == 'dyslipidemia') {
      return needsAttention ? 'Needs attention' : 'On track';
    }
    if (conditionType.slug == 'hypertension') {
      return needsAttention ? 'High' : 'Controlled';
    }
    if (conditionType.slug == 'diabetes') {
      return needsAttention ? 'High' : 'In range';
    }
    return statusLabel;
  }

  String get summarySubtitle {
    if (summarySubtitleSnapshot.isNotEmpty) {
      return summarySubtitleSnapshot;
    }
    switch (conditionType.slug) {
      case 'diabetes':
        return 'Last glucose reading recorded';
      case 'hypertension':
        return 'Last blood pressure reading recorded';
      case 'dyslipidemia':
        return 'Latest lipid follow-up recorded';
      default:
        return 'Latest condition update';
    }
  }

  String get summaryLine {
    if (summaryLineSnapshot.isNotEmpty) {
      return summaryLineSnapshot;
    }
    final latest = latestReading;
    if (latest != null) {
      return latest.primaryValueLabel;
    }
    if (conditionType.slug == 'dyslipidemia') {
      return 'Track follow-ups and nutrition-linked insights.';
    }
    if (conditionType.slug == 'hypertension') {
      return 'Track blood pressure and sodium-aware guidance.';
    }
    if (conditionType.slug == 'diabetes') {
      return 'Track glucose and daily care guidance.';
    }
    return 'Tracking summary not available yet.';
  }

  String get secondarySummaryLine {
    if (secondarySummaryLineSnapshot.isNotEmpty) {
      return secondarySummaryLineSnapshot;
    }
    if (summary?.recommendations.isNotEmpty == true) {
      return summary!.recommendations.first.message;
    }
    if (constraintSummary.isNotEmpty) {
      return constraintSummary.first;
    }
    if (conditionType.slug == 'dyslipidemia') {
      return 'Nutrition choices and follow-up targets stay connected.';
    }
    return 'Open the tracking view for readings, targets, and guidance.';
  }
}

class ChronicDoseEntry {
  final ChronicCondition condition;
  final ChronicMedication medication;
  final MedicationSchedule schedule;

  const ChronicDoseEntry({
    required this.condition,
    required this.medication,
    required this.schedule,
  });
}

class DoseActionResult {
  final int scheduleId;
  final String status;
  final String scheduledDate;
  final String takenAt;
  final String scheduledFor;
  final String skipReason;
  final int pointsApplied;

  const DoseActionResult({
    required this.scheduleId,
    required this.status,
    required this.scheduledDate,
    required this.takenAt,
    required this.scheduledFor,
    required this.skipReason,
    required this.pointsApplied,
  });

  factory DoseActionResult.fromJson(Map<String, dynamic> json) {
    return DoseActionResult(
      scheduleId: _asInt(json['schedule_id']),
      status: _asString(json['status']),
      scheduledDate: _asString(json['scheduled_date']),
      takenAt: _asString(json['taken_at']),
      scheduledFor: _asString(json['scheduled_for']),
      skipReason: _asString(json['skip_reason']),
      pointsApplied: _asInt(json['points_applied']),
    );
  }
}

class ConditionReadingResult {
  final String classification;
  final String riskLevel;
  final String status;
  final List<String> riskFlags;
  final List<Map<String, dynamic>> effectiveRestrictions;
  final List<Map<String, dynamic>> adjustedTargets;
  final List<Map<String, dynamic>> alerts;
  final List<ConditionRecommendation> recommendations;
  final int pointsDelta;

  const ConditionReadingResult({
    required this.classification,
    required this.riskLevel,
    required this.status,
    required this.riskFlags,
    required this.effectiveRestrictions,
    required this.adjustedTargets,
    required this.alerts,
    required this.recommendations,
    required this.pointsDelta,
  });

  factory ConditionReadingResult.fromJson(Map<String, dynamic> json) {
    final reading = _asMap(json['reading']);
    final evaluation = _asMap(json['evaluation']);
    return ConditionReadingResult(
      classification: _asString(reading['classification']),
      riskLevel: _asString(reading['risk_level']),
      status: _asString(evaluation['status']),
      riskFlags: _asStringList(evaluation['risk_flags']),
      effectiveRestrictions: _asMapList(json['effective_restrictions']),
      adjustedTargets: _asMapList(json['adjusted_targets']),
      alerts: _asMapList(json['alerts']),
      recommendations: _asMapList(
        json['recommendations'],
      ).map(ConditionRecommendation.fromJson).toList(),
      pointsDelta: _asInt(json['points_delta']),
    );
  }
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const <String>[];
}

List<int> _asIntList(dynamic value) {
  if (value is List) {
    return value.map(_asInt).toList();
  }
  return const <int>[];
}

String _asString(dynamic value) => value?.toString() ?? '';

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
  }
  return fallback;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
