import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/features/medications/data/medications_api.dart';
import 'package:vitamate/features/medications/data/medications_repository.dart';
import 'package:vitamate/features/medications/models/medication_adherence_summary.dart';
import 'package:vitamate/features/medications/models/medication_dose_log.dart';
import 'package:vitamate/features/medications/models/medication_item.dart';
import 'package:vitamate/features/medications/models/medication_schedule.dart';
import 'package:vitamate/features/medications/state/medications_controller.dart';

class _FakeMedicationsRepository extends MedicationsRepository {
  _FakeMedicationsRepository();

  final createdPayloads = <Map<String, dynamic>>[];
  var medications = <MedicationItem>[];
  var today = <MedicationDoseLog>[];
  var adherence = MedicationAdherenceSummary.empty();

  @override
  Future<List<MedicationItem>> getMedications() async => medications;

  @override
  Future<List<MedicationDoseLog>> getTodayPlan({String? date}) async => today;

  @override
  Future<MedicationAdherenceSummary> getOverallAdherence() async => adherence;

  @override
  Future<MedicationItem> createMedication(Map<String, dynamic> payload) async {
    createdPayloads.add(payload);
    final item = MedicationItem(
      id: 10,
      displayName: payload['display_name'] as String,
      sourceType: payload['source_type'] as String,
      linkedConditionId: payload['user_condition_id'] as int?,
      linkedConditionName: null,
      doseAmount: payload['dose_amount']?.toString() ?? '',
      doseUnit: payload['dose_unit']?.toString() ?? '',
      dosage: '',
      form: payload['form']?.toString() ?? '',
      instructions: payload['instructions']?.toString() ?? '',
      startDate: DateTime(2026, 4, 17),
      endDate: null,
      isActive: true,
      isPrn: false,
      timezone: 'Asia/Damascus',
      supplementNutrientId: null,
      supplementNutrientCode: '',
      supplementNutrientAmount: 0,
      supplementNutrientUnit: '',
      nextDue: DateTime(2026, 4, 17, 8),
      adherenceSummaryShort: adherence,
      schedules: const [
        MedicationSchedule(
          id: 5,
          scheduleType: 'daily',
          time: '08:00',
          daysOfWeek: [],
          intervalHours: null,
          mealRelation: 'after_meal',
          gracePeriodMinutes: 60,
          snoozeDefaultMinutes: 15,
          isActive: true,
        ),
      ],
    );
    medications = [item];
    return item;
  }

  @override
  Future<MedicationDoseLog> markTaken(
    int logId, {
    DateTime? takenAt,
    String? doseTakenAmount,
  }) async {
    final updated = MedicationDoseLog(
      logId: logId,
      medicationId: 10,
      displayName: 'Metformin',
      linkedConditionId: 2,
      linkedConditionName: 'Diabetes',
      scheduledFor: DateTime(2026, 4, 17, 8),
      status: 'taken',
      rawStatus: 'taken_on_time',
      snoozedUntil: null,
      takenAt: DateTime(2026, 4, 17, 8, 2),
      doseAmount: '500',
      doseUnit: 'mg',
      form: 'tablet',
      mealRelation: 'after_meal',
      notes: '',
      pointsApplied: 3,
      scheduledDate: '2026-04-17',
      isPrn: false,
    );
    today = [updated];
    return updated;
  }
}

class _EnvelopeMedicationsApi extends MedicationsApi {
  @override
  Future<Map<String, dynamic>> fetchOverview() async {
    return {
      'data': {
        'medications': [
          {
            'id': 7,
            'display_name': 'Vitamin D',
            'source_type': 'manual',
            'dose_amount': '1000',
            'dose_unit': 'IU',
            'form': 'capsule',
            'is_active': true,
            'is_prn': false,
            'timezone': 'Asia/Damascus',
            'adherence_summary_short': {
              'expected_doses': 1,
              'taken_doses': 0,
              'pending_doses': 1,
              'adherence_percent': 0,
            },
            'schedules': [
              {
                'id': 11,
                'schedule_type': 'daily',
                'time': '09:00',
                'meal_relation': 'after_meal',
              },
            ],
          },
        ],
        'today_plan': [
          {
            'log_id': 99,
            'medication_id': 7,
            'display_name': 'Vitamin D',
            'scheduled_for': '2026-05-05T09:00:00',
            'status': 'pending',
            'dose_amount': '1000',
            'dose_unit': 'IU',
            'form': 'capsule',
          },
        ],
        'overall_adherence': {
          'expected_doses': 1,
          'taken_doses': 0,
          'pending_doses': 1,
          'adherence_percent': 0,
        },
        'today_adherence': {
          'expected': 1,
          'taken': 0,
          'pending': 1,
          'missed': 0,
          'overdue': 0,
          'skipped': 0,
          'percent': 0,
        },
        'next_dose': {
          'log_id': 99,
          'medication_id': 7,
          'display_name': 'Vitamin D',
          'scheduled_for': '2026-05-05T09:00:00',
          'status': 'pending',
          'raw_status': 'pending',
          'dose_amount': '1000',
          'dose_unit': 'IU',
          'form': 'capsule',
        },
        'streak': 0,
        'shortcut_counts': {
          'today_plan': 1,
          'all_medications': 1,
          'history': 1,
          'insights': 0,
        },
      },
      'meta': {'is_stale': false, 'request_id': 'test'},
    };
  }
}

