import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../models/chronic_condition.dart';

class ChronicMedicationPayload {
  final int? medicationId;
  final int userConditionId;
  final String name;
  final String scientificName;
  final String dosage;
  final String dosageAmount;
  final String dosageUnit;
  final String instructions;
  final String relationToMeal;
  final List<int> recurrencePattern;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final bool reminderEnabled;
  final int reminderLeadMinutes;
  final List<ChronicMedicationSchedulePayload> schedules;

  const ChronicMedicationPayload({
    this.medicationId,
    required this.userConditionId,
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

  Map<String, dynamic> toJson() {
    return {
      'user_condition': userConditionId,
      'name': name,
      'scientific_name': scientificName,
      'dosage': dosage,
      'dosage_amount': dosageAmount,
      'dosage_unit': dosageUnit,
      'instructions': instructions,
      'relation_to_meal': relationToMeal,
      'recurrence_pattern': recurrencePattern,
      'start_date': _formatDate(startDate),
      'end_date': _formatDate(endDate),
      'is_active': isActive,
      'reminder_enabled': reminderEnabled,
      'reminder_lead_minutes': reminderLeadMinutes,
      'schedules': schedules.map((item) => item.toJson()).toList(),
    };
  }
}

class ChronicMedicationSchedulePayload {
  final String timeOfDay;
  final List<int> recurrenceDays;

  const ChronicMedicationSchedulePayload({
    required this.timeOfDay,
    required this.recurrenceDays,
  });

  Map<String, dynamic> toJson() {
    return {'time_of_day': timeOfDay, 'recurrence_days': recurrenceDays};
  }
}

class ConditionTargetOverridePayload {
  final String targetKey;
  final String targetName;
  final String category;
  final String metricKey;
  final String evaluationMode;
  final String unit;
  final double? minValue;
  final double? maxValue;
  final String sourceType;
  final String guidance;

  const ConditionTargetOverridePayload({
    required this.targetKey,
    required this.targetName,
    required this.category,
    required this.metricKey,
    required this.evaluationMode,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    required this.sourceType,
    required this.guidance,
  });

  Map<String, dynamic> toJson() {
    return {
      'target_key': targetKey,
      'target_name': targetName,
      'category': category,
      'metric_key': metricKey,
      'evaluation_mode': evaluationMode,
      'unit': unit,
      'min_value': minValue,
      'max_value': maxValue,
      'source_type': sourceType,
      'guidance': guidance,
    };
  }
}

class ChronicConditionsApi {
  const ChronicConditionsApi();

  Future<List<ChronicCondition>> getConditions() async {
    final res = await HttpClient.dio.get(ApiEndpoints.chronicUserConditions);
    return _readList(res.data)
        .map(
          (item) => ChronicCondition.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<ChronicConditionType>> getConditionTypes() async {
    final res = await HttpClient.dio.get(
      ApiEndpoints.chronicSupportedConditionTypes,
    );
    return _readList(res.data)
        .map(
          (item) =>
              ChronicConditionType.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<ConditionSummary> getConditionSummary(int conditionId) async {
    final res = await HttpClient.dio.get(
      '${ApiEndpoints.chronicUserConditions}$conditionId/summary/',
    );
    return ConditionSummary.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<List<ConditionIndicatorRecord>> getConditionReadings(
    int conditionId,
  ) async {
    final res = await HttpClient.dio.get(
      '${ApiEndpoints.chronicUserConditions}$conditionId/readings/',
    );
    return _readList(res.data)
        .map(
          (item) => ConditionIndicatorRecord.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> createCondition({
    required int conditionTypeId,
    DateTime? diagnosisDate,
    required String severityCode,
    required String status,
    String notes = '',
    Map<String, dynamic> profileData = const {},
    bool isActive = true,
    List<ConditionTargetOverridePayload> targetOverrides = const [],
  }) async {
    await HttpClient.dio.post(
      ApiEndpoints.chronicUserConditions,
      data: {
        'condition_type': conditionTypeId,
        'diagnosis_date': _formatDate(diagnosisDate),
        'condition_status': status,
        'status': status,
        'severity': severityCode,
        'severity_code': severityCode,
        'profile_data': profileData,
        'notes': notes,
        'is_active': isActive,
        'target_overrides': targetOverrides
            .map((item) => item.toJson())
            .toList(),
      },
    );
  }

  Future<void> updateCondition({
    required int conditionId,
    required int conditionTypeId,
    DateTime? diagnosisDate,
    required String severityCode,
    required String status,
    String notes = '',
    Map<String, dynamic> profileData = const {},
    bool isActive = true,
    List<ConditionTargetOverridePayload>? targetOverrides,
  }) async {
    final data = <String, dynamic>{
      'diagnosis_date': _formatDate(diagnosisDate),
      'condition_status': status,
      'severity_code': severityCode,
      'severity': severityCode,
      'status': status,
      'profile_data': profileData,
      'notes': notes,
      'is_active': isActive,
    };
    if (conditionTypeId > 0) {
      data['condition_type'] = conditionTypeId;
    }
    if (targetOverrides != null) {
      data['target_overrides'] = targetOverrides
          .map((item) => item.toJson())
          .toList();
    }
    await HttpClient.dio.patch(
      '${ApiEndpoints.chronicUserConditions}$conditionId/',
      data: data,
    );
  }

  Future<void> deactivateCondition(int conditionId) async {
    await HttpClient.dio.post(
      '${ApiEndpoints.chronicUserConditions}$conditionId/deactivate/',
    );
  }

  Future<ConditionReadingResult> logReading({
    required int conditionId,
    required Map<String, dynamic> payload,
  }) async {
    final res = await HttpClient.dio.post(
      '${ApiEndpoints.chronicUserConditions}$conditionId/readings/',
      data: payload,
    );
    return ConditionReadingResult.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<void> createMedication(ChronicMedicationPayload payload) async {
    await HttpClient.dio.post(
      ApiEndpoints.conditionMedications,
      data: payload.toJson(),
    );
  }

  Future<void> updateMedication(ChronicMedicationPayload payload) async {
    final id = payload.medicationId;
    if (id == null) {
      throw ArgumentError('medicationId is required for update.');
    }
    await HttpClient.dio.patch(
      '${ApiEndpoints.conditionMedications}$id/',
      data: payload.toJson(),
    );
  }

  Future<void> deactivateMedication(int medicationId) async {
    await HttpClient.dio.post(
      '${ApiEndpoints.conditionMedications}$medicationId/deactivate/',
    );
  }

  Future<List<Map<String, dynamic>>> getTodayDoseEntries() async {
    final res = await HttpClient.dio.get(
      '${ApiEndpoints.conditionMedicationSchedules}today/',
    );
    return _readList(res.data);
  }

  Future<DoseActionResult> markMedicationTaken(int scheduleId) async {
    final res = await HttpClient.dio.post(
      '${ApiEndpoints.conditionMedicationSchedules}$scheduleId/take/',
    );
    return DoseActionResult.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<DoseActionResult> markMedicationMissed(int scheduleId) async {
    final res = await HttpClient.dio.post(
      '${ApiEndpoints.conditionMedicationSchedules}$scheduleId/miss/',
    );
    return DoseActionResult.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<DoseActionResult> snoozeMedicationDose(
    int scheduleId, {
    required int snoozeMinutes,
  }) async {
    final res = await HttpClient.dio.post(
      '${ApiEndpoints.conditionMedicationSchedules}$scheduleId/snooze/',
      data: {'snooze_minutes': snoozeMinutes},
    );
    return DoseActionResult.fromJson(Map<String, dynamic>.from(res.data));
  }

  Future<DoseActionResult> skipMedicationDose(
    int scheduleId, {
    required String reason,
  }) async {
    final res = await HttpClient.dio.post(
      '${ApiEndpoints.conditionMedicationSchedules}$scheduleId/skip/',
      data: {'reason': reason},
    );
    return DoseActionResult.fromJson(Map<String, dynamic>.from(res.data));
  }

  List<Map<String, dynamic>> _readList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map && data['results'] is List) {
      return (data['results'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }
}

String? _formatDate(DateTime? value) {
  if (value == null) return null;
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
