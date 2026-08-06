import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/vitamate_theme.dart';

class MedicationUi {
  static const Color background = Color(0xFFFFFCFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color panelTint = Color(0xFFFAF5FF);
  static const Color pending = Color(0xFFF19A2A);
  static const Color skipped = Color(0xFF7A4DF3);
  static const Color snoozed = Color(0xFF5368E8);
  static const Color successSoft = Color(0xFFEAF8F0);
  static const Color pendingSoft = Color(0xFFFFF5E7);
  static const Color dangerSoft = Color(0xFFFFEEF3);
  static const Color primarySoft = Color(0xFFF1EAFF);

  static bool isTaken(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'taken' ||
        normalized == 'taken_on_time' ||
        normalized == 'taken_late';
  }

  static bool isFinal(String status) {
    final normalized = status.toLowerCase();
    return isTaken(normalized) ||
        normalized == 'missed' ||
        normalized == 'skipped';
  }

  static bool isPendingLike(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'pending' ||
        normalized == 'snoozed' ||
        normalized == 'overdue';
  }

  static Color statusColor(String status) {
    final normalized = status.toLowerCase();
    return switch (normalized) {
      'taken' || 'taken_on_time' => VitaMateTheme.success,
      'taken_late' => pending,
      'missed' => VitaMateTheme.danger,
      'overdue' => pending,
      'skipped' => skipped,
      'snoozed' => snoozed,
      'pending' => pending,
      _ => VitaMateTheme.textMuted,
    };
  }

  static IconData statusIcon(String status) {
    final normalized = status.toLowerCase();
    return switch (normalized) {
      'taken' || 'taken_on_time' || 'taken_late' => Icons.check_rounded,
      'missed' => Icons.close_rounded,
      'overdue' => Icons.warning_amber_rounded,
      'skipped' => Icons.keyboard_double_arrow_right_rounded,
      'snoozed' => Icons.snooze_rounded,
      'pending' => Icons.notifications_active_outlined,
      _ => Icons.circle_outlined,
    };
  }

  static String statusLabel(String status) {
    final normalized = status.toLowerCase();
    return switch (normalized) {
      'taken' || 'taken_on_time' || 'taken_late' => 'Taken',
      'missed' => 'Missed',
      'overdue' => 'Late',
      'skipped' => 'Skipped',
      'snoozed' => 'Snoozed',
      'pending' => 'Pending',
      _ =>
        normalized.isEmpty
            ? 'Pending'
            : '${normalized[0].toUpperCase()}${normalized.substring(1).replaceAll('_', ' ')}',
    };
  }

  static String timeLabel(DateTime? value) {
    if (value == null) return '--:--';
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static String compactDate(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  static String historyDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final value = DateTime(parsed.year, parsed.month, parsed.day);
    if (value == today) {
      return 'Today, ${DateFormat('d MMMM').format(parsed)}';
    }
    if (value == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat('d MMMM').format(parsed)}';
    }
    return DateFormat('EEEE, d MMMM').format(parsed);
  }

  static String doseLine({
    required String doseAmount,
    required String doseUnit,
    required String form,
  }) {
    return [
      doseAmount,
      doseUnit,
      form,
    ].where((item) => item.trim().isNotEmpty).join(' ');
  }

  static String mealRelationLabel(String value) {
    return switch (value) {
      'after_meal' => 'After meal',
      'before_meal' => 'Before meal',
      'with_food' => 'With food',
      'empty_stomach' => 'Empty stomach',
      _ => 'With or without food',
    };
  }

  static String scheduleTypeTitle(String value) {
    return switch (value) {
      'specific_days' => 'Specific days',
      'interval' => 'Every N hours',
      'as_needed' => 'As needed',
      _ => 'Daily',
    };
  }

  static String scheduleTypeSubtitle(String value) {
    return switch (value) {
      'specific_days' => 'Choose days of the week',
      'interval' => 'Take every N hours',
      'as_needed' => 'Only when needed',
      _ => 'Take every day at set times',
    };
  }

  static IconData scheduleTypeIcon(String value) {
    return switch (value) {
      'specific_days' => Icons.calendar_month_rounded,
      'interval' => Icons.schedule_rounded,
      'as_needed' => Icons.back_hand_outlined,
      _ => Icons.wb_sunny_rounded,
    };
  }

  static Color scheduleTypeColor(String value) {
    return switch (value) {
      'specific_days' => VitaMateTheme.primary,
      'interval' => VitaMateTheme.primaryDeep,
      'as_needed' => VitaMateTheme.textMuted,
      _ => pending,
    };
  }
}

class MedicationSurfaceCard extends StatelessWidget {
  const MedicationSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.color = MedicationUi.card,
    this.borderColor = VitaMateTheme.border,
    this.shadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color borderColor;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: VitaMateTheme.shadow,
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}
