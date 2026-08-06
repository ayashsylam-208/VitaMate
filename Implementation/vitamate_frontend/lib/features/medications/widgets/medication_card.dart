import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/medication_item.dart';

class MedicationCard extends StatelessWidget {
  const MedicationCard({
    super.key,
    required this.medication,
    required this.onTap,
  });

  final MedicationItem medication;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final adherence = medication.adherenceSummaryShort.adherencePercent;
    final accent = medication.isPrn
        ? VitaMateTheme.accent
        : medication.linkedConditionName != null
        ? VitaMateTheme.success
        : VitaMateTheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: VitaMateTheme.border),
          boxShadow: const [
            BoxShadow(
              color: VitaMateTheme.shadow,
              blurRadius: 16,
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
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    medication.isPrn
                        ? Icons.medication_outlined
                        : Icons.medication_liquid_rounded,
                    color: accent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.displayName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: VitaMateTheme.primaryDeep,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medication.doseLabel.isEmpty
                            ? 'Dose details not set yet'
                            : medication.doseLabel,
                        style: const TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: VitaMateTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${adherence.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: VitaMateTheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      medication.nextDue == null
                          ? 'No dose due'
                          : 'Next ${_timeLabel(medication.nextDue!)}',
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(
                  label: medication.isPrn ? 'As needed' : _scheduleSummary(),
                  color: accent,
                ),
                if (medication.linkedConditionName != null)
                  _Badge(
                    label: medication.linkedConditionName!,
                    color: VitaMateTheme.success,
                  ),
                if (medication.instructions.trim().isNotEmpty)
                  _Badge(
                    label: medication.instructions.trim(),
                    color: VitaMateTheme.primaryDeep,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _scheduleSummary() {
    if (medication.schedules.isEmpty) {
      return 'No reminder times';
    }
    final labels = medication.schedules
        .take(2)
        .map((schedule) => _formatTimeText(schedule.time))
        .where((text) => text.isNotEmpty)
        .toList();
    if (labels.isEmpty) {
      return 'Reminder plan ready';
    }
    final extra = medication.schedules.length > 2
        ? ' +${medication.schedules.length - 2}'
        : '';
    return '${labels.join(' | ')}$extra';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

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

String _timeLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _formatTimeText(String value) {
  final parts = value.split(':');
  if (parts.length < 2) {
    return value;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return value;
  }
  final normalizedHour = hour.toString().padLeft(2, '0');
  final normalizedMinute = minute.toString().padLeft(2, '0');
  return '$normalizedHour:$normalizedMinute';
}
