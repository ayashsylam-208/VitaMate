import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/http_client.dart';
import '../../../core/config/api_endpoints.dart';
import '../models/water_log.dart';

class WaterApi {
  Future<List<WaterLog>> getTodayLogs() async {
    final res = await HttpClient.dio.get(ApiEndpoints.water);
    final list = (res.data as List).cast<dynamic>();
    return list
        .map((e) => WaterLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addWaterMl(int amountMl) async {
    final liters = amountMl / 1000.0;

    final payload = <String, dynamic>{
      'amount_liter': double.parse(liters.toStringAsFixed(3)),
    };

    final res = await HttpClient.dio.post(
      ApiEndpoints.water,
      data: jsonEncode(payload),
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    final code = res.statusCode ?? 0;
    if (code >= 400) {
      debugPrint('POST /api/water/ failed');
      debugPrint('Status: $code');
      debugPrint('Response: ${res.data}');
      debugPrint('Sent: $payload');
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: res.data,
      );
    }
  }
}
