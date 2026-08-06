import 'package:flutter/material.dart';

import '../../../core/routing/routes.dart';
import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../models/unhealthy_habit.dart';
import '../presentation/mappers/habit_ui_mapper.dart';
import '../presentation/widgets/habit_overview_card.dart';
import '../presentation/widgets/habits_today_summary.dart';
import '../state/unhealthy_habits_controller.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  late final UnhealthyHabitsController _controller;
  final Set<String> _expandedCards = <String>{};

  @override
  void initState() {
    super.initState();
    _controller = UnhealthyHabitsController()..addListener(_onChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = _controller.overview;
    final summary = HabitUiMapper.mapSummary(overview);
    final habits = overview.habits.map(HabitUiMapper.mapHabit).toList();

    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            tooltip: 'Refresh habits',
            onPressed: _controller.loading ? null : () => _controller.load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 3),
      body: RefreshIndicator(
        onRefresh: () => _controller.load(),
        child: ListView(
          key: const ValueKey(AppTestKeys.habitsScreen),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const _ScreenHeader(),
            const SizedBox(height: 14),
            HabitsTodaySummary(summary: summary),
            if (_controller.error != null) ...[
              const SizedBox(height: 12),
              _ErrorCard(message: _controller.error!),
            ],
            const SizedBox(height: 14),
            for (final model in habits) ...[
              HabitOverviewCard(
                model: model,
                expanded: _expandedCards.contains(model.key),
                busy: _controller.saving,
                onToggleExpanded: () => _toggleExpanded(model.key),
                onPrimaryAction: () => _handlePrimaryAction(model),
                onEditPlan: () => _openSetup(model.habit),
                onPauseOrResume: () => _togglePaused(model.habit),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 2),
            const _WeeklyProgressShortcut(),
            const SizedBox(height: 12),
            const _SafetyCard(),
          ],
        ),
      ),
    );
  }

  void _toggleExpanded(String key) {
    setState(() {
      if (_expandedCards.contains(key)) {
        _expandedCards.remove(key);
      } else {
        _expandedCards.add(key);
      }
    });
  }

  void _expandOnly(String key) {
    setState(() => _expandedCards.add(key));
  }

  Future<void> _handlePrimaryAction(HabitCardViewModel model) async {
    switch (model.primaryAction) {
      case HabitPrimaryActionType.setup:
        await _openSetup(model.habit);
        return;
      case HabitPrimaryActionType.checkIn:
        await _openCheckIn(model.habit);
        return;
      case HabitPrimaryActionType.log:
        await _openLog(model.habit);
        return;
      case HabitPrimaryActionType.resume:
        await _togglePaused(model.habit);
        return;
      case HabitPrimaryActionType.viewDetails:
      case HabitPrimaryActionType.reviewToday:
      case HabitPrimaryActionType.viewProgress:
      case HabitPrimaryActionType.completeEntry:
        _expandOnly(model.key);
        return;
    }
  }

  Future<void> _openSetup(UnhealthyHabit habit) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SetupHabitWizard(
        habit: habit,
        saving: _controller.saving,
        onSave:
            ({
              required String goalType,
              required double initialQuantity,
              required String unit,
              required String commonTrigger,
              required String cutoffTime,
              required String reminderTime,
            }) async {
              final saved = await _controller.setupHabit(
                habitType: habit.habitType,
                goalType: goalType,
                initialQuantity: initialQuantity,
                unit: unit,
                commonTrigger: commonTrigger,
                cutoffTime: cutoffTime,
                reminderTime: reminderTime,
              );
              if (saved != null && context.mounted) {
                Navigator.pop(context);
                _showSnack('Plan started');
              }
            },
      ),
    );
  }

  Future<void> _openCheckIn(UnhealthyHabit habit) async {
    if (!habit.isActive) {
      return;
    }
    final action = await showModalBottomSheet<_CheckInAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CheckInSheet(habit: habit),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == _CheckInAction.noUse) {
      final confirmed = await _confirmNoUse(habit);
      if (confirmed != true || !mounted) {
        return;
      }
      final ok = await _controller.dailyCheckIn(habit: habit, used: false);
      if (ok && mounted) {
        _showSnack(_noUseSavedMessage(habit));
      }
      return;
    }
    await _openLog(habit);
  }

  Future<bool?> _confirmNoUse(UnhealthyHabit habit) {
    final isSmoking = habit.habitType == 'smoking';
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm today\'s check-in?'),
        content: Text(
          isSmoking
              ? 'You are confirming that you stayed smoke-free today.'
              : 'You are confirming that you avoided this habit today.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLog(UnhealthyHabit habit) async {
    if (habit.habitType == 'caffeine') {
      await _openCaffeineLog(habit);
      return;
    }
    if (habit.habitType == 'fast_food') {
      await _openFastFoodLog(habit);
      return;
    }
    await _openSmokingLog(habit);
  }

  Future<void> _openSmokingLog(UnhealthyHabit habit) async {
    final payload = await showModalBottomSheet<_SmokingLogPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _SmokingLogSheet(),
    );
    if (payload == null || !mounted) {
      return;
    }
    final ok = await _controller.logHabit(
      habit: habit,
      quantity: payload.cigarettes,
      unit: 'cigarettes',
      trigger: payload.ledBy,
      mood: payload.mood,
      syncToTracker: false,
      loggedAt: payload.loggedAt,
    );
    if (ok && mounted) {
      _showSnack('Smoking check-in saved');
    }
  }

  Future<void> _openCaffeineLog(UnhealthyHabit habit) async {
    final payload = await showModalBottomSheet<_CaffeineLogPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CaffeineLogSheet(),
    );
    if (payload == null || !mounted) {
      return;
    }
    final ok = await _controller.logHabit(
      habit: habit,
      quantity: payload.servings.toDouble(),
      unit: 'servings',
      trigger: payload.ledBy,
      mood: '',
      syncToTracker: payload.addToHydration,
      caffeineMg: payload.caffeineMg,
      caloriesKcal: 0,
      foodName: payload.drinkLabel,
      mealType: 'drink',
      loggedAt: payload.loggedAt,
    );
    if (ok && mounted) {
      _showSnack('Added to your Caffeine habit');
    }
  }

  Future<void> _openFastFoodLog(UnhealthyHabit habit) async {
    final payload = await showModalBottomSheet<_FastFoodLogPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _FastFoodLogSheet(),
    );
    if (payload == null || !mounted) {
      return;
    }
    final ok = await _controller.logHabit(
      habit: habit,
      quantity: 1,
      unit: 'meals',
      trigger: payload.ledBy,
      mood: '',
      syncToTracker: payload.addToNutrition,
      caloriesKcal: payload.caloriesKcal,
      foodName: payload.foodName,
      healthyReplacement: payload.healthierChoice,
      mealType: payload.mealType,
      loggedAt: payload.loggedAt,
    );
    if (ok && mounted) {
      _showSnack('Added to your Fast Food habit');
    }
  }

  Future<void> _togglePaused(UnhealthyHabit habit) async {
    if (habit.id == null) {
      return;
    }
    if (habit.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pause this plan?'),
          content: const Text(
            'Reminders and daily tracking will stop until you continue it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pause this plan'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }
    final ok = await _controller.togglePaused(habit);
    if (ok && mounted) {
      _showSnack(habit.isActive ? 'Plan paused' : 'Plan continued');
    }
  }

  String _noUseSavedMessage(UnhealthyHabit habit) {
    if (habit.habitType == 'smoking') {
      return 'Smoke-free check-in saved';
    }
    if (habit.habitType == 'fast_food') {
      return 'Fast-food-free check-in saved';
    }
    return 'Check-in saved';
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Habits',
          style: TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Small steps, healthier days',
          style: TextStyle(
            color: VitaMateTheme.textMuted,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

enum _CheckInAction { noUse, used }

class _CheckInSheet extends StatelessWidget {
  const _CheckInSheet({required this.habit});

  final UnhealthyHabit habit;

  @override
  Widget build(BuildContext context) {
    final isSmoking = habit.habitType == 'smoking';
    return _SheetShell(
      title: 'How was today?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActionTile(
            icon: Icons.check_circle_outline_rounded,
            title: isSmoking
                ? 'I stayed smoke-free'
                : 'I avoided this habit today',
            subtitle: 'This will be confirmed before saving.',
            onTap: () => Navigator.pop(context, _CheckInAction.noUse),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.edit_note_rounded,
            title: isSmoking ? 'I smoked' : 'I used this habit',
            subtitle: 'Log what happened so your plan stays accurate.',
            onTap: () => Navigator.pop(context, _CheckInAction.used),
          ),
        ],
      ),
    );
  }
}