void main() {
  test('medication models parse backend payload', () {
    final item = MedicationItem.fromJson({
      'id': 1,
      'display_name': 'Metformin',
      'source_type': 'condition',
      'linked_condition_id': 4,
      'linked_condition_name': 'Diabetes',
      'dose_amount': '500',
      'dose_unit': 'mg',
      'form': 'tablet',
      'instructions': 'After food',
      'start_date': '2026-04-17',
      'next_due': '2026-04-17T08:00:00Z',
      'adherence_summary_short': {
        'expected_doses': 2,
        'taken_doses': 1,
        'missed_doses': 0,
        'skipped_doses': 0,
        'pending_doses': 1,
        'overdue_doses': 0,
        'adherence_percent': 50,
        'streak_days': 1,
        'on_time_percent': 50,
      },
      'schedules': [
        {
          'id': 7,
          'schedule_type': 'daily',
          'time': '08:00',
          'meal_relation': 'after_meal',
        },
      ],
    });

    expect(item.displayName, 'Metformin');
    expect(item.linkedConditionName, 'Diabetes');
    expect(item.schedules.single.time, '08:00');
    expect(item.adherenceSummaryShort.expectedDoses, 2);
  });

  test('repository unwraps medications overview envelope', () async {
    final repository = MedicationsRepository(api: _EnvelopeMedicationsApi());

    final overview = await repository.getOverview();

    expect(overview.medications, hasLength(1));
    expect(overview.medications.single.displayName, 'Vitamin D');
    expect(overview.todayPlan, hasLength(1));
    expect(overview.overallAdherence.pendingDoses, 1);
    expect(overview.todayAdherence.pending, 1);
    expect(overview.nextDose?.logId, 99);
  });

  test('controller creates medication and refreshes state', () async {
    final repo = _FakeMedicationsRepository();
    final controller = MedicationsController(repository: repo);

    final saved = await controller.createMedication({
      'display_name': 'Metformin',
      'source_type': 'condition',
      'user_condition_id': 2,
      'dose_amount': '500',
      'dose_unit': 'mg',
      'form': 'tablet',
      'instructions': 'After food',
      'schedules': [
        {'schedule_type': 'daily', 'time': '08:00'},
      ],
    });

    expect(saved, isTrue);
    expect(repo.createdPayloads, hasLength(1));
    expect(controller.state.medications.single.displayName, 'Metformin');
  });

  test('controller does not block save on background refresh', () async {
    final repo = _FakeMedicationsRepository();
    final controller = MedicationsController(repository: repo);

    final saved = await controller.createMedication({
      'display_name': 'Metformin',
      'source_type': 'condition',
      'user_condition_id': 2,
      'dose_amount': '500',
      'dose_unit': 'mg',
      'form': 'tablet',
      'instructions': 'After food',
      'schedules': [
        {'schedule_type': 'daily', 'time': '08:00'},
      ],
    });

    expect(saved, isTrue);
    expect(controller.state.isSaving, isFalse);
    expect(controller.state.medications.single.displayName, 'Metformin');
    await Future<void>.delayed(Duration.zero);
  });

  test('controller refreshes today plan after dose action', () async {
    final repo = _FakeMedicationsRepository()
      ..today = [
        MedicationDoseLog(
          logId: 3,
          medicationId: 10,
          displayName: 'Metformin',
          linkedConditionId: 2,
          linkedConditionName: 'Diabetes',
          scheduledFor: DateTime(2026, 4, 17, 8),
          status: 'pending',
          rawStatus: 'pending',
          snoozedUntil: null,
          takenAt: null,
          doseAmount: '500',
          doseUnit: 'mg',
          form: 'tablet',
          mealRelation: 'after_meal',
          notes: '',
          pointsApplied: 0,
          scheduledDate: '2026-04-17',
          isPrn: false,
        ),
      ];
    final controller = MedicationsController(repository: repo);

    final ok = await controller.markDoseTaken(3);

    expect(ok, isTrue);
    expect(controller.state.todayPlan.single.status, 'taken');
  });
}
