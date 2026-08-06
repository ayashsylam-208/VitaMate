import 'package:flutter/material.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../models/manager_models.dart';
import '../state/goals_controller.dart';
import '../widgets/goal_card.dart';

class ManagerGoalsScreen extends StatefulWidget {
  const ManagerGoalsScreen({super.key});

  @override
  State<ManagerGoalsScreen> createState() => _ManagerGoalsScreenState();
}

class _ManagerGoalsScreenState extends State<ManagerGoalsScreen> {
  late final GoalsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GoalsController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VitaMateTheme.shellBackground,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  sliver: SliverList.list(
                    children: [
                      _TopBar(onReset: _resetAll),
                      const SizedBox(height: 14),
                      const Text(
                        'Tune daily targets without changing how VitaMate calculates recommendations.',
                        style: TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (_controller.isLoading && _controller.goals.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_controller.goals.isEmpty)
                        _EmptyState(
                          message:
                              _controller.error ?? 'Goals are unavailable.',
                          onRetry: _controller.load,
                        )
                      else
                        for (final goal in _controller.goals) ...[
                          GoalCard(
                            goal: goal,
                            onTap: () => _openGoalRoute(goal),
                            onEdit: () => _editGoal(goal),
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openGoalRoute(ManagerGoal goal) {
    if (goal.route.isEmpty) return;
    Navigator.pushNamed(context, goal.route);
  }

  Future<void> _editGoal(ManagerGoal goal) async {
    final controller = TextEditingController(
      text:
          goal.customValue?.toStringAsFixed(
            goal.customValue! % 1 == 0 ? 0 : 1,
          ) ??
          goal.effectiveValue.toStringAsFixed(
            goal.effectiveValue % 1 == 0 ? 0 : 1,
          ),
    );
    final result = await showModalBottomSheet<double?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit ${goal.label}',
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recommended: ${goal.recommendedValue.toStringAsFixed(goal.recommendedValue % 1 == 0 ? 0 : 1)} ${goal.unit}',
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Custom target',
                    suffixText: goal.unit,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: const Text('Use recommended'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          double.tryParse(controller.text.trim()),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (!mounted) return;
    final ok = await _controller.saveCustomGoal(goal.key, result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Goal updated.' : _controller.error ?? 'Failed.'),
      ),
    );
  }

  Future<void> _resetAll() async {
    final ok = await _controller.resetAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Goals reset to VitaMate recommendations.'
              : _controller.error ?? 'Failed.',
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        const Expanded(
          child: Text(
            'Goals',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(onPressed: onReset, child: const Text('Reset')),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(
              context,
              Routes.managerHealthProfile,
            ),
            child: const Text('Review health profile'),
          ),
        ],
      ),
    );
  }
}
