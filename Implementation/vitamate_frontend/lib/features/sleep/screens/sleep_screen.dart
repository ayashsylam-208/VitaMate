import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../models/sleep_coach.dart';
import '../models/sleep_log.dart';
import '../models/sleep_summary.dart';
import '../state/sleep_coach_controller.dart';
import '../state/sleep_controller.dart';
import '../state/sleep_settings_controller.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({
    super.key,
    this.sleepController,
    this.settingsController,
    this.coachController,
    this.authRepository,
    this.autoLoad = true,
  });

  final SleepController? sleepController;
  final SleepSettingsController? settingsController;
  final SleepCoachController? coachController;
  final AuthRepository? authRepository;
  final bool autoLoad;

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  late final SleepController sleepController;
  late final SleepSettingsController settingsController;
  late final SleepCoachController coachController;
  late final AuthRepository _authRepository;
  late final bool _ownsSleepController;
  late final bool _ownsSettingsController;
  late final bool _ownsCoachController;

  DateTime _wakeTime = DateTime(2000, 1, 1, 7);
  DateTime _bedTime = DateTime(2000, 1, 1, 23);
  double _goalHours = 8.0;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? AuthRepository(AuthApi());
    sleepController = widget.sleepController ?? SleepController(_authRepository);
    settingsController =
        widget.settingsController ?? SleepSettingsController(_authRepository);
    coachController = widget.coachController ?? SleepCoachController();
    _ownsSleepController = widget.sleepController == null;
    _ownsSettingsController = widget.settingsController == null;
    _ownsCoachController = widget.coachController == null;
    if (widget.autoLoad) {
      unawaited(_loadInitial());
    }
  }

  Future<void> _loadInitial() async {
    unawaited(
      settingsController.load().then((_) {
        final settings = settingsController.settings;
        if (!mounted || settings == null) return;
        setState(() {
          _wakeTime = settings.wakeTime;
          _bedTime = settings.bedTime;
          _goalHours = settings.goalHours;
        });
      }),
    );
    await Future.wait([
      sleepController.loadAll(),
      coachController.load(),
    ]);
  }

  Future<void> _pickTime(
    DateTime current,
    ValueChanged<DateTime> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked != null) {
      onPicked(DateTime(2000, 1, 1, picked.hour, picked.minute));
    }
  }

  Future<void> _openPlanSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SleepPlanSheet(
        controller: coachController,
        initialBedTime: _todayAt(_bedTime),
        initialWakeTime: _tomorrowAt(_wakeTime),
      ),
    );
    if (created == true && mounted) {
      _showSnack('Sleep plan scheduled');
    }
  }

  Future<void> _openFeedbackSheet() async {
    final plan = coachController.plan;
    if (plan == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MorningFeedbackSheet(
        controller: coachController,
        plan: plan,
      ),
    );
    if (saved == true && mounted) {
      await sleepController.loadAll();
      _showSnack('Morning feedback saved');
    }
  }

  DateTime _todayAt(DateTime t) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, t.hour, t.minute);
  }

  DateTime _tomorrowAt(DateTime t) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, t.hour, t.minute);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        settingsController,
        sleepController,
        coachController,
      ]),
      builder: (context, _) {
        final summary = sleepController.summary;
        final logs = sleepController.logs;
        final progress = (summary.progressPercent.clamp(0, 100)) / 100;

        return Scaffold(
          backgroundColor: VitaMateTheme.background,
          bottomNavigationBar: const VitaMateBottomNav(currentIndex: -1),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadInitial,
              child: ListView(
                key: const ValueKey(AppTestKeys.sleepScreen),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Sleep',
                          style: TextStyle(
                            color: VitaMateTheme.primaryDeep,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadInitial,
                        color: VitaMateTheme.primaryDeep,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Plan tonight, wake smarter, and learn what improves your rest.',
                    style: TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SleepCoachCard(
                    controller: coachController,
                    onPlan: _openPlanSheet,
                    onFeedback: _openFeedbackSheet,
                    onCancel: () async {
                      await coachController.cancelPlan();
                      if (mounted) _showSnack('Sleep plan cancelled');
                    },
                  ),
                  if (coachController.shouldAskFeedback) ...[
                    const SizedBox(height: 12),
                    _MorningPromptCard(onTap: _openFeedbackSheet),
                  ],
                  const SizedBox(height: 12),
                  _summaryCard(
                    progress,
                    summary,
                    sleepController.sleepPointsToday,
                  ),
                  if (coachController.overview.learningSummary.sampleSize > 0)
                    ...[
                      const SizedBox(height: 12),
                      _LearningSummaryCard(
                        summary: coachController.overview.learningSummary,
                      ),
                    ],
                  const SizedBox(height: 12),
                  _routineCard(),
                  const SizedBox(height: 12),
                  _manualLogCard(),
                  const SizedBox(height: 12),
                  _recentLogs(logs),
                  const SizedBox(height: 16),
                  _saveButtonRow(),
                  if (settingsController.error != null ||
                      sleepController.error != null ||
                      coachController.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _InlineError(
                        text:
                            settingsController.error ??
                            sleepController.error ??
                            coachController.error!,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summaryCard(
    double progress,
    SleepSummary summary,
    int sleepPointsToday,
  ) {
    return _Panel(
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: VitaMateTheme.softSurface,
              shape: BoxShape.circle,
              border: Border.all(color: VitaMateTheme.borderStrong, width: 6),
            ),
            child: Center(
              child: Text(
                '${summary.progressPercent.clamp(0, 100)}%',
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today’s sleep',
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${summary.loggedHoursToday.toStringAsFixed(1)} / ${summary.goalHours.toStringAsFixed(1)} h',
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: VitaMateTheme.softSurface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    VitaMateTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(label: '$sleepPointsToday pts'),
                    _Badge(label: 'Goal ${summary.goalHours.toStringAsFixed(1)}h'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _routineCard() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sleep routine',
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              Switch.adaptive(
                value: settingsController.notificationsEnabled,
                onChanged: (value) async {
                  await settingsController.setNotificationsEnabled(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Routine reminders stay separate from Smart Wake suggestions.',
            style: TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _TimeTile(
            icon: Icons.nightlight_round,
            title: 'Bedtime',
            value: _formatTime(_bedTime),
            onTap: () => _pickTime(
              _bedTime,
              (picked) => setState(() => _bedTime = picked),
            ),
          ),
          const SizedBox(height: 10),
          _TimeTile(
            icon: Icons.wb_sunny_rounded,
            title: 'Wake-up',
            value: _formatTime(_wakeTime),
            onTap: () => _pickTime(
              _wakeTime,
              (picked) => setState(() => _wakeTime = picked),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.timelapse, color: VitaMateTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Daily goal ${_goalHours.toStringAsFixed(1)} hours',
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _goalHours,
            min: 5,
            max: 10,
            divisions: 10,
            activeColor: VitaMateTheme.primary,
            onChanged: (value) => setState(() => _goalHours = value),
          ),
        ],
      ),
    );
  }

  Widget _manualLogCard() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manual sleep log',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use this if you already know when you slept and woke up.',
            style: TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openManualSleepSheet,
            icon: const Icon(Icons.edit_calendar_rounded),
            label: const Text('Log sleep manually'),
          ),
        ],
      ),
    );
  }

  Widget _recentLogs(List<SleepLog> logs) {
    final dateFmt = DateFormat.MMMd();
    if (sleepController.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (logs.isEmpty) {
      return const _Panel(
        child: Text(
          'No sleep logs yet. Track sleep to update Progress and points.',
          style: TextStyle(
            color: VitaMateTheme.textMuted,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      );
    }
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent sleep',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          for (final log in logs.take(3)) ...[
            _SleepLogRow(log: log, dateLabel: dateFmt.format(log.date)),
            if (log != logs.take(3).last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _saveButtonRow() {
    return _PrimaryGradientButton(
      label: 'Save routine',
      icon: Icons.check_rounded,
      onPressed: () async {
        await settingsController.update(
          goalHours: _goalHours,
          wakeTime: _wakeTime,
          bedTime: _bedTime,
        );
        await sleepController.loadAll();
        if (mounted) _showSnack('Sleep routine saved');
      },
    );
  }

  String _formatTime(DateTime t) => DateFormat('h:mm a').format(t);

  Future<void> _openManualSleepSheet() async {
    TimeOfDay start = const TimeOfDay(hour: 23, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 7, minute: 0);
    String quality = 'Okay';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return _SheetScaffold(
              children: [
                const _SheetHandle(),
                const SizedBox(height: 18),
                const Text(
                  'Log sleep',
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 12),
                _TimeTile(
                  icon: Icons.nightlight_round,
                  title: 'Sleep start',
                  value: start.format(ctx),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: start,
                    );
                    if (picked != null) {
                      setSheetState(() => start = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                _TimeTile(
                  icon: Icons.wb_sunny_rounded,
                  title: 'Wake time',
                  value: end.format(ctx),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: end,
                    );
                    if (picked != null) {
                      setSheetState(() => end = picked);
                    }
                  },
                ),
                const SizedBox(height: 14),
                _ChoiceWrap<String>(
                  label: 'How did it feel?',
                  value: quality,
                  options: const {
                    'Restful': 'Restful',
                    'Okay': 'Okay',
                    'Interrupted': 'Interrupted',
                  },
                  onChanged: (value) => setSheetState(() => quality = value),
                ),
                const SizedBox(height: 18),
                _PrimaryGradientButton(
                  label: 'Save sleep',
                  icon: Icons.check_rounded,
                  onPressed: () async {
                    final now = DateTime.now();
                    var startDt = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      start.hour,
                      start.minute,
                    );
                    var endDt = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      end.hour,
                      end.minute,
                    );
                    if (endDt.isBefore(startDt)) {
                      endDt = endDt.add(const Duration(days: 1));
                    }
                    await sleepController.add(
                      startTime: startDt,
                      endTime: endDt,
                      quality: _qualityToBackend(quality),
                    );
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    if (mounted) _showSnack('Sleep logged');
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _qualityToBackend(String value) {
    switch (value) {
      case 'Restful':
        return 'Deep';
      case 'Interrupted':
        return 'Interrupted';
      default:
        return 'Light';
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    if (_ownsSleepController) sleepController.dispose();
    if (_ownsSettingsController) settingsController.dispose();
    if (_ownsCoachController) coachController.dispose();
    super.dispose();
  }
}

class _SleepCoachCard extends StatelessWidget {
  const _SleepCoachCard({
    required this.controller,
    required this.onPlan,
    required this.onFeedback,
    required this.onCancel,
  });

  final SleepCoachController controller;
  final VoidCallback onPlan;
  final VoidCallback onFeedback;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final plan = controller.plan;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: VitaMateTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: VitaMateTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tonight’s Sleep Plan',
                      style: TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Plan tonight, then rate tomorrow so recommendations improve.',
                      style: TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (controller.loading)
            const Center(child: CircularProgressIndicator())
          else if (plan == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No plan for tonight yet.',
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _PrimaryGradientButton(
                  label: 'Plan tonight',
                  icon: Icons.bedtime_rounded,
                  onPressed: onPlan,
                ),
              ],
            )
          else
            _ActiveSleepPlan(
              plan: plan,
              onPlan: onPlan,
              onFeedback: onFeedback,
              onCancel: onCancel,
            ),
        ],
      ),
    );
  }
}

class _ActiveSleepPlan extends StatelessWidget {
  const _ActiveSleepPlan({
    required this.plan,
    required this.onPlan,
    required this.onFeedback,
    required this.onCancel,
  });

  final SleepPlan plan;
  final VoidCallback onPlan;
  final VoidCallback onFeedback;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('h:mm a');
    final recommended = plan.recommendedOption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7F21F5), Color(0xFF9E2CFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recommended smart wake',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                recommended == null ? 'Not set' : fmt.format(recommended.wakeTime),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                plan.recommendationReason,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Badge(label: 'Sleep start ${fmt.format(plan.estimatedSleepStart)}'),
            _Badge(
              label:
                  'Window ${fmt.format(plan.wakeWindowStart)}-${fmt.format(plan.wakeWindowEnd)}',
            ),
            if (plan.primaryNegativeFactor != 'none')
              _Badge(
                label: plan.primaryNegativeFactor.replaceAll('_', ' '),
                color: VitaMateTheme.warning,
              ),
          ],
        ),
        if (recommended?.warning.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _InfoStrip(text: recommended!.warning),
        ],
        const SizedBox(height: 12),
        _InfoStrip(text: plan.nightTip),
        const SizedBox(height: 12),
        const Text(
          'This is a scheduled reminder, not a guaranteed alarm.',
          style: TextStyle(
            color: VitaMateTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onPlan,
                child: const Text('Adjust'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
        if (!plan.hasFeedback) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onFeedback,
            icon: const Icon(Icons.wb_sunny_rounded),
            label: const Text('Morning check-in'),
          ),
        ],
      ],
    );
  }
}

class _MorningPromptCard extends StatelessWidget {
  const _MorningPromptCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: VitaMateTheme.softSurface,
      child: Row(
        children: [
          const Icon(Icons.wb_sunny_rounded, color: VitaMateTheme.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'How did you wake up? Add a quick rating so your coach learns.',
              style: TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
          ),
          TextButton(onPressed: onTap, child: const Text('Rate')),
        ],
      ),
    );
  }
}

class _LearningSummaryCard extends StatelessWidget {
  const _LearningSummaryCard({required this.summary});

  final SleepLearningSummary summary;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sleep learning',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(label: '${summary.sampleSize} check-ins'),
              _Badge(label: 'Avg ${summary.averageQuality.toStringAsFixed(1)}/5'),
              if (summary.bestSleepDurationRange.isNotEmpty)
                _Badge(label: summary.bestSleepDurationRange),
            ],
          ),
          if (summary.insights.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final insight in summary.insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  insight,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SleepPlanSheet extends StatefulWidget {
  const _SleepPlanSheet({
    required this.controller,
    required this.initialBedTime,
    required this.initialWakeTime,
  });

  final SleepCoachController controller;
  final DateTime initialBedTime;
  final DateTime initialWakeTime;

  @override
  State<_SleepPlanSheet> createState() => _SleepPlanSheetState();
}

class _SleepPlanSheetState extends State<_SleepPlanSheet> {
  late DateTime _bedTime;
  late DateTime _wakeTime;
  int _flexibility = 30;
  String _caffeine = 'none';
  String _dinner = 'normal';
  String _stress = 'medium';
  String _exercise = 'none';
  String _nap = 'none';
  String _screen = 'medium';
  String _tomorrowGoal = 'normal';
  SleepPlan? _createdPlan;

  @override
  void initState() {
    super.initState();
    _bedTime = widget.initialBedTime;
    _wakeTime = widget.initialWakeTime;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return _SheetScaffold(
          children: [
            const _SheetHandle(),
            const SizedBox(height: 18),
            const Text(
              'Plan tonight',
              style: TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w900,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A 30-second plan that combines your answers with nutrition and activity signals.',
              style: TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            _TimeTile(
              icon: Icons.bedtime_rounded,
              title: 'Planned bedtime',
              value: DateFormat('h:mm a').format(_bedTime),
              onTap: () => _pickSheetTime(_bedTime, (value) => _bedTime = value),
            ),
            const SizedBox(height: 10),
            _TimeTile(
              icon: Icons.alarm_rounded,
              title: 'Latest wake time',
              value: DateFormat('h:mm a').format(_wakeTime),
              onTap: () => _pickSheetTime(_wakeTime, (value) => _wakeTime = value),
            ),
            const SizedBox(height: 14),
            _ChoiceWrap<int>(
              label: 'Wake flexibility',
              value: _flexibility,
              options: const {
                0: 'Exact',
                15: '15 min',
                30: '30 min',
                60: '1 hour',
              },
              onChanged: (value) => setState(() => _flexibility = value),
            ),
            const SizedBox(height: 14),
            _ChoiceWrap<String>(
              label: 'Last caffeine',
              value: _caffeine,
              options: const {
                'none': 'None',
                'before_noon': 'Before noon',
                'after_afternoon': 'After afternoon',
                'last_4_hours': 'Last 4h',
              },
              onChanged: (value) => setState(() => _caffeine = value),
            ),
            _ChoiceWrap<String>(
              label: 'Dinner',
              value: _dinner,
              options: const {
                'light': 'Light',
                'normal': 'Normal',
                'heavy_late': 'Heavy/late',
              },
              onChanged: (value) => setState(() => _dinner = value),
            ),
            _ChoiceWrap<String>(
              label: 'Stress',
              value: _stress,
              options: const {'low': 'Low', 'medium': 'Medium', 'high': 'High'},
              onChanged: (value) => setState(() => _stress = value),
            ),
            _ChoiceWrap<String>(
              label: 'Exercise',
              value: _exercise,
              options: const {
                'none': 'None',
                'light': 'Light',
                'strong': 'Strong',
                'intense_late': 'Strong late',
              },
              onChanged: (value) => setState(() => _exercise = value),
            ),
            _ChoiceWrap<String>(
              label: 'Nap',
              value: _nap,
              options: const {
                'none': 'None',
                'short': '< 30 min',
                'long_late': 'Long/late',
              },
              onChanged: (value) => setState(() => _nap = value),
            ),
            _ChoiceWrap<String>(
              label: 'Screen before bed',
              value: _screen,
              options: const {'low': 'Low', 'medium': 'Medium', 'high': 'High'},
              onChanged: (value) => setState(() => _screen = value),
            ),
            _ChoiceWrap<String>(
              label: 'Tomorrow',
              value: _tomorrowGoal,
              options: const {
                'normal': 'Normal',
                'focus': 'Focus',
                'exam': 'Exam/meeting',
                'workout': 'Workout',
              },
              onChanged: (value) => setState(() => _tomorrowGoal = value),
            ),
            if (_createdPlan != null) ...[
              const SizedBox(height: 14),
              _PlanResultPanel(plan: _createdPlan!),
            ],
            const SizedBox(height: 18),
            _PrimaryGradientButton(
              label: widget.controller.saving
                  ? 'Creating...'
                  : _createdPlan == null
                  ? 'Create smart wake'
                  : 'Update smart wake',
              icon: Icons.auto_awesome_rounded,
              onPressed: widget.controller.saving ? null : _createPlan,
            ),
            if (_createdPlan != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Use this wake time'),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _pickSheetTime(
    DateTime current,
    ValueChanged<DateTime> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;
    final base = current;
    setState(() {
      onPicked(DateTime(base.year, base.month, base.day, picked.hour, picked.minute));
    });
  }

  Future<void> _createPlan() async {
    var wakeTime = _wakeTime;
    if (!wakeTime.isAfter(_bedTime)) {
      wakeTime = wakeTime.add(const Duration(days: 1));
    }
    final plan = await widget.controller.createPlan(
      plannedBedTime: _bedTime,
      latestWakeTime: wakeTime,
      flexibilityMinutes: _flexibility,
      questionnaire: {
        'caffeine': _caffeine,
        'dinner': _dinner,
        'stress': _stress,
        'exercise': _exercise,
        'nap': _nap,
        'screen': _screen,
        'tomorrow_goal': _tomorrowGoal,
      },
    );
    if (plan != null && mounted) {
      setState(() => _createdPlan = plan);
    }
  }
}

class _MorningFeedbackSheet extends StatefulWidget {
  const _MorningFeedbackSheet({
    required this.controller,
    required this.plan,
  });

  final SleepCoachController controller;
  final SleepPlan plan;

  @override
  State<_MorningFeedbackSheet> createState() => _MorningFeedbackSheetState();
}

class _MorningFeedbackSheetState extends State<_MorningFeedbackSheet> {
  int _quality = 3;
  String _wakeFeeling = 'okay';
  int _focus = 3;
  String _disruptor = '';
  bool _includeActualTimes = true;
  late TimeOfDay _actualSleepStart;
  late TimeOfDay _actualWake;

  @override
  void initState() {
    super.initState();
    _actualSleepStart = TimeOfDay.fromDateTime(widget.plan.estimatedSleepStart);
    _actualWake = TimeOfDay.fromDateTime(
      widget.plan.selectedWakeTime ?? widget.plan.latestWakeTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return _SheetScaffold(
          children: [
            const _SheetHandle(),
            const SizedBox(height: 18),
            const Text(
              'How did you wake up?',
              style: TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Three quick answers help personalize future sleep plans.',
              style: TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            _RatingPicker(
              label: 'Sleep quality',
              value: _quality,
              onChanged: (value) => setState(() => _quality = value),
            ),
            const SizedBox(height: 14),
            _ChoiceWrap<String>(
              label: 'Wake feeling',
              value: _wakeFeeling,
              options: const {
                'rested': 'Rested',
                'okay': 'Okay',
                'groggy': 'Groggy',
                'exhausted': 'Exhausted',
              },
              onChanged: (value) => setState(() => _wakeFeeling = value),
            ),
            _RatingPicker(
              label: 'Focus first hour',
              value: _focus,
              onChanged: (value) => setState(() => _focus = value),
            ),
            const SizedBox(height: 14),
            _ChoiceWrap<String>(
              label: 'What affected sleep?',
              value: _disruptor,
              options: const {
                '': 'Not sure',
                'stress': 'Stress',
                'noise': 'Noise',
                'heat': 'Heat',
                'pain': 'Pain',
                'woke_often': 'Woke often',
              },
              onChanged: (value) => setState(() => _disruptor = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeActualTimes,
              onChanged: (value) => setState(() => _includeActualTimes = value),
              title: const Text(
                'Use these times to update sleep progress',
                style: TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (_includeActualTimes) ...[
              _TimeTile(
                icon: Icons.nightlight_round,
                title: 'Actual sleep start',
                value: _actualSleepStart.format(context),
                onTap: () => _pickTime(_actualSleepStart, (value) {
                  setState(() => _actualSleepStart = value);
                }),
              ),
              const SizedBox(height: 10),
              _TimeTile(
                icon: Icons.wb_sunny_rounded,
                title: 'Actual wake',
                value: _actualWake.format(context),
                onTap: () => _pickTime(_actualWake, (value) {
                  setState(() => _actualWake = value);
                }),
              ),
            ],
            const SizedBox(height: 18),
            _PrimaryGradientButton(
              label: widget.controller.saving ? 'Saving...' : 'Save feedback',
              icon: Icons.check_rounded,
              onPressed: widget.controller.saving ? null : _save,
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickTime(
    TimeOfDay current,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    final now = DateTime.now();
    DateTime? sleepStart;
    DateTime? wake;
    if (_includeActualTimes) {
      sleepStart = DateTime(
        now.year,
        now.month,
        now.day,
        _actualSleepStart.hour,
        _actualSleepStart.minute,
      );
      wake = DateTime(
        now.year,
        now.month,
        now.day,
        _actualWake.hour,
        _actualWake.minute,
      );
      if (!wake.isAfter(sleepStart)) {
        wake = wake.add(const Duration(days: 1));
      }
      if (sleepStart.isAfter(now.add(const Duration(hours: 2)))) {
        sleepStart = sleepStart.subtract(const Duration(days: 1));
      }
    }
    final saved = await widget.controller.saveFeedback(
      planId: widget.plan.id,
      qualityRating: _quality,
      wakeFeeling: _wakeFeeling,
      focusRating: _focus,
      disruptor: _disruptor,
      actualSleepStart: sleepStart,
      actualWakeTime: wake,
    );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _PlanResultPanel extends StatelessWidget {
  const _PlanResultPanel({required this.plan});

  final SleepPlan plan;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('h:mm a');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended: ${fmt.format(plan.recommendedOption?.wakeTime ?? plan.latestWakeTime)}',
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            plan.recommendationReason,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          for (final option in plan.wakeOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    option.isRecommended
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                    color: option.isRecommended
                        ? VitaMateTheme.primary
                        : VitaMateTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_optionLabel(option.kind)} ${fmt.format(option.wakeTime)}',
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          _InfoStrip(text: plan.nightTip),
        ],
      ),
    );
  }

  String _optionLabel(String kind) {
    switch (kind) {
      case 'earlier':
        return 'Earlier';
      case 'not_preferred':
        return 'Less ideal';
      default:
        return 'Best';
    }
  }
}

class _RatingPicker extends StatelessWidget {
  const _RatingPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 1; i <= 5; i++) ...[
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: i == value
                          ? VitaMateTheme.primary
                          : VitaMateTheme.softSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: VitaMateTheme.border),
                    ),
                    child: Text(
                      '$i',
                      style: TextStyle(
                        color: i == value ? Colors.white : VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              if (i != 5) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _ChoiceWrap<T> extends StatelessWidget {
  const _ChoiceWrap({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in options.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: entry.key == value,
                  onSelected: (_) => onChanged(entry.key),
                  selectedColor: VitaMateTheme.primary,
                  backgroundColor: VitaMateTheme.softSurface,
                  labelStyle: TextStyle(
                    color: entry.key == value
                        ? Colors.white
                        : VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w800,
                  ),
                  side: const BorderSide(color: VitaMateTheme.border),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SleepLogRow extends StatelessWidget {
  const _SleepLogRow({required this.log, required this.dateLabel});

  final SleepLog log;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('h:mm a');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              log.durationHours.toStringAsFixed(1),
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fmt.format(log.startTime)} - ${fmt.format(log.endTime)}',
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$dateLabel · ${_sleepQualityLabel(log.quality)}',
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _Badge(label: '+${log.pointsEarned} pts'),
        ],
      ),
    );
  }
}

String _sleepQualityLabel(String quality) {
  switch (quality) {
    case 'Deep':
      return 'Restful';
    case 'Light':
      return 'Okay';
    case 'Interrupted':
      return 'Interrupted';
    default:
      return 'Logged';
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VitaMateTheme.softSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: VitaMateTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: VitaMateTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
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

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7F21F5), Color(0xFF9E2CFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.color = VitaMateTheme.primary});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: VitaMateTheme.textMuted,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaMateTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
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

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: VitaMateTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            children: children,
          ),
        );
      },
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 58,
        height: 6,
        decoration: BoxDecoration(
          color: VitaMateTheme.borderStrong,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