class _SetupHabitWizard extends StatefulWidget {
  const _SetupHabitWizard({
    required this.habit,
    required this.saving,
    required this.onSave,
  });

  final UnhealthyHabit habit;
  final bool saving;
  final Future<void> Function({
    required String goalType,
    required double initialQuantity,
    required String unit,
    required String commonTrigger,
    required String cutoffTime,
    required String reminderTime,
  })
  onSave;

  @override
  State<_SetupHabitWizard> createState() => _SetupHabitWizardState();
}

class _SetupHabitWizardState extends State<_SetupHabitWizard> {
  final TextEditingController _currentAmount = TextEditingController();
  final TextEditingController _whatLedToIt = TextEditingController();
  final TextEditingController _cutoffTime = TextEditingController();
  final TextEditingController _reminderTime = TextEditingController(
    text: '18:00',
  );
  int _step = 0;
  String _strategy = 'reduce';

  @override
  void initState() {
    super.initState();
    final baseline = widget.habit.baseline;
    final plan = widget.habit.plan;
    _currentAmount.text = baseline?.initialQuantity.toString() ?? '';
    _whatLedToIt.text = baseline?.commonTrigger ?? '';
    _cutoffTime.text = plan?.cutoffTime.isNotEmpty == true
        ? plan!.cutoffTime
        : (widget.habit.habitType == 'caffeine' ? '18:00' : '');
    _reminderTime.text = plan?.reminderTime.isNotEmpty == true
        ? plan!.reminderTime
        : _defaultReminderTime(widget.habit.habitType);
    _strategy = widget.habit.goalType == 'quit' ? 'quit' : 'reduce';
  }

