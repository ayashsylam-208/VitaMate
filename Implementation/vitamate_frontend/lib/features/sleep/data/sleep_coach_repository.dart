import '../models/sleep_coach.dart';
import 'sleep_coach_api.dart';

class SleepCoachRepository {
  SleepCoachRepository({SleepCoachApi? api}) : _api = api ?? SleepCoachApi();

  final SleepCoachApi _api;

  Future<SleepCoachOverview> getToday() => _api.getToday();

  Future<SleepPlan> createPlan({
    required DateTime plannedBedTime,
    required DateTime latestWakeTime,
    required int flexibilityMinutes,
    required Map<String, dynamic> questionnaire,
  }) {
    return _api.createPlan(
      plannedBedTime: plannedBedTime,
      latestWakeTime: latestWakeTime,
      flexibilityMinutes: flexibilityMinutes,
      questionnaire: questionnaire,
    );
  }

  Future<SleepFeedbackResult> saveFeedback({
    required int planId,
    required int qualityRating,
    required String wakeFeeling,
    required int focusRating,
    String disruptor = '',
    DateTime? actualSleepStart,
    DateTime? actualWakeTime,
  }) {
    return _api.saveFeedback(
      planId: planId,
      qualityRating: qualityRating,
      wakeFeeling: wakeFeeling,
      focusRating: focusRating,
      disruptor: disruptor,
      actualSleepStart: actualSleepStart,
      actualWakeTime: actualWakeTime,
    );
  }

  Future<void> cancelPlan() => _api.cancelPlan();
}
