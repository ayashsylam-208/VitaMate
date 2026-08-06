import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/user.dart';
import '../../../core/health/chronic_target_guide.dart';
import '../../../core/notification_hub/notification_hub.dart';
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

enum StepSensorLifecycleState {
  uninitialized,
  initializing,
  ready,
  unavailable,
  permissionDenied,
  error,
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
  bool stepSensorPermissionGranted = false;
  bool stepSensorPermissionPermanentlyDenied = false;
  bool stepSensorActive = false;
  bool usingDebugStepSimulation = false;
  StepSensorLifecycleState stepSensorState =
      StepSensorLifecycleState.uninitialized;
  DateTime? lastStepSensorSyncedAt;
  double _profileWeightKg = 0;
  double _profileHeightCm = 0;
  String _profileGender = '';
  DateTime _liveClock = DateTime.now();
  Timer? _ticker;
  StreamSubscription<StepCount>? _stepSub;
  Timer? _stepSyncTimer;
  Timer? _stepNotifyTimer;
  Future<void>? _stepSensorInitInFlight;
  int _stepBaseline = 0;
  String _stepBaselineDate = '';
  int _serverStepsToday = 0;
  int _sensorStepsToday = 0;
  int _manualStepAdjustment = 0;
  int _lastSyncedSensorSteps = 0;
  bool _stepBaselineInitialized = false;

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
    return activityPointsToday > 0 ? activityPointsToday : stepsPointsToday;
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

  int get extraStepsOverGoal => targetSteps <= 0 || stepsToday <= targetSteps
      ? 0
      : stepsToday - targetSteps;

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

