import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/notifications_service.dart';
import '../data/steps_api.dart';

class StepsController extends ChangeNotifier {
  StepsController({StepsApi? api}) : _api = api ?? StepsApi();

  final StepsApi _api;

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
  int get remainingSteps => (targetSteps - stepsToday).clamp(0, targetSteps);

  bool reminderEnabled = false;
  TimeOfDay reminderTime = const TimeOfDay(hour: 11, minute: 0);

  StreamSubscription<StepCount>? _sub;
  int _baseline = 0;
  String _baselineDate = '';
  int _serverStepsToday = 0;
  bool _baselineInitialized = false;

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
      final d = await _api.getDashboard();
      final activity = _asMap(d['activity']);
      targetSteps =
          _toInt(activity['steps_target'] ?? activity['daily_step_goal'] ?? targetSteps);
      stepsToday = _toInt(activity['steps'] ?? activity['steps_count'] ?? stepsToday);
      _serverStepsToday = stepsToday;
      distanceKm = _toDouble(activity['distance_km']);
      caloriesBurned = _toInt(activity['steps_burned']);
      burnRateKcalPerKm = _toDouble(activity['steps_burn_rate']);
      pointsToday = _calcPoints(stepsToday);
      if (caloriesBurned == 0 && stepsToday > 0) {
        caloriesBurned = (stepsToday * 0.04).round();
      }
      if (burnRateKcalPerKm == 0 && distanceKm > 0) {
        burnRateKcalPerKm = caloriesBurned / distanceKm;
      }
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
      _serverStepsToday = 0;
      stepsToday = 0;
      pointsToday = 0;
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
    try {
      _sub = Pedometer.stepCountStream.listen(_onStepCount, onError: (e) {
        error = e.toString();
        notifyListeners();
      });
    } catch (e) {
      error = 'Pedometer unavailable: $e';
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
    _maybeInitBaseline(event.steps);

    final todayKey = _todayKey();
    if (_baselineDate != todayKey) {
      _saveBaseline(event.steps);
    }

    final current = (event.steps - _baseline).clamp(0, 1000000);
    stepsToday = current < _serverStepsToday ? _serverStepsToday : current;
    pointsToday = _calcPoints(stepsToday);
    caloriesBurned = (stepsToday * 0.04).round();
    if (distanceKm > 0) {
      burnRateKcalPerKm = caloriesBurned / distanceKm;
    }
    notifyListeners();
  }

  Future<void> syncSteps() async {
    if (!permissionGranted) return;
    try {
      await _api.logSteps(stepsCount: stepsToday);
      await _loadDashboard();
      lastSyncedAt = DateTime.now();
    } catch (_) {
      error = 'Failed to sync steps';
    }
    notifyListeners();
  }

  Future<void> addManualSteps(int value) async {
    if (value <= 0) return;
    stepsToday = (stepsToday + value).clamp(0, 1000000);
    _serverStepsToday = stepsToday;
    pointsToday = _calcPoints(stepsToday);
    notifyListeners();
    try {
      await _api.logSteps(stepsCount: stepsToday);
      await _loadDashboard();
      lastSyncedAt = DateTime.now();
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

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return <String, dynamic>{};
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
    _sub?.cancel();
    super.dispose();
  }
}
