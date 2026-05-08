import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/medication_adherence_summary.dart';

class MedicationAdherenceCard extends StatelessWidget {
  const MedicationAdherenceCard({
    super.key,
    required this.summary,
    this.plannedToday = 0,
  });

  final MedicationAdherenceSummary summary;
  final int plannedToday;

  @override
  Widget build(BuildContext context) {
    final progress = (summary.adherencePercent / 100).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
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
                      'Adherence details',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: VitaMateTheme.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      summary.overdueDoses > 0
                          ? '${summary.overdueDoses} overdue doses are dragging your score down.'
                          : plannedToday > 0
                          ? 'You have $plannedToday dose events planned today.'
                          : 'No doses planned yet today.',
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        color: VitaMateTheme.primary,
                        backgroundColor: VitaMateTheme.softSurface,
                      ),
                    ),
                    Text(
                      '${summary.adherencePercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                label: '${summary.expectedDoses} expected',
                color: VitaMateTheme.primaryDeep,
              ),
              _Pill(
                label: '${summary.takenDoses} taken',
                color: VitaMateTheme.success,
              ),
              _Pill(
                label: '${summary.pendingDoses} pending',
                color: VitaMateTheme.warning,
              ),
              _Pill(
                label: '${summary.missedDoses} missed',
                color: VitaMateTheme.danger,
              ),
              _Pill(
                label: '${summary.streakDays} day streak',
                color: VitaMateTheme.primary,
              ),
              _Pill(
                label: '${summary.onTimePercent.toStringAsFixed(0)}% on time',
                color: VitaMateTheme.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

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
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
