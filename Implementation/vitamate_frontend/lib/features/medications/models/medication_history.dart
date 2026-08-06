import 'medication_dose_log.dart';

class MedicationHistoryGroup {
  const MedicationHistoryGroup({required this.date, required this.items});

  final String date;
  final List<MedicationDoseLog> items;

  factory MedicationHistoryGroup.fromJson(Map<String, dynamic> json) {
    return MedicationHistoryGroup(
      date: (json['date'] ?? '').toString(),
      items: _asList(json['items'])
          .whereType<Map>()
          .map(
            (item) => MedicationDoseLog.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

class MedicationHistoryPage {
  const MedicationHistoryPage({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasNext,
    required this.status,
    required this.groups,
  });

  final int page;
  final int pageSize;
  final int total;
  final bool hasNext;
  final String status;
  final List<MedicationHistoryGroup> groups;

  factory MedicationHistoryPage.empty() {
    return const MedicationHistoryPage(
      page: 1,
      pageSize: 30,
      total: 0,
      hasNext: false,
      status: 'all',
      groups: [],
    );
  }

  factory MedicationHistoryPage.fromJson(Map<String, dynamic> json) {
    return MedicationHistoryPage(
      page: _asInt(json['page'], fallback: 1),
      pageSize: _asInt(json['page_size'], fallback: 30),
      total: _asInt(json['total']),
      hasNext: _asBool(json['has_next']),
      status: (json['status'] ?? 'all').toString(),
      groups: _asList(json['groups'])
          .whereType<Map>()
          .map(
            (item) =>
                MedicationHistoryGroup.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

List<dynamic> _asList(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().toLowerCase() == 'true';
}
