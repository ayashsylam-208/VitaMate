import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/features/chronic_conditions/data/chronic_conditions_api.dart';
import 'package:vitamate/features/chronic_conditions/models/chronic_condition.dart';
import 'package:vitamate/features/chronic_conditions/screens/chronic_conditions_screen.dart';
import 'package:vitamate/features/chronic_conditions/state/chronic_conditions_controller.dart';

class _FakeChronicConditionsApi extends ChronicConditionsApi {
  _FakeChronicConditionsApi({
    required this.conditions,
    required this.catalog,
    this.compactConditions,
  });

  final List<ChronicCondition> conditions;
  final List<ChronicCondition>? compactConditions;
  final List<ChronicConditionType> catalog;

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
}

void main() {
  testWidgets('screen shows supported cards and no global add entry point', (
    WidgetTester tester,
  ) async {
    final controller = ChronicConditionsController(
      api: _FakeChronicConditionsApi(
        conditions: const [],
        catalog: _sampleCatalog(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: ChronicConditionsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conditions Center'), findsOneWidget);
    expect(
      find.textContaining('No chronic conditions added yet'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Diabetes'), 300);
    expect(find.text('Diabetes'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Hypertension'), 300);
    expect(find.text('Hypertension'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cholesterol'), 300);
    expect(find.text('Cholesterol'), findsOneWidget);
    expect(find.text('Add medication'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets(
    'opening an active card shows summary, readings, and medications',
    (WidgetTester tester) async {
      final controller = ChronicConditionsController(
        api: _FakeChronicConditionsApi(
          conditions: [_sampleCondition()],
          compactConditions: [_sampleCompactCondition()],
          catalog: _sampleCatalog(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: ChronicConditionsScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      final openButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'View tracking').first,
      );
      openButton.onPressed!.call();
      await tester.pumpAndSettle();

      expect(find.text('Tracking summary'), findsOneWidget);
      expect(find.text('Add reading'), findsOneWidget);
      expect(find.text('Add medication'), findsAtLeastNWidgets(1));

      await tester.scrollUntilVisible(find.text('Applied care limits'), 300);
      expect(find.text('Applied care limits'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Recent alerts'), 300);
      expect(find.text('Recent alerts'), findsOneWidget);
    },
  );
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
      'setup_fields': const [],
      'measurement_types': const ['glucose'],
      'supports_direct_daily_reading': true,
      'severity_options': const [
        {
          'code': 'diabetes_managed',
          'label': 'Managed diabetes',
          'description': 'Sample severity',
        },
      ],
      'restrictions': const [],
      'rule_profiles': const [],
    },
    'diagnosis_date': '2026-04-11',
    'condition_status': 'active',
    'severity': 'diabetes_managed',
    'notes': 'Clinician approved current plan.',
    'profile_data': const {'glucose_target': 110},
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
      'payload': const {'glucose': 110},
      'classification': 'in_range',
      'risk_level': 'low',
      'recorded_at': '2026-04-11T08:30:00Z',
    },
    'latest_recorded_at': '2026-04-11T08:30:00Z',
    'disclaimer': 'Supportive self-management only.',
  });
}

List<ChronicConditionType> _sampleCatalog() {
  return [
    _sampleConditionType(
      id: 1,
      slug: 'diabetes',
      displayName: 'Diabetes',
      supportsDirectDailyReading: true,
      measurementTypes: const ['glucose'],
    ),
    _sampleConditionType(
      id: 2,
      slug: 'hypertension',
      displayName: 'Hypertension',
      supportsDirectDailyReading: true,
      measurementTypes: const ['blood_pressure'],
    ),
    _sampleConditionType(
      id: 3,
      slug: 'dyslipidemia',
      displayName: 'Dyslipidemia',
      supportsDirectDailyReading: false,
      measurementTypes: const ['lipid_panel'],
    ),
  ];
}

ChronicConditionType _sampleConditionType({
  required int id,
  required String slug,
  required String displayName,
  required bool supportsDirectDailyReading,
  required List<String> measurementTypes,
}) {
  return ChronicConditionType.fromJson({
    'id': id,
    'code': slug == 'dyslipidemia' ? 'hyperlipidemia' : slug,
    'slug': slug,
    'name': displayName,
    'display_name': displayName,
    'description': 'Sample condition type',
    'can_add': true,
    'is_active_for_user': false,
    'setup_fields': const [],
    'measurement_types': measurementTypes,
    'supports_direct_daily_reading': supportsDirectDailyReading,
    'severity_options': [
      {
        'code': slug == 'diabetes' ? 'diabetes_managed' : 'stage_1',
        'label': slug == 'diabetes' ? 'Managed diabetes' : 'Moderate',
        'description': 'Sample severity',
      },
    ],
    'restrictions': const [],
    'rule_profiles': const [],
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
      'setup_fields': const [],
      'measurement_types': const ['glucose'],
      'supports_direct_daily_reading': true,
      'severity_options': [
        {
          'code': 'diabetes_managed',
          'label': 'Managed diabetes',
          'description': 'Sample severity',
        },
      ],
      'restrictions': const [],
      'rule_profiles': const [],
    },
    'diagnosis_date': '2026-04-11',
    'condition_status': 'active',
    'severity': 'diabetes_managed',
    'notes': 'Clinician approved current plan.',
    'profile_data': {'glucose_target': 110, 'hba1c_target': 6.5},
    'is_active': true,
    'targets': [
      {
        'id': 9,
        'target_key': 'fasting_glucose',
        'target_name': 'Fasting glucose',
        'category': 'monitoring',
        'metric_key': 'fasting_glucose',
        'evaluation_mode': 'latest_indicator',
        'status': 'within_target',
        'unit': 'mg/dL',
        'min_value': 80,
        'max_value': 130,
        'current_value': 110,
        'source_type': 'dynamic_condition_state',
        'priority': 2,
        'guidance': 'Keep fasting glucose in range.',
        'evidence_source': 'Sample source',
        'is_scored': false,
      },
    ],
    'evaluation': {
      'evaluation_date': '2026-04-11',
      'status': 'stable',
      'risk_flags': const [],
      'medication_adherence_percent': 100,
      'restriction_adherence_percent': 100,
      'points_delta': 5,
      'streak_bonus': 2,
      'latest_recorded_at': '2026-04-11T08:30:00Z',
      'recommendations': [
        {
          'code': 'keep_current_plan',
          'message': 'Continue the current meal and medication routine.',
        },
      ],
      'tracker_impacts': [
        {'tracker': 'nutrition', 'key': 'added_sugar_limit', 'value': 20},
      ],
      'targets': [
        {
          'id': 9,
          'target_key': 'fasting_glucose',
          'target_name': 'Fasting glucose',
          'category': 'monitoring',
          'metric_key': 'fasting_glucose',
          'evaluation_mode': 'latest_indicator',
          'status': 'within_target',
          'unit': 'mg/dL',
          'min_value': 80,
          'max_value': 130,
          'current_value': 110,
          'source_type': 'dynamic_condition_state',
          'priority': 2,
          'guidance': 'Keep fasting glucose in range.',
          'evidence_source': 'Sample source',
          'is_scored': false,
        },
      ],
    },
    'summary': {
      'condition_id': 4,
      'status': 'stable',
      'risk_flags': const [],
      'latest_recorded_at': '2026-04-11T08:30:00Z',
      'recommendations': [
        {
          'code': 'keep_current_plan',
          'message': 'Continue the current meal and medication routine.',
        },
      ],
      'tracker_impacts': [
        {'tracker': 'nutrition', 'key': 'added_sugar_limit', 'value': 20},
      ],
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
        'payload': const {'glucose': 110},
        'classification': 'in_range',
        'risk_level': 'low',
        'recorded_at': '2026-04-11T08:30:00Z',
      },
      'alerts': [
        {
          'id': 51,
          'code': 'monitoring_due',
          'level': 'info',
          'message': 'Keep logging your morning glucose.',
          'alert_type': 'monitoring',
          'status': 'open',
          'created_at': '2026-04-11T09:00:00Z',
        },
      ],
      'targets': [
        {
          'id': 9,
          'target_key': 'fasting_glucose',
          'target_name': 'Fasting glucose',
          'category': 'monitoring',
          'metric_key': 'fasting_glucose',
          'evaluation_mode': 'latest_indicator',
          'status': 'within_target',
          'unit': 'mg/dL',
          'min_value': 80,
          'max_value': 130,
          'current_value': 110,
          'source_type': 'dynamic_condition_state',
          'priority': 2,
          'guidance': 'Keep fasting glucose in range.',
          'evidence_source': 'Sample source',
          'is_scored': false,
        },
      ],
    },
    'medications': [
      {
        'id': 11,
        'name': 'Metformin',
        'scientific_name': 'Metformin',
        'dosage': '500 mg',
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
    'indicator_records': [
      {
        'id': 91,
        'indicator_name': 'fasting_glucose',
        'indicator_type': 'glucose',
        'value': 110,
        'value_1': 110,
        'value_2': 0,
        'value_3': 0,
        'unit': 'mg/dL',
        'reading_context': 'fasting',
        'payload': const {'glucose': 110},
        'classification': 'in_range',
        'risk_level': 'low',
        'recorded_at': '2026-04-11T08:30:00Z',
      },
    ],
    'alerts': [
      {
        'id': 51,
        'code': 'monitoring_due',
        'level': 'info',
        'message': 'Keep logging your morning glucose.',
        'alert_type': 'monitoring',
        'status': 'open',
        'created_at': '2026-04-11T09:00:00Z',
      },
    ],
    'constraint_summary': [
      'Prefer low added sugar meals when readings trend high.',
    ],
    'daily_medication_count': 1,
    'daily_pending_doses': 1,
    'disclaimer': 'Supportive self-management only.',
  });
}
