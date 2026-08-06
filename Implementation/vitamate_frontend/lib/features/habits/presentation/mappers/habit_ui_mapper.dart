import 'package:flutter/material.dart';

import '../../../../core/theme/vitamate_theme.dart';
import '../../models/unhealthy_habit.dart';

enum HabitDisplayState {
  setupRequired,
  notLogged,
  withinPlan,
  approachingLimit,
  limitReached,
  limitExceeded,
  confirmedAbstinent,
  paused,
  insufficientData,
}

enum HabitPrimaryActionType {
  setup,
  checkIn,
  log,
  viewDetails,
  reviewToday,
  resume,
  viewProgress,
  completeEntry,
}

class HabitPrimaryMetric {
  const HabitPrimaryMetric({required this.value, this.helper = ''});

  final String value;
  final String helper;
}

class HabitDetailItem {
  const HabitDetailItem({required this.label, required this.value});

  final String label;
  final String value;
}

class HabitCardViewModel {
  const HabitCardViewModel({
    required this.key,
    required this.habit,
    required this.title,
    required this.icon,
    required this.displayState,
    required this.statusLabel,
    required this.statusColor,
    required this.supportingText,
    required this.primaryMetric,
    required this.primaryAction,
    required this.primaryActionLabel,
    required this.details,
    required this.canExpand,
    required this.canEditPlan,
    required this.canPauseOrResume,
    required this.isPaused,
    required this.isSetupComplete,
    this.inlineMessage = '',
  });

  final String key;
  final UnhealthyHabit habit;
  final String title;
  final IconData icon;
  final HabitDisplayState displayState;
  final String statusLabel;
  final Color statusColor;
  final String supportingText;
  final HabitPrimaryMetric? primaryMetric;
  final HabitPrimaryActionType primaryAction;
  final String primaryActionLabel;
  final List<HabitDetailItem> details;
  final bool canExpand;
  final bool canEditPlan;
  final bool canPauseOrResume;
  final bool isPaused;
  final bool isSetupComplete;
  final String inlineMessage;
}

class HabitsTodaySummaryViewModel {
  const HabitsTodaySummaryViewModel({
    required this.title,
    required this.subtitle,
    required this.toneColor,
  });

  final String title;
  final String subtitle;
  final Color toneColor;
}

class HabitUiMapper {
  const HabitUiMapper._();

  static HabitCardViewModel mapHabit(UnhealthyHabit habit) {
    final state = _displayState(habit);
    final primaryAction = _primaryAction(habit, state);
    final metric = _primaryMetric(habit, state);
    final details = _details(habit);
    final feedback = _feedbackMessage(habit);

    return HabitCardViewModel(
      key: habit.id?.toString() ?? habit.habitType,
      habit: habit,
      title: HabitUiText.habitTitle(habit.habitType, habit.label),
      icon: _icon(habit.habitType),
      displayState: state,
      statusLabel: HabitUiText.statusLabel(state, habit.habitType),
      statusColor: _statusColor(state),
      supportingText: HabitUiText.supportingText(habit, state),
      primaryMetric: metric,
      primaryAction: primaryAction,
      primaryActionLabel: HabitUiText.primaryActionLabel(
        primaryAction,
        habit.habitType,
      ),
      details: details,
      canExpand: habit.isSetup || details.isNotEmpty,
      canEditPlan: habit.isSetup,
      canPauseOrResume: habit.id != null,
      isPaused: state == HabitDisplayState.paused,
      isSetupComplete: habit.isSetup,
      inlineMessage: feedback,
    );
  }

  static HabitsTodaySummaryViewModel mapSummary(
    UnhealthyHabitsOverview overview,
  ) {
    final summary = overview.summary;
    if (summary.activeCount <= 0) {
      return const HabitsTodaySummaryViewModel(
        title: 'Set up your first plan',
        subtitle: 'Choose one habit to track with a plan that fits you.',
        toneColor: VitaMateTheme.primary,
      );
    }
    if (summary.relapsesToday > 0) {
      return HabitsTodaySummaryViewModel(
        title: '${summary.relapsesToday} plan needs attention',
        subtitle: '${summary.logsToday} check-ins or logs today',
        toneColor: VitaMateTheme.warning,
      );
    }
    if (summary.logsToday > 0) {
      return HabitsTodaySummaryViewModel(
        title: '${summary.activeCount} active plans',
        subtitle: '${summary.logsToday} updates recorded today',
        toneColor: VitaMateTheme.success,
      );
    }
    return HabitsTodaySummaryViewModel(
      title: '${summary.activeCount} active plans',
      subtitle: 'No check-ins yet today',
      toneColor: VitaMateTheme.primary,
    );
  }

