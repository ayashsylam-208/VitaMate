import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/user.dart';
import '../../../core/health/chronic_target_guide.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../../steps/data/steps_repository.dart';
import '../data/activity_repository.dart';
import '../models/activity_log.dart';
import '../models/activity_reminder_settings.dart';
import '../models/activity_session.dart';
import '../models/activity_summary.dart';
import '../models/exercise.dart';

enum WorkoutSessionState {
  idle,
  preparing,
  running,
  paused,
  completed,
  cancelled,
}

class ActivityController extends ChangeNotifier {
  ActivityController({
    ActivityRepository? repository,
    StepsRepository? stepsRepository,
    AuthRepository? authRepository,
    ChronicTargetGuideService? chronicTargetGuideService,
  }) : _repository = repository ?? ActivityRepository(),
       _stepsRepository = stepsRepository ?? StepsRepository(),
       _authRepository = authRepository ?? AuthRepository(AuthApi()),
       _chronicTargetGuideService =
           chronicTargetGuideService ?? const ChronicTargetGuideService();

  final ActivityRepository _repository;
  final StepsRepository _stepsRepository;
  final AuthRepository _authRepository;
  final ChronicTargetGuideService _chronicTargetGuideService;

  bool loading = false;
  bool sessionBusy = false;
  String? error;

  List<Exercise> exercises = <Exercise>[];
  List<ActivityLog> logs = <ActivityLog>[];
  List<ChronicGuideCardData> chronicActivityGuides = const [];
  ActivitySummarySnapshot summary = ActivitySummarySnapshot.empty();
  ActivitySession? activeSession;
  ActivitySession? lastCompletedSession;
  ActivityReminderSettings reminderSettings =
      ActivityReminderSettings.defaults();

  int stepsToday = 0;
  int targetSteps = 0;
  int stepsPointsToday = 0;
  int stepsCaloriesBurned = 0;
  double stepsDistanceKm = 0;
  double stepsBurnRateKcalPerKm = 0;
  double _profileWeightKg = 0;
  double _profileHeightCm = 0;
  String _profileGender = '';
  DateTime _liveClock = DateTime.now();
  Timer? _ticker;

  WorkoutSessionState _workoutState = WorkoutSessionState.idle;
  Exercise? preparedExercise;
  int preparedDurationMinutes = 30;
  String preparedIntensity = 'moderate';

  WorkoutSessionState get workoutState => _workoutState;
  ActivityTodaySummary get todaySummary => summary.todaySummary;
  ActivityWeeklySummary get weeklySummary => summary.weeklySummary;
  List<ActivitySuggestion> get suggestions => summary.suggestions;

  List<ActivityLog> get todayLogs {
    final now = DateTime.now();
    return logs.where((log) => _isSameLocalDate(log.date, now)).toList();
  }

  List<ActivityLog> get recentLogs {
    final now = DateTime.now();
    return logs.where((log) => !_isSameLocalDate(log.date, now)).toList();
  }

  int get burnTargetToday =>
      summary.burnTarget > 0 ? summary.burnTarget : todaySummary.burnTarget;

  int get caloriesBurnedToday => summary.burnCurrent > 0
      ? summary.burnCurrent
      : todaySummary.caloriesBurned;

  int get exerciseMinutesToday => summary.exerciseMinutes > 0
      ? summary.exerciseMinutes
      : todaySummary.activeMinutes;

  int get activityPointsToday => summary.pointsEstimate;
  double get stepDistanceKmToday => stepsDistanceKm > 0
      ? stepsDistanceKm
      : _estimateStepDistanceKm(stepsToday);
  int get stepActiveMinutesEstimate => _estimateStepMinutes(stepsToday);

  int get movementPointsToday {
    final localEstimate = (todayLogs.length * 5) + stepsPointsToday;
    return activityPointsToday > localEstimate
        ? activityPointsToday
        : localEstimate;
  }

