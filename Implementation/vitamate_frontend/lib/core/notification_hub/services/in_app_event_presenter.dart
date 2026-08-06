import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../routing/app_navigator.dart';
import '../models/notification_plan_model.dart';
import '../widgets/notification_experience_widgets.dart';
import 'local_plan_executor.dart';

enum InAppPresentationOutcome {
  presented,
  acknowledged,
  dismissed,
  failedToPresent,
  suppressedByPolicy,
  expired,
}

class InAppPresentationResult {
  const InAppPresentationResult({
    required this.outcome,
    this.presentedAt,
    this.acknowledgedAt,
    this.failureCode,
    this.suppressionReason,
    this.fallbackScheduled = false,
  });

  final InAppPresentationOutcome outcome;
  final DateTime? presentedAt;
  final DateTime? acknowledgedAt;
  final String? failureCode;
  final String? suppressionReason;
  final bool fallbackScheduled;
}

class InAppEventPresentation {
  const InAppEventPresentation({required this.event, required this.result});

  final NotificationPlanModel event;
  final InAppPresentationResult result;
}

class InAppEventPresenter {
  static bool _draining = false;
  static final List<_PresentationBatch> _pending = <_PresentationBatch>[];
  static final Set<String> _presentedRevisions = <String>{};
  static Future<bool> Function(NotificationPlanModel) fallbackScheduler =
      LocalPlanExecutor.showImmediateFallback;

  @visibleForTesting
  static void resetForTesting() {
    _draining = false;
    _pending.clear();
    _presentedRevisions.clear();
    fallbackScheduler = LocalPlanExecutor.showImmediateFallback;
  }

  static Future<List<InAppEventPresentation>> presentAll(
    List<NotificationPlanModel> events,
  ) {
    final completer = Completer<List<InAppEventPresentation>>();
    _pending.add(_PresentationBatch(events: events, completer: completer));
    if (!_draining) {
      _draining = true;
      unawaited(_drain());
    }
    return completer.future;
  }

  static Future<void> _drain() async {
    while (_pending.isNotEmpty) {
      final batch = _pending.removeAt(0);
      try {
        final sorted = [...batch.events]
          ..sort((left, right) {
            final category = _categoryRank(
              right,
            ).compareTo(_categoryRank(left));
            if (category != 0) return category;
            return right.priority.compareTo(left.priority);
          });
        final results = <InAppEventPresentation>[];
        for (final event in sorted) {
          final key = '${event.planId}:${event.revision}';
          if (_presentedRevisions.contains(key)) continue;
          final result = await _presentOne(event);
          if (result.outcome != InAppPresentationOutcome.failedToPresent ||
              result.fallbackScheduled) {
            _presentedRevisions.add(key);
          }
          results.add(InAppEventPresentation(event: event, result: result));
        }
        batch.completer.complete(results);
      } catch (error, stackTrace) {
        batch.completer.completeError(error, stackTrace);
      }
    }
    _draining = false;
  }

  static Future<InAppPresentationResult> present(
    NotificationPlanModel event,
  ) async {
    final results = await presentAll(<NotificationPlanModel>[event]);
    if (results.isEmpty) {
      return const InAppPresentationResult(
        outcome: InAppPresentationOutcome.suppressedByPolicy,
        suppressionReason: 'duplicate_revision',
      );
    }
    return results.first.result;
  }

  static Future<InAppPresentationResult> _presentOne(
    NotificationPlanModel event,
  ) async {
    final now = DateTime.now();
    if (event.expireAt != null && !event.expireAt!.isAfter(now)) {
      return const InAppPresentationResult(
        outcome: InAppPresentationOutcome.expired,
      );
    }
    if (event.category == 'health_critical' ||
        event.foregroundBehavior == 'alert') {
      return _presentHealthAlert(event);
    }
    return _presentNonBlocking(event);
  }

