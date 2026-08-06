import 'package:dio/dio.dart';

import 'steps_api.dart';

class StepsRepository {
  StepsRepository({StepsApi? api}) : _api = api ?? StepsApi();

  final StepsApi _api;

  Future<Map<String, dynamic>> getSummary({CancelToken? cancelToken}) {
    return _api.getSummary(cancelToken: cancelToken);
  }

  Future<void> logSteps({
    required int stepsCount,
    double distanceKm = 0,
    String? localDate,
    String? timezoneName,
    String? installationId,
    DateTime? measuredAt,
    int? sensorSteps,
    int? manualAdjustmentSteps,
    int? importedAdjustmentSteps,
    int? syncVersion,
  }) {
    return _api.logSteps(
      stepsCount: stepsCount,
      distanceKm: distanceKm,
      localDate: localDate,
      timezoneName: timezoneName,
      installationId: installationId,
      measuredAt: measuredAt,
      sensorSteps: sensorSteps,
      manualAdjustmentSteps: manualAdjustmentSteps,
      importedAdjustmentSteps: importedAdjustmentSteps,
      syncVersion: syncVersion,
    );
  }
}