  int get totalBurnedToday {
    final fallback = todaySummary.caloriesBurned > 0
        ? todaySummary.caloriesBurned
        : (todayActivityCaloriesBurned + stepsCaloriesBurned);
    return caloriesBurnedToday > fallback ? caloriesBurnedToday : fallback;
  }

  int get todayActivityCaloriesBurned =>
      todayLogs.fold<int>(0, (total, log) => total + log.caloriesBurned);
  int get workoutCaloriesToday {
    final derived = (totalBurnedToday - stepsCaloriesBurned)
        .clamp(0, totalBurnedToday)
        .toInt();
    return todayActivityCaloriesBurned > 0
        ? todayActivityCaloriesBurned
        : derived;
  }

  int get remainingBurn => burnTargetToday <= 0
      ? 0
      : (burnTargetToday - totalBurnedToday).clamp(0, burnTargetToday).toInt();

  int get remainingSteps => targetSteps <= 0
      ? 0
      : (targetSteps - stepsToday).clamp(0, targetSteps).toInt();

  double get burnProgress {
    if (burnTargetToday <= 0) {
      return totalBurnedToday > 0 ? 0.12 : 0.0;
    }
    return (totalBurnedToday / burnTargetToday).clamp(0.0, 1.0).toDouble();
  }

  double get stepsProgress {
    if (targetSteps <= 0) {
      return stepsToday > 0 ? 0.12 : 0.0;
    }
    return (stepsToday / targetSteps).clamp(0.0, 1.0).toDouble();
  }

  bool get hasActiveSession => activeSession != null && activeSession!.isActive;

  Duration get liveElapsed => Duration(seconds: _activeSessionElapsedSeconds());

  Duration get liveRemaining =>
      Duration(seconds: _activeSessionRemainingSeconds());

  int get liveCaloriesBurned => _activeSessionCaloriesBurned();

  int get liveProgressPercent =>
      activeSession == null ? 0 : activeSession!.progressPercentAt(_liveClock);

