import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/network/network_error_mapper.dart';
import '../../../core/network/request_manager.dart';
import '../data/stats_repository.dart';
import '../models/day_stat.dart';
import '../models/progress_models.dart';

class StatsController extends ChangeNotifier {
  StatsController({StatsRepository? repository, RequestManager? requestManager})
    : _repository = repository ?? StatsRepository(),
      _requestManager = requestManager ?? RequestManager();

  final StatsRepository _repository;
  final RequestManager _requestManager;

  bool loading = false;
  String? error;
  bool isStale = false;

  int pointsTotal = 0;
  int level = 1;
  double waterTarget = 0;
  double waterCurrent = 0;
  double sleepGoalHours = 0;
  double sleepLoggedHours = 0;
  int caloriesTarget = 0;
  int caloriesConsumed = 0;
  int caloriesRemaining = 0;
  double proteinG = 0;
  double carbsG = 0;
  double fatG = 0;
  double sugarsG = 0;
  double fiberG = 0;
  double caffeineMg = 0;
  int burnTarget = 0;
  int burnCurrent = 0;
  int stepsTarget = 0;
  int stepsCurrent = 0;
  int chronicConditionCount = 0;
  int chronicPendingDoses = 0;
  double chronicAdherencePercent = 0;
  List<String> chronicSummaries = const [];
  String chronicDisclaimer = '';
  List<DayStat> history = <DayStat>[];
  ProgressOverview overview = ProgressOverview.empty();

  Future<void> load() async {
    final overviewLease = _requestManager.beginLatest('progress.overview');
    final historyLease = _requestManager.beginLatest('progress.history');
    loading = true;
    error = null;
    notifyListeners();

    try {
      final snapshot = await _repository.getProgress(
        overviewCancelToken: overviewLease.cancelToken,
        historyCancelToken: historyLease.cancelToken,
      );
      if (!_requestManager.isCurrent(overviewLease) ||
          !_requestManager.isCurrent(historyLease)) {
        return;
      }

      _parseDashboard(snapshot.overview);
      history = snapshot.history;
      overview = ProgressOverview.fromJson(
        snapshot.overview,
        fallbackHistory: history,
      );
      isStale = snapshot.isStale;
    } catch (e) {
      if (NetworkErrorMapper.isCanceled(e)) {
        return;
      }
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load progress data',
      );
    } finally {
      _requestManager.complete(overviewLease);
      _requestManager.complete(historyLease);
      loading = false;
      notifyListeners();
    }
  }

  void _parseDashboard(Map<String, dynamic> d) {
    final summary = _asMap(d['summary']);
    final hydration = _asMap(d['hydration']);
    final sleep = _asMap(d['sleep']);
    final activity = _asMap(d['activity']);
    final gamification = _asMap(d['gamification']);
    final chronic = _asMap(d['chronic_conditions']);

    caloriesTarget = _toInt(summary['calories_target']);
    caloriesConsumed = _toInt(summary['calories_consumed']);
    caloriesRemaining = _toInt(summary['calories_remaining']);
    proteinG = _toDouble(summary['protein_g']);
    carbsG = _toDouble(summary['carbs_g']);
    fatG = _toDouble(summary['fat_g']);
    sugarsG = _toDouble(summary['sugars_g']);
    fiberG = _toDouble(summary['fiber_g']);
    caffeineMg = _toDouble(summary['caffeine_mg']);
    burnCurrent = _toInt(summary['calories_burned']);
    burnTarget = _toInt(summary['burn_target']);

    waterTarget = _toDouble(hydration['target']);
    waterCurrent = _toDouble(hydration['current']);

    sleepGoalHours = _toDouble(sleep['recommended_sleep_hours']);
    sleepLoggedHours = _toDouble(sleep['logged_hours_today']);

    stepsTarget = _toInt(activity['steps_target']);
    stepsCurrent = _toInt(activity['steps']);

    pointsTotal = _toInt(gamification['points']);
    level = _toInt(gamification['level']);

    chronicConditionCount = _toInt(chronic['count']);
    chronicPendingDoses = _toInt(chronic['pending_doses_today']);
    chronicAdherencePercent = _toDouble(chronic['adherence_percent']);
    chronicSummaries = _asStringList(chronic['applied_summaries']);
    chronicDisclaimer = (chronic['disclaimer'] ?? '').toString();
  }

  String formatDate(DateTime d) => DateFormat.MMMd().format(d);

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return const <String>[];
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

  @override
  void dispose() {
    _requestManager.cancelAll();
    super.dispose();
  }
}

class ProgressDetailController extends ChangeNotifier {
  ProgressDetailController({
    required this.tracker,
    StatsRepository? repository,
    RequestManager? requestManager,
  }) : _repository = repository ?? StatsRepository(),
       _requestManager = requestManager ?? RequestManager();

  final String tracker;
  final StatsRepository _repository;
  final RequestManager _requestManager;

  bool loading = false;
  String? error;
  ProgressDetailPayload data = ProgressDetailPayload.empty('');

  Future<void> load({int rangeDays = 7}) async {
    final lease = _requestManager.beginLatest('progress.detail.$tracker');
    loading = true;
    error = null;
    notifyListeners();
    try {
      final payload = await _repository.getDetail(
        tracker: tracker,
        rangeDays: rangeDays,
        cancelToken: lease.cancelToken,
      );
      if (!_requestManager.isCurrent(lease)) {
        return;
      }
      data = payload;
    } catch (e) {
      if (NetworkErrorMapper.isCanceled(e)) {
        return;
      }
      debugPrint('ProgressDetailController.load failed: tracker=$tracker error=$e');
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load $tracker progress detail',
        statusMessages: <int, String>{
          401: 'Session expired while loading $tracker progress. Sign in again.',
          404: 'Progress detail endpoint is missing for $tracker. Restart the Django backend.',
        },
      );
    } finally {
      _requestManager.complete(lease);
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _requestManager.cancelAll();
    super.dispose();
  }
}
