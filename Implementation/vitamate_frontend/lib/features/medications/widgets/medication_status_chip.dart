import 'package:flutter/material.dart';

import 'medication_ui.dart';

class MedicationStatusChip extends StatelessWidget {
  const MedicationStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = MedicationUi.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MedicationUi.statusIcon(status), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            MedicationUi.statusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
