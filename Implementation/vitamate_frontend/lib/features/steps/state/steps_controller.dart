import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/notifications_service.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../data/steps_repository.dart';

class StepsController extends ChangeNotifier {
  StepsController({StepsRepository? repository})
    : _repository = repository ?? StepsRepository();

  final StepsRepository _repository;

  bool loading = false;
  String? error;
  bool permissionGranted = false;
  bool permissionPermanentlyDenied = false;

  int stepsToday = 0;
  int targetSteps = 6000;
  int pointsToday = 0;
  double distanceKm = 0;
  int caloriesBurned = 0;
  double burnRateKcalPerKm = 0;
  DateTime? lastSyncedAt;
  bool usingDebugStepSimulation = false;
  int get activeMinutesEstimate => _estimateActiveMinutes(stepsToday);
  int get remainingSteps => (targetSteps - stepsToday).clamp(0, targetSteps);

  bool reminderEnabled = false;
  TimeOfDay reminderTime = const TimeOfDay(hour: 11, minute: 0);

  StreamSubscription<StepCount>? _sub;
  int _baseline = 0;
  String _baselineDate = '';
  int _serverStepsToday = 0;
  bool _baselineInitialized = false;
  bool _receivedSensorEvent = false;
  Timer? _debugFallbackStarter;
  Timer? _debugFallbackTicker;
  Timer? _stepNotifyTimer;

  Future<void> init({bool requestPermission = true}) async {
    loading = true;
    error = null;
    notifyListeners();

    await _loadReminderPrefs();
    await ensurePermission(request: requestPermission);
    if (!permissionGranted) {
      loading = false;
      notifyListeners();
      return;
    }

    await _loadDashboard();
    await _loadBaseline();
    _startPedometer();

    loading = false;
    notifyListeners();
  }

  Future<void> refresh() => init(requestPermission: false);

  Future<void> ensurePermission({bool request = false}) async {
    final status = await Permission.activityRecognition.status;
    if (status.isGranted) {
      permissionGranted = true;
      permissionPermanentlyDenied = false;
      error = null;
      return;
    }

    if (request) {
      final res = await Permission.activityRecognition.request();
      permissionGranted = res.isGranted;
      permissionPermanentlyDenied = res.isPermanentlyDenied;
    } else {
      permissionGranted = status.isGranted;
      permissionPermanentlyDenied = status.isPermanentlyDenied;
    }

    if (!permissionGranted) {
      error = 'Activity recognition permission is required';
    } else {
      error = null;
    }
    notifyListeners();
  }

  Future<void> _loadDashboard() async {
    try {
      final summary = await _repository.getSummary();
      targetSteps = _toInt(summary['target_steps'] ?? targetSteps);
      stepsToday = _toInt(summary['steps_today'] ?? stepsToday);
      _serverStepsToday = stepsToday;
      distanceKm = _toDouble(summary['distance_km']);
      caloriesBurned = _toInt(summary['calories_burned']);
      burnRateKcalPerKm = _toDouble(summary['burn_rate_kcal_per_km']);
      pointsToday = _toInt(summary['points']);
      _applyDerivedMetrics();
    } catch (_) {
      error ??= 'Failed to load steps data';
    }
  }

  Future<void> _loadBaseline() async {
    final sp = await SharedPreferences.getInstance();
    _baseline = sp.getInt('steps_baseline') ?? 0;
    _baselineDate = sp.getString('steps_baseline_date') ?? '';

    if (_baselineDate != _todayKey()) {
      _baseline = 0;
      _baselineDate = '';
      _baselineInitialized = false;
      lastSyncedAt = null;
    } else {
      _baselineInitialized = true;
    }
  }

  Future<void> _saveBaseline(int value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('steps_baseline', value);
    await sp.setString('steps_baseline_date', _todayKey());
    _baseline = value;
    _baselineDate = _todayKey();
    _baselineInitialized = true;
  }

