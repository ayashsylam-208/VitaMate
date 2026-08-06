import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/manager_models.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, this.onTap, this.onEdit});

  final ManagerGoal goal;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: VitaMateTheme.border),
          boxShadow: const [
            BoxShadow(
              color: VitaMateTheme.shadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: VitaMateTheme.softSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _iconFor(goal.icon),
                    color: VitaMateTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.label,
                        style: const TextStyle(
                          color: VitaMateTheme.primaryDeep,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goal.sourceLabel,
                        style: const TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: goal.isComplete
                        ? VitaMateTheme.success.withValues(alpha: 0.12)
                        : VitaMateTheme.softSurface,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${goal.progressPercent}%',
                    style: TextStyle(
                      color: goal.isComplete
                          ? VitaMateTheme.success
                          : VitaMateTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.progressLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(onPressed: onEdit, child: const Text('Edit')),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: goal.progressPercent / 100,
                minHeight: 9,
                backgroundColor: VitaMateTheme.softSurface,
                color: goal.isComplete
                    ? VitaMateTheme.success
                    : VitaMateTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String icon) {
    switch (icon) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'directions_walk':
        return Icons.directions_walk_rounded;
      case 'timer':
        return Icons.timer_rounded;
      case 'bedtime':
        return Icons.bedtime_rounded;
      case 'monitor_weight':
        return Icons.monitor_weight_rounded;
      case 'check_circle':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.flag_rounded;
    }
  }
}
