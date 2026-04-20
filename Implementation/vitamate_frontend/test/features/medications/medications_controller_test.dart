import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/core/notifications/notifications_service.dart';
import 'package:vitamate/features/medications/data/medications_repository.dart';
import 'package:vitamate/features/medications/models/medication_adherence_summary.dart';
import 'package:vitamate/features/medications/models/medication_dose_log.dart';
import 'package:vitamate/features/medications/models/medication_item.dart';
import 'package:vitamate/features/medications/models/medication_schedule.dart';
import 'package:vitamate/features/medications/models/reminder_sync_payload.dart';
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
  Future<List<MedicationDoseLog>> getTodayPlan() async => today;

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
      snoozedUntil: null,
      doseAmount: '500',
      doseUnit: 'mg',
      form: 'tablet',
    );
    today = [updated];
    return updated;
  }

  @override
  Future<ReminderSyncPayload> getReminderSync() async {
    return ReminderSyncPayload.fromJson({
      'items': [
        {
          'medication_id': 10,
          'schedule_id': 5,
          'display_name': 'Metformin',
          'timezone': 'Asia/Damascus',
          'scheduled_times': ['08:00'],
          'days_of_week': [0, 2],
          'meal_relation': 'after_meal',
          'snooze_default_minutes': 15,
          'reminder_lead_minutes': 10,
          'linked_condition': {'id': 2, 'name': 'Diabetes'},
        },
      ],
    });
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

  test('controller creates medication and syncs reminders', () async {
    final repo = _FakeMedicationsRepository();
    final plans = <ChronicMedicationReminderPlan>[];
    final controller = MedicationsController(
      repository: repo,
      reminderSyncer: (value) async => plans.addAll(value),
    );

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
    expect(plans.single.medicationName, 'Metformin');
    expect(plans.single.recurrenceDays, [0, 2]);
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
          snoozedUntil: null,
          doseAmount: '500',
          doseUnit: 'mg',
          form: 'tablet',
        ),
      ];
    final controller = MedicationsController(
      repository: repo,
      reminderSyncer: (_) async {},
    );

    final ok = await controller.markDoseTaken(3);

    expect(ok, isTrue);
    expect(controller.state.todayPlan.single.status, 'taken');
  });
}
