import 'package:dio/dio.dart';

import '../models/day_stat.dart';
import '../models/progress_models.dart';
import 'stats_api.dart';

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.overview,
    required this.history,
    required this.isStale,
  });

  final Map<String, dynamic> overview;
  final List<DayStat> history;
  final bool isStale;
}

class StatsRepository {
  StatsRepository({StatsApi? api}) : _api = api ?? StatsApi();

  final StatsApi _api;

  Future<ProgressSnapshot> getProgress({
    CancelToken? overviewCancelToken,
    CancelToken? historyCancelToken,
  }) async {
    final overviewEnvelope = await _api.getOverview(
      cancelToken: overviewCancelToken,
    );
    final historyFromOverview = _historyFromOverview(overviewEnvelope.data);
    if (historyFromOverview.isNotEmpty) {
      return ProgressSnapshot(
        overview: overviewEnvelope.data,
        history: historyFromOverview,
        isStale: overviewEnvelope.meta.isStale,
      );
    }

    final historyEnvelope = await _api.getHistory(
      cancelToken: historyCancelToken,
    );
    return ProgressSnapshot(
      overview: overviewEnvelope.data,
      history: historyEnvelope.data
          .map((item) => DayStat.fromJson(_asMap(item)))
          .toList(growable: false),
      isStale: overviewEnvelope.meta.isStale || historyEnvelope.meta.isStale,
    );
  }

  Future<ProgressDetailPayload> getDetail({
    required String tracker,
    int rangeDays = 7,
    CancelToken? cancelToken,
  }) async {
    final envelope = await _api.getDetail(
      tracker: tracker,
      rangeDays: rangeDays,
      cancelToken: cancelToken,
    );
    return ProgressDetailPayload.fromJson(envelope.data);
  }

  Future<void> logSleep({
    required DateTime start,
    required DateTime end,
    String quality = 'Deep',
  }) {
    return _api.logSleep(start: start, end: end, quality: quality);
  }

  List<DayStat> _historyFromOverview(Map<String, dynamic> overview) {
    final timeline = overview['timeline_7d'];
    if (timeline is! List || timeline.isEmpty) {
      return const <DayStat>[];
    }
    return timeline
        .map((item) {
          final data = _asMap(item);
          final parsedDate = DateTime.tryParse(data['date']?.toString() ?? '');
          if (parsedDate == null) {
            return null;
          }
          return DayStat(
            date: parsedDate,
            waterCurrent: 0,
            waterTarget: 0,
            steps: 0,
            stepsTarget: 0,
            distanceKm: 0,
            caloriesIn: 0,
            caloriesTarget: 0,
            caloriesBurned: 0,
            proteinG: 0,
            carbsG: 0,
            fatG: 0,
            sugarsG: 0,
            fiberG: 0,
            caffeineMg: 0,
            burnTarget: 0,
            sleepHours: 0,
            sleepTarget: 0,
            exerciseMinutes: 0,
            pointsEstimate: _toInt(data['points']),
            conditionAdherencePercent: 0,
            pendingConditionDoses: 0,
          );
        })
        .whereType<DayStat>()
        .toList(growable: false);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