  @override
  void dispose() {
    _currentAmount.dispose();
    _whatLedToIt.dispose();
    _cutoffTime.dispose();
    _reminderTime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title:
          'Set up ${HabitUiText.habitTitle(widget.habit.habitType, widget.habit.label)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(step: _step + 1, total: 5, title: _stepTitle),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: KeyedSubtree(key: ValueKey(_step), child: _stepBody()),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.saving
                        ? null
                        : () => setState(() => _step--),
                    child: const Text('Back'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: widget.saving ? null : _nextOrSave,
                  child: Text(_step == 4 ? 'Start plan' : 'Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _stepTitle {
    switch (_step) {
      case 0:
        return 'Your current habit';
      case 1:
        return 'Choose your goal';
      case 2:
        return 'Set your plan';
      case 3:
        return 'Preview';
      default:
        return 'Start plan';
    }
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _currentHabitStep();
      case 1:
        return _goalStep();
      case 2:
        return _planStep();
      case 3:
      case 4:
        return _previewStep(finalStep: _step == 4);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _currentHabitStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Field(
          controller: _currentAmount,
          label: _currentQuestion(widget.habit.habitType),
          suffix: _setupFieldSuffix(widget.habit.habitType),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _Field(controller: _whatLedToIt, label: 'What usually leads to it?'),
      ],
    );
  }

  Widget _goalStep() {
    return _ChoicePills(
      value: _strategy,
      options: _strategyOptions(widget.habit.habitType),
      onChanged: (value) => setState(() => _strategy = value),
    );
  }

  Widget _planStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.habit.habitType == 'caffeine') ...[
          _Field(
            controller: _cutoffTime,
            label: 'Avoid caffeine after',
            suffix: 'HH:MM',
          ),
          const SizedBox(height: 12),
        ],
        _Field(
          controller: _reminderTime,
          label: 'Reminder time',
          suffix: 'HH:MM',
        ),
        const SizedBox(height: 12),
        const _InfoBox(
          text:
              'VitaMate will generate the daily or weekly targets from your starting point and refresh the plan from the backend.',
        ),
      ],
    );
  }

  Widget _previewStep({required bool finalStep}) {
    return _PlanPreviewCard(
      title:
          'Your ${HabitUiText.habitTitle(widget.habit.habitType, widget.habit.label)} plan',
      items: [
        'Starting point: ${_currentAmount.text.trim()} ${_setupFieldSuffix(widget.habit.habitType)}',
        _previewGoalText(widget.habit.habitType, _strategy),
        if (_cutoffTime.text.trim().isNotEmpty)
          'Avoid after ${_cutoffTime.text.trim()}',
        if (_reminderTime.text.trim().isNotEmpty)
          'Reminder at ${_reminderTime.text.trim()}',
        'Your progress will be reviewed daily',
      ],
      footer: finalStep
          ? 'This is one atomic save. If the request fails, no partial plan is shown.'
          : 'Review this before continuing to the final step.',
    );
  }

  Future<void> _nextOrSave() async {
    if (_step == 0 && (double.tryParse(_currentAmount.text.trim()) ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your current amount first.')),
      );
      return;
    }
    if (_step < 4) {
      setState(() => _step++);
      return;
    }
    await widget.onSave(
      goalType: _strategy == 'quit' ? 'quit' : 'reduce',
      initialQuantity: double.tryParse(_currentAmount.text.trim()) ?? 0,
      unit: _setupPayloadUnit(widget.habit.habitType),
      commonTrigger: _whatLedToIt.text.trim(),
      cutoffTime: _cutoffTime.text.trim(),
      reminderTime: _reminderTime.text.trim(),
    );
  }

  static String _currentQuestion(String habitType) {
    if (habitType == 'smoking') {
      return 'How many cigarettes do you usually smoke per day?';
    }
    if (habitType == 'caffeine') {
      return 'How much caffeine do you usually have per day?';
    }
    return 'How often do you usually eat fast food?';
  }

  static Map<String, String> _strategyOptions(String habitType) {
    if (habitType == 'smoking') {
      return const {
        'quit': 'Stay smoke-free',
        'reduce': 'Reduce gradually',
        'limit': 'Stay within a daily goal',
      };
    }
    if (habitType == 'caffeine') {
      return const {
        'reduce': 'Reduce daily caffeine',
        'cutoff': 'Avoid caffeine later',
        'quit': 'Stay caffeine-free',
      };
    }
    return const {
      'quit': 'Avoid fast food',
      'reduce': 'Reduce weekly meals',
      'limit': 'Stay within a weekly goal',
    };
  }

  static String _previewGoalText(String habitType, String strategy) {
    if (habitType == 'smoking' && strategy == 'quit') {
      return 'Goal: stay smoke-free';
    }
    if (habitType == 'caffeine' && strategy == 'cutoff') {
      return 'Goal: avoid caffeine later in the day';
    }
    if (habitType == 'fast_food' && strategy == 'quit') {
      return 'Goal: avoid fast food';
    }
    return 'Goal: reduce gradually';
  }
}

