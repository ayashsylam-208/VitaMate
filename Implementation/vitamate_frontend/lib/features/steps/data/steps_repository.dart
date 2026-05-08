import 'package:dio/dio.dart';

import 'steps_api.dart';

class StepsRepository {
  StepsRepository({StepsApi? api}) : _api = api ?? StepsApi();

  final StepsApi _api;

  Future<Map<String, dynamic>> getSummary({CancelToken? cancelToken}) {
    return _api.getSummary(cancelToken: cancelToken);
  }

  Future<void> logSteps({required int stepsCount, double distanceKm = 0}) {
    return _api.logSteps(stepsCount: stepsCount, distanceKm: distanceKm);
  }
}