  static HabitDisplayState _displayState(UnhealthyHabit habit) {
    if (!habit.isSetup) {
      return HabitDisplayState.setupRequired;
    }
    if (!habit.isActive || habit.status == 'paused') {
      return HabitDisplayState.paused;
    }
    final status = (habit.evaluation['status'] ?? '').toString();
    switch (status) {
      case 'not_logged':
        return HabitDisplayState.notLogged;
      case 'within_plan':
        return HabitDisplayState.withinPlan;
      case 'within_plan_with_sleep_risk':
      case 'approaching_limit':
        return HabitDisplayState.approachingLimit;
      case 'limit_reached':
        return HabitDisplayState.limitReached;
      case 'limit_exceeded':
      case 'relapse':
        return HabitDisplayState.limitExceeded;
      case 'confirmed_abstinent':
        return HabitDisplayState.confirmedAbstinent;
      case 'not_applicable':
      case 'paused':
        return HabitDisplayState.paused;
      case 'insufficient_data':
        return HabitDisplayState.insufficientData;
      default:
        return HabitDisplayState.notLogged;
    }
  }

  static HabitPrimaryActionType _primaryAction(
    UnhealthyHabit habit,
    HabitDisplayState state,
  ) {
    if (state == HabitDisplayState.setupRequired) {
      return HabitPrimaryActionType.setup;
    }
    if (state == HabitDisplayState.paused) {
      return HabitPrimaryActionType.resume;
    }
    if (state == HabitDisplayState.limitExceeded) {
      return HabitPrimaryActionType.reviewToday;
    }
    if (state == HabitDisplayState.limitReached) {
      return HabitPrimaryActionType.viewDetails;
    }
    if (state == HabitDisplayState.confirmedAbstinent) {
      return HabitPrimaryActionType.viewProgress;
    }
    if (state == HabitDisplayState.insufficientData) {
      return HabitPrimaryActionType.completeEntry;
    }
    if (habit.habitType == 'smoking') {
      return HabitPrimaryActionType.checkIn;
    }
    return HabitPrimaryActionType.log;
  }

  static HabitPrimaryMetric? _primaryMetric(
    UnhealthyHabit habit,
    HabitDisplayState state,
  ) {
    if (state == HabitDisplayState.setupRequired ||
        state == HabitDisplayState.paused) {
      return null;
    }
    final progress = habit.progress;
    final isFastFood = habit.habitType == 'fast_food';
    final limit = isFastFood ? progress.weeklyLimit : progress.dailyLimit;
    final value = isFastFood ? progress.weekValue : progress.todayValue;
    final unit = _unitLabel(habit.baseline?.unit, habit.habitType);
    if (limit == null || limit <= 0) {
      return HabitPrimaryMetric(
        value: '${_format(value)} $unit',
        helper: isFastFood ? 'this week' : 'today',
      );
    }
    return HabitPrimaryMetric(
      value: '${_format(value)} of ${_format(limit)} $unit',
      helper: isFastFood ? 'this week' : 'today',
    );
  }

  static List<HabitDetailItem> _details(UnhealthyHabit habit) {
    if (!habit.isSetup) {
      return const [];
    }
    final items = <HabitDetailItem>[];
    final progress = habit.progress;
    final plan = habit.plan;
    final todayCount = progress.logsToday.length;
    items.add(
      HabitDetailItem(
        label: 'Today',
        value: todayCount == 0
            ? 'No entries yet'
            : '$todayCount ${todayCount == 1 ? 'entry' : 'entries'} recorded',
      ),
    );
    final planText = _planText(habit);
    if (planText.isNotEmpty) {
      items.add(HabitDetailItem(label: 'Your plan', value: planText));
    }
    if ((plan?.cutoffTime ?? '').isNotEmpty) {
      items.add(
        HabitDetailItem(
          label: 'Cutoff',
          value: 'Avoid after ${plan!.cutoffTime}',
        ),
      );
    }
    if (habit.reminders.isNotEmpty) {
      items.add(
        HabitDetailItem(
          label: 'Reminder',
          value: habit.reminders.first.timeOfDay,
        ),
      );
    }
    if (progress.topTrigger.isNotEmpty) {
      items.add(
        HabitDetailItem(label: 'What led to it?', value: progress.topTrigger),
      );
    }
    if (progress.improvementPercent > 0) {
      items.add(
        HabitDetailItem(
          label: 'Progress',
          value: '${progress.improvementPercent}% from your starting point',
        ),
      );
    }
    if (progress.logsToday.isNotEmpty) {
      final latest = progress.logsToday.first;
      final name = latest.foodName.trim().isNotEmpty
          ? latest.foodName.trim()
          : '${_format(latest.quantity)} ${_unitLabel(latest.unit, habit.habitType)}';
      items.add(HabitDetailItem(label: 'Last entry', value: name));
    }
    return items;
  }

  static String _planText(UnhealthyHabit habit) {
    final plan = habit.plan;
    if (plan == null) {
      return '';
    }
    if (habit.habitType == 'fast_food' && plan.weeklyLimit != null) {
      return 'Up to ${_format(plan.weeklyLimit!)} fast-food meals per week';
    }
    if (plan.dailyLimit != null) {
      return 'Up to ${_format(plan.dailyLimit!)} ${_unitLabel(habit.baseline?.unit, habit.habitType)} per day';
    }
    if (plan.targetQuantity != null) {
      return 'Target: ${_format(plan.targetQuantity!)} ${_unitLabel(habit.baseline?.unit, habit.habitType)}';
    }
    if (habit.goalType == 'quit') {
      return 'Stay completely ${habit.habitType == 'smoking' ? 'smoke-free' : 'free of this habit'}';
    }
    return 'Gradual reduction plan';
  }