  void _startPedometer() {
    _sub?.cancel();
    _receivedSensorEvent = false;
    _stopDebugStepFallback(notify: false);
    try {
      _sub = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (e) {
          error = e.toString();
          _scheduleDebugStepFallback();
          notifyListeners();
        },
      );
      _scheduleDebugStepFallback();
    } catch (e) {
      error = 'Pedometer unavailable: $e';
      _scheduleDebugStepFallback();
      notifyListeners();
    }
  }

  void _maybeInitBaseline(int sensorSteps) {
    final todayKey = _todayKey();
    final baselineMissing = !_baselineInitialized || _baselineDate != todayKey;
    if (!baselineMissing) return;

    final candidate = sensorSteps - _serverStepsToday;
    final base = candidate >= 0 ? candidate : sensorSteps;
    _saveBaseline(base);
  }

  void _onStepCount(StepCount event) {
    _receivedSensorEvent = true;
    _stopDebugStepFallback();
    _maybeInitBaseline(event.steps);

    final todayKey = _todayKey();
    if (_baselineDate != todayKey) {
      _saveBaseline(event.steps);
    }

    final current = (event.steps - _baseline).clamp(0, 1000000).toInt();
    stepsToday = current < _serverStepsToday ? _serverStepsToday : current;
    _applyDerivedMetrics(preferEstimate: true);
    _stepNotifyTimer ??= Timer(const Duration(milliseconds: 400), () {
      _stepNotifyTimer = null;
      notifyListeners();
    });
  }

  Future<void> syncSteps() async {
    if (!permissionGranted) return;
    try {
      await _repository.logSteps(
        stepsCount: stepsToday,
        distanceKm: distanceKm,
      );
      await _loadDashboard();
      lastSyncedAt = DateTime.now();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.steps,
        HealthSyncScope.activity,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
    } catch (_) {
      error = 'Failed to sync steps';
    }
    notifyListeners();
  }

  Future<void> addManualSteps(int value) async {
    if (value <= 0) return;
    stepsToday = (stepsToday + value).clamp(0, 1000000).toInt();
    _applyDerivedMetrics(preferEstimate: true);
    notifyListeners();
    try {
      await _repository.logSteps(
        stepsCount: stepsToday,
        distanceKm: distanceKm,
      );
      await _loadDashboard();
      lastSyncedAt = DateTime.now();
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.steps,
        HealthSyncScope.activity,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
    } catch (_) {
      error = 'Failed to sync manual steps';
      notifyListeners();
    }
  }

  Future<void> enableReminder(TimeOfDay time) async {
    reminderEnabled = true;
    reminderTime = time;
    await _saveReminderPrefs();
    final dt = DateTime(2000, 1, 1, time.hour, time.minute);
    await NotificationsService.scheduleDailyStepsReminder(time: dt);
    notifyListeners();
  }

  Future<void> disableReminder() async {
    reminderEnabled = false;
    await _saveReminderPrefs();
    await NotificationsService.cancelStepsReminder();
    notifyListeners();
  }

  Future<void> _loadReminderPrefs() async {
    final sp = await SharedPreferences.getInstance();
    reminderEnabled = sp.getBool('steps_reminder_enabled') ?? false;
    final h = sp.getInt('steps_reminder_hour');
    final m = sp.getInt('steps_reminder_minute');
    if (h != null && m != null) {
      reminderTime = TimeOfDay(hour: h, minute: m);
    }
  }

  Future<void> _saveReminderPrefs() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('steps_reminder_enabled', reminderEnabled);
    await sp.setInt('steps_reminder_hour', reminderTime.hour);
    await sp.setInt('steps_reminder_minute', reminderTime.minute);
  }

  void _applyDerivedMetrics({bool preferEstimate = false}) {
    if (stepsToday <= 0) {
      distanceKm = 0;
      burnRateKcalPerKm = 0;
      if (preferEstimate) {
        caloriesBurned = 0;
        pointsToday = 0;
      }
      return;
    }
    final estimatedDistanceKm = _estimateDistanceKm(stepsToday);
    if (preferEstimate || distanceKm <= 0 || stepsToday != _serverStepsToday) {
      distanceKm = estimatedDistanceKm;
    }
    if (preferEstimate ||
        caloriesBurned <= 0 ||
        stepsToday != _serverStepsToday) {
      caloriesBurned = (stepsToday * 0.04).round();
    }
    if (preferEstimate || pointsToday <= 0 || stepsToday != _serverStepsToday) {
      pointsToday = _calcPoints(stepsToday);
    }
    burnRateKcalPerKm = distanceKm > 0 ? caloriesBurned / distanceKm : 0;
  }

  double _estimateDistanceKm(int steps) {
    if (steps <= 0) return 0;
    return (steps * 0.74) / 1000;
  }

  int _estimateActiveMinutes(int steps) {
    if (steps <= 0) return 0;
    return (steps / 105).round();
  }

  void _scheduleDebugStepFallback() {
    if (!_supportsDebugStepFallback ||
        _receivedSensorEvent ||
        !permissionGranted ||
        stepsToday > 0 ||
        _serverStepsToday > 0) {
      return;
    }
    _debugFallbackStarter?.cancel();
    _debugFallbackStarter = Timer(const Duration(seconds: 4), () {
      if (_receivedSensorEvent || !permissionGranted) {
        return;
      }
      _beginDebugStepFallback();
    });
  }

  void _beginDebugStepFallback() {
    if (!_supportsDebugStepFallback || _receivedSensorEvent) {
      return;
    }
    usingDebugStepSimulation = true;
    error = null;
    _debugFallbackTicker?.cancel();
    _debugFallbackTicker = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_receivedSensorEvent || !permissionGranted) {
        _stopDebugStepFallback();
        return;
      }
      final nextIncrement = 6 + ((DateTime.now().second ~/ 3) % 4);
      stepsToday = (stepsToday + nextIncrement).clamp(0, 1000000).toInt();
      _applyDerivedMetrics(preferEstimate: true);
      notifyListeners();
      if (stepsToday > 0 && stepsToday % 24 <= nextIncrement) {
        unawaited(syncSteps());
      }
    });
    notifyListeners();
  }

  void _stopDebugStepFallback({bool notify = true}) {
    final wasRunning = usingDebugStepSimulation;
    usingDebugStepSimulation = false;
    _debugFallbackStarter?.cancel();
    _debugFallbackStarter = null;
    _debugFallbackTicker?.cancel();
    _debugFallbackTicker = null;
    if (notify && wasRunning) {
      notifyListeners();
    }
  }

  bool get _supportsDebugStepFallback {
    if (!kDebugMode ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final binding = WidgetsBinding.instance;
    return binding == null || !binding.runtimeType.toString().contains('Test');
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _calcPoints(int steps) {
    if (steps <= 0) return 0;
    final pts = (steps ~/ 1000) * 5;
    return pts <= 0 ? 1 : pts;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  @override
  void dispose() {
    _debugFallbackStarter?.cancel();
    _debugFallbackTicker?.cancel();
    _stepNotifyTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