  Future<void> load({
    bool silent = false,
    bool requestStepPermission = false,
    bool startStepSensor = true,
  }) async {
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
      reminderSettings = ActivityReminderSettings.fromNotificationPreferences(
        NotificationHubController.instance.preferences,
      );
      _applyDerivedStepMetrics();
      if (startStepSensor) {
        await _ensureStepSensorRunning(
          requestPermission: requestStepPermission,
        );
      }

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
      await load(silent: true, startStepSensor: false);
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
    await _rolloverStepsIfNeeded();
    _manualStepAdjustment = (_manualStepAdjustment + value)
        .clamp(-1000000, 1000000)
        .toInt();
    _recomputeStepsFromSources();
    _applyDerivedStepMetrics(preferEstimate: true);
    notifyListeners();
    try {
      await _stepsRepository.logSteps(
        stepsCount: stepsToday,
        distanceKm: stepDistanceKmToday,
        localDate: _todayKey(),
        timezoneName: DateTime.now().timeZoneName,
        measuredAt: DateTime.now(),
        sensorSteps: _sensorStepsToday,
        manualAdjustmentSteps: _manualStepAdjustment,
        importedAdjustmentSteps: 0,
        syncVersion: DateTime.now().millisecondsSinceEpoch,
      );
      if (stepsToday > _serverStepsToday) {
        _serverStepsToday = stepsToday;
      }
      _lastSyncedSensorSteps = stepsToday;
      await _refreshStepsSummaryOnly();
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

  Future<void> requestStepSensorPermission() async {
    await _ensureStepSensorRunning(requestPermission: true);
    notifyListeners();
  }

  Future<void> openStepSensorSettings() async {
    await openAppSettings();
  }

  Future<void> syncSensorStepsNow() async {
    await _syncStepSensorIfNeeded(force: true);
  }

  Future<ActivityReminderSettings> updateReminderSettings(
    ActivityReminderSettings next,
  ) async {
    final saved = await NotificationHubController.instance.updatePreferences(
      next.toPatchPayload(),
    );
    reminderSettings = ActivityReminderSettings.fromNotificationPreferences(
      saved,
    );
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
    _rolloverStepsIfNeededSync();
    targetSteps = _toInt(summaryMap['target_steps'] ?? targetSteps);
    final summarySteps = _toInt(summaryMap['steps_today']);
    final fallbackSteps = todaySummary.steps;
    final summaryDate = (summaryMap['date'] ?? summaryMap['server_date'])
        ?.toString();
    final sameLocalDate =
        summaryDate == null ||
        summaryDate.isEmpty ||
        summaryDate == _todayKey();
    final incomingSteps = !sameLocalDate
        ? 0
        : summarySteps > 0
        ? summarySteps
        : fallbackSteps;
    final previousLocalSteps = sameLocalDate ? stepsToday : 0;

    if (incomingSteps > _serverStepsToday) {
      _serverStepsToday = incomingSteps;
    }
    _sensorStepsToday = _toInt(summaryMap['sensor_steps']);
    _manualStepAdjustment = _toInt(summaryMap['manual_adjustment_steps']);
    if (_sensorStepsToday <= 0 && _manualStepAdjustment == 0) {
      _sensorStepsToday = incomingSteps;
    }
    stepsToday = incomingSteps > previousLocalSteps
        ? incomingSteps
        : previousLocalSteps;
    stepsDistanceKm = _toDouble(summaryMap['distance_km']);
    stepsCaloriesBurned = _toInt(summaryMap['calories_burned']);
    stepsBurnRateKcalPerKm = _toDouble(summaryMap['burn_rate_kcal_per_km']);
    stepsPointsToday = _toInt(summaryMap['points']);

    if (targetSteps <= 0) {
      targetSteps = todaySummary.stepsTarget;
    }
    if (stepsToday <= 0) {
      stepsToday = incomingSteps;
    }
    if (stepsCaloriesBurned <= 0) {
      final fromSummary =
          todaySummary.caloriesBurned - todayActivityCaloriesBurned;
      if (fromSummary > 0) {
        stepsCaloriesBurned = fromSummary;
      }
    }
    _applyDerivedStepMetrics(preferEstimate: stepsToday > incomingSteps);
  }

  Future<void> _ensureStepSensorRunning({
    required bool requestPermission,
  }) async {
    if (_stepSensorInitInFlight != null) {
      return _stepSensorInitInFlight!;
    }
    final future = _initializeStepSensor(requestPermission: requestPermission);
    _stepSensorInitInFlight = future;
    try {
      await future;
    } finally {
      _stepSensorInitInFlight = null;
    }
  }

  Future<void> _initializeStepSensor({required bool requestPermission}) async {
    if (!_supportsStepSensor) {
      stepSensorPermissionGranted = false;
      stepSensorPermissionPermanentlyDenied = false;
      stepSensorActive = false;
      stepSensorState = StepSensorLifecycleState.unavailable;
      return;
    }

    stepSensorState = StepSensorLifecycleState.initializing;
    await _ensureStepPermission(request: requestPermission);
    if (!stepSensorPermissionGranted) {
      stepSensorActive = false;
      stepSensorState = StepSensorLifecycleState.permissionDenied;
      return;
    }

    await _rolloverStepsIfNeeded();
    await _loadStepBaseline();
    _startStepSensor();
  }

  Future<void> _ensureStepPermission({required bool request}) async {
    try {
      final status = await Permission.activityRecognition.status;
      if (status.isGranted) {
        stepSensorPermissionGranted = true;
        stepSensorPermissionPermanentlyDenied = false;
        return;
      }

      if (request) {
        final result = await Permission.activityRecognition.request();
        stepSensorPermissionGranted = result.isGranted;
        stepSensorPermissionPermanentlyDenied = result.isPermanentlyDenied;
      } else {
        stepSensorPermissionGranted = status.isGranted;
        stepSensorPermissionPermanentlyDenied = status.isPermanentlyDenied;
      }
    } catch (_) {
      stepSensorPermissionGranted = false;
      stepSensorPermissionPermanentlyDenied = false;
    }
  }

  Future<void> _loadStepBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    _stepBaseline = prefs.getInt('activity_steps_baseline') ?? 0;
    _stepBaselineDate = prefs.getString('activity_steps_baseline_date') ?? '';
    if (_stepBaselineDate != _todayKey()) {
      _stepBaseline = 0;
      _stepBaselineDate = '';
      _stepBaselineInitialized = false;
      _sensorStepsToday = 0;
      _manualStepAdjustment = 0;
      stepsToday = _serverStepsToday;
      lastStepSensorSyncedAt = null;
      _lastSyncedSensorSteps = _serverStepsToday;
    } else {
      _stepBaselineInitialized = true;
      _lastSyncedSensorSteps = _serverStepsToday;
    }
  }

  Future<void> _saveStepBaseline(int value) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _todayKey();
    await prefs.setInt('activity_steps_baseline', value);
    await prefs.setString('activity_steps_baseline_date', todayKey);
    _stepBaseline = value;
    _stepBaselineDate = todayKey;
    _stepBaselineInitialized = true;
  }

  void _startStepSensor() {
    _stepSub?.cancel();
    try {
      _stepSub = Pedometer.stepCountStream.listen(
        (event) => unawaited(_handleStepSensorCount(event)),
        onError: (_) {
          stepSensorActive = false;
          stepSensorState = StepSensorLifecycleState.error;
          notifyListeners();
        },
      );
      stepSensorActive = true;
    } catch (_) {
      stepSensorActive = false;
      stepSensorState = StepSensorLifecycleState.error;
    }
  }

  Future<void> _handleStepSensorCount(StepCount event) async {
    stepSensorActive = true;
    await _rolloverStepsIfNeeded();
    await _maybeInitStepBaseline(event.steps);
    final todayKey = _todayKey();
    if (_stepBaselineDate != todayKey) {
      await _saveStepBaseline(event.steps);
    }
    if (!_stepBaselineInitialized || _stepBaselineDate != todayKey) {
      return;
    }

    final sensorSteps = (event.steps - _stepBaseline).clamp(0, 1000000).toInt();
    _sensorStepsToday = sensorSteps;
    _recomputeStepsFromSources();
    stepSensorState = StepSensorLifecycleState.ready;
    _applyDerivedStepMetrics(preferEstimate: true);
    _scheduleStepSensorSync();
    _stepNotifyTimer ??= Timer(const Duration(milliseconds: 350), () {
      _stepNotifyTimer = null;
      notifyListeners();
    });
  }

