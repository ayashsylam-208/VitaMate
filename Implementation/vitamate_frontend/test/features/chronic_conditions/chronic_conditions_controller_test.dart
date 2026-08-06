import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/features/chronic_conditions/data/chronic_conditions_api.dart';
import 'package:vitamate/features/chronic_conditions/models/chronic_condition.dart';
import 'package:vitamate/features/chronic_conditions/state/chronic_conditions_controller.dart';

class _FakeChronicConditionsApi extends ChronicConditionsApi {
  _FakeChronicConditionsApi({
    required this.conditions,
    required this.catalog,
    this.createError,
    this.compactConditions,
  });

  final List<ChronicCondition> conditions;
  final List<ChronicCondition>? compactConditions;
  final List<ChronicConditionType> catalog;
  final Object? createError;

  @override
  Future<List<ChronicCondition>> getOverviewConditions({
    bool forceRefresh = false,
    bool guidanceOnly = false,
  }) async => compactConditions ?? conditions;

  @override
  Future<List<ChronicCondition>> getConditions({bool compact = false}) async =>
      compact ? (compactConditions ?? conditions) : conditions;

  @override
  Future<ChronicCondition> getCondition(int conditionId) async {
    return conditions.firstWhere((item) => item.id == conditionId);
  }

  @override
  Future<List<ChronicConditionType>> getConditionTypes() async => catalog;

  @override
  Future<ChronicCondition> createCondition({
    required int conditionTypeId,
    DateTime? diagnosisDate,
    required String severityCode,
    required String status,
    String notes = '',
    Map<String, dynamic> profileData = const {},
    bool isActive = true,
    List<ConditionTargetOverridePayload> targetOverrides = const [],
  }) async {
    if (createError != null) {
      throw createError!;
    }
    return conditions.first;
  }
}

