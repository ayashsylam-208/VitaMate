import 'package:flutter/foundation.dart';

import '../../../core/network/network_error_mapper.dart';
import '../../../core/network/request_manager.dart';
import '../data/motivation_repository.dart';
import '../models/motivation_models.dart';

class MotivationController extends ChangeNotifier {
  MotivationController({
    MotivationRepository? repository,
    RequestManager? requestManager,
  }) : _repository = repository ?? MotivationRepository(),
       _requestManager = requestManager ?? RequestManager();

  final MotivationRepository _repository;
  final RequestManager _requestManager;

  bool loading = false;
  String? error;
  bool isStale = false;

  MotivationOverview overview = MotivationOverview.empty();
  List<DailyMission> missions = const <DailyMission>[];
  List<BadgeProgress> badges = const <BadgeProgress>[];
  MotivationPointsPayload points = MotivationPointsPayload.empty();

  Future<void> loadOverview() async {
    final lease = _requestManager.beginLatest('motivation.overview');
    loading = true;
    error = null;
    notifyListeners();
    try {
      final (nextOverview, meta) = await _repository.getOverview(
        cancelToken: lease.cancelToken,
      );
      if (!_requestManager.isCurrent(lease)) {
        return;
      }
      overview = nextOverview;
      isStale = meta.isStale;
    } catch (e) {
      if (NetworkErrorMapper.isCanceled(e)) {
        return;
      }
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load motivation overview',
      );
    } finally {
      _requestManager.complete(lease);
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadDetails({int rangeDays = 7}) async {
    final overviewLease = _requestManager.beginLatest('motivation.overview');
    final missionsLease = _requestManager.beginLatest('motivation.missions');
    final pointsLease = _requestManager.beginLatest('motivation.points');
    final badgesLease = _requestManager.beginLatest('motivation.badges');

    loading = true;
    error = null;
    notifyListeners();
    try {
      final overviewFuture = _repository.getOverview(
        cancelToken: overviewLease.cancelToken,
      );
      final missionsFuture = _repository.getMissions(
        cancelToken: missionsLease.cancelToken,
      );
      final pointsFuture = _repository.getPoints(
        rangeDays: rangeDays,
        cancelToken: pointsLease.cancelToken,
      );
      final badgesFuture = _repository.getBadges(
        cancelToken: badgesLease.cancelToken,
      );

      final (nextOverview, meta) = await overviewFuture;
      final nextMissions = await missionsFuture;
      final nextPoints = await pointsFuture;
      final nextBadges = await badgesFuture;
      if (!_requestManager.isCurrent(overviewLease) ||
          !_requestManager.isCurrent(missionsLease) ||
          !_requestManager.isCurrent(pointsLease) ||
          !_requestManager.isCurrent(badgesLease)) {
        return;
      }
      overview = nextOverview;
      missions = nextMissions;
      points = nextPoints;
      badges = nextBadges;
      isStale = meta.isStale;
    } catch (e) {
      if (NetworkErrorMapper.isCanceled(e)) {
        return;
      }
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Failed to load motivation details',
      );
    } finally {
      _requestManager.complete(overviewLease);
      _requestManager.complete(missionsLease);
      _requestManager.complete(pointsLease);
      _requestManager.complete(badgesLease);
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshMission(int missionId) async {
    final lease = _requestManager.beginLatest('motivation.mission.refresh');
    try {
      final refreshed = await _repository.refreshMission(
        missionId: missionId,
        cancelToken: lease.cancelToken,
      );
      if (!_requestManager.isCurrent(lease) || refreshed == null) {
        return;
      }
      final index = missions.indexWhere((item) => item.id == refreshed.id);
      if (index >= 0) {
        final updated = List<DailyMission>.from(missions);
        updated[index] = refreshed;
        missions = updated;
      }
      await loadOverview();
    } finally {
      _requestManager.complete(lease);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _requestManager.cancelAll();
    super.dispose();
  }
}
