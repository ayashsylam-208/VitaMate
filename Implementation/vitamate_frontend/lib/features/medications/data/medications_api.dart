import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_metrics_interceptor.dart';

class MedicationsApi {
  Future<Map<String, dynamic>> fetchOverview() async {
    final res = await HttpClient.dio.get(
      ApiEndpoints.medicationsOverview,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'medications.overview',
      ),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<dynamic>> fetchMedications() async {
    final res = await HttpClient.dio.get(ApiEndpoints.medications);
    return (res.data as List).cast<dynamic>();
  }

  Future<Map<String, dynamic>> createMedication(
    Map<String, dynamic> payload,
  ) async {
    final res = await HttpClient.dio.post(
      ApiEndpoints.medications,
      data: payload,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updateMedication(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final res = await HttpClient.dio.patch(
      '${ApiEndpoints.medications}$id/',
      data: payload,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> deactivateMedication(int id) async {
    final res = await HttpClient.dio.post(
      '${ApiEndpoints.medications}$id/deactivate/',
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<dynamic> fetchTodayPlan({String? date}) async {
    final res = await HttpClient.dio.get(
      ApiEndpoints.medicationsToday,
      queryParameters: {if (date != null && date.isNotEmpty) 'date': date},
    );
    return res.data;
  }

  Future<Map<String, dynamic>> materializePlans() async {
    final res = await HttpClient.dio.post(ApiEndpoints.medicationsMaterialize);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> logPrnDose(
    int medicationId,
    Map<String, dynamic> payload,
  ) async {
    final res = await HttpClient.dio.post(
      ApiEndpoints.medicationPrnDose(medicationId),
      data: payload,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> fetchMedicationHistory({
    String status = 'all',
    int page = 1,
    int pageSize = 30,
  }) async {
    final res = await HttpClient.dio.get(
      ApiEndpoints.medicationsHistory,
      queryParameters: {'status': status, 'page': page, 'page_size': pageSize},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> markDoseTaken(
    int logId,
    Map<String, dynamic> payload,
  ) async {
    final res = await HttpClient.dio.post(
      '${ApiEndpoints.medicationDoses}$logId/taken/',
      data: payload,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> markDoseMissed(int logId) async {
    final res = await HttpClient.dio.post(
      '${ApiEndpoints.medicationDoses}$logId/missed/',
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> markDoseSkipped(
    int logId,
    Map<String, dynamic> payload,
  ) async {
    final res = await HttpClient.dio.post(
      '${ApiEndpoints.medicationDoses}$logId/skipped/',
      data: payload,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> snoozeDose(
    int logId,
    Map<String, dynamic> payload,
  ) async {
    final res = await HttpClient.dio.post(
      '${ApiEndpoints.medicationDoses}$logId/snooze/',
      data: payload,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> fetchMedicationAdherence(
    int medicationId,
  ) async {
    final res = await HttpClient.dio.get(
      '${ApiEndpoints.medications}$medicationId/adherence/',
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> fetchOverallAdherence() async {
    final res = await HttpClient.dio.get(
      ApiEndpoints.medicationAdherenceSummary,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }
}
