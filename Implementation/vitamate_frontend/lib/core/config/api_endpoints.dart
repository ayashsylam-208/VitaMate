import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiEndpoints {
  static const String _adbReverseBaseUrl = 'http://127.0.0.1:8000';
  static const String _emulatorBaseUrl = 'http://10.0.2.2:8000';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String _resolvedBaseUrl = _preferredDefaultBaseUrl;

  static String get baseUrl => _resolvedBaseUrl;

  static void setResolvedBaseUrlForTesting(String value) {
    _resolvedBaseUrl = value;
  }

  static String get _preferredDefaultBaseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _emulatorBaseUrl;
    }

    return _adbReverseBaseUrl;
  }

  static List<String> get candidateBaseUrls {
    final values = <String>[
      if (_configuredBaseUrl.isNotEmpty) _configuredBaseUrl,
      _preferredDefaultBaseUrl,
      _emulatorBaseUrl,
      _adbReverseBaseUrl,
    ];
    final seen = <String>{};
    return [
      for (final value in values)
        if (value.isNotEmpty && seen.add(value)) value,
    ];
  }

  static Future<String> resolveReachableBaseUrl() async {
    final probe = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    for (final candidate in candidateBaseUrls) {
      try {
        final res = await probe.get('$candidate$health');
        if (res.statusCode == 200) {
          _resolvedBaseUrl = candidate;
          debugPrint('ApiEndpoints: using backend at $candidate');
          return candidate;
        }
      } catch (error) {
        debugPrint('ApiEndpoints: backend probe failed for $candidate: $error');
        // Try the next candidate.
      }
    }

    _resolvedBaseUrl = _preferredDefaultBaseUrl;
    debugPrint(
      'ApiEndpoints: no reachable backend found. Falling back to '
      '$_resolvedBaseUrl. Set --dart-define=API_BASE_URL=http://<host>:8000 '
      'if the backend runs on another machine.',
    );
    return _resolvedBaseUrl;
  }

  // ✅ Auth (SimpleJWT)
  static const String register = '/api/auth/register/';
  static const String login = '/api/auth/login/';
  static const String refresh = '/api/auth/refresh/';
  static const String me = '/api/auth/me/';
  static const String health = '/api/health/';

  // ✅ Dashboard
  static const String dashboard = '/api/dashboard/';
  static const String history = '/api/history/';

  // ✅ Router endpoints (حسب router.register في Django)
  static const String meals = '/api/meals/';
  static const String water = '/api/water/';
  static const String medicines = '/api/medicines/';
  static const String medications = '/api/medications/';
  static const String medicationsToday = '/api/medications/today/';
  static const String medicationDoses = '/api/medications/doses/';
  static const String medicationAdherenceSummary =
      '/api/medications/adherence-summary/';
  static const String medicationReminderSync =
      '/api/medications/reminder-sync/';
  static const String steps = '/api/steps/';
  static const String activities = '/api/activities/';
  static const String exercises = '/api/exercises/';
  static const String sleep = '/api/sleep/';
  static const String habits = '/api/habits/';
  static const String foods = '/api/foods/';
  static const String foodsSearch = '/api/foods/search/';
  static const String foodsAutocomplete = '/api/foods/autocomplete/';
  static const String nutritionFacts = '/api/nutrition-facts/';
  static const String nutritionServingOptions =
      '/api/nutrition-serving-options/';
  static const String conditionTypes = '/api/condition-types/';
  static const String userConditions = '/api/user-conditions/';
  static const String chronicConditionTypes = '/api/chronic/condition-types/';
  static const String chronicSupportedConditionTypes =
      '/api/chronic/condition-types/supported/';
  static const String chronicUserConditions = '/api/chronic/user-conditions/';
  static const String conditionMedications = '/api/condition-medications/';
  static const String conditionMedicationSchedules =
      '/api/condition-medication-schedules/';
  static const String healthIndicators = '/api/health-indicators/';
}
