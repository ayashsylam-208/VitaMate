import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/notifications_service.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/chronic_guide_card.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../models/activity_log.dart';
import '../models/activity_reminder_settings.dart';
import '../models/activity_session.dart';
import '../models/activity_summary.dart';
import '../models/exercise.dart';
import '../state/activity_controller.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, this.controller, this.autoLoad = true});

  final ActivityController? controller;
  final bool autoLoad;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late final ActivityController controller;
  late final bool _ownsController;

  Exercise? _selectedManualExercise;
  final _manualDurationCtrl = TextEditingController(text: '30');
  final _manualStepsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? ActivityController();
    _ownsController = widget.controller == null;
    HealthSyncBus.instance.addListener(_handleTrackerRefresh);
    if (widget.autoLoad) {
      unawaited(controller.load());
    }
  }

  @override
  void dispose() {
    HealthSyncBus.instance.removeListener(_handleTrackerRefresh);
    _manualDurationCtrl.dispose();
    _manualStepsCtrl.dispose();
    if (_ownsController) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleTrackerRefresh() {
    if (!HealthSyncBus.instance.affects(const {
      HealthSyncScope.activity,
      HealthSyncScope.steps,
    })) {
      return;
    }
    unawaited(controller.load(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: -1),
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.loading ? null : () => controller.load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final showInitialLoader =
                controller.loading &&
                controller.exercises.isEmpty &&
                controller.logs.isEmpty &&
                !controller.hasActiveSession;

            if (showInitialLoader) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.error != null &&
                controller.exercises.isEmpty &&
                controller.logs.isEmpty &&
                !controller.hasActiveSession) {
              return _ErrorPanel(
                message: controller.error!,
                onRetry: () => controller.load(),
              );
            }

            _syncManualExerciseSelection();
            final workoutOptions = _workoutCards();

            return RefreshIndicator(
              onRefresh: () => controller.load(),
              child: ListView(
                key: const ValueKey(AppTestKeys.activityScreen),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
                children: [
                  const Text(
                    'Live workouts, manual logging, reminders, and weekly progress in one place.',
                    style: TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (controller.error != null) ...[
                    const SizedBox(height: 12),
                    _InlineMessage(text: controller.error!),
                  ],
                  const SizedBox(height: 16),
                  _todaySummaryPanel(fmt),
                  if (controller.hasActiveSession) ...[
                    const SizedBox(height: 14),
                    _liveWorkoutPanel(fmt),
                  ],
                  const SizedBox(height: 14),
                  _startWorkoutPanel(workoutOptions),
                  const SizedBox(height: 14),
                  _weeklyGoalPanel(fmt),
                  if (controller.chronicActivityGuides.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _conditionGuidesPanel(),
                  ],
                  const SizedBox(height: 14),
                  _reminderPanel(),
                  const SizedBox(height: 14),
                  _manualLogPanel(),
                  const SizedBox(height: 14),
                  _todaySessionsPanel(fmt),
                  const SizedBox(height: 14),
                  _recentHistoryPanel(fmt),
                  const SizedBox(height: 14),
                  _weeklyInsightsPanel(fmt),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<ActivitySuggestion> _workoutCards() {
    if (controller.suggestions.isNotEmpty) {
      return controller.suggestions;
    }
    return controller.exercises
        .take(6)
        .map((exercise) {
          return ActivitySuggestion(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            iconKey: exercise.iconKey,
            intensity: 'moderate',
            recommendedDurationMinutes: exercise.defaultDurationMinutes,
            estimatedCalories: controller.estimatedCaloriesFor(
              exercise: exercise,
              durationMinutes: exercise.defaultDurationMinutes,
              intensity: 'moderate',
            ),
            reason: 'Quick start option.',
          );
        })
        .toList(growable: false);
  }

  void _syncManualExerciseSelection() {
    if (_selectedManualExercise == null) {
      if (controller.exercises.isNotEmpty) {
        _selectedManualExercise = controller.exercises.first;
      }
      return;
    }
    for (final exercise in controller.exercises) {
      if (exercise.id == _selectedManualExercise!.id) {
        _selectedManualExercise = exercise;
        return;
      }
    }
    _selectedManualExercise = controller.exercises.isEmpty
        ? null
        : controller.exercises.first;
  }

  Widget _todaySummaryPanel(NumberFormat fmt) {
    final summary = controller.todaySummary;
    final progress = controller.burnProgress;
    final progressPercent = controller.burnTargetToday > 0
        ? (progress * 100).round()
        : summary.goalProgressPercent;
    final stepsProgress = controller.stepsProgress;
    final headlineCalories = controller.totalBurnedToday;
    final remainingBurn = controller.remainingBurn;
    final statusMessage = controller.burnTargetToday > 0
        ? remainingBurn > 0
              ? 'You are ${fmt.format(remainingBurn)} kcal away from your daily burn goal.'
              : 'Daily burn goal completed.'
        : (summary.message.isEmpty
              ? 'Track movement to unlock richer coaching.'
              : summary.message);
    final detailTiles = <Widget>[
      _MetricTile(
        icon: Icons.fitness_center_rounded,
        label: 'Workout burn',
        value: '${fmt.format(controller.workoutCaloriesToday)} kcal',
      ),
      _MetricTile(
        icon: Icons.local_fire_department_outlined,
        label: 'Steps burn',
        value: '${fmt.format(controller.stepsCaloriesBurned)} kcal',
      ),
      _MetricTile(
        icon: Icons.timer_outlined,
        label: 'Today workout',
        value: '${fmt.format(controller.exerciseMinutesToday)} min',
      ),
      _MetricTile(
        icon: Icons.straighten_rounded,
        label: 'Step distance',
        value: '${controller.stepDistanceKmToday.toStringAsFixed(2)} km',
      ),
    ];

    return _ActivityPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      icon: Icons.local_fire_department_rounded,
                      title: 'Today Activity Summary',
                      subtitle:
                          'Burn, points, workout time, and step progress.',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${fmt.format(headlineCalories)} kcal burned',
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusMessage,
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProgressRing(
                    value: progress,
                    label: '$progressPercent%',
                    caption: 'goal',
                    icon: Icons.auto_graph_rounded,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${fmt.format(controller.movementPointsToday)} pts',
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'points today',
                    style: TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VitaMateTheme.softSurface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: VitaMateTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.directions_walk_rounded,
                      color: VitaMateTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Step counter',
                        style: TextStyle(
                          color: VitaMateTheme.primaryDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      controller.targetSteps > 0
                          ? '${fmt.format(controller.stepsToday)} / ${fmt.format(controller.targetSteps)}'
                          : fmt.format(controller.stepsToday),
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: stepsProgress,
                    minHeight: 10,
                    backgroundColor: VitaMateTheme.border.withValues(
                      alpha: 0.35,
                    ),
                    color: VitaMateTheme.success,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.targetSteps > 0
                      ? '${fmt.format(controller.remainingSteps)} steps left to reach your goal'
                      : 'No step goal set yet',
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _metricGrid(children: detailTiles),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.flash_on_rounded,
                size: 18,
                color: VitaMateTheme.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Quick step update',
                style: TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (controller.targetSteps > 0)
                Text(
                  '${fmt.format(controller.remainingSteps)} left',
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualStepsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.add_rounded),
                    labelText: 'Add steps',
                    hintText: 'Example: 500',
                    suffixText: 'steps',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: controller.loading ? null : _addManualSteps,
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveWorkoutPanel(NumberFormat fmt) {
    final session = controller.activeSession!;
    final isPaused = session.isPaused;
    return _ActivityPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  icon: Icons.watch_later_outlined,
                  title: 'Live Workout',
                  subtitle: 'Your current session is tracked in real time.',
                ),
              ),
              _Badge(isPaused ? 'Paused' : 'Running'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _ProgressRing(
                value: controller.liveProgressPercent / 100,
                label: '${controller.liveProgressPercent}%',
                caption: 'progress',
                icon: _iconForKey(session.exerciseIconKey),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.exerciseName,
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.liveMilestoneMessage,
                      style: const TextStyle(
                        color: VitaMateTheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${fmt.format(controller.liveCaloriesBurned)} kcal burned',
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _metricGrid(
            children: [
              _MetricTile(
                icon: Icons.hourglass_bottom_rounded,
                label: 'Remaining',
                value: _formatClock(controller.liveRemaining),
              ),
              _MetricTile(
                icon: Icons.timer_outlined,
                label: 'Elapsed',
                value: _formatClock(controller.liveElapsed),
              ),
              _MetricTile(
                icon: Icons.flag_outlined,
                label: 'Target',
                value: _formatClock(
                  Duration(seconds: session.targetDurationSeconds),
                ),
              ),
              _MetricTile(
                icon: Icons.local_fire_department_rounded,
                label: 'Estimate',
                value: '${fmt.format(session.estimatedCalories)} kcal',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: controller.sessionBusy
                    ? null
                    : (isPaused ? _resumeWorkout : _pauseWorkout),
                icon: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                label: Text(isPaused ? 'Resume' : 'Pause'),
              ),
              OutlinedButton.icon(
                onPressed: controller.sessionBusy
                    ? null
                    : () => _openWorkoutSetupSheet(
                        initialExercise: _exerciseById(session.exerciseId),
                        editing: true,
                      ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: controller.sessionBusy ? null : _handleFinishWorkout,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conditionGuidesPanel() {
    final guideCount = controller.chronicActivityGuides.length;
    return _ActivityExpansionPanel(
      icon: Icons.rule_folder_outlined,
      title: 'Condition Goals and Limits',
      subtitle: '$guideCount active guideline${guideCount == 1 ? '' : 's'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity targets are adjusted when chronic-condition guidance applies.',
            style: TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: controller.chronicActivityGuides
                .take(3)
                .map((item) => ChronicGuideCard(item: item, compact: true))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _startWorkoutPanel(List<ActivitySuggestion> workoutOptions) {
    return _ActivityPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.play_circle_outline_rounded,
            title: 'Start Workout',
            subtitle: 'Choose an activity card to set duration and intensity.',
          ),
          const SizedBox(height: 16),
          if (workoutOptions.isEmpty)
            const Text(
              'No activity catalog is available yet. Refresh to try again.',
              style: TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: workoutOptions
                      .map(
                        (option) => SizedBox(
                          width: itemWidth,
                          child: _WorkoutCard(
                            suggestion: option,
                            onTap: () => _openWorkoutSetupSheet(
                              initialExercise: _exerciseById(option.exerciseId),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _weeklyGoalPanel(NumberFormat fmt) {
    final weekly = controller.weeklySummary;
    final progress = weekly.goalTargetMinutes <= 0
        ? 0.0
        : (weekly.goalAchievementRate / 100).clamp(0.0, 1.0);
    return _ActivityPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.calendar_month_rounded,
            title: 'Weekly Goal',
            subtitle: 'Track active minutes against your weekly target.',
          ),
          const SizedBox(height: 16),
          Text(
            '${fmt.format(weekly.weeklyMinutes)} / ${fmt.format(weekly.goalTargetMinutes)} min',
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: progress,
              backgroundColor: VitaMateTheme.softSurface,
              color: VitaMateTheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            weekly.remainingMinutes > 0
                ? '${fmt.format(weekly.remainingMinutes)} min remaining this week'
                : 'Weekly activity goal completed.',
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderPanel() {
    final settings = controller.reminderSettings;
    return _ActivityExpansionPanel(
      icon: Icons.notifications_active_outlined,
      title: 'Activity Notifications',
      subtitle: _reminderSummary(settings),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily workout nudges plus inactivity reminders.',
            style: TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          _ToggleTile(
            title: 'Daily reminder',
            subtitle: _daysLabel(settings.reminderDays),
            value: settings.dailyReminderEnabled,
            onChanged: (value) => _toggleDailyReminder(value),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: settings.dailyReminderEnabled ? _pickReminderTime : null,
            child: Opacity(
              opacity: settings.dailyReminderEnabled ? 1 : 0.45,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VitaMateTheme.softSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: VitaMateTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: VitaMateTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reminder time',
                            style: TextStyle(
                              color: VitaMateTheme.primaryDeep,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            TimeOfDay.fromDateTime(
                              settings.reminderTime,
                            ).format(context),
                            style: const TextStyle(
                              color: VitaMateTheme.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_rounded,
                      color: VitaMateTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChoicePill(
                label: 'Every day',
                selected: _isEveryDay(settings.reminderDays),
                onTap: () =>
                    _updateReminderDays(const <int>[1, 2, 3, 4, 5, 6, 7]),
              ),
              _ChoicePill(
                label: 'Weekdays',
                selected: listEquals(settings.reminderDays, const <int>[
                  1,
                  2,
                  3,
                  4,
                  5,
                ]),
                onTap: () => _updateReminderDays(const <int>[1, 2, 3, 4, 5]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ToggleTile(
            title: 'Inactive reminder',
            subtitle:
                'Remind me if I stay inactive for ${settings.inactiveReminderHours} hours',
            value: settings.inactiveReminderEnabled,
            onChanged: (value) => _toggleInactiveReminder(value),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [2, 3, 4, 6]
                .map(
                  (hours) => _ChoicePill(
                    label: '$hours h',
                    selected: settings.inactiveReminderHours == hours,
                    onTap: () => _updateInactiveHours(hours),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _manualLogPanel() {
    return _ActivityExpansionPanel(
      icon: Icons.edit_note_rounded,
      title: 'Manual Log',
      subtitle: 'Add a workout after you finish it outside the timer.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          DropdownButtonFormField<Exercise>(
            key: ValueKey<int?>(_selectedManualExercise?.id),
            isExpanded: true,
            initialValue: _selectedManualExercise,
            items: controller.exercises
                .map(
                  (exercise) => DropdownMenuItem(
                    value: exercise,
                    child: Text(exercise.name),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _selectedManualExercise = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.sports_gymnastics_rounded),
              labelText: 'Select activity',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualDurationCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.timer_outlined),
              labelText: 'Duration',
              suffixText: 'min',
            ),
          ),
          const SizedBox(height: 14),
          _GradientButton(
            label: 'Save manual activity',
            icon: Icons.check_rounded,
            onPressed: _selectedManualExercise == null ? null : _saveManualLog,
          ),
        ],
      ),
    );
  }

  Widget _todaySessionsPanel(NumberFormat fmt) {
    final count = controller.todayLogs.length;
    return _ActivityExpansionPanel(
      icon: Icons.today_rounded,
      title: 'Today Sessions',
      subtitle: count == 0
          ? 'No saved sessions yet today.'
          : '$count saved session${count == 1 ? '' : 's'} today',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.todayLogs.isEmpty)
            const Text(
              'No sessions saved today yet.',
              style: TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < controller.todayLogs.length; i++) ...[
                  _ActivityLogRow(log: controller.todayLogs[i], fmt: fmt),
                  if (i != controller.todayLogs.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _recentHistoryPanel(NumberFormat fmt) {
    final items = controller.recentLogs.take(5).toList();
    final total = controller.recentLogs.length;
    return _ActivityExpansionPanel(
      icon: Icons.history_rounded,
      title: 'Recent History',
      subtitle: total == 0
          ? 'No earlier activity logs.'
          : '$total earlier session${total == 1 ? '' : 's'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty)
            const Text(
              'No earlier activity logs found.',
              style: TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _ActivityLogRow(log: items[i], fmt: fmt),
                  if (i != items.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _weeklyInsightsPanel(NumberFormat fmt) {
    final weekly = controller.weeklySummary;
    return _ActivityExpansionPanel(
      icon: Icons.insights_rounded,
      title: 'Weekly Insights',
      subtitle:
          '${fmt.format(weekly.activeDays)} active days • ${fmt.format(weekly.weeklyMinutes)} min this week',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricGrid(
            children: [
              _MetricTile(
                icon: Icons.calendar_view_week_rounded,
                label: 'Active days',
                value: '${fmt.format(weekly.activeDays)} days',
              ),
              _MetricTile(
                icon: Icons.timelapse_rounded,
                label: 'Weekly minutes',
                value: '${fmt.format(weekly.weeklyMinutes)} min',
              ),
              _MetricTile(
                icon: Icons.local_fire_department_rounded,
                label: 'Burned',
                value: '${fmt.format(weekly.weeklyKcal)} kcal',
              ),
              _MetricTile(
                icon: Icons.star_rounded,
                label: 'Best activity',
                value: weekly.bestActivity.isEmpty
                    ? 'Not enough data'
                    : weekly.bestActivity,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricGrid({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }

  Future<void> _openWorkoutSetupSheet({
    required Exercise initialExercise,
    bool editing = false,
  }) async {
    final currentSession = controller.activeSession;
    var selectedExercise = initialExercise;
    var durationMinutes = editing && currentSession != null
        ? (currentSession.targetDurationSeconds / 60).round()
        : (controller
                  .suggestionForExercise(initialExercise.id)
                  ?.recommendedDurationMinutes ??
              initialExercise.defaultDurationMinutes);
    var intensity = editing && currentSession != null
        ? currentSession.intensity
        : (controller.suggestionForExercise(initialExercise.id)?.intensity ??
              'moderate');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final estimatedCalories = controller.estimatedCaloriesFor(
              exercise: selectedExercise,
              durationMinutes: durationMinutes,
              intensity: intensity,
            );
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 16,
              ),
              child: _ActivityPanel(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      icon: _iconForKey(selectedExercise.iconKey),
                      title: editing ? 'Edit Session' : 'Session Setup',
                      subtitle: selectedExercise.name,
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<Exercise>(
                      value: selectedExercise,
                      isExpanded: true,
                      items: controller.exercises
                          .map(
                            (exercise) => DropdownMenuItem(
                              value: exercise,
                              child: Text(exercise.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => selectedExercise = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Activity',
                        prefixIcon: Icon(Icons.fitness_center_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Recommended duration',
                      style: TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setSheetState(() {
                              durationMinutes = (durationMinutes - 5)
                                  .clamp(5, 180)
                                  .toInt();
                            });
                          },
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$durationMinutes min',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: VitaMateTheme.primaryDeep,
                                ),
                              ),
                              Slider(
                                value: durationMinutes.toDouble(),
                                min: 5,
                                max: 90,
                                divisions: 17,
                                label: '$durationMinutes min',
                                onChanged: (value) {
                                  setSheetState(() {
                                    durationMinutes = value.round();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setSheetState(() {
                              durationMinutes = (durationMinutes + 5)
                                  .clamp(5, 180)
                                  .toInt();
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Intensity',
                      style: TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in const [
                          'light',
                          'moderate',
                          'intense',
                        ])
                          _ChoicePill(
                            label: _capitalize(item),
                            selected: intensity == item,
                            onTap: () => setSheetState(() => intensity = item),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: VitaMateTheme.softSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: VitaMateTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: VitaMateTheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Estimated calories: $estimatedCalories kcal',
                              style: const TextStyle(
                                color: VitaMateTheme.primaryDeep,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _GradientButton(
                      label: editing ? 'Apply changes' : 'Start session',
                      icon: editing
                          ? Icons.check_rounded
                          : Icons.play_arrow_rounded,
                      onPressed: () async {
                        ActivitySession? result;
                        if (editing) {
                          result = await controller.editLiveSession(
                            durationMinutes: durationMinutes,
                            intensity: intensity,
                            exerciseId: selectedExercise.id,
                          );
                        } else {
                          result = await controller.startWorkout(
                            exerciseId: selectedExercise.id,
                            durationMinutes: durationMinutes,
                            intensity: intensity,
                          );
                        }
                        if (result == null || !mounted) {
                          return;
                        }
                        Navigator.of(context).pop();
                        _showSnack(
                          editing ? 'Workout updated' : 'Live workout started',
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pauseWorkout() async {
    final result = await controller.pauseLiveSession();
    if (result != null) {
      _showSnack('Workout paused');
    }
  }

  Future<void> _resumeWorkout() async {
    final result = await controller.resumeLiveSession();
    if (result != null) {
      _showSnack('Workout resumed');
    }
  }

  Future<void> _handleFinishWorkout() async {
    final session = controller.activeSession;
    if (session == null) {
      return;
    }
    if (controller.liveRemaining.inSeconds <= 0) {
      final completed = await controller.finishLiveSession(savePartial: false);
      if (completed != null && mounted) {
        await _postFinishEffects(completed);
      }
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish early?'),
        content: Text(
          'You ended ${session.exerciseName} before the target time. Save it as a partial workout?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('resume'),
            child: const Text('Resume'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('partial'),
            child: const Text('Save partial'),
          ),
        ],
      ),
    );

    if (action == 'partial') {
      final completed = await controller.finishLiveSession(savePartial: true);
      if (completed != null && mounted) {
        await _postFinishEffects(completed);
      }
      return;
    }

    if (action == 'discard') {
      final cancelled = await controller.cancelLiveSession();
      if (cancelled != null) {
        _showSnack('Workout discarded');
      }
    }
  }

  Future<void> _postFinishEffects(ActivitySession session) async {
    final durationMinutes = (session.actualDurationSeconds / 60)
        .round()
        .clamp(1, 999)
        .toInt();
    await NotificationsService.showPostWorkoutHydrationNudge(
      activityName: session.exerciseName,
      durationMinutes: durationMinutes,
    );
    await _showWorkoutSummary(session);
  }

  Future<void> _showWorkoutSummary(ActivitySession session) async {
    final durationMinutes = (session.actualDurationSeconds / 60)
        .round()
        .clamp(1, 999)
        .toInt();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: _ActivityPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.emoji_events_outlined,
                  title: 'Workout Summary',
                  subtitle: 'Saved to your daily and weekly progress.',
                ),
                const SizedBox(height: 18),
                _metricGrid(
                  children: [
                    _MetricTile(
                      icon: _iconForKey(session.exerciseIconKey),
                      label: 'Activity',
                      value: session.exerciseName,
                    ),
                    _MetricTile(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: '$durationMinutes min',
                    ),
                    _MetricTile(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Burned',
                      value: '${session.caloriesBurned} kcal',
                    ),
                    _MetricTile(
                      icon: Icons.stars_rounded,
                      label: 'Points',
                      value: '+5 pts',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _GradientButton(
                  label: 'Done',
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickReminderTime() async {
    final current = controller.reminderSettings;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current.reminderTime),
    );
    if (picked == null) return;
    final next = current.copyWith(
      reminderTime: DateTime(2000, 1, 1, picked.hour, picked.minute),
    );
    final saved = await controller.updateReminderSettings(next);
    await _syncActivityNotifications(saved);
    _showSnack('Activity reminder updated');
  }

  Future<void> _toggleDailyReminder(bool value) async {
    final next = controller.reminderSettings.copyWith(
      dailyReminderEnabled: value,
    );
    final saved = await controller.updateReminderSettings(next);
    await _syncActivityNotifications(saved);
    _showSnack(
      value ? 'Daily activity reminder on' : 'Daily activity reminder off',
    );
  }

  Future<void> _toggleInactiveReminder(bool value) async {
    final next = controller.reminderSettings.copyWith(
      inactiveReminderEnabled: value,
    );
    final saved = await controller.updateReminderSettings(next);
    await _syncActivityNotifications(saved);
    _showSnack(value ? 'Inactive reminder on' : 'Inactive reminder off');
  }

  Future<void> _updateInactiveHours(int hours) async {
    final next = controller.reminderSettings.copyWith(
      inactiveReminderHours: hours,
      legacyIntervalHours: hours,
    );
    final saved = await controller.updateReminderSettings(next);
    await _syncActivityNotifications(saved);
    _showSnack('Inactive reminder set to every $hours hours');
  }

  Future<void> _updateReminderDays(List<int> days) async {
    final next = controller.reminderSettings.copyWith(reminderDays: days);
    await controller.updateReminderSettings(next);
    _showSnack('Reminder days updated');
  }

  Future<void> _syncActivityNotifications(
    ActivityReminderSettings settings,
  ) async {
    await NotificationsService.cancelDailyActivityReminder();
    await NotificationsService.cancelActivityIntervals();

    if (settings.dailyReminderEnabled) {
      await NotificationsService.scheduleDailyActivityReminder(
        time: settings.reminderTime,
      );
    }
    if (settings.inactiveReminderEnabled) {
      await NotificationsService.scheduleActivityEveryXHours(
        settings.inactiveReminderHours,
      );
    }
  }

  Future<void> _saveManualLog() async {
    final minutes = int.tryParse(_manualDurationCtrl.text.trim()) ?? 0;
    if (_selectedManualExercise == null || minutes <= 0) {
      _showSnack('Enter a valid duration and activity');
      return;
    }
    await controller.addActivity(
      exerciseId: _selectedManualExercise!.id,
      durationMinutes: minutes,
    );
    _showSnack('Manual activity saved');
  }

  Future<void> _addManualSteps() async {
    final steps = int.tryParse(_manualStepsCtrl.text.trim()) ?? 0;
    if (steps <= 0) {
      _showSnack('Enter a positive number of steps');
      return;
    }
    await controller.addManualSteps(steps);
    _manualStepsCtrl.clear();
    _showSnack('Added $steps steps');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _reminderSummary(ActivityReminderSettings settings) {
    final daily = settings.dailyReminderEnabled
        ? 'Daily ${TimeOfDay.fromDateTime(settings.reminderTime).format(context)}'
        : 'Daily off';
    final inactive = settings.inactiveReminderEnabled
        ? 'Inactive ${settings.inactiveReminderHours}h'
        : 'Inactive off';
    return '$daily • $inactive';
  }

  Exercise _exerciseById(int id) {
    for (final exercise in controller.exercises) {
      if (exercise.id == id) {
        return exercise;
      }
    }
    return controller.exercises.isNotEmpty
        ? controller.exercises.first
        : Exercise(id: id, name: 'Workout', metValue: 4.0);
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: VitaMateTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ActivityExpansionPanel extends StatelessWidget {
  const _ActivityExpansionPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return _ActivityPanel(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('activity-$title'),
          initiallyExpanded: initiallyExpanded,
          maintainState: true,
          tilePadding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          iconColor: VitaMateTheme.primary,
          collapsedIconColor: VitaMateTheme.primary,
          shape: const Border(),
          collapsedShape: const Border(),
          title: _SectionTitle(icon: icon, title: title, subtitle: subtitle),
          children: [child],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: VitaMateTheme.softSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: VitaMateTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.value,
    required this.label,
    required this.caption,
    required this.icon,
  });

  final double value;
  final String label;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0).toDouble(),
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              color: VitaMateTheme.primary,
              backgroundColor: VitaMateTheme.softSurface,
            ),
          ),
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: VitaMateTheme.softSurface,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: VitaMateTheme.primary, size: 18),
                Text(
                  label,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                Text(
                  caption,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: VitaMateTheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.suggestion, required this.onTap});

  final ActivitySuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: VitaMateTheme.softSurface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: VitaMateTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _iconForKey(suggestion.iconKey),
                      color: VitaMateTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  _Badge(_capitalize(suggestion.intensity)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                suggestion.exerciseName,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${suggestion.recommendedDurationMinutes} min',
                style: const TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '≈ ${suggestion.estimatedCalories} kcal',
                style: const TextStyle(
                  color: VitaMateTheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                suggestion.reason,
                style: const TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityLogRow extends StatelessWidget {
  const _ActivityLogRow({required this.log, required this.fmt});

  final ActivityLog log;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.fitness_center_rounded,
            color: VitaMateTheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.exerciseName,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${fmt.format(log.durationMinutes)} min - ${fmt.format(log.caloriesBurned)} kcal',
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat.MMMd().format(log.date.toLocal()),
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: VitaMateTheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onPressed,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [VitaMateTheme.primary, Color(0xFFC000F5)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x228A33FF),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? VitaMateTheme.primary.withValues(alpha: 0.12)
              : VitaMateTheme.softSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? VitaMateTheme.primary : VitaMateTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? VitaMateTheme.primaryDeep
                : VitaMateTheme.textMuted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitaMateTheme.danger.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: VitaMateTheme.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _ActivityPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.directions_run_rounded,
                color: VitaMateTheme.primary,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatClock(Duration duration) {
  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

String _daysLabel(List<int> days) {
  if (_isEveryDay(days)) {
    return 'Every day';
  }
  if (listEquals(days, const <int>[1, 2, 3, 4, 5])) {
    return 'Weekdays';
  }
  return 'Custom days';
}

bool _isEveryDay(List<int> days) {
  return listEquals(days, const <int>[1, 2, 3, 4, 5, 6, 7]);
}

IconData _iconForKey(String key) {
  switch (key) {
    case 'directions_walk':
      return Icons.directions_walk_rounded;
    case 'directions_run':
      return Icons.directions_run_rounded;
    case 'directions_bike':
      return Icons.directions_bike_rounded;
    case 'sports_mma':
      return Icons.sports_mma_rounded;
    case 'self_improvement':
      return Icons.self_improvement_rounded;
    case 'pool':
      return Icons.pool_rounded;
    case 'rowing':
      return Icons.rowing_rounded;
    case 'music_note':
      return Icons.music_note_rounded;
    default:
      return Icons.fitness_center_rounded;
  }
}
