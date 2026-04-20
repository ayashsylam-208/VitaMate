import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/medication_adherence_summary.dart';

class MedicationAdherenceCard extends StatelessWidget {
  const MedicationAdherenceCard({super.key, required this.summary});

  final MedicationAdherenceSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VitaMateTheme.surface,
        borderRadius: BorderRadius.circular(8),
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
              const Expanded(
                child: Text(
                  'Medication adherence',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: VitaMateTheme.softSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${summary.adherencePercent.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: VitaMateTheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: (summary.adherencePercent / 100).clamp(0, 1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(8),
            color: VitaMateTheme.primary,
            backgroundColor: VitaMateTheme.softSurface,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: '${summary.expectedDoses} expected'),
              _Pill(label: '${summary.takenDoses} taken'),
              _Pill(label: '${summary.pendingDoses} pending'),
              _Pill(label: '${summary.missedDoses} missed'),
              _Pill(label: '${summary.streakDays} day streak'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: VitaMateTheme.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
