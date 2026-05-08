import 'package:flutter/foundation.dart';

import '../../../core/network/network_error_mapper.dart';
import '../../../core/notifications/notifications_service.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../data/sleep_coach_repository.dart';
import '../models/sleep_coach.dart';

class SleepCoachController extends ChangeNotifier {
  SleepCoachController({SleepCoachRepository? repository})
    : _repository = repository ?? SleepCoachRepository();

  final SleepCoachRepository _repository;

  bool loading = false;
  bool saving = false;
  String? error;
  SleepCoachOverview overview = SleepCoachOverview.empty();

  SleepPlan? get plan => overview.plan;
  bool get shouldAskFeedback =>
      overview.feedbackPrompt && overview.plan != null && !overview.plan!.hasFeedback;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    error = null;
    try {
      overview = await _repository.getToday();
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not load sleep coach.',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<SleepPlan?> createPlan({
    required DateTime plannedBedTime,
    required DateTime latestWakeTime,
    required int flexibilityMinutes,
    required Map<String, dynamic> questionnaire,
  }) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      final newPlan = await _repository.createPlan(
        plannedBedTime: plannedBedTime,
        latestWakeTime: latestWakeTime,
        flexibilityMinutes: flexibilityMinutes,
        questionnaire: questionnaire,
      );
      await _schedulePlanWake(newPlan);
      overview = SleepCoachOverview(
        plan: newPlan,
        feedbackPrompt: false,
        learningSummary: overview.learningSummary,
        latestTrackerFactors: newPlan.trackerFactors,
        disclaimer: overview.disclaimer,
      );
      return newPlan;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not save sleep plan.',
      );
      return null;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> cancelPlan() async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _repository.cancelPlan();
      await NotificationsService.cancelSleepCoachWake();
      await load(silent: true);
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not cancel sleep plan.',
      );
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> saveFeedback({
    required int planId,
    required int qualityRating,
    required String wakeFeeling,
    required int focusRating,
    String disruptor = '',
    DateTime? actualSleepStart,
    DateTime? actualWakeTime,
  }) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _repository.saveFeedback(
        planId: planId,
        qualityRating: qualityRating,
        wakeFeeling: wakeFeeling,
        focusRating: focusRating,
        disruptor: disruptor,
        actualSleepStart: actualSleepStart,
        actualWakeTime: actualWakeTime,
      );
      await NotificationsService.cancelSleepCoachWake();
      await load(silent: true);
      HealthSyncBus.instance.publish(const {
        HealthSyncScope.sleep,
        HealthSyncScope.homeOverview,
        HealthSyncScope.progressHistory,
      });
      return true;
    } catch (e) {
      error = NetworkErrorMapper.toMessage(
        e,
        fallback: 'Could not save morning feedback.',
      );
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> _schedulePlanWake(SleepPlan plan) async {
    final wakeTime = plan.selectedWakeTime ?? plan.recommendedOption?.wakeTime;
    if (wakeTime == null) {
      return;
    }
    await NotificationsService.cancelSleepCoachWake();
    await NotificationsService.scheduleSleepCoachWake(wakeTime: wakeTime);
  }
}
