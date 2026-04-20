import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      appBar: AppBar(title: const Text('Habit Quit Tracker')),
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 3),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: const [
          _OverviewCard(),
          SizedBox(height: 14),
          _HabitGuideCard(
            icon: Icons.smoke_free_rounded,
            title: 'Quit harmful habits',
            body:
                'Track the habits you want to stop, watch your streaks, and keep your reasons visible when cravings show up.',
          ),
          SizedBox(height: 12),
          _HabitGuideCard(
            icon: Icons.calendar_month_rounded,
            title: 'Coming next',
            body:
                'This screen is ready for the dedicated quit-flow. Logging, streak history, reminders, and trigger notes will be wired here next.',
          ),
          SizedBox(height: 12),
          _HabitExamplesCard(),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF2E8FF), Color(0xFFFFEDF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.self_improvement_rounded,
              color: VitaMateTheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Build a cleaner routine',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use this section for quitting unhealthy habits such as smoking, late-night sugar, or anything else you want to leave behind step by step.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: VitaMateTheme.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitGuideCard extends StatelessWidget {
  const _HabitGuideCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _HabitSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: VitaMateTheme.softSurface,
              borderRadius: BorderRadius.circular(14),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: VitaMateTheme.primaryDeep,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: VitaMateTheme.textMuted,
                    height: 1.4,
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

class _HabitExamplesCard extends StatelessWidget {
  const _HabitExamplesCard();

  @override
  Widget build(BuildContext context) {
    const habits = [
      ('Smoking', Icons.smoking_rooms_rounded),
      ('Sugary drinks', Icons.local_drink_outlined),
      ('Late caffeine', Icons.coffee_rounded),
    ];

    return _HabitSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggested quit targets',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final habit in habits)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: VitaMateTheme.softSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(habit.$2, size: 18, color: VitaMateTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        habit.$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: VitaMateTheme.primaryDeep,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitSurface extends StatelessWidget {
  const _HabitSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
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
