import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/manager_models.dart';

class MotivationSummaryCard extends StatelessWidget {
  const MotivationSummaryCard({super.key, required this.motivation});

  final ManagerMotivation motivation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryBlock(
            icon: Icons.bolt_rounded,
            label: "Today's points",
            value: '+${motivation.dailyPoints}',
            color: VitaMateTheme.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryBlock(
            icon: Icons.local_fire_department_rounded,
            label: 'Streak',
            value: '${motivation.currentStreak} days',
            color: VitaMateTheme.danger,
          ),
        ),
      ],
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
