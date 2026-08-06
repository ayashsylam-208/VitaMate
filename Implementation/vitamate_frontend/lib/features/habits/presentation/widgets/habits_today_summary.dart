import 'package:flutter/material.dart';

import '../../../../core/theme/vitamate_theme.dart';
import '../mappers/habit_ui_mapper.dart';

class HabitsTodaySummary extends StatelessWidget {
  const HabitsTodaySummary({super.key, required this.summary});

  final HabitsTodaySummaryViewModel summary;

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
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: summary.toneColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.today_rounded,
              color: summary.toneColor,
              semanticLabel: 'Today status',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.subtitle,
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
    );
  }
}