class _SmokingLogPayload {
  const _SmokingLogPayload({
    required this.cigarettes,
    required this.ledBy,
    required this.mood,
    required this.loggedAt,
  });

  final double cigarettes;
  final String ledBy;
  final String mood;
  final DateTime loggedAt;
}

class _SmokingLogSheet extends StatefulWidget {
  const _SmokingLogSheet();

  @override
  State<_SmokingLogSheet> createState() => _SmokingLogSheetState();
}

class _SmokingLogSheetState extends State<_SmokingLogSheet> {
  final TextEditingController _cigarettes = TextEditingController(text: '1');
  final TextEditingController _ledBy = TextEditingController();
  final TextEditingController _mood = TextEditingController();

  @override
  void dispose() {
    _cigarettes.dispose();
    _ledBy.dispose();
    _mood.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Log smoking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Field(
            controller: _cigarettes,
            label: 'Cigarettes',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _Field(controller: _ledBy, label: 'What led to it?'),
          const SizedBox(height: 12),
          _Field(controller: _mood, label: 'How did you feel?'),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _SmokingLogPayload(
                cigarettes: double.tryParse(_cigarettes.text.trim()) ?? 1,
                ledBy: _ledBy.text.trim(),
                mood: _mood.text.trim(),
                loggedAt: DateTime.now(),
              ),
            ),
            child: const Text('Save check-in'),
          ),
        ],
      ),
    );
  }
}

class _CaffeineLogPayload {
  const _CaffeineLogPayload({
    required this.drinkLabel,
    required this.servings,
    required this.caffeineMg,
    required this.addToHydration,
    required this.ledBy,
    required this.loggedAt,
  });

  final String drinkLabel;
  final int servings;
  final double caffeineMg;
  final bool addToHydration;
  final String ledBy;
  final DateTime loggedAt;
}

class _CaffeineLogSheet extends StatefulWidget {
  const _CaffeineLogSheet();

  @override
  State<_CaffeineLogSheet> createState() => _CaffeineLogSheetState();
}