  Future<void> _maybeInitStepBaseline(int sensorSteps) async {
    final baselineMissing =
        !_stepBaselineInitialized || _stepBaselineDate != _todayKey();
    if (!baselineMissing) {
      return;
    }
    final candidate = sensorSteps - _serverStepsToday;
    final baseline = candidate >= 0 ? candidate : sensorSteps;
    await _saveStepBaseline(baseline);
  }

  void _scheduleStepSensorSync() {
    if (!stepSensorPermissionGranted ||
        stepSensorState != StepSensorLifecycleState.ready ||
        !_stepBaselineInitialized ||
        usingDebugStepSimulation ||
        stepsToday <= 0) {
      return;
    }
    final delta = (stepsToday - _lastSyncedSensorSteps).abs();
    if (delta < 20 && _lastSyncedSensorSteps > 0) {
      return;
    }
    _stepSyncTimer ??= Timer(const Duration(seconds: 12), () {
      _stepSyncTimer = null;
      unawaited(_syncStepSensorIfNeeded());
    });
  }

  Future<void> _syncStepSensorIfNeeded({bool force = false}) async {
    await _rolloverStepsIfNeeded();
    if (!stepSensorPermissionGranted ||
        stepSensorState != StepSensorLifecycleState.ready ||
        !_stepBaselineInitialized ||
        usingDebugStepSimulation ||
        stepsToday <= 0) {
      return;
    }
    final delta = (stepsToday - _lastSyncedSensorSteps).abs();
    if (!force && delta < 20 && _lastSyncedSensorSteps > 0) {
      return;
    }
    try {
      await _stepsRepository.logSteps(
        stepsCount: stepsToday,
        distanceKm: stepDistanceKmToday,
        localDate: _todayKey(),
        timezoneName: DateTime.now().timeZoneName,
        measuredAt: DateTime.now(),
        sensorSteps: _sensorStepsToday,
        manualAdjustmentSteps: _manualStepAdjustment,
        importedAdjustmentSteps: 0,
        syncVersion: DateTime.now().millisecondsSinceEpoch,
      );
      _serverStepsToday = stepsToday;
      _lastSyncedSensorSteps = stepsToday;
      lastStepSensorSyncedAt = DateTime.now();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.steps,
        HealthSyncScope.activity,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
    } catch (_) {
      error = 'Failed to sync automatic steps';
    }
    notifyListeners();
  }

  Future<void> _refreshStepsSummaryOnly() async {
    final nextSummary = await _safeStepsSummary();
    _applyStepsSummary(nextSummary);
    notifyListeners();
  }

  Future<void> _rolloverStepsIfNeeded() async {
    final todayKey = _todayKey();
    if (_stepBaselineDate.isEmpty || _stepBaselineDate == todayKey) {
      return;
    }
    _resetLocalStepStateForNewDay();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activity_steps_baseline');
    await prefs.remove('activity_steps_baseline_date');
  }

  void _rolloverStepsIfNeededSync() {
    if (_stepBaselineDate.isNotEmpty && _stepBaselineDate != _todayKey()) {
      _resetLocalStepStateForNewDay();
    }
  }

  void _resetLocalStepStateForNewDay() {
    _stepSyncTimer?.cancel();
    _stepSyncTimer = null;
    _stepBaseline = 0;
    _stepBaselineDate = '';
    _stepBaselineInitialized = false;
    _serverStepsToday = 0;
    _sensorStepsToday = 0;
    _manualStepAdjustment = 0;
    _lastSyncedSensorSteps = 0;
    stepsToday = 0;
    lastStepSensorSyncedAt = null;
    stepSensorState = StepSensorLifecycleState.uninitialized;
  }

  void _recomputeStepsFromSources() {
    final sourceTotal = (_sensorStepsToday + _manualStepAdjustment)
        .clamp(0, 1000000)
        .toInt();
    stepsToday = sourceTotal > _serverStepsToday
        ? sourceTotal
        : _serverStepsToday;
  }

  void _applyDerivedStepMetrics({bool preferEstimate = false}) {
    if (stepsToday <= 0) {
      stepsDistanceKm = 0;
      stepsBurnRateKcalPerKm = 0;
      if (preferEstimate) {
        stepsCaloriesBurned = 0;
      }
      return;
    }
    stepsDistanceKm = _estimateStepDistanceKm(stepsToday);
    if (preferEstimate || stepsCaloriesBurned <= 0) {
      stepsCaloriesBurned = (stepsToday * 0.04).round();
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

  bool _isSameLocalDate(DateTime value, DateTime reference) {
    final localValue = value.toLocal();
    final localReference = reference.toLocal();
    return localValue.year == localReference.year &&
        localValue.month == localReference.month &&
        localValue.day == localReference.day;
  }

  bool get _supportsStepSensor {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stepSub?.cancel();
    _stepSyncTimer?.cancel();
    _stepNotifyTimer?.cancel();
    super.dispose();
  }
}
