import 'package:dio/dio.dart';
import '../../../core/network/http_client.dart';
import '../../../core/config/api_endpoints.dart';

class HomeApi {
  const HomeApi();

  Future<Map<String, dynamic>> getDashboard() async {
    final Response res = await HttpClient.dio.get(ApiEndpoints.dashboard);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
