import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_metrics_interceptor.dart';
import '../../../shared/models/api_result.dart';
import '../models/sleep_coach.dart';

class SleepCoachApi {
  Future<SleepCoachOverview> getToday() async {
    final response = await HttpClient.dio.get(
      ApiEndpoints.sleepCoachToday,
      options: RequestMetricsInterceptor.taggedOptions(tag: 'sleep.coach'),
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
    return SleepCoachOverview.fromJson(envelope.data);
  }

  Future<SleepPlan> createPlan({
    required DateTime plannedBedTime,
    required DateTime latestWakeTime,
    required int flexibilityMinutes,
    required Map<String, dynamic> questionnaire,
  }) async {
    final response = await HttpClient.dio.post(
      ApiEndpoints.sleepCoachPlans,
      data: {
        'planned_bed_time': plannedBedTime.toIso8601String(),
        'latest_wake_time': latestWakeTime.toIso8601String(),
        'flexibility_minutes': flexibilityMinutes,
        'questionnaire': questionnaire,
      },
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'sleep.coach.plan',
      ),
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
    return SleepPlan.fromJson(asMap(envelope.data['plan']));
  }

  Future<SleepFeedbackResult> saveFeedback({
    required int planId,
    required int qualityRating,
    required String wakeFeeling,
    required int focusRating,
    String disruptor = '',
    DateTime? actualSleepStart,
    DateTime? actualWakeTime,
  }) async {
    final response = await HttpClient.dio.post(
      ApiEndpoints.sleepCoachFeedback,
      data: {
        'plan_id': planId,
        'quality_rating': qualityRating,
        'wake_feeling': wakeFeeling,
        'focus_rating': focusRating,
        'disruptor': disruptor,
        if (actualSleepStart != null)
          'actual_sleep_start': actualSleepStart.toIso8601String(),
        if (actualWakeTime != null)
          'actual_wake_time': actualWakeTime.toIso8601String(),
      },
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'sleep.coach.feedback',
      ),
    );
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data,
      dataParser: (rawData) => asMap(rawData),
      emptyData: const <String, dynamic>{},
    );
    return SleepFeedbackResult.fromJson(envelope.data);
  }

  Future<void> cancelPlan() async {
    await HttpClient.dio.post(
      ApiEndpoints.sleepCoachPlansCancel,
      options: RequestMetricsInterceptor.taggedOptions(
        tag: 'sleep.coach.cancel',
      ),
    );
  }
}
