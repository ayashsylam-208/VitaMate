import 'package:dio/dio.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_metrics_interceptor.dart';
import '../models/ai_meal_analysis.dart';

class AiMealApi {
  Future<AiMealAnalysis> analyze({
    required String imagePath,
    required String idempotencyKey,
    String autoWeightMode = 'try',
  }) async {
    final filename = imagePath.split(RegExp(r'[/\\]')).last;
    final response = await HttpClient.dio.post(
      ApiEndpoints.aiMealsAnalyze,
      data: FormData.fromMap(<String, dynamic>{
        'image': await MultipartFile.fromFile(imagePath, filename: filename),
        'auto_weight_mode': autoWeightMode,
      }),
      options:
          RequestMetricsInterceptor.taggedOptions(
            tag: 'nutrition.ai.analyze',
          ).copyWith(
            headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
            sendTimeout: const Duration(minutes: 2),
            receiveTimeout: const Duration(minutes: 2),
          ),
    );
    return AiMealAnalysis.fromJson(_dataMap(response.data));
  }

  Future<AiMealAnalysis> getAnalysis(String analysisId) async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.aiMeal(analysisId),
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'nutrition.ai.detail',
      ),
    );
    return AiMealAnalysis.fromJson(_dataMap(response.data));
  }

  Future<AiMealAnalysis> confirm({
    required AiMealAnalysis analysis,
    required String selectedDishLabel,
    required String selectedDishId,
    required String mealType,
    required DateTime consumedAt,
    required List<AiMealComponent> components,
  }) async {
    final response = await HttpClient.dio.patch(
      ApiEndpoints.aiMealConfirmation(analysis.id),
      data: <String, dynamic>{
        'selected_dish_label': selectedDishLabel,
        'selected_dish_id': selectedDishId,
        'meal_type': mealType,
        'consumed_at': consumedAt.toIso8601String(),
        'components': components
            .map(
              (item) => <String, dynamic>{
                if (item.id > 0) 'id': item.id,
                'food_item_id': item.mappedFoodItemId,
                'confirmed_grams': item.confirmedGrams,
                'is_included': item.isIncluded,
                'provider_id': item.providerId,
                'provider_label': item.providerLabel,
              },
            )
            .toList(growable: false),
      },
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'nutrition.ai.confirm',
      ),
    );
    return AiMealAnalysis.fromJson(_dataMap(response.data));
  }

  Future<AiMealFinalizeResult> finalize({
    required String analysisId,
    required String idempotencyKey,
    String notes = '',
  }) async {
    final response = await HttpClient.dio.post(
      ApiEndpoints.aiMealFinalize(analysisId),
      data: <String, dynamic>{'notes': notes},
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'nutrition.ai.finalize',
      ).copyWith(headers: <String, dynamic>{'Idempotency-Key': idempotencyKey}),
    );
    return AiMealFinalizeResult.fromJson(_dataMap(response.data));
  }
}

Map<String, dynamic> _dataMap(dynamic responseData) {
  if (responseData is! Map || responseData['data'] is! Map) {
    throw const FormatException('Invalid AI meal response.');
  }
  return Map<String, dynamic>.from(responseData['data'] as Map);
}
