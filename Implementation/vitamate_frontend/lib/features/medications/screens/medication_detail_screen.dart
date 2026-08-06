import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/medication_item.dart';
import '../state/medications_controller.dart';
import '../widgets/medication_schedule_type_card.dart';
import '../widgets/medication_ui.dart';
import 'add_edit_medication_screen.dart';
import 'medication_adherence_screen.dart';
import 'medication_dose_logged_success_screen.dart';
import 'medication_history_screen.dart';
import 'medication_today_plan_screen.dart';

class MedicationDetailScreen extends StatefulWidget {
  const MedicationDetailScreen({
    super.key,
    required this.controller,
    required this.medicationId,
  });

  final MedicationsController controller;
  final int medicationId;

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _openEdit(MedicationItem medication) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditMedicationScreen(
          controller: widget.controller,
          medication: medication,
        ),
      ),
    );
  }

  Future<void> _logPrnDose(int medicationId) async {
    final ok = await widget.controller.logPrnDose(medicationId);
    if (!ok || !mounted) return;
    await widget.controller.refreshAll();
    if (!mounted) return;
    final dose = widget.controller.state.lastDoseAction;
    if (dose == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationDoseLoggedSuccessScreen(
          dose: dose,
          daySummary: widget.controller.state.todayAdherence,
          nextDose: widget.controller.state.nextDose,
          streak: widget.controller.state.streak,
        ),
      ),
    );
  }

  Future<void> _removeMedication(MedicationItem medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove medication?'),
        content: const Text(
          'Future reminders will stop, but historical dose logs are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: VitaMateTheme.danger,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await widget.controller.deactivateMedication(medication.id);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final medication = widget.controller.medicationById(widget.medicationId);
    if (medication == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: MedicationUi.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          children: [
            _MedicationDetailHeader(
              medication: medication,
              onEdit: () => _openEdit(medication),
              onRemove: () => _removeMedication(medication),
            ),
            if (medication.isPrn) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: widget.controller.state.isSaving
                      ? null
                      : () => _logPrnDose(medication.id),
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Log dose now'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            MedicationSurfaceCard(
              padding: EdgeInsets.zero,
              radius: 17,
              child: Column(
                children: [
                  _DetailActionRow(
                    icon: Icons.info_outline_rounded,
                    title: 'About this medication',
                    subtitle: 'Purpose, notes, important info',
                    onTap: () => _showAboutSheet(medication),
                  ),
                  const _RowDivider(),
                  _DetailActionRow(
                    icon: Icons.calendar_month_rounded,
                    title: 'Schedule',
                    subtitle: _scheduleSummary(medication),
                    onTap: () => _showScheduleSheet(medication),
                  ),
                  const _RowDivider(),
                  _DetailActionRow(
                    icon: Icons.schedule_rounded,
                    title: 'Today plan',
                    subtitle: "See today's doses and status",
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MedicationTodayPlanScreen(
                          controller: widget.controller,
                        ),
                      ),
                    ),
                  ),
                  const _RowDivider(),
                  _DetailActionRow(
                    icon: Icons.history_rounded,
                    title: 'History',
                    subtitle: 'All doses and actions',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MedicationHistoryScreen(
                          controller: widget.controller,
                        ),
                      ),
                    ),
                  ),
                  const _RowDivider(),
                  _DetailActionRow(
                    icon: Icons.track_changes_rounded,
                    title: 'Adherence',
                    subtitle: 'Your adherence insights',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MedicationAdherenceScreen(
                          controller: widget.controller,
                          medicationId: medication.id,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            InkWell(
              onTap: () => _removeMedication(medication),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: VitaMateTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: VitaMateTheme.danger,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Remove medication',
                      style: TextStyle(
                        color: VitaMateTheme.danger,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutSheet(MedicationItem medication) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailBottomSheet(
        title: 'About this medication',
        children: [
          _SheetLine(label: 'Name', value: medication.displayName),
          _SheetLine(label: 'Dose', value: medication.doseLabel),
          if (medication.instructions.trim().isNotEmpty)
            _SheetLine(label: 'Instructions', value: medication.instructions),
          if (medication.linkedConditionName != null)
            _SheetLine(
              label: 'Linked condition',
              value: medication.linkedConditionName!,
            ),
        ],
      ),
    );
  }

  void _showScheduleSheet(MedicationItem medication) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailBottomSheet(
        title: 'Schedule',
        children: [
          if (medication.isPrn || medication.schedules.isEmpty)
            const Text(
              'As needed. No fixed pending doses are generated.',
              style: TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            for (final schedule in medication.schedules) ...[
              MedicationScheduleTypeCard(schedule: schedule),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _MedicationDetailHeader extends StatelessWidget {
  const _MedicationDetailHeader({
    required this.medication,
    required this.onEdit,
    required this.onRemove,
  });

  final MedicationItem medication;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9), Color(0xFFA855F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x333B1386),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: VitaMateTheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  medication.doseLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _headerPurpose(medication),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    visualDensity: VisualDensity.compact,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                    ),
                    onSelected: (value) {
                      if (value == 'remove') onRemove();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: medication.isActive
                      ? VitaMateTheme.success.withValues(alpha: 0.92)
                      : VitaMateTheme.textMuted.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  medication.isActive ? 'Active' : 'Inactive',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailActionRow extends StatelessWidget {
  const _DetailActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: VitaMateTheme.primary, size: 27),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: VitaMateTheme.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 57,
      endIndent: 16,
      color: VitaMateTheme.border,
    );
  }
}

class _DetailBottomSheet extends StatelessWidget {
  const _DetailBottomSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      decoration: const BoxDecoration(
        color: MedicationUi.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SheetLine extends StatelessWidget {
  const _SheetLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _headerPurpose(MedicationItem medication) {
  if (medication.instructions.trim().isNotEmpty) {
    return medication.instructions.trim();
  }
  if (medication.linkedConditionName != null) {
    return 'For ${medication.linkedConditionName}';
  }
  return medication.isPrn ? 'Take when needed' : 'Medication plan';
}

String _scheduleSummary(MedicationItem medication) {
  if (medication.isPrn) return 'As needed';
  if (medication.schedules.isEmpty) return 'No schedule';
  final first = medication.schedules.first;
  final times = medication.schedules
      .map((schedule) => _formatScheduleTime(schedule.time))
      .where((value) => value.isNotEmpty)
      .take(3)
      .join(', ');
  return switch (first.scheduleType) {
    'specific_days' => '${_dayLabels(first.daysOfWeek).join(', ')} • $times',
    'interval' => 'Every ${first.intervalHours ?? 0} hours • $times',
    _ => 'Every day • $times',
  };
}

String _formatScheduleTime(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return value;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return value;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

List<String> _dayLabels(List<int> days) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days
      .where((day) => day >= 0 && day < labels.length)
      .map((day) => labels[day])
      .toList(growable: false);
}