class _CaffeineLogSheetState extends State<_CaffeineLogSheet> {
  final TextEditingController _customMg = TextEditingController();
  final TextEditingController _ledBy = TextEditingController();
  String _drinkType = 'Coffee';
  String _size = 'Medium';
  int _servings = 1;
  bool _editMg = false;
  bool _addToHydration = true;

  @override
  void dispose() {
    _customMg.dispose();
    _ledBy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estimatedMg = _estimatedCaffeineMg;
    if (!_editMg) {
      _customMg.text = estimatedMg.toStringAsFixed(0);
    }
    return _SheetShell(
      title: 'Log a caffeinated drink',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('What did you drink?'),
          _ChoicePills(
            value: _drinkType,
            options: const {
              'Coffee': 'Coffee',
              'Tea': 'Tea',
              'Energy drink': 'Energy drink',
              'Soft drink': 'Soft drink',
              'Other': 'Other',
            },
            onChanged: (value) => setState(() => _drinkType = value),
          ),
          const SizedBox(height: 14),
          _CounterRow(
            label: 'Servings',
            value: _servings,
            onChanged: (value) => setState(() => _servings = value),
          ),
          const SizedBox(height: 14),
          const _SectionLabel('Size'),
          _ChoicePills(
            value: _size,
            options: const {
              'Small': 'Small',
              'Medium': 'Medium',
              'Large': 'Large',
              'Custom': 'Custom',
            },
            onChanged: (value) => setState(() => _size = value),
          ),
          const SizedBox(height: 14),
          _Field(
            controller: _customMg,
            label: 'Estimated caffeine',
            suffix: 'mg',
            keyboardType: TextInputType.number,
            enabled: _editMg,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _editMg = !_editMg),
              child: Text(_editMg ? 'Use estimate' : 'Edit caffeine amount'),
            ),
          ),
          _Field(controller: _ledBy, label: 'What led to it?'),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: _addToHydration,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: VitaMateTheme.primary,
            title: const Text(
              'Also add to Hydration',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            onChanged: (value) => setState(() => _addToHydration = value),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _CaffeineLogPayload(
                drinkLabel: _drinkType,
                servings: _servings,
                caffeineMg:
                    double.tryParse(_customMg.text.trim()) ?? estimatedMg,
                addToHydration: _addToHydration,
                ledBy: _ledBy.text.trim(),
                loggedAt: DateTime.now(),
              ),
            ),
            child: const Text('Save drink'),
          ),
        ],
      ),
    );
  }

  double get _estimatedCaffeineMg {
    final base = switch (_drinkType) {
      'Tea' => 45.0,
      'Energy drink' => 80.0,
      'Soft drink' => 35.0,
      'Other' => 60.0,
      _ => 95.0,
    };
    final sizeFactor = switch (_size) {
      'Small' => 0.75,
      'Large' => 1.35,
      'Custom' => 1.0,
      _ => 1.0,
    };
    return base * sizeFactor * _servings;
  }
}

class _FastFoodLogPayload {
  const _FastFoodLogPayload({
    required this.mealType,
    required this.foodName,
    required this.caloriesKcal,
    required this.ledBy,
    required this.addToNutrition,
    required this.healthierChoice,
    required this.loggedAt,
  });

  final String mealType;
  final String foodName;
  final double caloriesKcal;
  final String ledBy;
  final bool addToNutrition;
  final bool healthierChoice;
  final DateTime loggedAt;
}

class _FastFoodLogSheet extends StatefulWidget {
  const _FastFoodLogSheet();

  @override
  State<_FastFoodLogSheet> createState() => _FastFoodLogSheetState();
}

class _FastFoodLogSheetState extends State<_FastFoodLogSheet> {
  final TextEditingController _foodName = TextEditingController(
    text: 'Fast food meal',
  );
  final TextEditingController _calories = TextEditingController();
  final TextEditingController _ledBy = TextEditingController();
  String _mealType = 'lunch';
  String _when = 'now';
  bool _addToNutrition = true;
  bool _healthierChoice = false;

