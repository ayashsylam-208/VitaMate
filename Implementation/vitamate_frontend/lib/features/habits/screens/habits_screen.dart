import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../models/unhealthy_habit.dart';
import '../state/unhealthy_habits_controller.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  late final UnhealthyHabitsController _controller;

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
    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      appBar: AppBar(
        title: const Text('Habit Support'),
        actions: [
          IconButton(
            onPressed: _controller.loading ? null : () => _controller.load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 3),
      body: RefreshIndicator(
        onRefresh: () => _controller.load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _HeaderCard(
              summary: overview.summary,
              supportMessage: overview.supportMessage,
            ),
            if (_controller.error != null) ...[
              const SizedBox(height: 12),
              _ErrorCard(message: _controller.error!),
            ],
            const SizedBox(height: 14),
            for (final habit in overview.habits) ...[
              _HabitCard(
                habit: habit,
                busy: _controller.saving,
                onSetup: () => _openSetup(habit),
                onLog: () => _openLog(habit),
              ),
              const SizedBox(height: 12),
            ],
            const _SafetyCard(),
          ],
        ),
      ),
    );
  }

  Future<void> _openSetup(UnhealthyHabit habit) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SetupHabitSheet(
        habit: habit,
        saving: _controller.saving,
        onSave: ({
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
          }
        },
      ),
    );
  }

  Future<void> _openLog(UnhealthyHabit habit) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LogHabitSheet(
        habit: habit,
        saving: _controller.saving,
        onSave: ({
          required double quantity,
          required String unit,
          required String trigger,
          required String mood,
          required bool syncToTracker,
          required double caffeineMg,
          required double caloriesKcal,
          required String foodName,
          required bool healthyReplacement,
        }) async {
          final ok = await _controller.logHabit(
            habit: habit,
            quantity: quantity,
            unit: unit,
            trigger: trigger,
            mood: mood,
            syncToTracker: syncToTracker,
            caffeineMg: caffeineMg,
            caloriesKcal: caloriesKcal,
            foodName: foodName,
            healthyReplacement: healthyReplacement,
          );
          if (ok && context.mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.summary, required this.supportMessage});

  final UnhealthyHabitSummary summary;
  final String supportMessage;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      gradient: const LinearGradient(
        colors: [Color(0xFFF0E5FF), Color(0xFFFFF5FA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.self_improvement_rounded, color: VitaMateTheme.primary),
              SizedBox(width: 8),
              Text(
                'Unhealthy habit management',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: VitaMateTheme.primaryDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            supportMessage.isEmpty
                ? 'Track triggers, reduce gradually, and keep the plan supportive.'
                : supportMessage,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: '${summary.activeCount} active'),
              _Chip(label: '${summary.logsToday} logs today'),
              _Chip(label: '+${summary.pointsToday} pts'),
              if (summary.relapsesToday > 0)
                _Chip(
                  label: '${summary.relapsesToday} needs review',
                  color: VitaMateTheme.danger,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.busy,
    required this.onSetup,
    required this.onLog,
  });

  final UnhealthyHabit habit;
  final bool busy;
  final VoidCallback onSetup;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final progress = habit.progress;
    final limit = habit.habitType == 'fast_food'
        ? progress.weeklyLimit
        : progress.dailyLimit;
    final value = habit.habitType == 'fast_food'
        ? progress.weekValue
        : progress.todayValue;
    final unit = habit.baseline?.unit ?? _defaultUnit(habit.habitType);

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HabitIcon(type: habit.habitType),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.label,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: VitaMateTheme.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      habit.isSetup
                          ? habit.plan?.planStage ?? 'Active plan'
                          : 'Set a baseline and reduction plan',
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _ProgressBadge(value: habit.isSetup ? progress.adherencePercent : 0),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  label: habit.habitType == 'fast_food' ? 'This week' : 'Today',
                  value: limit == null
                      ? '${_fmt(value)} $unit'
                      : '${_fmt(value)} / ${_fmt(limit)} $unit',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  label: 'Improvement',
                  value: '${progress.improvementPercent}%',
                ),
              ),
            ],
          ),
          if (progress.supportMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              progress.supportMessage,
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (progress.topTrigger.isNotEmpty)
                _Chip(label: 'Trigger: ${progress.topTrigger}'),
              if (progress.riskyHour != null)
                _Chip(label: 'Risk ${progress.riskyHour}:00'),
              if (progress.relapseCount > 0)
                _Chip(
                  label: '${progress.relapseCount} review',
                  color: VitaMateTheme.danger,
                ),
              if (habit.reminders.isNotEmpty)
                _Chip(label: '${habit.reminders.length} reminder'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onSetup,
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(habit.isSetup ? 'Adjust plan' : 'Set up'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy || !habit.isSetup ? null : onLog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Log'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _defaultUnit(String type) {
    if (type == 'caffeine') return 'mg';
    if (type == 'fast_food') return 'meals';
    return 'cigarettes';
  }
}

class _SetupHabitSheet extends StatefulWidget {
  const _SetupHabitSheet({
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
  }) onSave;

  @override
  State<_SetupHabitSheet> createState() => _SetupHabitSheetState();
}

class _SetupHabitSheetState extends State<_SetupHabitSheet> {
  late final TextEditingController _initial;
  late final TextEditingController _trigger;
  late final TextEditingController _reminder;
  late final TextEditingController _cutoff;
  String _goalType = 'reduce';

  @override
  void initState() {
    super.initState();
    _goalType = widget.habit.isSetup && widget.habit.goalType != 'quit'
        ? 'reduce'
        : 'quit';
    _initial = TextEditingController(
      text: widget.habit.baseline?.initialQuantity.toString() ?? '',
    );
    _trigger = TextEditingController(text: widget.habit.baseline?.commonTrigger ?? '');
    _reminder = TextEditingController(
      text: widget.habit.plan?.reminderTime.isNotEmpty == true
          ? widget.habit.plan!.reminderTime
          : '18:00',
    );
    _cutoff = TextEditingController(
      text: widget.habit.plan?.cutoffTime.isNotEmpty == true
          ? widget.habit.plan!.cutoffTime
          : (widget.habit.habitType == 'caffeine' ? '18:00' : ''),
    );
  }

  @override
  void dispose() {
    _initial.dispose();
    _trigger.dispose();
    _reminder.dispose();
    _cutoff.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = _HabitCard._defaultUnit(widget.habit.habitType);
    final isFastFood = widget.habit.habitType == 'fast_food';
    return _SheetShell(
      title: '${widget.habit.label} plan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Segmented(
            value: _goalType,
            options: const {'quit': 'Quit', 'reduce': 'Reduce'},
            onChanged: (value) => setState(() => _goalType = value),
          ),
          const SizedBox(height: 14),
          _Field(
            controller: _initial,
            label: isFastFood
                ? 'How many fast-food meals per week?'
                : widget.habit.habitType == 'caffeine'
                    ? 'How much caffeine per day?'
                    : 'How many cigarettes per day?',
            suffix: unit,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VitaMateTheme.softSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: VitaMateTheme.border),
            ),
            child: Text(
              _goalType == 'quit'
                  ? 'VitaMate will generate a quit plan from this amount. You do not need to enter limits.'
                  : 'VitaMate will generate a gradual reduction plan from this amount. You do not need to enter limits.',
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _trigger,
            label: 'Most common trigger',
          ),
          if (widget.habit.habitType == 'caffeine') ...[
            const SizedBox(height: 12),
            _Field(controller: _cutoff, label: 'Caffeine cutoff', suffix: 'HH:MM'),
          ],
          const SizedBox(height: 12),
          _Field(controller: _reminder, label: 'Reminder time', suffix: 'HH:MM'),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: widget.saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save plan'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() {
    final initialQuantity = double.tryParse(_initial.text.trim()) ?? 0;
    if (initialQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your current consumption first.')),
      );
      return Future.value();
    }
    return widget.onSave(
      goalType: _goalType,
      initialQuantity: initialQuantity,
      unit: _HabitCard._defaultUnit(widget.habit.habitType),
      commonTrigger: _trigger.text.trim(),
      cutoffTime: _cutoff.text.trim(),
      reminderTime: _reminder.text.trim(),
    );
  }
}

