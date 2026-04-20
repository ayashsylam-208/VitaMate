import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';

class MedicationsApi {
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

  Future<List<dynamic>> fetchTodayPlan() async {
    final res = await HttpClient.dio.get(ApiEndpoints.medicationsToday);
    return (res.data as List).cast<dynamic>();
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

  Future<Map<String, dynamic>> fetchReminderSync() async {
    final res = await HttpClient.dio.get(ApiEndpoints.medicationReminderSync);
    return Map<String, dynamic>.from(res.data as Map);
  }
}