  @override
  void dispose() {
    _foodName.dispose();
    _calories.dispose();
    _ledBy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Log fast food',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Meal type'),
          _ChoicePills(
            value: _mealType,
            options: const {
              'breakfast': 'Breakfast',
              'lunch': 'Lunch',
              'dinner': 'Dinner',
              'snack': 'Snack',
            },
            onChanged: (value) => setState(() => _mealType = value),
          ),
          const SizedBox(height: 14),
          _Field(controller: _foodName, label: 'What did you have?'),
          const SizedBox(height: 12),
          _Field(
            controller: _calories,
            label: 'Calories',
            suffix: 'kcal',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          const _SectionLabel('When?'),
          _ChoicePills(
            value: _when,
            options: const {'now': 'Now', 'earlier': 'Earlier today'},
            onChanged: (value) => setState(() => _when = value),
          ),
          const SizedBox(height: 12),
          _Field(controller: _ledBy, label: 'What led to it?'),
          CheckboxListTile(
            value: _healthierChoice,
            contentPadding: EdgeInsets.zero,
            activeColor: VitaMateTheme.primary,
            title: const Text(
              'I chose a healthier option',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            onChanged: (value) =>
                setState(() => _healthierChoice = value ?? false),
          ),
          SwitchListTile.adaptive(
            value: _addToNutrition,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: VitaMateTheme.primary,
            title: const Text(
              'Also add to Nutrition',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            onChanged: (value) => setState(() => _addToNutrition = value),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _FastFoodLogPayload(
                mealType: _mealType,
                foodName: _foodName.text.trim(),
                caloriesKcal: double.tryParse(_calories.text.trim()) ?? 0,
                ledBy: _ledBy.text.trim(),
                addToNutrition: _addToNutrition,
                healthierChoice: _healthierChoice,
                loggedAt: _when == 'earlier'
                    ? DateTime.now().subtract(const Duration(hours: 2))
                    : DateTime.now(),
              ),
            ),
            child: const Text('Save fast food'),
          ),
        ],
      ),
    );
  }
}

class _WeeklyProgressShortcut extends StatelessWidget {
  const _WeeklyProgressShortcut();

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.pushNamed(context, Routes.progress),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(Icons.insights_rounded, color: VitaMateTheme.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Weekly progress',
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: VitaMateTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VitaMateTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: VitaMateTheme.primary),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.total,
    required this.title,
  });

  final int step;
  final int total;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $step of $total',
          style: const TextStyle(
            color: VitaMateTheme.textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _PlanPreviewCard extends StatelessWidget {
  const _PlanPreviewCard({
    required this.title,
    required this.items,
    required this.footer,
  });

  final String title;
  final List<String> items;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VitaMateTheme.border),
      ),
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
          const SizedBox(height: 12),
          for (final item in items.where((item) => item.trim().isNotEmpty)) ...[
            Text(
              '- $item',
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 4),
          Text(
            footer,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoicePills extends StatelessWidget {
  const _ChoicePills({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            selected: value == entry.key,
            onSelected: (_) => onChanged(entry.key),
            selectedColor: VitaMateTheme.primary,
            label: Text(entry.value),
            labelStyle: TextStyle(
              color: value == entry.key
                  ? Colors.white
                  : VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        SizedBox(
          width: 44,
          child: Center(
            child: Text(
              '$value',
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.suffix,
    this.keyboardType,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      minLines: 1,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: VitaMateTheme.primaryDeep,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitaMateTheme.border),
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

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, controller) => Container(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          MediaQuery.of(context).viewInsets.bottom + 22,
        ),
        decoration: const BoxDecoration(
          color: VitaMateTheme.shellBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: ListView(
          controller: controller,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 6,
                decoration: BoxDecoration(
                  color: VitaMateTheme.borderStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: VitaMateTheme.primaryDeep,
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
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

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return const _Surface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: VitaMateTheme.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This feature supports tracking and gradual behavior change. It does not replace medical care or a cessation program.',
              style: TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Text(
        message,
        style: const TextStyle(
          color: VitaMateTheme.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _setupFieldSuffix(String habitType) {
  if (habitType == 'caffeine') {
    return 'mg';
  }
  if (habitType == 'fast_food') {
    return 'meals/week';
  }
  return 'cigarettes/day';
}

String _setupPayloadUnit(String habitType) {
  if (habitType == 'caffeine') {
    return 'mg';
  }
  if (habitType == 'fast_food') {
    return 'meals';
  }
  return 'cigarettes';
}

String _defaultReminderTime(String habitType) {
  if (habitType == 'caffeine') {
    return '14:00';
  }
  if (habitType == 'fast_food') {
    return '12:00';
  }
  return '18:00';
}
