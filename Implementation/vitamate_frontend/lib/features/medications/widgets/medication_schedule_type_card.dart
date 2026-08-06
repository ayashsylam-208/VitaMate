import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/medication_schedule.dart';

class MedicationScheduleTypeCard extends StatelessWidget {
  const MedicationScheduleTypeCard({super.key, required this.schedule});

  final MedicationSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final accent = _accent(schedule.scheduleType);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_icon(schedule.scheduleType), color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(schedule.scheduleType),
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle(schedule),
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _accent(String type) {
    return switch (type) {
      'interval' => VitaMateTheme.accent,
      'specific_days' => VitaMateTheme.success,
      'as_needed' => VitaMateTheme.warning,
      _ => VitaMateTheme.primary,
    };
  }

  IconData _icon(String type) {
    return switch (type) {
      'interval' => Icons.repeat_rounded,
      'specific_days' => Icons.calendar_month_rounded,
      'as_needed' => Icons.bolt_rounded,
      _ => Icons.schedule_rounded,
    };
  }

  String _title(String type) {
    return switch (type) {
      'interval' => 'Interval schedule',
      'specific_days' => 'Specific days',
      'as_needed' => 'As needed',
      _ => 'Daily schedule',
    };
  }

  String _subtitle(MedicationSchedule schedule) {
    if (schedule.scheduleType == 'interval' && schedule.intervalHours != null) {
      return 'Every ${schedule.intervalHours} hours from ${schedule.time}';
    }
    if (schedule.scheduleType == 'specific_days' &&
        schedule.daysOfWeek.isNotEmpty) {
      return '${_dayLabels(schedule.daysOfWeek).join(', ')} at ${schedule.time}';
    }
    if (schedule.scheduleType == 'as_needed') {
      return 'Logged manually only when taken';
    }
    final relation = schedule.mealRelation == 'none'
        ? ''
        : ' - ${schedule.mealRelation.replaceAll('_', ' ')}';
    return '${schedule.time}$relation';
  }

  List<String> _dayLabels(List<int> days) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days
        .where((day) => day >= 0 && day < labels.length)
        .map((day) => labels[day])
        .toList(growable: false);
  }
}
