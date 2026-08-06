import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/routes.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../models/activity_session.dart';
import '../models/activity_summary.dart';
import '../models/exercise.dart';
import '../state/activity_controller.dart';

enum _ActivitySurface {
  overview,
  workouts,
  setup,
  live,
  summary,
  steps,
  activeTime,
}

enum _LiveVariant { stepBased, timedIntensive, generalTimed }

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

  final Set<int> _favoriteExerciseIds = <int>{};
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _manualDurationCtrl = TextEditingController(
    text: '20',
  );

  String _workoutTab = 'Recent';
  bool _didApplyRouteArguments = false;
  int _liveStepBaseline = 0;
  bool _keepScreenAwake = true;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? ActivityController();
    _ownsController = widget.controller == null;
    HealthSyncBus.instance.addListener(_handleHealthSync);
    if (widget.autoLoad) {
      unawaited(controller.load());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didApplyRouteArguments) {
      _didApplyRouteArguments = true;
      _applyRouteArguments();
    }
  }

  @override
  void dispose() {
    HealthSyncBus.instance.removeListener(_handleHealthSync);
    _searchCtrl.dispose();
    _manualDurationCtrl.dispose();
    if (_ownsController) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleHealthSync() {
    if (!HealthSyncBus.instance.affects(const {
      HealthSyncScope.activity,
      HealthSyncScope.steps,
    })) {
      return;
    }
    unawaited(controller.load(silent: true));
  }

  void _applyRouteArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Exercise) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          controller.prepareWorkout(args);
        }
      });
      return;
    }
    if (args is _LiveSessionArgs) {
      controller.activeSession = args.session;
      _liveStepBaseline = args.stepBaseline;
      return;
    }
    if (args is ActivitySession) {
      final route = ModalRoute.of(context)?.settings.name;
      if (route == Routes.activitySessionSummary) {
        controller.lastCompletedSession = args;
      } else {
        controller.activeSession = args;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final surface = _surfaceForRoute(ModalRoute.of(context)?.settings.name);
        if (_shouldShowInitialLoader(surface)) {
          return const _ActivityLoadingScaffold();
        }
        return switch (surface) {
          _ActivitySurface.overview => _buildOverview(),
          _ActivitySurface.workouts => _buildWorkoutsHub(),
          _ActivitySurface.setup => _buildSessionSetup(),
          _ActivitySurface.live => _buildLiveSession(),
          _ActivitySurface.summary => _buildSessionSummary(),
          _ActivitySurface.steps => _buildStepsDetails(),
          _ActivitySurface.activeTime => _buildActiveTimeDetails(),
        };
      },
    );
  }

  bool _shouldShowInitialLoader(_ActivitySurface surface) {
    if (!controller.loading) {
      return false;
    }
    return controller.exercises.isEmpty &&
        controller.summary == ActivitySummarySnapshot.empty() &&
        surface != _ActivitySurface.setup;
  }

  _ActivitySurface _surfaceForRoute(String? route) {
    return switch (route) {
      Routes.activityWorkouts => _ActivitySurface.workouts,
      Routes.activitySessionSetup => _ActivitySurface.setup,
      Routes.activitySessionLive => _ActivitySurface.live,
      Routes.activitySessionSummary => _ActivitySurface.summary,
      Routes.activitySteps || Routes.steps => _ActivitySurface.steps,
      Routes.activityActiveTime => _ActivitySurface.activeTime,
      _ => _ActivitySurface.overview,
    };
  }

  Future<void> _refreshActivity({bool syncStepsFirst = true}) async {
    if (syncStepsFirst) {
      await controller.syncSensorStepsNow();
    }
    await controller.load(silent: true);
  }

  Scaffold _activityShell({
    required Widget body,
    bool bottomNav = true,
    Color background = VitaMateTheme.background,
  }) {
    return Scaffold(
      key: const ValueKey(AppTestKeys.activityScreen),
      backgroundColor: background,
      bottomNavigationBar: bottomNav ? const _ActivityBottomNav() : null,
      body: SafeArea(child: body),
    );
  }

  Widget _buildOverview() {
    final fmt = NumberFormat.decimalPattern();
    final active = controller.totalBurnedToday;
    final target = controller.burnTargetToday > 0
        ? controller.burnTargetToday
        : 900;
    final percent = target <= 0
        ? 0
        : ((active / target) * 100).clamp(0, 100).round();
    final stepsCalories = controller.stepsCaloriesBurned;
    final workoutCalories = controller.workoutCaloriesToday;
    final permissionMissing = _hasStepSensorPermissionIssue();

    return _activityShell(
      body: RefreshIndicator(
        onRefresh: () => _refreshActivity(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
          children: [
            _OverviewTopBar(onRefresh: () => _refreshActivity()),
            const SizedBox(height: 18),
            const Text(
              'Activity',
              style: TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Today, ${DateFormat('MMM d').format(DateTime.now())}',
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            if (permissionMissing) ...[
              _StepRecoveryCard(
                onGrant: controller.requestStepSensorPermission,
                onSettings: controller.openStepSensorSettings,
              ),
              const SizedBox(height: 18),
            ],
            _ActCard(
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
                            const Text(
                              'Active calories today',
                              style: TextStyle(
                                color: VitaMateTheme.textMuted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: VitaMateTheme.primaryDeep,
                                  fontWeight: FontWeight.w900,
                                ),
                                children: [
                                  TextSpan(
                                    text: fmt.format(active),
                                    style: const TextStyle(fontSize: 34),
                                  ),
                                  TextSpan(
                                    text: ' / ${fmt.format(target)} kcal',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: VitaMateTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CompactRing(
                        percent: percent,
                        size: 64,
                        stroke: 7,
                        center: '$percent%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BreakdownBar(
                    total: target,
                    first: stepsCalories,
                    second: workoutCalories,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _LegendMetric(
                          color: VitaMateTheme.primary,
                          label: 'Steps',
                          value: '${fmt.format(stepsCalories)} kcal',
                        ),
                      ),
                      Expanded(
                        child: _LegendMetric(
                          color: VitaMateTheme.warning,
                          label: 'Workouts',
                          value: '${fmt.format(workoutCalories)} kcal',
                        ),
                      ),
                      _RemainingBadge(
                        value: '${fmt.format(controller.remainingBurn)} kcal',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _OverviewMetricCard(
                    icon: Icons.directions_walk_rounded,
                    value: fmt.format(controller.stepsToday),
                    label: 'Steps',
                    route: Routes.activitySteps,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OverviewMetricCard(
                    icon: Icons.timer_outlined,
                    value: '${fmt.format(_activeMinutesToday())} min',
                    label: 'Active time',
                    route: Routes.activityActiveTime,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OverviewMetricCard(
                    icon: Icons.link_rounded,
                    value: fmt.format(controller.todayLogs.length),
                    label: 'Workouts',
                    route: Routes.activityWorkouts,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SyncStrip(
              state: _syncStateLabel(),
              subtitle: _syncSubtitle(),
              onRefresh: () => _refreshActivity(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutsHub() {
    final exercises = _filteredExercises();
    return _activityShell(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
            child: Column(
              children: [
                _TitleBar(
                  title: 'Workouts',
                  subtitle: 'Choose an activity',
                  leading: Icons.arrow_back_ios_new_rounded,
                  onLeading: () => Navigator.maybePop(context),
                  trailing: Icons.refresh_rounded,
                  onTrailing: () => _refreshActivity(syncStepsFirst: false),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search activities',
                  ),
                ),
                const SizedBox(height: 12),
                _SegmentTabs(
                  values: const ['Recent', 'Favorites', 'Suggested', 'All'],
                  selected: _workoutTab,
                  onSelected: (value) => setState(() => _workoutTab = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              itemCount: exercises.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                final config = _configForExercise(exercise);
                return _WorkoutCatalogRow(
                  exercise: exercise,
                  config: config,
                  favorite: _favoriteExerciseIds.contains(exercise.id),
                  onFavorite: () {
                    setState(() {
                      if (!_favoriteExerciseIds.add(exercise.id)) {
                        _favoriteExerciseIds.remove(exercise.id);
                      }
                    });
                  },
                  onAdd: () => _openPastWorkoutSheet(exercise),
                  onStart: () {
                    controller.prepareWorkout(exercise);
                    Navigator.pushNamed(
                      context,
                      Routes.activitySessionSetup,
                      arguments: exercise,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSetup() {
    final exercise = _setupExercise();
    final config = exercise == null
        ? _ActivityConfig.fallback()
        : _configForExercise(exercise);
    final duration = controller.preparedDurationMinutes.clamp(5, 180);
    final intensity = controller.preparedIntensity;
    final calories = exercise == null
        ? 0
        : _estimateCalories(exercise, duration, intensity);

    if (exercise != null && controller.preparedExercise?.id != exercise.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          controller.prepareWorkout(exercise);
        }
      });
    }

    return _activityShell(
      bottomNav: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
        children: [
          _TitleBar(
            title: 'Session Setup',
            leading: Icons.arrow_back_ios_new_rounded,
            onLeading: () => Navigator.maybePop(context),
            trailing: Icons.music_note_rounded,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _ActivityIcon(config: config, size: 58),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise?.name ?? 'Workout',
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Get ready to start',
                    style: TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ActCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: VitaMateTheme.primaryDeep,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Duration',
                      style: TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    _TinyTag(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Recommended',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.remove_rounded,
                      onTap: () =>
                          controller.updatePreparedDuration(duration - 5),
                    ),
                    Expanded(
                      child: Center(child: _DurationDial(minutes: duration)),
                    ),
                    _RoundIconButton(
                      icon: Icons.add_rounded,
                      onTap: () =>
                          controller.updatePreparedDuration(duration + 5),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DurationPresets(
                  selected: duration,
                  onSelected: controller.updatePreparedDuration,
                  onCustom: () => _openCustomDurationSheet(duration),
                ),
                Slider(
                  value: duration.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  activeColor: VitaMateTheme.primary,
                  inactiveColor: VitaMateTheme.softSurface,
                  onChanged: (value) =>
                      controller.updatePreparedDuration(value.round()),
                ),
                const Center(
                  child: Text(
                    'Slide or use +/- to adjust',
                    style: TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ActCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 18,
                      color: VitaMateTheme.primaryDeep,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Intensity',
                      style: TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _IntensitySelector(
                  selected: intensity,
                  onSelected: controller.updatePreparedIntensity,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ActCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: VitaMateTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: VitaMateTheme.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated Burn',
                        style: TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '~ $calories kcal',
                        style: const TextStyle(
                          color: VitaMateTheme.primaryDeep,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'Based on duration and intensity',
                        style: TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _TipStrip(
            text:
                'Tip: A steady walk boosts heart and energy. You have got this!',
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: controller.sessionBusy || exercise == null
                ? null
                : () => _startSession(exercise),
            child: Text(
              controller.sessionBusy ? 'Starting...' : 'Start Session',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSession() {
    final session =
        controller.activeSession ??
        (ModalRoute.of(context)?.settings.arguments is ActivitySession
            ? ModalRoute.of(context)!.settings.arguments! as ActivitySession
            : null);
    if (session == null) {
      return _activityShell(
        bottomNav: false,
        body: _EmptyTaskScreen(
          title: 'No active session',
          message: 'Start a workout from the Workouts screen.',
          actionLabel: 'Choose workout',
          onAction: () =>
              Navigator.pushReplacementNamed(context, Routes.activityWorkouts),
        ),
      );
    }

    final config = _configForSession(session);
    final variant = config.variant;
    return switch (variant) {
      _LiveVariant.stepBased => _buildWalkingLive(session, config),
      _LiveVariant.timedIntensive => _buildHiitLive(session, config),
      _LiveVariant.generalTimed => _buildGeneralLive(session, config),
    };
  }

  Widget _buildWalkingLive(ActivitySession session, _ActivityConfig config) {
    final elapsed = controller.liveElapsed;
    final target = Duration(
      seconds: math.max(1, session.targetDurationSeconds),
    );
    final remaining = controller.liveRemaining;
    final calories = controller.liveCaloriesBurned;
    final sessionSteps = _sessionSteps();
    final distanceKm = sessionSteps <= 0 ? 0 : sessionSteps * 0.00075;
    final elapsedMinutes = elapsed.inSeconds <= 0 ? 0 : elapsed.inSeconds / 60;
    final stepRate = elapsedMinutes <= 0
        ? 0
        : (sessionSteps / elapsedMinutes).round();

    return _activityShell(
      bottomNav: false,
      body: _LiveScaffold(
        title: session.exerciseName,
        config: config,
        live: true,
        keepAwake: _keepScreenAwake,
        onBack: () => Navigator.maybePop(context),
        onMusic: () {},
        onKeepAwakeChanged: (value) => setState(() => _keepScreenAwake = value),
        primary: Column(
          children: [
            _LargeSessionRing(
              elapsed: elapsed,
              target: target,
              remaining: remaining,
            ),
            const SizedBox(height: 14),
            _BurnLine(calories: calories),
            const SizedBox(height: 4),
            Text(
              '${_sessionTimerLabel(elapsed)} completed - ${_sessionTimerLabel(remaining)} left',
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: [
                _LiveMetricCard(
                  icon: Icons.directions_walk_rounded,
                  value: NumberFormat.decimalPattern().format(sessionSteps),
                  label: 'Steps',
                ),
                _LiveMetricCard(
                  icon: Icons.location_on_outlined,
                  value: '${distanceKm.toStringAsFixed(1)} km',
                  label: 'Est. Distance',
                ),
                _LiveMetricCard(
                  icon: Icons.speed_rounded,
                  value: '$stepRate',
                  label: 'steps/min',
                ),
                _LiveMetricCard(
                  icon: Icons.favorite_border_rounded,
                  value: _intensityLabel(session.intensity),
                  label: 'Intensity',
                ),
              ],
            ),
          ],
        ),
        actions: _liveActions(session),
      ),
    );
  }

  Widget _buildHiitLive(ActivitySession session, _ActivityConfig config) {
    final elapsed = controller.liveElapsed;
    final target = Duration(
      seconds: math.max(1, session.targetDurationSeconds),
    );
    final remaining = controller.liveRemaining;
    return _activityShell(
      bottomNav: false,
      body: _LiveScaffold(
        title: 'HIIT',
        config: config,
        live: true,
        keepAwake: _keepScreenAwake,
        onBack: () => Navigator.maybePop(context),
        onMusic: () {},
        onKeepAwakeChanged: (value) => setState(() => _keepScreenAwake = value),
        primary: Column(
          children: [
            _LargeSessionRing(
              elapsed: elapsed,
              target: target,
              remaining: remaining,
              size: 234,
            ),
            const SizedBox(height: 20),
            _BurnLine(calories: controller.liveCaloriesBurned),
            const SizedBox(height: 14),
            _IntensityChip(intensity: session.intensity),
          ],
        ),
        actions: _liveActions(session),
      ),
    );
  }

  Widget _buildGeneralLive(ActivitySession session, _ActivityConfig config) {
    final elapsed = controller.liveElapsed;
    final target = Duration(
      seconds: math.max(1, session.targetDurationSeconds),
    );
    final remaining = controller.liveRemaining;
    return _activityShell(
      bottomNav: false,
      body: _LiveScaffold(
        title: session.exerciseName,
        config: config,
        live: true,
        keepAwake: _keepScreenAwake,
        onBack: () => Navigator.maybePop(context),
        onMusic: () {},
        onKeepAwakeChanged: (value) => setState(() => _keepScreenAwake = value),
        primary: Column(
          children: [
            _LargeSessionRing(
              elapsed: elapsed,
              target: target,
              remaining: remaining,
              size: 224,
            ),
            const SizedBox(height: 22),
            _BurnLine(calories: controller.liveCaloriesBurned),
            const SizedBox(height: 14),
            _IntensityChip(intensity: session.intensity),
          ],
        ),
        actions: _liveActions(session),
      ),
    );
  }

  Widget _buildSessionSummary() {
    final session =
        controller.lastCompletedSession ??
        (ModalRoute.of(context)?.settings.arguments is ActivitySession
            ? ModalRoute.of(context)!.settings.arguments! as ActivitySession
            : null);
    if (session == null) {
      return _activityShell(
        bottomNav: false,
        body: _EmptyTaskScreen(
          title: 'No saved workout',
          message: 'Your completed workout summary will appear here.',
          actionLabel: 'Back to Activity',
          onAction: () =>
              Navigator.pushReplacementNamed(context, Routes.activities),
        ),
      );
    }

    final config = _configForSession(session);
    final minutes = math.max(1, (session.actualDurationSeconds / 60).round());
    final steps = config.variant == _LiveVariant.stepBased
        ? _sessionSteps()
        : 0;
    return _activityShell(
      bottomNav: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
        children: [
          _TitleBar(
            title: 'Session Summary',
            subtitle: 'Great job',
            leading: Icons.arrow_back_ios_new_rounded,
            onLeading: () => Navigator.maybePop(context),
            trailingWidget: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _ActCard(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
            child: Column(
              children: [
                _SavedWorkoutBadge(config: config),
                const SizedBox(height: 16),
                const Text(
                  'Workout saved!',
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _ActivityIcon(config: config, size: 42),
                const SizedBox(height: 6),
                Text(
                  session.exerciseName,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat(
                    'MMM d, h:mm a',
                  ).format(session.endedAt ?? DateTime.now()),
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const _TipStrip(
                  text:
                      'Every step you take is a step closer to a stronger you.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.schedule_rounded,
                  value: _durationLabel(Duration(minutes: minutes)),
                  label: 'Duration',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.local_fire_department_rounded,
                  value: '${session.caloriesBurned}',
                  label: 'kcal burned',
                ),
              ),
              if (steps > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.directions_walk_rounded,
                    value: NumberFormat.decimalPattern().format(steps),
                    label: 'Steps',
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.bolt_rounded,
                  value: _intensityLabel(session.intensity),
                  label: 'Intensity',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ActCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Activity Goal',
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _GoalProgressLine(
                  percent: controller.burnProgress,
                  label:
                      'Great progress! Keep it up. ${controller.totalBurnedToday} / ${controller.burnTargetToday} kcal',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, Routes.activities),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsDetails() {
    final fmt = NumberFormat.decimalPattern();
    final permissionMissing = _hasStepSensorPermissionIssue();

    return _activityShell(
      body: RefreshIndicator(
        onRefresh: () => _refreshActivity(),
        child: ListView(
          key: const ValueKey(AppTestKeys.stepsScreen),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
          children: [
            _TitleBar(
              title: 'Steps',
              subtitle: 'Track your daily walking progress.',
              leading: Icons.arrow_back_ios_new_rounded,
              onLeading: () => Navigator.maybePop(context),
              trailing: Icons.refresh_rounded,
              onTrailing: () => _refreshActivity(),
            ),
            const SizedBox(height: 16),
            if (permissionMissing)
              _StepRecoveryCard(
                onGrant: controller.requestStepSensorPermission,
                onSettings: controller.openStepSensorSettings,
              )
            else
              _StepsHeroCard(
                steps: controller.stepsToday,
                target: controller.targetSteps,
                percent: (controller.stepsProgress * 100).round(),
                calories: controller.stepsCaloriesBurned,
                distanceKm: controller.stepDistanceKmToday,
                remaining: controller.remainingSteps,
              ),
            const SizedBox(height: 12),
            _SyncStrip(
              state: _syncStateLabel(),
              subtitle: _syncSubtitle(),
              onRefresh: () => _refreshActivity(),
            ),
            const SizedBox(height: 14),
            _SevenDayChart(
              title: '7-Day Trend',
              unit: 'Steps',
              values: _stepTrendValues(),
              target: controller.targetSteps,
            ),
            const SizedBox(height: 14),
            _ActCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: VitaMateTheme.softSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.directions_walk_rounded,
                      color: VitaMateTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Steps add to your active calories. Every step uses your profile and sensor data without duplicating workout movement.',
                      style: TextStyle(
                        color: VitaMateTheme.primaryDeep.withValues(
                          alpha: 0.86,
                        ),
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: VitaMateTheme.borderStrong,
                  ),
                ],
              ),
            ),
            if (controller.extraStepsOverGoal > 0) ...[
              const SizedBox(height: 12),
              _TipStrip(
                text:
                    'Extra steps +${fmt.format(controller.extraStepsOverGoal)} still count in today\'s total.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTimeDetails() {
    final today = _activeMinutesToday();
    final dailyTarget = math.max(
      1,
      controller.weeklySummary.goalTargetMinutes > 0
          ? (controller.weeklySummary.goalTargetMinutes / 7).round()
          : 60,
    );
    final weeklyTarget = controller.weeklySummary.goalTargetMinutes > 0
        ? controller.weeklySummary.goalTargetMinutes
        : 150;
    final weekly = math.max(controller.weeklySummary.weeklyMinutes, today);
    final workoutMinutes = controller.todayLogs.fold<int>(
      0,
      (sum, log) => sum + log.durationMinutes,
    );
    final walkingMinutes = math.max(0, today - workoutMinutes);
    final percent = ((today / dailyTarget) * 100).clamp(0, 100).round();

    return _activityShell(
      body: RefreshIndicator(
        onRefresh: () => _refreshActivity(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
          children: [
            _TitleBar(
              title: 'Active Time',
              leading: Icons.arrow_back_ios_new_rounded,
              onLeading: () => Navigator.maybePop(context),
              trailing: Icons.refresh_rounded,
              onTrailing: () => _refreshActivity(),
            ),
            const SizedBox(height: 16),
            _ActCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today, ${DateFormat('MMM d').format(DateTime.now())}',
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: VitaMateTheme.primaryDeep,
                              fontWeight: FontWeight.w900,
                            ),
                            children: [
                              TextSpan(
                                text: '$today',
                                style: const TextStyle(fontSize: 36),
                              ),
                              const TextSpan(text: ' min\n'),
                              const TextSpan(
                                text: 'Active today',
                                style: TextStyle(
                                  color: VitaMateTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _CompactRing(
                        percent: percent,
                        size: 68,
                        stroke: 7,
                        center: '$percent%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _GoalProgressLine(
                    percent: (today / dailyTarget).clamp(0.0, 1.0),
                    label:
                        'Daily goal $dailyTarget min - Remaining ${math.max(0, dailyTarget - today)} min',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _ActCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This week',
                    style: TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActiveTimeWeeklyMetric(
                          value: '$weekly / $weeklyTarget min',
                          label: 'Weekly goal',
                        ),
                      ),
                      Expanded(
                        child: _ActiveTimeWeeklyMetric(
                          value:
                              '${math.max(controller.weeklySummary.activeDays, today > 0 ? 1 : 0)}',
                          label: 'Active days',
                          icon: Icons.home_work_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MiniBars(
                    values: _activeTimeTrendValues(),
                    target: dailyTarget,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _ActCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Where it comes from',
                    style: TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SourceBreakdownRow(
                    icon: Icons.directions_walk_rounded,
                    label: 'Walking (steps)',
                    subtitle: _activeTimeCoverageLabel(walkingMinutes),
                    value: '$walkingMinutes min',
                  ),
                  const SizedBox(height: 10),
                  _SourceBreakdownRow(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Workouts',
                    subtitle: 'Recorded workout sessions',
                    value: '$workoutMinutes min',
                    color: VitaMateTheme.warning,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SyncStrip(
              state: _syncStateLabel(),
              subtitle: 'Active time updates automatically.',
              onRefresh: () => _refreshActivity(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _liveActions(ActivitySession session) {
    final paused = session.isPaused;
    return [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: controller.sessionBusy
              ? null
              : () async {
                  if (paused) {
                    await controller.resumeLiveSession();
                  } else {
                    await controller.pauseLiveSession();
                  }
                },
          icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
          label: Text(paused ? 'Resume' : 'Pause'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: VitaMateTheme.danger),
          onPressed: controller.sessionBusy ? null : _confirmEndSession,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('End Session'),
        ),
      ),
    ];
  }

  Future<void> _startSession(Exercise exercise) async {
    _liveStepBaseline = controller.stepsToday;
    final session = await controller.startPreparedWorkout();
    if (!mounted || session == null) {
      return;
    }
    Navigator.pushReplacementNamed(
      context,
      Routes.activitySessionLive,
      arguments: _LiveSessionArgs(
        session: session,
        stepBaseline: _liveStepBaseline,
      ),
    );
  }

  Future<void> _confirmEndSession() async {
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text('Save this workout and open your session summary?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
    if (save != true) {
      return;
    }
    final completed = await controller.finishLiveSession(savePartial: true);
    if (!mounted || completed == null) {
      return;
    }
    Navigator.pushReplacementNamed(
      context,
      Routes.activitySessionSummary,
      arguments: completed,
    );
  }

  Future<void> _openPastWorkoutSheet(Exercise exercise) async {
    _manualDurationCtrl.text = '${exercise.defaultDurationMinutes}';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: VitaMateTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add ${exercise.name}',
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Save a workout you already completed.',
                style: TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _manualDurationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  suffixText: 'min',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final minutes =
                      int.tryParse(_manualDurationCtrl.text.trim()) ?? 0;
                  if (minutes <= 0) {
                    return;
                  }
                  await controller.addActivity(
                    exerciseId: exercise.id,
                    durationMinutes: minutes,
                  );
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Save workout'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${exercise.name} saved')));
    }
  }

  Future<void> _openCustomDurationSheet(int current) async {
    _manualDurationCtrl.text = '$current';
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Custom duration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _manualDurationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(suffixText: 'min'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                final minutes = int.tryParse(_manualDurationCtrl.text.trim());
                Navigator.pop(context, minutes);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      controller.updatePreparedDuration(result);
    }
  }

  Exercise? _setupExercise() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Exercise) {
      return args;
    }
    if (controller.preparedExercise != null) {
      return controller.preparedExercise;
    }
    return _catalogExercises().isEmpty ? null : _catalogExercises().first;
  }

  List<Exercise> _catalogExercises() {
    if (controller.exercises.isNotEmpty) {
      final list = [...controller.exercises]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    }
    if (controller.suggestions.isNotEmpty) {
      return controller.suggestions
          .map(
            (item) => Exercise(
              id: item.exerciseId,
              name: item.exerciseName,
              metValue: 4,
              iconKey: item.iconKey,
              defaultDurationMinutes: item.recommendedDurationMinutes > 0
                  ? item.recommendedDurationMinutes
                  : 20,
            ),
          )
          .toList(growable: false);
    }
    return <Exercise>[
      Exercise(id: 1, name: 'Walking', metValue: 3.5, iconKey: 'walking'),
      Exercise(id: 2, name: 'Cycling', metValue: 6, iconKey: 'cycling'),
      Exercise(id: 3, name: 'Strength', metValue: 5, iconKey: 'strength'),
      Exercise(id: 4, name: 'HIIT', metValue: 8, iconKey: 'hiit'),
    ];
  }

  List<Exercise> _filteredExercises() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final all = _catalogExercises();
    Iterable<Exercise> scoped = switch (_workoutTab) {
      'Favorites' => all.where(
        (item) => _favoriteExerciseIds.contains(item.id),
      ),
      'Suggested' => all.where((item) => item.isFeatured),
      'Recent' => _recentExercises(all),
      _ => all,
    };
    if (query.isNotEmpty) {
      scoped = scoped.where((item) => item.name.toLowerCase().contains(query));
    }
    final list = scoped.toList(growable: false);
    if (list.isEmpty && _workoutTab == 'Favorites') {
      return all.take(3).toList(growable: false);
    }
    return list;
  }

  Iterable<Exercise> _recentExercises(List<Exercise> all) {
    final recentIds = controller.logs.map((log) => log.exerciseId).toSet();
    if (recentIds.isEmpty) {
      return all.take(3);
    }
    return all.where((item) => recentIds.contains(item.id));
  }

  _ActivityConfig _configForSession(ActivitySession session) {
    final match = _catalogExercises().where(
      (item) => item.id == session.exerciseId,
    );
    if (match.isNotEmpty) {
      return _configForExercise(match.first);
    }
    return _configForName(session.exerciseName, session.exerciseIconKey);
  }

  _ActivityConfig _configForExercise(Exercise exercise) {
    return _configForName(exercise.name, exercise.iconKey);
  }

  _ActivityConfig _configForName(String name, String iconKey) {
    final normalized = '$name $iconKey'.toLowerCase();
    if (normalized.contains('walk') || normalized.contains('run')) {
      return const _ActivityConfig(
        icon: Icons.directions_walk_rounded,
        classification: 'Low impact',
        calorieRange: '100-250 kcal/hour',
        variant: _LiveVariant.stepBased,
        color: VitaMateTheme.primary,
      );
    }
    if (normalized.contains('hiit') || normalized.contains('interval')) {
      return const _ActivityConfig(
        icon: Icons.sports_martial_arts_rounded,
        classification: 'High intensity',
        calorieRange: '250-500 kcal/hour',
        variant: _LiveVariant.timedIntensive,
        color: VitaMateTheme.primary,
      );
    }
    if (normalized.contains('cycle') || normalized.contains('bike')) {
      return const _ActivityConfig(
        icon: Icons.directions_bike_rounded,
        classification: 'Cardio',
        calorieRange: '300-500 kcal/hour',
        variant: _LiveVariant.generalTimed,
        color: VitaMateTheme.success,
      );
    }
    if (normalized.contains('strength') ||
        normalized.contains('weight') ||
        normalized.contains('lift')) {
      return const _ActivityConfig(
        icon: Icons.fitness_center_rounded,
        classification: 'Muscle',
        calorieRange: '150-300 kcal/hour',
        variant: _LiveVariant.generalTimed,
        color: Color(0xFF4BA9FF),
      );
    }
    return const _ActivityConfig(
      icon: Icons.self_improvement_rounded,
      classification: 'Timed activity',
      calorieRange: '120-280 kcal/hour',
      variant: _LiveVariant.generalTimed,
      color: VitaMateTheme.primary,
    );
  }

  int _estimateCalories(Exercise exercise, int minutes, String intensity) {
    final weight = 75.0;
    final met = exercise.metForIntensity(intensity);
    return ((met * 3.5 * weight) / 200 * minutes).round();
  }

  int _activeMinutesToday() {
    final fromSummary = controller.todaySummary.activeMinutes;
    final fromExercise = controller.exerciseMinutesToday;
    return math.max(fromSummary, fromExercise);
  }

  int _sessionSteps() {
    return math.max(0, controller.stepsToday - _liveStepBaseline);
  }

  List<int> _stepTrendValues() {
    final today = controller.stepsToday;
    return <int>[
      (today * 0.64).round(),
      (today * 0.82).round(),
      (today * 0.93).round(),
      (today * 1.02).round(),
      (today * 0.78).round(),
      (today * 0.71).round(),
      today,
    ];
  }

  List<int> _activeTimeTrendValues() {
    final today = _activeMinutesToday();
    return <int>[12, 24, 8, today, 18, 21, math.max(today - 4, 0)];
  }

  bool _hasStepSensorPermissionIssue() {
    return !controller.stepSensorPermissionGranted ||
        controller.stepSensorState ==
            StepSensorLifecycleState.permissionDenied ||
        controller.stepSensorState == StepSensorLifecycleState.unavailable;
  }

  String _syncStateLabel() {
    if (controller.error != null) {
      return 'Sync failed';
    }
    if (controller.stepSensorState == StepSensorLifecycleState.initializing ||
        controller.loading) {
      return 'Syncing';
    }
    if (controller.stepSensorState ==
        StepSensorLifecycleState.permissionDenied) {
      return 'Unavailable';
    }
    if (controller.lastStepSensorSyncedAt != null ||
        controller.summary.meta.computedAt != null) {
      return 'Synced just now';
    }
    return 'Synced';
  }

  String _syncSubtitle() {
    if (controller.error != null) {
      return controller.error!;
    }
    if (controller.stepSensorState ==
        StepSensorLifecycleState.permissionDenied) {
      return 'Grant activity recognition to count steps automatically.';
    }
    return 'Your activity data is up to date.';
  }

  String _activeTimeCoverageLabel(int walkingMinutes) {
    if (controller.stepSensorState ==
        StepSensorLifecycleState.permissionDenied) {
      return 'Permission unavailable';
    }
    if (controller.stepsToday > 0 && walkingMinutes == 0) {
      return 'Insufficient interval coverage';
    }
    return 'Detected meaningful walking';
  }
}

class _LiveSessionArgs {
  const _LiveSessionArgs({required this.session, required this.stepBaseline});

  final ActivitySession session;
  final int stepBaseline;
}

class _ActivityConfig {
  const _ActivityConfig({
    required this.icon,
    required this.classification,
    required this.calorieRange,
    required this.variant,
    required this.color,
  });

  const _ActivityConfig.fallback()
    : icon = Icons.fitness_center_rounded,
      classification = 'Timed activity',
      calorieRange = '120-280 kcal/hour',
      variant = _LiveVariant.generalTimed,
      color = VitaMateTheme.primary;

  final IconData icon;
  final String classification;
  final String calorieRange;
  final _LiveVariant variant;
  final Color color;
}

class _ActivityLoadingScaffold extends StatelessWidget {
  const _ActivityLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: ValueKey(AppTestKeys.activityScreen),
      backgroundColor: VitaMateTheme.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ActCard extends StatelessWidget {
  const _ActCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _OverviewTopBar extends StatelessWidget {
  const _OverviewTopBar({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderIcon(icon: Icons.notifications_none_rounded, onTap: () {}),
        const Expanded(
          child: Center(
            child: Text(
              'VitaMate',
              style: TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        _HeaderIcon(icon: Icons.refresh_rounded, onTap: onRefresh),
        const SizedBox(width: 8),
        _HeaderIcon(icon: Icons.settings_outlined, onTap: () {}),
      ],
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.trailingWidget,
    this.onLeading,
    this.onTrailing,
  });

  final String title;
  final String? subtitle;
  final IconData? leading;
  final IconData? trailing;
  final Widget? trailingWidget;
  final VoidCallback? onLeading;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[
          _HeaderIcon(icon: leading!, onTap: onLeading),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        if (trailingWidget != null)
          trailingWidget!
        else if (trailing != null)
          _HeaderIcon(icon: trailing!, onTap: onTrailing)
        else
          const SizedBox(width: 42),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VitaMateTheme.border),
        ),
        child: Icon(icon, size: 18, color: VitaMateTheme.primaryDeep),
      ),
    );
  }
}

class _CompactRing extends StatelessWidget {
  const _CompactRing({
    required this.percent,
    required this.center,
    this.size = 70,
    this.stroke = 7,
  });

  final int percent;
  final String center;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: percent / 100,
            strokeWidth: stroke,
            backgroundColor: VitaMateTheme.softSurface,
            color: VitaMateTheme.primary,
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Text(
              center,
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  const _BreakdownBar({
    required this.total,
    required this.first,
    required this.second,
  });

  final int total;
  final int first;
  final int second;

  @override
  Widget build(BuildContext context) {
    final safeTotal = math.max(total, 1);
    final firstWidth = (first / safeTotal).clamp(0.0, 1.0);
    final secondWidth = (second / safeTotal).clamp(0.0, 1.0 - firstWidth);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            Expanded(
              flex: (firstWidth * 1000).round().clamp(1, 1000),
              child: Container(color: VitaMateTheme.primary),
            ),
            Expanded(
              flex: (secondWidth * 1000).round().clamp(1, 1000),
              child: Container(color: VitaMateTheme.warning),
            ),
            Expanded(
              flex: (((1 - firstWidth - secondWidth) * 1000).round()).clamp(
                1,
                1000,
              ),
              child: Container(color: VitaMateTheme.softSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendMetric extends StatelessWidget {
  const _LegendMetric({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RemainingBadge extends StatelessWidget {
  const _RemainingBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: VitaMateTheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'remaining',
            style: TextStyle(
              color: VitaMateTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewMetricCard extends StatelessWidget {
  const _OverviewMetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String value;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.pushNamed(context, route),
      child: _ActCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: VitaMateTheme.softSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: VitaMateTheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: VitaMateTheme.borderStrong,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStrip extends StatelessWidget {
  const _SyncStrip({
    required this.state,
    required this.subtitle,
    required this.onRefresh,
  });

  final String state;
  final String subtitle;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final failed = state.toLowerCase().contains('failed');
    final unavailable = state.toLowerCase().contains('unavailable');
    final color = failed
        ? VitaMateTheme.danger
        : unavailable
        ? VitaMateTheme.warning
        : VitaMateTheme.success;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Row(
        children: [
          Icon(
            failed
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            color: VitaMateTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final value in values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelected(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected == value
                      ? VitaMateTheme.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected == value
                        ? VitaMateTheme.primary
                        : VitaMateTheme.border,
                  ),
                ),
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected == value
                        ? Colors.white
                        : VitaMateTheme.primaryDeep,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WorkoutCatalogRow extends StatelessWidget {
  const _WorkoutCatalogRow({
    required this.exercise,
    required this.config,
    required this.favorite,
    required this.onFavorite,
    required this.onAdd,
    required this.onStart,
  });

  final Exercise exercise;
  final _ActivityConfig config;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onAdd;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _ActCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _ActivityIcon(config: config, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  config.classification,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  config.calorieRange,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Favorite',
            onPressed: onFavorite,
            icon: Icon(
              favorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: VitaMateTheme.warning,
            ),
          ),
          IconButton(
            tooltip: 'Add',
            onPressed: onAdd,
            icon: const Icon(
              Icons.add_box_outlined,
              color: VitaMateTheme.primary,
            ),
          ),
          InkWell(
            onTap: onStart,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: VitaMateTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityIcon extends StatelessWidget {
  const _ActivityIcon({required this.config, this.size = 48});

  final _ActivityConfig config;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(config.icon, color: config.color, size: size * 0.54),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 11, color: VitaMateTheme.primary),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: VitaMateTheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: VitaMateTheme.border),
        ),
        child: Icon(icon, color: VitaMateTheme.primaryDeep),
      ),
    );
  }
}

class _DurationDial extends StatelessWidget {
  const _DurationDial({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      height: 126,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: VitaMateTheme.softSurface, width: 8),
      ),
      child: Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
            ),
            children: [
              TextSpan(text: '$minutes', style: const TextStyle(fontSize: 46)),
              const TextSpan(text: '\nmin', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationPresets extends StatelessWidget {
  const _DurationPresets({
    required this.selected,
    required this.onSelected,
    required this.onCustom,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final value in const [10, 20, 30, 45, 60])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _PresetButton(
                label: '$value\nmin',
                selected: selected == value,
                onTap: () => onSelected(value),
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _PresetButton(
              label: 'Custom',
              selected: !const [10, 20, 30, 45, 60].contains(selected),
              onTap: onCustom,
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? VitaMateTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? VitaMateTheme.primary : VitaMateTheme.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : VitaMateTheme.primaryDeep,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _IntensitySelector extends StatelessWidget {
  const _IntensitySelector({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final option in const [
          ('light', 'Light'),
          ('moderate', 'Moderate'),
          ('intense', 'Intense'),
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => onSelected(option.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected == option.$1
                        ? VitaMateTheme.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected == option.$1
                          ? VitaMateTheme.primary
                          : VitaMateTheme.border,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected == option.$1
                            ? Icons.check_circle_rounded
                            : Icons.circle,
                        size: 13,
                        color: selected == option.$1
                            ? Colors.white
                            : VitaMateTheme.borderStrong,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        option.$2,
                        style: TextStyle(
                          color: selected == option.$1
                              ? Colors.white
                              : VitaMateTheme.primaryDeep,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TipStrip extends StatelessWidget {
  const _TipStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: VitaMateTheme.primary,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveScaffold extends StatelessWidget {
  const _LiveScaffold({
    required this.title,
    required this.config,
    required this.live,
    required this.primary,
    required this.actions,
    required this.keepAwake,
    required this.onBack,
    required this.onMusic,
    required this.onKeepAwakeChanged,
  });

  final String title;
  final _ActivityConfig config;
  final bool live;
  final Widget primary;
  final List<Widget> actions;
  final bool keepAwake;
  final VoidCallback onBack;
  final VoidCallback onMusic;
  final ValueChanged<bool> onKeepAwakeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Column(
        children: [
          _TitleBar(
            title: title,
            subtitle: live ? 'Live' : null,
            leading: Icons.arrow_back_ios_new_rounded,
            onLeading: onBack,
            trailing: Icons.music_note_rounded,
            onTrailing: onMusic,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(child: SingleChildScrollView(child: primary)),
          ),
          Row(children: actions),
          const SizedBox(height: 12),
          _ActCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.phonelink_lock_rounded,
                  color: VitaMateTheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Keep screen awake',
                    style: TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Switch(
                  value: keepAwake,
                  activeThumbColor: VitaMateTheme.primary,
                  onChanged: onKeepAwakeChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeSessionRing extends StatelessWidget {
  const _LargeSessionRing({
    required this.elapsed,
    required this.target,
    required this.remaining,
    this.size = 206,
  });

  final Duration elapsed;
  final Duration target;
  final Duration remaining;
  final double size;

  @override
  Widget build(BuildContext context) {
    final targetSeconds = math.max(1, target.inSeconds);
    final progress = (elapsed.inSeconds / targetSeconds).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 12,
            strokeCap: StrokeCap.round,
            color: VitaMateTheme.primary,
            backgroundColor: VitaMateTheme.border,
          ),
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
                children: [
                  TextSpan(
                    text: _sessionTimerLabel(elapsed),
                    style: const TextStyle(fontSize: 38),
                  ),
                  TextSpan(
                    text: ' / ${_sessionTimerLabel(target)}\n',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const TextSpan(
                    text: 'mm:ss\n',
                    style: TextStyle(fontSize: 13),
                  ),
                  TextSpan(
                    text: '${_sessionTimerLabel(remaining)} left',
                    style: const TextStyle(
                      fontSize: 12,
                      color: VitaMateTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BurnLine extends StatelessWidget {
  const _BurnLine({required this.calories});

  final int calories;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.local_fire_department_rounded,
          color: VitaMateTheme.warning,
        ),
        const SizedBox(width: 5),
        Text(
          '$calories kcal burned',
          style: const TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _LiveMetricCard extends StatelessWidget {
  const _LiveMetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _ActCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: VitaMateTheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntensityChip extends StatelessWidget {
  const _IntensityChip({required this.intensity});

  final String intensity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bolt_rounded,
            color: VitaMateTheme.primary,
            size: 17,
          ),
          const SizedBox(width: 6),
          Text(
            '${_intensityLabel(intensity)} intensity',
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedWorkoutBadge extends StatelessWidget {
  const _SavedWorkoutBadge({required this.config});

  final _ActivityConfig config;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 124,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: 1,
            strokeWidth: 9,
            color: VitaMateTheme.primary,
            backgroundColor: VitaMateTheme.softSurface,
          ),
          Center(
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFFE8FBF0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: VitaMateTheme.success,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _ActCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        children: [
          Icon(icon, color: VitaMateTheme.primary, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalProgressLine extends StatelessWidget {
  const _GoalProgressLine({required this.percent, required this.label});

  final double percent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            minHeight: 9,
            backgroundColor: VitaMateTheme.softSurface,
            color: VitaMateTheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: VitaMateTheme.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _StepsHeroCard extends StatelessWidget {
  const _StepsHeroCard({
    required this.steps,
    required this.target,
    required this.percent,
    required this.calories,
    required this.distanceKm,
    required this.remaining,
  });

  final int steps;
  final int target;
  final int percent;
  final int calories;
  final double distanceKm;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return _ActCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              _CompactRing(
                percent: percent,
                center: '$percent%\nof goal',
                size: 102,
                stroke: 9,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontWeight: FontWeight.w900,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Today\n',
                        style: TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      TextSpan(
                        text: fmt.format(steps),
                        style: const TextStyle(fontSize: 32),
                      ),
                      TextSpan(
                        text: ' / ${fmt.format(target)}\nsteps',
                        style: const TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StepDetailMetric(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Calories from steps',
                  value: '$calories kcal',
                ),
              ),
              Expanded(
                child: _StepDetailMetric(
                  icon: Icons.location_on_outlined,
                  label: 'Est. distance',
                  value: '${distanceKm.toStringAsFixed(1)} km',
                ),
              ),
              Expanded(
                child: _StepDetailMetric(
                  icon: Icons.directions_walk_rounded,
                  label: 'Remaining',
                  value: '${fmt.format(remaining)} steps',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDetailMetric extends StatelessWidget {
  const _StepDetailMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: VitaMateTheme.primary, size: 19),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: VitaMateTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StepRecoveryCard extends StatelessWidget {
  const _StepRecoveryCard({required this.onGrant, required this.onSettings});

  final VoidCallback onGrant;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return _ActCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_walk_rounded, color: VitaMateTheme.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Grant activity recognition',
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Enable phone step tracking to update your daily movement automatically.',
            style: TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onGrant,
                  child: const Text('Grant permission'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSettings,
                  child: const Text('Manual fallback'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SevenDayChart extends StatelessWidget {
  const _SevenDayChart({
    required this.title,
    required this.unit,
    required this.values,
    required this.target,
  });

  final String title;
  final String unit;
  final List<int> values;
  final int target;

  @override
  Widget build(BuildContext context) {
    return _ActCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                unit,
                style: const TextStyle(
                  color: VitaMateTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MiniBars(values: values, target: math.max(target, 1)),
        ],
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.values, required this.target});

  final List<int> values;
  final int target;

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(target, values.fold<int>(1, math.max));
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _shortNumber(values[i]),
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: (80 * (values[i] / maxValue)).clamp(8, 80),
                      decoration: BoxDecoration(
                        color: i == values.length - 1
                            ? VitaMateTheme.primary
                            : VitaMateTheme.borderStrong.withValues(
                                alpha: 0.55,
                              ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i.clamp(0, labels.length - 1)],
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveTimeWeeklyMetric extends StatelessWidget {
  const _ActiveTimeWeeklyMetric({
    required this.value,
    required this.label,
    this.icon = Icons.timer_outlined,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: VitaMateTheme.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceBreakdownRow extends StatelessWidget {
  const _SourceBreakdownRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    this.color = VitaMateTheme.primary,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: VitaMateTheme.borderStrong,
        ),
      ],
    );
  }
}

class _EmptyTaskScreen extends StatelessWidget {
  const _EmptyTaskScreen({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.fitness_center_rounded,
            color: VitaMateTheme.primary,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _ActivityBottomNav extends StatelessWidget {
  const _ActivityBottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: VitaMateTheme.border)),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Row(
            children: const [
              _ActivityNavButton('Home', Icons.home_outlined, Routes.home),
              _ActivityNavButton(
                'Activity',
                Icons.monitor_heart_outlined,
                Routes.activities,
                selected: true,
              ),
              _ActivityNavButton('Meds', Icons.link_rounded, Routes.meds),
              _ActivityNavButton(
                'Habits',
                Icons.sync_alt_rounded,
                Routes.habits,
              ),
              _ActivityNavButton(
                'My VitaMate',
                Icons.manage_accounts_outlined,
                Routes.myVitaMate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityNavButton extends StatelessWidget {
  const _ActivityNavButton(
    this.label,
    this.icon,
    this.route, {
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final String route;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? VitaMateTheme.primary : VitaMateTheme.borderStrong;
    return Expanded(
      child: InkWell(
        onTap: selected
            ? null
            : () => Navigator.pushReplacementNamed(context, route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: selected ? 22 : 21),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _sessionTimerLabel(Duration duration) {
  final totalSeconds = math.max(0, duration.inSeconds);
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _durationLabel(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) {
    return '$minutes:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return '${hours}h ${rest}m';
}

String _intensityLabel(String value) {
  return switch (value.toLowerCase()) {
    'light' => 'Light',
    'intense' || 'high' => 'Intense',
    _ => 'Moderate',
  };
}

String _shortNumber(int value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return '$value';
}
