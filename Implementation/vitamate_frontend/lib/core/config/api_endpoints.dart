import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiEndpoints {
  static const String _adbReverseBaseUrl = 'http://127.0.0.1:8000';
  static const String _emulatorBaseUrl = 'http://10.0.2.2:8000';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _configuredCandidateBaseUrls = String.fromEnvironment(
    'API_BASE_URL_CANDIDATES',
    defaultValue: '',
  );
  static const bool _strictConfiguredBaseUrl = bool.fromEnvironment(
    'API_BASE_URL_STRICT',
    defaultValue: false,
  );

  static String _resolvedBaseUrl = _preferredDefaultBaseUrl;
  static HttpClientAdapter? _probeTestAdapter;

  static String get baseUrl => _resolvedBaseUrl;
  static bool get hasConfiguredBaseUrl => _configuredBaseUrl.isNotEmpty;
  static bool get baseUrlFailoverLocked =>
      _configuredBaseUrl.isNotEmpty && _strictConfiguredBaseUrl;

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
    if (baseUrlFailoverLocked) {
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
    if (baseUrlFailoverLocked) {
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
    final configuredCandidates = _splitConfiguredCandidates();

    if (_configuredBaseUrl.isNotEmpty && _strictConfiguredBaseUrl) {
      return 'API_BASE_URL is strict. Verify it points to the machine running Django.';
    }

    if (_configuredBaseUrl.isNotEmpty) {
      if (configuredCandidates.isNotEmpty) {
        return 'Tried API_BASE_URL and these candidates: '
            '${configuredCandidates.join(', ')}. Verify Django is running on one of them.';
      }
      return 'API_BASE_URL was tried first, then local dev fallbacks. '
          'Use adb reverse tcp:8000 tcp:8000 or update API_BASE_URL.';
    }

    if (configuredCandidates.isNotEmpty) {
      return 'Tried backend candidates: ${configuredCandidates.join(', ')}. '
          'Verify Django is running and the phone can reach the same network.';
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'Android emulator uses http://10.0.2.2:8000 with Django on '
          '0.0.0.0:8000. A real device should use '
          'adb reverse tcp:8000 tcp:8000 and http://127.0.0.1:8000, '
          'or API_BASE_URL=http://<LAN-IP>:8000.';
    }

    return 'Check that the backend is running and listening on $targetBaseUrl.';
  }

  static List<String> _candidateBaseUrls({String? preferredBaseUrl}) {
    final candidates = <String>{
      if (preferredBaseUrl?.isNotEmpty == true) preferredBaseUrl!,
      if (_configuredBaseUrl.isNotEmpty) _configuredBaseUrl,
      ..._splitConfiguredCandidates(),
      _preferredDefaultBaseUrl,
      _adbReverseBaseUrl,
      _emulatorBaseUrl,
    };
    return candidates.where((candidate) => candidate.isNotEmpty).toList();
  }

  static List<String> _splitConfiguredCandidates() {
    if (_configuredCandidateBaseUrls.trim().isEmpty) {
      return const <String>[];
    }
    return _configuredCandidateBaseUrls
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
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
  static const String aiMeals = '/api/nutrition/ai-meals/';
  static const String aiMealsAnalyze = '/api/nutrition/ai-meals/analyze/';
  static String aiMeal(String analysisId) => '$aiMeals$analysisId/';
  static String aiMealConfirmation(String analysisId) =>
      '$aiMeals$analysisId/confirmation/';
  static String aiMealFinalize(String analysisId) =>
      '$aiMeals$analysisId/finalize/';
  static const String hydrationSummary = '/api/hydration/summary/';
  static const String hydrationLogs = '/api/hydration/logs/';
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
  static const String motivationOverview = '/api/motivation/overview/';
  static const String motivationPoints = '/api/motivation/points/';
  static const String motivationMissions = '/api/motivation/missions/';
  static String motivationMissionRefresh(int missionId) =>
      '/api/motivation/missions/$missionId/refresh/';
  static const String motivationBadges = '/api/motivation/badges/';
  static const String motivationFeed = '/api/motivation/feed/';
  static const String motivationCelebrationsAck =
      '/api/motivation/celebrations/ack/';
  static const String notificationHubDevicesRegister =
      '/api/notification-hub/devices/register/';
  static const String notificationHubPreferences =
      '/api/notification-hub/preferences/';
  static const String notificationHubSync = '/api/notification-hub/sync/';
  static const String notificationHubReport = '/api/notification-hub/report/';
  static const String managerOverview = '/api/manager/overview/';
  static const String managerGoals = '/api/manager/goals/';
  static const String managerGoalsReset = '/api/manager/goals/reset/';
  static String managerGoal(String key) => '/api/manager/goals/$key/';
  static const String managerNotifications = '/api/manager/notifications/';
  static const String managerAvatar = '/api/manager/avatar/';
  static const String managerSecurity = '/api/manager/security/';
  static const String managerChangePassword =
      '/api/manager/security/change-password/';
  static const String managerLogoutAll = '/api/manager/security/logout-all/';
  static const String managerPrivacy = '/api/manager/privacy/';
  static const String managerPrivacyExport = '/api/manager/privacy/export/';
  static const String managerAccountDeletion =
      '/api/manager/privacy/account-deletion/';
  static const String schema = '/api/schema/';

  static const String meals = '/api/meals/';
  static String meal(int id) => '/api/meals/$id/';
  static const String water = '/api/water/';
  static const String medicines = '/api/medicines/';
  static const String medications = '/api/medications/';
  static const String medicationsToday = '/api/medications/today/';
  static const String medicationsMaterialize = '/api/medications/materialize/';
  static const String medicationsHistory = '/api/medications/history/';
  static const String medicationDoses = '/api/medications/doses/';
  static const String medicationAdherenceSummary =
      '/api/medications/adherence-summary/';
  static String medicationPrnDose(int id) => '/api/medications/$id/prn-dose/';
  static const String steps = '/api/steps/';
  static const String activities = '/api/activities/';
  static const String exercises = '/api/exercises/';
  static const String sleep = '/api/sleep/';
  static const String habits = '/api/habits/';
  static const String unhealthyHabitsOverview =
      '/api/habits/unhealthy/overview/';
  static const String unhealthyHabits = '/api/habits/unhealthy/';
  static const String unhealthyHabitsSetup = '/api/habits/unhealthy/setup/';
  static String unhealthyHabitLogs(int habitId) =>
      '/api/habits/unhealthy/$habitId/logs/';
  static String unhealthyHabitLog(int habitId, int logId) =>
      '/api/habits/unhealthy/$habitId/logs/$logId/';
  static String unhealthyHabitDailyCheckIn(int habitId) =>
      '/api/habits/unhealthy/$habitId/daily-check-in/';
  static String unhealthyHabitPause(int habitId) =>
      '/api/habits/unhealthy/$habitId/pause/';
  static String unhealthyHabitResume(int habitId) =>
      '/api/habits/unhealthy/$habitId/resume/';
  static const String foods = '/api/foods/';
  static const String foodsSearch = '/api/foods/search/';
  static const String foodsAutocomplete = '/api/foods/autocomplete/';
  static const String foodsFavorites = '/api/foods/favorites/';
  static const String foodsRecent = '/api/foods/recent/';
  static String foodFavorite(int foodId) => '/api/foods/$foodId/favorite/';
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
