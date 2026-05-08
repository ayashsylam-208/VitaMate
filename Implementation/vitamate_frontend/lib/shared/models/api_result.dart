typedef ApiDataParser<T> = T Function(dynamic rawData);

class ApiMeta {
  const ApiMeta({
    required this.isStale,
    required this.computedAt,
    required this.snapshotVersion,
    required this.requestId,
  });

  final bool isStale;
  final DateTime? computedAt;
  final int? snapshotVersion;
  final String requestId;

  factory ApiMeta.empty() {
    return const ApiMeta(
      isStale: false,
      computedAt: null,
      snapshotVersion: null,
      requestId: '',
    );
  }

  factory ApiMeta.fromJson(dynamic value) {
    final json = asMap(value);
    return ApiMeta(
      isStale: json['is_stale'] == true,
      computedAt: DateTime.tryParse((json['computed_at'] ?? '').toString()),
      snapshotVersion: _asNullableInt(json['snapshot_version']),
      requestId: (json['request_id'] ?? '').toString(),
    );
  }
}

class ApiEnvelope<T> {
  const ApiEnvelope({required this.data, required this.meta});

  final T data;
  final ApiMeta meta;

  factory ApiEnvelope.fromJson(
    dynamic value, {
    required ApiDataParser<T> dataParser,
    required T emptyData,
  }) {
    final json = asMap(value);
    if (json.isEmpty) {
      return ApiEnvelope<T>(data: emptyData, meta: ApiMeta.empty());
    }
    return ApiEnvelope<T>(
      data: dataParser(json['data']),
      meta: ApiMeta.fromJson(json['meta']),
    );
  }
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList(growable: false);
}

int? _asNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return int.tryParse(value.toString());
}