  static Future<InAppPresentationResult> _presentHealthAlert(
    NotificationPlanModel event,
  ) async {
    final context = appNavigatorKey.currentContext;
    if (context == null) {
      return _healthFallback(event, failureCode: 'missing_context');
    }
    try {
      SystemSound.play(SystemSoundType.alert);
      unawaited(HapticFeedback.heavyImpact());
    } catch (_) {
      // Audio and haptics are secondary; visual delivery must still proceed.
    }
    try {
      var shouldOpen = false;
      final allowAcknowledge = event.payload['allow_acknowledge'] == true;
      final acknowledged = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) => VitaHealthAlertDialog(
          title: event.title,
          message: event.body,
          sourceLabel: (event.payload['source_label'] ?? '').toString(),
          allowAcknowledge: allowAcknowledge,
          onReview: () {
            shouldOpen = event.route.isNotEmpty;
            Navigator.of(dialogContext, rootNavigator: true).pop(false);
          },
          onAcknowledge: () =>
              Navigator.of(dialogContext, rootNavigator: true).pop(true),
        ),
      );
      final presentedAt = DateTime.now().toUtc();
      if (shouldOpen) await pushAppRoute(event.route);
      if (acknowledged == true) {
        return InAppPresentationResult(
          outcome: InAppPresentationOutcome.acknowledged,
          presentedAt: presentedAt,
          acknowledgedAt: DateTime.now().toUtc(),
        );
      }
      return InAppPresentationResult(
        outcome: InAppPresentationOutcome.presented,
        presentedAt: presentedAt,
      );
    } catch (_) {
      return _healthFallback(event, failureCode: 'dialog_failed');
    }
  }

  static Future<InAppPresentationResult> _healthFallback(
    NotificationPlanModel event, {
    required String failureCode,
  }) async {
    final scheduled = await fallbackScheduler(event);
    return InAppPresentationResult(
      outcome: InAppPresentationOutcome.failedToPresent,
      failureCode: failureCode,
      fallbackScheduled: scheduled,
    );
  }

  static Future<InAppPresentationResult> _presentNonBlocking(
    NotificationPlanModel event,
  ) async {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) {
      return const InAppPresentationResult(
        outcome: InAppPresentationOutcome.failedToPresent,
        failureCode: 'missing_messenger',
      );
    }
    var opened = false;
    void open() {
      opened = true;
      messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
      if (event.route.isNotEmpty) unawaited(pushAppRoute(event.route));
    }

    final points = int.tryParse(
      (event.payload['points_delta'] ?? event.payload['reward_points'] ?? '0')
          .toString(),
    );
    final content = switch (event.category) {
      'celebration' => VitaAchievementCelebration(
        title: event.title,
        message: event.body,
        points: points,
      ),
      'motivation' => VitaMotivationNudgeCard(
        title: event.title,
        message: event.body,
        points: points,
        onOpen: event.route.isEmpty ? null : open,
      ),
      _ => VitaRoutineReminderBanner(
        title: event.title,
        message: event.body,
        onOpen: event.route.isEmpty ? null : open,
      ),
    };
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
        padding: EdgeInsets.zero,
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: Duration(seconds: event.category == 'celebration' ? 3 : 5),
        content: content,
      ),
    );
    final presentedAt = DateTime.now().toUtc();
    await controller.closed;
    if (event.category == 'celebration') {
      return InAppPresentationResult(
        outcome: InAppPresentationOutcome.acknowledged,
        presentedAt: presentedAt,
        acknowledgedAt: DateTime.now().toUtc(),
      );
    }
    return InAppPresentationResult(
      outcome: opened
          ? InAppPresentationOutcome.presented
          : InAppPresentationOutcome.dismissed,
      presentedAt: presentedAt,
    );
  }

  static int _categoryRank(NotificationPlanModel event) =>
      switch (event.category) {
        'health_critical' => 5,
        'routine' when event.type.startsWith('medication') => 4,
        'routine' => 3,
        'celebration' => 2,
        'motivation' => 1,
        _ => 0,
      };

  static Future<void> showWelcomeNewUser() async {
    await present(
      const NotificationPlanModel(
        planId: 'welcome',
        kind: 'in_app',
        category: 'system',
        type: 'welcome',
        priority: 1,
        title: 'Welcome to VitaMate',
        body: 'Finish setup and VitaMate will prepare your reminders.',
        route: '',
        payload: <String, dynamic>{},
        scheduleSpec: <String, dynamic>{},
        deliverAt: null,
        expireAt: null,
        soundProfile: '',
        exactRequired: false,
        foregroundBehavior: 'banner',
        dedupeKey: 'welcome',
        status: 'planned',
      ),
    );
  }

  static Future<void> showDiabetesSugarWarning({
    required double limitG,
    required double currentG,
    required String sourceLabel,
  }) async {
    await showConditionLimitWarning(
      metricKey: 'sugar',
      metricLabel: 'Sugar',
      limitValue: limitG,
      currentValue: currentG,
      unit: 'g',
      sourceLabel: sourceLabel,
      conditionLabel: 'Diabetes',
    );
  }

  static Future<void> showConditionLimitWarning({
    required String metricKey,
    required String metricLabel,
    required double limitValue,
    required double currentValue,
    required String unit,
    required String sourceLabel,
    required String conditionLabel,
  }) async {
    await present(
      NotificationPlanModel(
        planId: 'condition-$metricKey',
        kind: 'in_app',
        category: 'health_critical',
        type: 'condition_limit_warning',
        priority: 95,
        title: '$metricLabel needs review',
        body:
            '$sourceLabel brings the total to ${currentValue.toStringAsFixed(1)} $unit. Current limit: ${limitValue.toStringAsFixed(1)} $unit.',
        route: '/meals',
        payload: <String, dynamic>{'source_label': conditionLabel},
        scheduleSpec: const <String, dynamic>{},
        deliverAt: null,
        expireAt: DateTime.now().add(const Duration(hours: 1)),
        soundProfile: 'health_critical',
        exactRequired: false,
        foregroundBehavior: 'alert',
        dedupeKey: 'condition-$metricKey',
        status: 'planned',
      ),
    );
  }

  static Future<void> showPostWorkoutHydrationNudge() async {
    await present(
      const NotificationPlanModel(
        planId: 'post-workout-hydration',
        kind: 'in_app',
        category: 'motivation',
        type: 'post_workout_hydration',
        priority: 50,
        title: 'Post-workout nudge',
        body: 'Log your next glass of water to recover better.',
        route: '/water',
        payload: <String, dynamic>{},
        scheduleSpec: <String, dynamic>{},
        deliverAt: null,
        expireAt: null,
        soundProfile: '',
        exactRequired: false,
        foregroundBehavior: 'banner',
        dedupeKey: 'post-workout-hydration',
        status: 'planned',
      ),
    );
  }
}

class _PresentationBatch {
  const _PresentationBatch({required this.events, required this.completer});

  final List<NotificationPlanModel> events;
  final Completer<List<InAppEventPresentation>> completer;
}
