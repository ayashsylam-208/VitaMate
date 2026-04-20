import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/medication_dose_log.dart';

class TodayDoseTile extends StatelessWidget {
  const TodayDoseTile({
    super.key,
    required this.dose,
    required this.onTaken,
    required this.onMissed,
    required this.onSkipped,
    required this.onSnooze,
  });

  final MedicationDoseLog dose;
  final VoidCallback onTaken;
  final VoidCallback onMissed;
  final VoidCallback onSkipped;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    final isFinal = {'taken', 'missed', 'skipped'}.contains(dose.status);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: VitaMateTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dose.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusChip(status: dose.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_timeLabel(dose.scheduledFor)}  ${dose.doseLabel}',
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (dose.linkedConditionName != null) ...[
            const SizedBox(height: 4),
            Text(
              dose.linkedConditionName!,
              style: const TextStyle(
                color: VitaMateTheme.success,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (!isFinal) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onTaken,
                    child: const Text('Taken'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onSnooze,
                  icon: const Icon(Icons.snooze_rounded),
                ),
                IconButton(
                  onPressed: onMissed,
                  icon: const Icon(Icons.close_rounded),
                ),
                IconButton(
                  onPressed: onSkipped,
                  icon: const Icon(Icons.pause_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'taken' => VitaMateTheme.success,
      'missed' => VitaMateTheme.danger,
      'skipped' => VitaMateTheme.warning,
      'snoozed' => VitaMateTheme.primary,
      'overdue' => VitaMateTheme.danger,
      _ => VitaMateTheme.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _timeLabel(DateTime? value) {
  if (value == null) return '--:--';
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
