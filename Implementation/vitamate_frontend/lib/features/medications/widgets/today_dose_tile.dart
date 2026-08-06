import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/medication_dose_log.dart';
import 'medication_status_chip.dart';
import 'medication_ui.dart';

class TodayDoseTile extends StatelessWidget {
  const TodayDoseTile({
    super.key,
    required this.dose,
    required this.onTaken,
    required this.onSkipped,
    required this.onSnooze,
    this.onMissed,
    this.compact = false,
  });

  final MedicationDoseLog dose;
  final VoidCallback onTaken;
  final VoidCallback onSkipped;
  final VoidCallback onSnooze;
  final VoidCallback? onMissed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isFinal = MedicationUi.isFinal(dose.rawStatus);
    final isOverdue = dose.rawStatus.toLowerCase() == 'overdue';
    final statusColor = MedicationUi.statusColor(dose.rawStatus);
    return MedicationSurfaceCard(
      padding: EdgeInsets.fromLTRB(16, compact ? 14 : 16, 16, 14),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dose.isPrn ? 'Now' : MedicationUi.timeLabel(dose.scheduledFor),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              MedicationStatusChip(status: dose.rawStatus),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            dose.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dose.doseLabel.isEmpty ? 'Dose details not set' : dose.doseLabel,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            MedicationUi.mealRelationLabel(dose.mealRelation),
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (dose.snoozedUntil != null && !isFinal) ...[
            const SizedBox(height: 7),
            Text(
              'Snoozed until ${MedicationUi.timeLabel(dose.snoozedUntil)}',
              style: const TextStyle(
                color: MedicationUi.snoozed,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (dose.takenAt != null) ...[
            const SizedBox(height: 7),
            Text(
              'Taken at ${MedicationUi.timeLabel(dose.takenAt)}',
              style: const TextStyle(
                color: VitaMateTheme.success,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (!isFinal) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: VitaMateTheme.border),
            SizedBox(
              height: 72,
              child: Row(
                children: [
                  Expanded(
                    child: _DoseAction(
                      icon: Icons.check_circle_rounded,
                      label: isOverdue ? 'Take\nlate' : 'Take',
                      color: VitaMateTheme.primary,
                      onTap: onTaken,
                    ),
                  ),
                  const _VerticalDivider(),
                  Expanded(
                    child: _DoseAction(
                      icon: Icons.snooze_rounded,
                      label: 'Snooze\n15 min',
                      color: VitaMateTheme.primaryDeep,
                      onTap: onSnooze,
                    ),
                  ),
                  const _VerticalDivider(),
                  Expanded(
                    child: _DoseAction(
                      icon: Icons.close_rounded,
                      label: 'Skip',
                      color: VitaMateTheme.primaryDeep,
                      onTap: onSkipped,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (MedicationUi.isTaken(dose.rawStatus)) ...[
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.check_rounded,
                color: VitaMateTheme.primaryDeep,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DoseAction extends StatelessWidget {
  const _DoseAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: VitaMateTheme.border);
  }
}
