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
  static HttpClientAdapter? _probeTestAdapter;

  static String get baseUrl => _resolvedBaseUrl;
  static bool get hasConfiguredBaseUrl => _configuredBaseUrl.isNotEmpty;

  static void setResolvedBaseUrlForTesting(String value) {
    promoteResolvedBaseUrl(value);
  }

  static void promoteResolvedBaseUrl(String value) {
    _resolvedBaseUrl = value;
  }

  static void setProbeAdapterForTesting(HttpClientAdapter? adapter) {
    _probeTestAdapter = adapter;
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

  static Future<String> resolveReachableBaseUrl({
    String? preferredBaseUrl,
  }) async {
    if (_configuredBaseUrl.isNotEmpty) {
      promoteResolvedBaseUrl(_configuredBaseUrl);
      return _resolvedBaseUrl;
    }

    final candidates = _candidateBaseUrls(preferredBaseUrl: preferredBaseUrl);
    for (final candidate in candidates) {
      final reachable = await _probeCandidate(candidate);
      if (reachable) {
        promoteResolvedBaseUrl(candidate);
        return candidate;
      }
    }

    _resolvedBaseUrl = candidates.first;
    return _resolvedBaseUrl;
  }

  static Future<String?> resolveAlternateReachableBaseUrl({
    required String currentBaseUrl,
  }) async {
    if (_configuredBaseUrl.isNotEmpty) {
      return null;
    }

    final candidates = _candidateBaseUrls(preferredBaseUrl: currentBaseUrl);
    for (final candidate in candidates) {
      if (candidate == currentBaseUrl) {
        continue;
      }
      final reachable = await _probeCandidate(candidate);
      if (reachable) {
        promoteResolvedBaseUrl(candidate);
        return candidate;
      }
    }

    return null;
  }

  static String connectionHint({String? failingBaseUrl}) {
    final targetBaseUrl = failingBaseUrl ?? _resolvedBaseUrl;

    if (_configuredBaseUrl.isNotEmpty) {
      return 'Verify that API_BASE_URL points to the machine running Django.';
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'Android emulator uses http://10.0.2.2:8000 with Django on '
          '0.0.0.0:8000. A real device needs adb reverse or '
          'API_BASE_URL=http://<LAN-IP>:8000.';
    }

    return 'Check that the backend is running and listening on $targetBaseUrl.';
  }

  static List<String> _candidateBaseUrls({String? preferredBaseUrl}) {
    final preferred = preferredBaseUrl?.isNotEmpty == true
        ? preferredBaseUrl!
        : _preferredDefaultBaseUrl;
    final fallback = preferred == _emulatorBaseUrl
        ? _adbReverseBaseUrl
        : _emulatorBaseUrl;
    return <String>{preferred, fallback}.toList();
  }

  static Future<bool> _probeCandidate(String candidate) async {
    if (candidate.isEmpty) {
      return false;
    }
    final probe = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 800),
        receiveTimeout: const Duration(milliseconds: 800),
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (_probeTestAdapter != null) {
      probe.httpClientAdapter = _probeTestAdapter!;
    }
    try {
      final response = await probe.get('$candidate$health');
      if (response.statusCode == 200) {
        debugPrint('ApiEndpoints: using backend at $candidate');
        return true;
      }
    } catch (_) {
      // Startup keeps a single fallback path instead of probing repeatedly.
    }
    return false;
  }

  static const String register = '/api/auth/register/';
  static const String login = '/api/auth/login/';
  static const String refresh = '/api/auth/refresh/';
  static const String me = '/api/auth/me/';
  static const String health = '/api/health/';

  static const String dashboard = '/api/dashboard/';
  static const String history = '/api/history/';

  static const String homeOverview = '/api/home/overview/';
  static const String progressOverview = '/api/progress/overview/';
  static const String progressHistory = '/api/progress/history/';
  static String progressDetail(String tracker) =>
      '/api/progress/details/$tracker/';
  static const String nutritionSummary = '/api/nutrition/summary/';
  static const String nutritionMicronutrients =
      '/api/nutrition/micronutrients/';
  static const String nutritionMicronutrientTargets =
      '/api/nutrition/micronutrients/targets/';
  static const String hydrationSummary = '/api/hydration/summary/';
  static const String sleepSummary = '/api/sleep/summary/';
  static const String sleepCoachToday = '/api/sleep/coach/today/';
  static const String sleepCoachPlans = '/api/sleep/coach/plans/';
  static const String sleepCoachPlansCancel = '/api/sleep/coach/plans/cancel/';
  static const String sleepCoachFeedback = '/api/sleep/coach/feedback/';
  static const String stepsSummary = '/api/steps/summary/';
  static const String activitySummary = '/api/activity/summary/';
  static const String activitySessions = '/api/activity/sessions/';
  static const String activitySessionsActive = '/api/activity/sessions/active/';
  static const String medicationsOverview = '/api/medications/overview/';
  static const String chronicOverview = '/api/chronic/overview/';
  static const String schema = '/api/schema/';

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
  static const String unhealthyHabitsOverview =
      '/api/habits/unhealthy/overview/';
  static const String unhealthyHabits = '/api/habits/unhealthy/';
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

  static String activitySessionPause(int id) =>
      '/api/activity/sessions/$id/pause/';
  static String activitySessionResume(int id) =>
      '/api/activity/sessions/$id/resume/';
  static String activitySessionEdit(int id) =>
      '/api/activity/sessions/$id/edit/';
  static String activitySessionFinish(int id) =>
      '/api/activity/sessions/$id/finish/';
  static String activitySessionCancel(int id) =>
      '/api/activity/sessions/$id/cancel/';
}
