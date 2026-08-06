import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_metrics_interceptor.dart';
import '../../../shared/models/api_result.dart';

class StepsApi {
  Future<Map<String, dynamic>> getSummary({CancelToken? cancelToken}) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.stepsSummary,
      cancelToken: cancelToken,
      options: RequestMetricsInterceptor.taggedOptions(tag: 'steps.summary'),
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
    return envelope.data;
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
  }) async {
    final data = <String, dynamic>{
      'steps_count': stepsCount,
      'distance_km': distanceKm,
    };
    if (localDate != null) data['local_date'] = localDate;
    if (timezoneName != null) data['timezone'] = timezoneName;
    if (installationId != null) data['installation_id'] = installationId;
    if (measuredAt != null) data['measured_at'] = measuredAt.toIso8601String();
    if (sensorSteps != null) data['sensor_steps'] = sensorSteps;
    if (manualAdjustmentSteps != null) {
      data['manual_adjustment_steps'] = manualAdjustmentSteps;
    }
    if (importedAdjustmentSteps != null) {
      data['imported_adjustment_steps'] = importedAdjustmentSteps;
    }
    if (syncVersion != null) data['sync_version'] = syncVersion;
    await HttpClient.dio.post(
      ApiEndpoints.steps,
      data: data,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'steps.log',
        method: 'POST',
      ),
    );
  }
}