  String get liveMilestoneMessage {
    if (activeSession == null) {
      return '';
    }
    if (_workoutState == WorkoutSessionState.paused) {
      return 'Workout paused. Resume when you are ready.';
    }
    final remainingSeconds = _activeSessionRemainingSeconds();
    if (remainingSeconds <= 120) {
      return 'Final push!';
    }
    final progress = liveProgressPercent;
    if (progress >= 75) {
      return 'Almost done. Stay steady.';
    }
    if (progress >= 50) {
      return 'Halfway there!';
    }
    if (progress >= 25) {
      return 'Great start, keep going.';
    }
    return 'Start strong!';
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
    }
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _repository.getSummary(),
        _repository.listExercises(),
        _repository.listLogs(),
        _safeStepsSummary(),
        _safeActiveSession(),
        _authRepository.getMe(),
      ]);

      summary = results[0] as ActivitySummarySnapshot;
      exercises = results[1] as List<Exercise>;
      logs = results[2] as List<ActivityLog>;
      _applyStepsSummary(results[3] as Map<String, dynamic>);

      final sessionFromEndpoint = results[4] as ActivitySession?;
      activeSession = sessionFromEndpoint ?? summary.activeSession;

      final authUser = results[5] as AuthUser;
      _profileWeightKg = authUser.profile.weight;
      _profileHeightCm = authUser.profile.height;
      _profileGender = authUser.profile.gender;
      reminderSettings = ActivityReminderSettings.fromProfile(authUser.profile);
      _applyDerivedStepMetrics();

      _syncPreparedExercise();
      _setWorkoutStateFromSession();
      _configureTicker();
    } catch (_) {
      error = 'Failed to load activity data';
    }

    try {
      chronicActivityGuides = await _chronicTargetGuideService.loadForScope(
        ChronicGuideScope.activity,
      );
    } catch (_) {
      chronicActivityGuides = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void prepareWorkout(Exercise exercise, {ActivitySuggestion? suggestion}) {
    preparedExercise = exercise;
    preparedIntensity = suggestion?.intensity ?? 'moderate';
    preparedDurationMinutes =
        suggestion?.recommendedDurationMinutes ??
        exercise.defaultDurationMinutes;
    _workoutState = WorkoutSessionState.preparing;
    notifyListeners();
  }

  void updatePreparedDuration(int minutes) {
    preparedDurationMinutes = minutes.clamp(5, 180).toInt();
    notifyListeners();
  }

  void updatePreparedIntensity(String value) {
    preparedIntensity = value;
    notifyListeners();
  }

  void clearPreparation() {
    if (_workoutState == WorkoutSessionState.preparing) {
      _workoutState = WorkoutSessionState.idle;
      notifyListeners();
    }
  }

  Future<ActivitySession?> startPreparedWorkout() async {
    final exercise = preparedExercise;
    if (exercise == null) {
      return null;
    }
    return startWorkout(
      exerciseId: exercise.id,
      durationMinutes: preparedDurationMinutes,
      intensity: preparedIntensity,
    );
  }

  Future<ActivitySession?> startWorkout({
    required int exerciseId,
    required int durationMinutes,
    required String intensity,
  }) async {
    sessionBusy = true;
    error = null;
    notifyListeners();
    try {
      final session = await _repository.startSession(
        exerciseId: exerciseId,
        targetDurationSeconds: durationMinutes * 60,
        intensity: intensity,
      );
      activeSession = session;
      lastCompletedSession = null;
      _workoutState = WorkoutSessionState.running;
      _liveClock = DateTime.now();
      _configureTicker();
      notifyListeners();
      return session;
    } catch (_) {
      error = 'Failed to start workout';
      notifyListeners();
      return null;
    } finally {
      sessionBusy = false;
      notifyListeners();
    }
  }

  Future<ActivitySession?> pauseLiveSession() async {
    final session = activeSession;
    if (session == null) {
      return null;
    }
    sessionBusy = true;
    notifyListeners();
    try {
      final next = await _repository.pauseSession(session.id);
      activeSession = next;
      _workoutState = WorkoutSessionState.paused;
      _configureTicker();
      notifyListeners();
      return next;
    } catch (_) {
      error = 'Failed to pause workout';
      notifyListeners();
      return null;
    } finally {
      sessionBusy = false;
      notifyListeners();
    }
  }

  Future<ActivitySession?> resumeLiveSession() async {
    final session = activeSession;
    if (session == null) {
      return null;
    }
    sessionBusy = true;
    notifyListeners();
    try {
      final next = await _repository.resumeSession(session.id);
      activeSession = next;
      _workoutState = WorkoutSessionState.running;
      _liveClock = DateTime.now();
      _configureTicker();
      notifyListeners();
      return next;
    } catch (_) {
      error = 'Failed to resume workout';
      notifyListeners();
      return null;
    } finally {
      sessionBusy = false;
      notifyListeners();
    }
  }

  Future<ActivitySession?> editLiveSession({
    required int durationMinutes,
    required String intensity,
    int? exerciseId,
  }) async {
    final session = activeSession;
    if (session == null) {
      return null;
    }
    sessionBusy = true;
    notifyListeners();
    try {
      final next = await _repository.editSession(
        sessionId: session.id,
        exerciseId: exerciseId,
        targetDurationSeconds: durationMinutes * 60,
        intensity: intensity,
      );
      activeSession = next;
      preparedDurationMinutes = durationMinutes;
      preparedIntensity = intensity;
      _setWorkoutStateFromSession();
      notifyListeners();
      return next;
    } catch (_) {
      error = 'Failed to update workout';
      notifyListeners();
      return null;
    } finally {
      sessionBusy = false;
      notifyListeners();
    }
  }

  Future<ActivitySession?> finishLiveSession({
    required bool savePartial,
  }) async {
    final session = activeSession;
    if (session == null) {
      return null;
    }
    sessionBusy = true;
    notifyListeners();
    try {
      final completed = await _repository.finishSession(
        sessionId: session.id,
        savePartial: savePartial,
      );
      lastCompletedSession = completed;
      activeSession = null;
      _workoutState = WorkoutSessionState.completed;
      _configureTicker();
      await load(silent: true);
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.activity,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
      return completed;
    } catch (_) {
      error = 'Failed to finish workout';
      notifyListeners();
      return null;
    } finally {
      sessionBusy = false;
      notifyListeners();
    }
  }

  Future<ActivitySession?> cancelLiveSession() async {
    final session = activeSession;
    if (session == null) {
      return null;
    }
    sessionBusy = true;
    notifyListeners();
    try {
      final cancelled = await _repository.cancelSession(session.id);
      activeSession = null;
      lastCompletedSession = cancelled;
      _workoutState = WorkoutSessionState.cancelled;
      _configureTicker();
      notifyListeners();
      return cancelled;
    } catch (_) {
      error = 'Failed to cancel workout';
      notifyListeners();
      return null;
    } finally {
      sessionBusy = false;
      notifyListeners();
    }
  }

  Future<void> addActivity({
    required int exerciseId,
    required int durationMinutes,
  }) async {
    await _repository.addActivity(
      exerciseId: exerciseId,
      durationMinutes: durationMinutes,
    );
    await load(silent: true);
    HealthSyncBus.instance.publish(const {
      HealthSyncScope.activity,
      HealthSyncScope.homeOverview,
      HealthSyncScope.progressHistory,
    });
  }

  Future<void> addManualSteps(int value) async {
    if (value <= 0) return;
    stepsToday = (stepsToday + value).clamp(0, 1000000).toInt();
    _applyDerivedStepMetrics(preferEstimate: true);
    notifyListeners();
    try {
      await _stepsRepository.logSteps(
        stepsCount: stepsToday,
        distanceKm: stepDistanceKmToday,
      );
      await load(silent: true);
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.steps,
        HealthSyncScope.activity,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
    } catch (_) {
      error = 'Failed to sync steps';
      notifyListeners();
    }
  }

  Future<ActivityReminderSettings> updateReminderSettings(
    ActivityReminderSettings next,
  ) async {
    final user = await _authRepository.updateMe(next.toPatchPayload());
    reminderSettings = ActivityReminderSettings.fromProfile(user.profile);
    notifyListeners();
    return reminderSettings;
  }

  Future<Map<String, dynamic>> _safeStepsSummary() async {
    try {
      return await _stepsRepository.getSummary();
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Future<ActivitySession?> _safeActiveSession() async {
    try {
      return await _repository.getActiveSession();
    } catch (_) {
      return null;
    }
  }

  void _applyStepsSummary(Map<String, dynamic> summaryMap) {
    targetSteps = _toInt(summaryMap['target_steps'] ?? targetSteps);
    stepsToday = _toInt(
      summaryMap['steps_today'] ?? todaySummary.steps ?? stepsToday,
    );
    stepsDistanceKm = _toDouble(summaryMap['distance_km']);
    stepsCaloriesBurned = _toInt(summaryMap['calories_burned']);
    stepsBurnRateKcalPerKm = _toDouble(summaryMap['burn_rate_kcal_per_km']);
    stepsPointsToday = _toInt(summaryMap['points']);

    if (targetSteps <= 0) {
      targetSteps = todaySummary.stepsTarget;
    }
    if (stepsToday <= 0) {
      stepsToday = todaySummary.steps;
    }
    if (stepsCaloriesBurned <= 0) {
      final fromSummary =
          todaySummary.caloriesBurned - todayActivityCaloriesBurned;
      if (fromSummary > 0) {
        stepsCaloriesBurned = fromSummary;
      }
    }
    _applyDerivedStepMetrics();
  }

  void _applyDerivedStepMetrics({bool preferEstimate = false}) {
    if (stepsToday <= 0) {
      stepsDistanceKm = 0;
      stepsBurnRateKcalPerKm = 0;
      if (preferEstimate) {
        stepsCaloriesBurned = 0;
        stepsPointsToday = 0;
      }
      return;
    }
    stepsDistanceKm = _estimateStepDistanceKm(stepsToday);
    if (preferEstimate || stepsCaloriesBurned <= 0) {
      stepsCaloriesBurned = (stepsToday * 0.04).round();
    }
    if (preferEstimate || stepsPointsToday <= 0) {
      stepsPointsToday = _calcStepPoints(stepsToday);
    }
    stepsBurnRateKcalPerKm = stepsDistanceKm > 0
        ? stepsCaloriesBurned / stepsDistanceKm
        : 0;
  }

  double _estimateStepDistanceKm(int steps) {
    if (steps <= 0) return 0;
    final normalizedGender = _profileGender.trim().toLowerCase();
    final strideFactor = normalizedGender.startsWith('m') ? 0.415 : 0.413;
    final heightCm = _profileHeightCm > 0 ? _profileHeightCm : 170.0;
    final strideCm = heightCm * strideFactor;
    return (steps * strideCm) / 100000;
  }

  int _estimateStepMinutes(int steps) {
    if (steps <= 0) return 0;
    return (steps / 100).round();
  }

  void _setWorkoutStateFromSession() {
    final session = activeSession;
    if (session == null) {
      if (_workoutState == WorkoutSessionState.preparing) {
        return;
      }
      if (_workoutState != WorkoutSessionState.completed &&
          _workoutState != WorkoutSessionState.cancelled) {
        _workoutState = WorkoutSessionState.idle;
      }
      return;
    }
    if (session.isPaused) {
      _workoutState = WorkoutSessionState.paused;
      return;
    }
    if (session.isRunning) {
      _workoutState = WorkoutSessionState.running;
      return;
    }
    if (session.isCompleted) {
      _workoutState = WorkoutSessionState.completed;
      return;
    }
    if (session.isCancelled) {
      _workoutState = WorkoutSessionState.cancelled;
    }
  }

  void _syncPreparedExercise() {
    if (preparedExercise == null) {
      return;
    }
    for (final item in exercises) {
      if (item.id == preparedExercise!.id) {
        preparedExercise = item;
        return;
      }
    }
  }

  void _configureTicker() {
    _ticker?.cancel();
    if (activeSession?.isRunning != true) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _liveClock = DateTime.now();
      notifyListeners();
    });
  }

  int _activeSessionElapsedSeconds() {
    final session = activeSession;
    if (session == null) {
      return 0;
    }
    return session.elapsedSecondsAt(_liveClock);
  }

  int _activeSessionRemainingSeconds() {
    final session = activeSession;
    if (session == null) {
      return 0;
    }
    return session.remainingSecondsAt(_liveClock);
  }

  int _activeSessionCaloriesBurned() {
    final session = activeSession;
    if (session == null) {
      return 0;
    }
    return session.caloriesBurnedAt(_liveClock, userWeightKg: _profileWeightKg);
  }

  int estimatedCaloriesFor({
    required Exercise exercise,
    required int durationMinutes,
    required String intensity,
  }) {
    final metValue = exercise.metForIntensity(intensity);
    final elapsedMinutes = durationMinutes <= 0 ? 0 : durationMinutes;
    return ((metValue * 3.5 * _profileWeightKg) / 200 * elapsedMinutes).round();
  }

  ActivitySuggestion? suggestionForExercise(int exerciseId) {
    for (final suggestion in suggestions) {
      if (suggestion.exerciseId == exerciseId) {
        return suggestion;
      }
    }
    return null;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _calcStepPoints(int steps) {
    if (steps <= 0) return 0;
    final points = (steps ~/ 1000) * 5;
    return points <= 0 ? 1 : points;
  }

  bool _isSameLocalDate(DateTime value, DateTime reference) {
    final localValue = value.toLocal();
    final localReference = reference.toLocal();
    return localValue.year == localReference.year &&
        localValue.month == localReference.month &&
        localValue.day == localReference.day;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
