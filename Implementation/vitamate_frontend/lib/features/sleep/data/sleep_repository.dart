import 'package:dio/dio.dart';

import '../models/sleep_log.dart';
import '../models/sleep_summary.dart';
import 'sleep_api.dart';

class SleepRepository {
  SleepRepository({SleepApi? api}) : _api = api ?? SleepApi();

  final SleepApi _api;

  Future<List<SleepLog>> getLogs() => _api.getLogs();

  Future<SleepSummary> getSummary({CancelToken? cancelToken}) {
    return _api.getSummary(cancelToken: cancelToken);
  }

  Future<void> addSleep({
    required DateTime startTime,
    required DateTime endTime,
    required String quality,
  }) {
    return _api.addSleep(
      startTime: startTime,
      endTime: endTime,
      quality: quality,
    );
  }

  Future<void> deleteSleep(int id) => _api.deleteSleep(id);
}
