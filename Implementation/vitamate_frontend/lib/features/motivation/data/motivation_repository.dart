import 'package:dio/dio.dart';

import '../../../shared/models/api_result.dart';
import '../models/motivation_models.dart';
import 'motivation_api.dart';

class MotivationRepository {
  MotivationRepository({MotivationApi? api})
    : _api = api ?? const MotivationApi();

  final MotivationApi _api;

  Future<(MotivationOverview, ApiMeta)> getOverview({
    CancelToken? cancelToken,
  }) async {
    final envelope = await _api.getOverview(cancelToken: cancelToken);
    return (MotivationOverview.fromJson(envelope.data), envelope.meta);
  }

  Future<List<DailyMission>> getMissions({CancelToken? cancelToken}) async {
    final envelope = await _api.getMissions(cancelToken: cancelToken);
    final missions = asMapList(
      envelope.data['missions'],
    ).map(DailyMission.fromJson).toList(growable: false);
    return missions;
  }

  Future<DailyMission?> refreshMission({
    required int missionId,
    CancelToken? cancelToken,
  }) async {
    final envelope = await _api.refreshMission(
      missionId: missionId,
      cancelToken: cancelToken,
    );
    final mission = asMap(envelope.data['mission']);
    if (mission.isEmpty) {
      return null;
    }
    return DailyMission.fromJson(mission);
  }

  Future<MotivationPointsPayload> getPoints({
    int rangeDays = 7,
    CancelToken? cancelToken,
  }) async {
    final envelope = await _api.getPoints(
      rangeDays: rangeDays,
      cancelToken: cancelToken,
    );
    return MotivationPointsPayload.fromJson(envelope.data);
  }

  Future<List<BadgeProgress>> getBadges({CancelToken? cancelToken}) async {
    final envelope = await _api.getBadges(cancelToken: cancelToken);
    return asMapList(
      envelope.data['badges'],
    ).map(BadgeProgress.fromJson).toList(growable: false);
  }

  Future<MotivationFeed> getFeed({CancelToken? cancelToken}) async {
    final envelope = await _api.getFeed(cancelToken: cancelToken);
    return MotivationFeed.fromJson(envelope.data);
  }

  Future<List<int>> acknowledgeCelebrations({
    required List<int> ids,
    CancelToken? cancelToken,
  }) async {
    final envelope = await _api.acknowledgeCelebrations(
      ids: ids,
      cancelToken: cancelToken,
    );
    return (envelope.data['acknowledged_ids'] as List<dynamic>? ?? const [])
        .map((item) => int.tryParse(item.toString()) ?? 0)
        .where((item) => item > 0)
        .toList(growable: false);
  }
}
