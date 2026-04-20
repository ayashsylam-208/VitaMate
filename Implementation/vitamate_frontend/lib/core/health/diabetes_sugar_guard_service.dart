import '../config/api_endpoints.dart';
import '../network/http_client.dart';

class DiabetesSugarGuard {
  const DiabetesSugarGuard({required this.limitG, required this.source});

  final double limitG;
  final String source;
}

class DiabetesSugarWarning {
  const DiabetesSugarWarning({
    required this.limitG,
    required this.currentG,
    required this.sourceLabel,
  });

  final double limitG;
  final double currentG;
  final String sourceLabel;
}

class DiabetesSugarGuardService {
  const DiabetesSugarGuardService();

  static const double fallbackDiabetesSugarLimitG = 25;

  Future<DiabetesSugarGuard?> getActiveGuard() async {
    final res = await HttpClient.dio.get(ApiEndpoints.chronicUserConditions);
    final payload = res.data;
    final items = payload is List
        ? payload
        : (payload is Map && payload['results'] is List
              ? payload['results'] as List
              : const []);

    for (final item in items) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final conditionType = _asMap(map['condition_type']);
      final slug = (conditionType['slug'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final isActive = _asBool(map['is_active'], fallback: true);
      final status = (map['status'] ?? map['condition_status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (slug != 'diabetes' || !isActive || status == 'inactive') {
        continue;
      }

      final dynamicLimit = _extractAddedSugarLimit(map);
      return DiabetesSugarGuard(
        limitG: dynamicLimit ?? fallbackDiabetesSugarLimitG,
        source: dynamicLimit != null
            ? 'condition_target'
            : 'default_diabetes_limit',
      );
    }

    return null;
  }

  double? _extractAddedSugarLimit(Map<String, dynamic> condition) {
    for (final bucket in [
      condition['targets'],
      _asMap(condition['evaluation'])['targets'],
      _asMap(condition['summary'])['targets'],
    ]) {
      if (bucket is! List) {
        continue;
      }
      for (final item in bucket) {
        if (item is! Map) {
          continue;
        }
        final target = Map<String, dynamic>.from(item);
        final targetKey = (target['target_key'] ?? '').toString().trim();
        if (targetKey != 'added_sugars_g' && targetKey != 'sugars_g') {
          continue;
        }
        final maxValue = _asNullableDouble(target['max_value']);
        if (maxValue != null && maxValue > 0) {
          return maxValue;
        }
      }
    }
    return null;
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final lowered = value.toLowerCase();
    if (lowered == 'true') {
      return true;
    }
    if (lowered == 'false') {
      return false;
    }
  }
  return fallback;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}
