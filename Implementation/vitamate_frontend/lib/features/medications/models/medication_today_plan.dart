import 'medication_dose_log.dart';

class MedicationTodaySummary {
  const MedicationTodaySummary({
    required this.expected,
    required this.taken,
    required this.pending,
    required this.missed,
    required this.overdue,
    required this.skipped,
    required this.percent,
  });

  final int expected;
  final int taken;
  final int pending;
  final int missed;
  final int overdue;
  final int skipped;
  final double percent;

  int get completed => taken + missed + skipped;
  int get unresolved => pending + overdue;

  factory MedicationTodaySummary.empty() {
    return const MedicationTodaySummary(
      expected: 0,
      taken: 0,
      pending: 0,
      missed: 0,
      overdue: 0,
      skipped: 0,
      percent: 0,
    );
  }

  factory MedicationTodaySummary.fromJson(Map<String, dynamic> json) {
    final expected = _asInt(
      json['expected'] ?? json['today_total_doses'] ?? json['expected_doses'],
    );
    final taken = _asInt(json['taken'] ?? json['taken_today']);
    final missed = _asInt(json['missed'] ?? json['missed_today']);
    final overdue = _asInt(json['overdue'] ?? json['overdue_today']);
    final skipped = _asInt(json['skipped'] ?? json['skipped_today']);
    final pending = _asInt(json['pending'] ?? json['pending_today']);
    final explicitPercent = json['percent'] ?? json['adherence_percent'];
    final computedPercent = expected <= 0 ? 0.0 : (taken / expected) * 100;
    return MedicationTodaySummary(
      expected: expected,
      taken: taken,
      pending: pending,
      missed: missed,
      overdue: overdue,
      skipped: skipped,
      percent: _asDouble(explicitPercent, fallback: computedPercent),
    );
  }
}

class MedicationTodayPlanData {
  const MedicationTodayPlanData({
    required this.serverNow,
    required this.timezone,
    required this.selectedDate,
    required this.summary,
    required this.doses,
    required this.upcoming,
    required this.completed,
  });

  final DateTime? serverNow;
  final String timezone;
  final String selectedDate;
  final MedicationTodaySummary summary;
  final List<MedicationDoseLog> doses;
  final List<MedicationDoseLog> upcoming;
  final List<MedicationDoseLog> completed;

  factory MedicationTodayPlanData.empty() {
    return MedicationTodayPlanData(
      serverNow: null,
      timezone: 'UTC',
      selectedDate: '',
      summary: MedicationTodaySummary.empty(),
      doses: const [],
      upcoming: const [],
      completed: const [],
    );
  }

  factory MedicationTodayPlanData.fromJson(dynamic raw) {
    final json = _asMap(raw);
    final doseRows = _asList(json['doses'] ?? raw);
    final grouped = _asMap(json['grouped']);
    final upcomingRows = _asList(grouped['upcoming']);
    final completedRows = _asList(grouped['completed']);
    final doses = _parseLogs(doseRows);
    return MedicationTodayPlanData(
      serverNow: DateTime.tryParse((json['server_now'] ?? '').toString()),
      timezone: (json['timezone'] ?? 'UTC').toString(),
      selectedDate: (json['selected_date'] ?? '').toString(),
      summary: MedicationTodaySummary.fromJson(_asMap(json['summary'])),
      doses: doses,
      upcoming: upcomingRows.isEmpty
          ? _upcomingFrom(doses)
          : _parseLogs(upcomingRows),
      completed: completedRows.isEmpty
          ? _completedFrom(doses)
          : _parseLogs(completedRows),
    );
  }

  static List<MedicationDoseLog> _parseLogs(List<dynamic> rows) {
    return rows
        .whereType<Map>()
        .map((item) => MedicationDoseLog.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  static List<MedicationDoseLog> _upcomingFrom(List<MedicationDoseLog> rows) {
    return rows
        .where((dose) => !_finalStatuses.contains(dose.rawStatus))
        .toList(growable: false);
  }

  static List<MedicationDoseLog> _completedFrom(List<MedicationDoseLog> rows) {
    return rows
        .where((dose) => _finalStatuses.contains(dose.rawStatus))
        .toList(growable: false);
  }
}

const _finalStatuses = {
  'taken',
  'taken_on_time',
  'taken_late',
  'missed',
  'skipped',
};

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