void main() {
  test(
    'controller loads compact center first, then detail doses separately',
    () async {
      final api = _FakeChronicConditionsApi(
        conditions: [_sampleCondition()],
        compactConditions: [_sampleCompactCondition()],
        catalog: [_sampleConditionType()],
      );
      final controller = ChronicConditionsController(api: api);

      await controller.loadCenter();

      expect(controller.catalog, hasLength(1));
      expect(controller.conditions, hasLength(1));
      expect(controller.conditionForType(1)?.id, 4);
      expect(controller.todayDoses, isEmpty);
      expect(controller.pendingSchedules, 1);

      await controller.loadConditionDetail(4);
      await Future<void>.delayed(Duration.zero);

      expect(controller.todayDoses, hasLength(1));
      expect(controller.todayDoses.single.medication.name, 'Metformin');
      expect(controller.todayDoses.single.condition.conditionType.name, 'Diabetes');
    },
  );

  test(
    'controller exposes backend validation errors on condition creation',
    () async {
      final request = RequestOptions(path: '/api/chronic/user-conditions/');
      final controller = ChronicConditionsController(
        api: _FakeChronicConditionsApi(
          conditions: const [],
          catalog: [_sampleConditionType()],
          createError: DioException(
            requestOptions: request,
            response: Response(
              requestOptions: request,
              statusCode: 400,
              data: {
                'severity': ['severity is required.'],
              },
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      );

      final success = await controller.createCondition(
        conditionTypeId: 1,
        severityCode: '',
        status: 'active',
      );

      expect(success, isFalse);
      expect(controller.error, 'severity is required.');
    },
  );
}

ChronicConditionType _sampleConditionType() {
  return ChronicConditionType.fromJson({
    'id': 1,
    'code': 'diabetes',
    'slug': 'diabetes',
    'name': 'Diabetes',
    'display_name': 'Diabetes',
    'description': 'Sample condition type',
    'can_add': true,
    'is_active_for_user': false,
    'setup_fields': [],
    'measurement_types': ['glucose'],
    'supports_direct_daily_reading': true,
    'severity_options': [
      {
        'code': 'diabetes_managed',
        'label': 'Managed diabetes',
        'description': 'Sample severity',
      },
    ],
    'restrictions': [],
    'rule_profiles': [],
  });
}

ChronicCondition _sampleCondition() {
  return ChronicCondition.fromJson({
    'id': 4,
    'condition_type': {
      'id': 1,
      'code': 'diabetes',
      'slug': 'diabetes',
      'name': 'Diabetes',
      'display_name': 'Diabetes',
      'description': 'Sample condition type',
      'can_add': false,
      'is_active_for_user': true,
      'setup_fields': [],
      'measurement_types': ['glucose'],
      'supports_direct_daily_reading': true,
      'severity_options': [
        {
          'code': 'diabetes_managed',
          'label': 'Managed diabetes',
          'description': 'Sample severity',
        },
      ],
      'restrictions': [],
      'rule_profiles': [],
    },
    'diagnosis_date': '2026-04-11',
    'condition_status': 'active',
    'severity': 'diabetes_managed',
    'notes': 'Clinician approved current plan.',
    'profile_data': {'glucose_target': 110},
    'is_active': true,
    'targets': [],
    'evaluation': {
      'evaluation_date': '2026-04-11',
      'status': 'stable',
      'risk_flags': [],
      'medication_adherence_percent': 100,
      'restriction_adherence_percent': 100,
      'points_delta': 5,
      'streak_bonus': 0,
      'latest_recorded_at': '2026-04-11T08:30:00Z',
      'recommendations': [],
      'tracker_impacts': [],
      'targets': [],
    },
    'summary': {
      'condition_id': 4,
      'status': 'stable',
      'risk_flags': [],
      'latest_recorded_at': '2026-04-11T08:30:00Z',
      'recommendations': [],
      'tracker_impacts': [],
      'latest_reading': {
        'id': 91,
        'indicator_name': 'fasting_glucose',
        'indicator_type': 'glucose',
        'value': 110,
        'value_1': 110,
        'value_2': 0,
        'value_3': 0,
        'unit': 'mg/dL',
        'reading_context': 'fasting',
        'payload': {'glucose': 110},
        'classification': 'in_range',
        'risk_level': 'low',
        'recorded_at': '2026-04-11T08:30:00Z',
      },
      'alerts': [],
      'targets': [],
    },
    'medications': [
      {
        'id': 11,
        'name': 'Metformin',
        'scientific_name': 'Metformin',
        'dosage': '1 tablet',
        'dosage_amount': '1',
        'dosage_unit': 'tablet',
        'instructions': 'After breakfast',
        'relation_to_meal': 'after_meal',
        'recurrence_pattern': [0, 1, 2, 3, 4, 5, 6],
        'start_date': '2026-04-11',
        'end_date': '',
        'is_active': true,
        'reminder_enabled': true,
        'reminder_lead_minutes': 15,
        'schedules': [
          {
            'id': 21,
            'time_of_day': '08:00',
            'today_status': 'pending',
            'taken_at': '',
            'scheduled_for': '2026-04-11T08:00:00+03:00',
            'skip_reason': '',
            'reminder_enabled': true,
            'reminder_lead_minutes': 15,
            'recurrence_days': [0, 1, 2, 3, 4, 5, 6],
            'is_scheduled_today': true,
          },
        ],
      },
    ],
    'indicator_records': [],
    'alerts': [],
    'constraint_summary': ['Unsweetened drinks are preferred for hydration.'],
    'daily_medication_count': 1,
    'daily_pending_doses': 1,
    'disclaimer': 'Supportive self-management only.',
  });
}

ChronicCondition _sampleCompactCondition() {
  return ChronicCondition.fromJson({
    'view': 'compact',
    'id': 4,
    'condition_type': {
      'id': 1,
      'code': 'diabetes',
      'slug': 'diabetes',
      'name': 'Diabetes',
      'display_name': 'Diabetes',
      'description': 'Sample condition type',
      'can_add': false,
      'is_active_for_user': true,
      'setup_fields': [],
      'measurement_types': ['glucose'],
      'supports_direct_daily_reading': true,
      'severity_options': [
        {
          'code': 'diabetes_managed',
          'label': 'Managed diabetes',
          'description': 'Sample severity',
        },
      ],
      'restrictions': [],
      'rule_profiles': [],
    },
    'diagnosis_date': '2026-04-11',
    'condition_status': 'active',
    'severity': 'diabetes_managed',
    'notes': 'Clinician approved current plan.',
    'profile_data': {'glucose_target': 110},
    'is_active': true,
    'daily_medication_count': 1,
    'daily_pending_doses': 1,
    'open_alerts_count': 0,
    'evaluation_status': 'stable',
    'summary_status_label': 'In range',
    'summary_subtitle': 'Last glucose reading recorded',
    'summary_line': '110 mg/dL',
    'secondary_summary_line':
        'Open the tracking view for readings, targets, and guidance.',
    'latest_reading': {
      'id': 91,
      'indicator_name': 'fasting_glucose',
      'indicator_type': 'glucose',
      'value': 110,
      'value_1': 110,
      'value_2': 0,
      'value_3': 0,
      'unit': 'mg/dL',
      'reading_context': 'fasting',
      'payload': {'glucose': 110},
      'classification': 'in_range',
      'risk_level': 'low',
      'recorded_at': '2026-04-11T08:30:00Z',
    },
    'latest_recorded_at': '2026-04-11T08:30:00Z',
    'disclaimer': 'Supportive self-management only.',
  });
}