class _LogHabitSheet extends StatefulWidget {
  const _LogHabitSheet({
    required this.habit,
    required this.saving,
    required this.onSave,
  });

  final UnhealthyHabit habit;
  final bool saving;
  final Future<void> Function({
    required double quantity,
    required String unit,
    required String trigger,
    required String mood,
    required bool syncToTracker,
    required double caffeineMg,
    required double caloriesKcal,
    required String foodName,
    required bool healthyReplacement,
  }) onSave;

  @override
  State<_LogHabitSheet> createState() => _LogHabitSheetState();
}

class _LogHabitSheetState extends State<_LogHabitSheet> {
  late final TextEditingController _quantity;
  late final TextEditingController _trigger;
  late final TextEditingController _mood;
  late final TextEditingController _foodName;
  late final TextEditingController _caffeine;
  late final TextEditingController _calories;
  bool _syncToTracker = true;
  bool _healthyReplacement = false;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(text: '1');
    _trigger = TextEditingController();
    _mood = TextEditingController();
    _foodName = TextEditingController(
      text: widget.habit.habitType == 'caffeine'
          ? 'Caffeinated drink'
          : widget.habit.habitType == 'fast_food'
              ? 'Fast food meal'
              : '',
    );
    _caffeine = TextEditingController();
    _calories = TextEditingController();
    _syncToTracker = widget.habit.habitType != 'smoking';
  }

  @override
  void dispose() {
    _quantity.dispose();
    _trigger.dispose();
    _mood.dispose();
    _foodName.dispose();
    _caffeine.dispose();
    _calories.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = _HabitCard._defaultUnit(widget.habit.habitType);
    final canSync = widget.habit.habitType != 'smoking';
    return _SheetShell(
      title: 'Log ${widget.habit.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Field(
            controller: _quantity,
            label: 'Quantity',
            suffix: unit,
            keyboardType: TextInputType.number,
          ),
          if (widget.habit.habitType == 'caffeine') ...[
            const SizedBox(height: 12),
            _Field(
              controller: _caffeine,
              label: 'Caffeine amount',
              suffix: 'mg',
              keyboardType: TextInputType.number,
            ),
          ],
          if (canSync) ...[
            const SizedBox(height: 12),
            _Field(controller: _foodName, label: 'Nutrition item name'),
            const SizedBox(height: 12),
            _Field(
              controller: _calories,
              label: 'Calories',
              suffix: 'kcal',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _syncToTracker,
              onChanged: (value) => setState(() => _syncToTracker = value),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: VitaMateTheme.primary,
              title: const Text(
                'Also add to nutrition tracking',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
          if (widget.habit.habitType == 'fast_food')
            CheckboxListTile(
              value: _healthyReplacement,
              onChanged: (value) =>
                  setState(() => _healthyReplacement = value ?? false),
              contentPadding: EdgeInsets.zero,
              activeColor: VitaMateTheme.primary,
              title: const Text(
                'I chose a healthier replacement',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          const SizedBox(height: 12),
          _Field(controller: _trigger, label: 'Trigger'),
          const SizedBox(height: 12),
          _Field(controller: _mood, label: 'Mood'),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: widget.saving ? null : _save,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Save log'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() {
    return widget.onSave(
      quantity: double.tryParse(_quantity.text.trim()) ?? 1,
      unit: _HabitCard._defaultUnit(widget.habit.habitType),
      trigger: _trigger.text.trim(),
      mood: _mood.text.trim(),
      syncToTracker: _syncToTracker,
      caffeineMg: double.tryParse(_caffeine.text.trim()) ?? 0,
      caloriesKcal: double.tryParse(_calories.text.trim()) ?? 0,
      foodName: _foodName.text.trim(),
      healthyReplacement: _healthyReplacement,
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
                fontSize: 28,
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.suffix,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
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
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            selected: value == entry.key,
            onSelected: (_) => onChanged(entry.key),
            label: Text(entry.value),
            selectedColor: VitaMateTheme.primary,
            labelStyle: TextStyle(
              color: value == entry.key ? Colors.white : VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: value.clamp(0, 100) / 100,
            strokeWidth: 7,
            backgroundColor: VitaMateTheme.softSurface,
            color: VitaMateTheme.primary,
          ),
          Center(
            child: Text(
              '$value%',
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

class _HabitIcon extends StatelessWidget {
  const _HabitIcon({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    if (type == 'caffeine') {
      icon = Icons.coffee_rounded;
    } else if (type == 'fast_food') {
      icon = Icons.fastfood_rounded;
    } else {
      icon = Icons.smoke_free_rounded;
    }
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: VitaMateTheme.primary),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? VitaMateTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: effectiveColor,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
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
              'This module supports tracking and gradual behavior change. It does not replace medical care or a smoking cessation program.',
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

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.gradient});

  final Widget child;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gradient == null ? Colors.white.withValues(alpha: 0.97) : null,
        gradient: gradient,
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

String _fmt(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