  static String _feedbackMessage(UnhealthyHabit habit) {
    final evaluation = habit.evaluation;
    final feedback = evaluation['feedback'];
    if (feedback is! Map) {
      return '';
    }
    return (feedback['message'] ?? '').toString().trim();
  }

  static String _unitLabel(String? raw, String habitType) {
    final unit = (raw ?? '').trim();
    if (unit.isNotEmpty) {
      return unit;
    }
    if (habitType == 'caffeine') {
      return 'mg';
    }
    if (habitType == 'fast_food') {
      return 'meals';
    }
    return 'cigarettes';
  }

  static IconData _icon(String habitType) {
    if (habitType == 'caffeine') {
      return Icons.coffee_rounded;
    }
    if (habitType == 'fast_food') {
      return Icons.fastfood_rounded;
    }
    return Icons.smoke_free_rounded;
  }

  static Color _statusColor(HabitDisplayState state) {
    switch (state) {
      case HabitDisplayState.withinPlan:
      case HabitDisplayState.confirmedAbstinent:
        return VitaMateTheme.success;
      case HabitDisplayState.approachingLimit:
      case HabitDisplayState.limitReached:
      case HabitDisplayState.limitExceeded:
        return VitaMateTheme.warning;
      case HabitDisplayState.paused:
      case HabitDisplayState.insufficientData:
        return VitaMateTheme.textMuted;
      case HabitDisplayState.setupRequired:
      case HabitDisplayState.notLogged:
        return VitaMateTheme.primary;
    }
  }

  static String _format(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class HabitUiText {
  const HabitUiText._();

  static String habitTitle(String habitType, String fallback) {
    if (habitType == 'caffeine') {
      return 'Caffeine';
    }
    if (habitType == 'fast_food') {
      return 'Fast Food';
    }
    if (habitType == 'smoking') {
      return 'Smoking';
    }
    return fallback;
  }

  static String statusLabel(HabitDisplayState state, String habitType) {
    switch (state) {
      case HabitDisplayState.setupRequired:
        return 'Set up a personal plan';
      case HabitDisplayState.notLogged:
        return 'Not checked yet';
      case HabitDisplayState.withinPlan:
        return 'On track';
      case HabitDisplayState.approachingLimit:
        return 'Almost at your goal';
      case HabitDisplayState.limitReached:
        return 'Goal reached';
      case HabitDisplayState.limitExceeded:
        return 'Needs attention';
      case HabitDisplayState.confirmedAbstinent:
        return habitType == 'smoking' ? 'Smoke-free today' : 'On track today';
      case HabitDisplayState.paused:
        return 'Plan paused';
      case HabitDisplayState.insufficientData:
        return 'More information needed';
    }
  }

  static String supportingText(UnhealthyHabit habit, HabitDisplayState state) {
    switch (state) {
      case HabitDisplayState.setupRequired:
        return 'Track this habit with a goal that fits you.';
      case HabitDisplayState.notLogged:
        return habit.habitType == 'smoking'
            ? 'How was today?'
            : 'No check-in yet today.';
      case HabitDisplayState.withinPlan:
        return 'You are still within your plan.';
      case HabitDisplayState.approachingLimit:
        return 'You are close to today\'s goal. Keep it gentle.';
      case HabitDisplayState.limitReached:
        return 'You reached the goal you set for today.';
      case HabitDisplayState.limitExceeded:
        return 'Review today and keep the next step small.';
      case HabitDisplayState.confirmedAbstinent:
        return habit.habitType == 'smoking'
            ? 'Great work staying with your plan.'
            : 'You confirmed today\'s plan.';
      case HabitDisplayState.paused:
        return 'Reminders and daily tracking are paused.';
      case HabitDisplayState.insufficientData:
        return 'Add details to update today\'s status.';
    }
  }

  static String primaryActionLabel(
    HabitPrimaryActionType action,
    String habitType,
  ) {
    switch (action) {
      case HabitPrimaryActionType.setup:
        return 'Set up';
      case HabitPrimaryActionType.checkIn:
        return 'Check in';
      case HabitPrimaryActionType.log:
        if (habitType == 'caffeine') {
          return 'Log a drink';
        }
        if (habitType == 'fast_food') {
          return 'Log fast food';
        }
        return 'Log';
      case HabitPrimaryActionType.viewDetails:
        return 'View details';
      case HabitPrimaryActionType.reviewToday:
        return 'Review today';
      case HabitPrimaryActionType.resume:
        return 'Continue plan';
      case HabitPrimaryActionType.viewProgress:
        return 'View progress';
      case HabitPrimaryActionType.completeEntry:
        return 'Complete entry';
    }
  }
}
