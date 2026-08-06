import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/medication_dose_log.dart';
import '../models/medication_history.dart';
import '../state/medications_controller.dart';
import '../widgets/medication_status_chip.dart';
import '../widgets/medication_ui.dart';

class MedicationHistoryScreen extends StatefulWidget {
  const MedicationHistoryScreen({super.key, required this.controller});

  final MedicationsController controller;

  @override
  State<MedicationHistoryScreen> createState() =>
      _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<MedicationHistoryScreen> {
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.loadHistory(status: _status);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _setStatus(String value) {
    if (_status == value) return;
    setState(() => _status = value);
    widget.controller.loadHistory(status: value);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final history = state.history;
    return Scaffold(
      backgroundColor: MedicationUi.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => widget.controller.loadHistory(status: _status),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const _HistoryHeader(),
              const SizedBox(height: 18),
              _FilterRow(selected: _status, onSelected: _setStatus),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 14),
                _InlineError(text: state.errorMessage!),
              ],
              const SizedBox(height: 18),
              if (state.isLoading && history.groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 110),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (history.groups.isEmpty)
                const _EmptyHistoryCard()
              else
                for (final group in history.groups) ...[
                  _DateHeader(date: group.date),
                  const SizedBox(height: 9),
                  _HistoryGroupCard(group: group),
                  const SizedBox(height: 18),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: VitaMateTheme.primaryDeep,
        ),
        const Expanded(
          child: Text(
            'History',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.calendar_month_outlined),
          color: VitaMateTheme.primaryDeep,
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const filters = [
      _FilterSpec('all', 'All', VitaMateTheme.primary),
      _FilterSpec('taken', 'Taken', VitaMateTheme.success),
      _FilterSpec('missed', 'Missed', VitaMateTheme.danger),
      _FilterSpec('skipped', 'Skipped', MedicationUi.skipped),
      _FilterSpec('snoozed', 'Snoozed', MedicationUi.snoozed),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            _FilterChipButton(
              spec: filter,
              selected: selected == filter.value,
              onTap: () => onSelected(filter.value),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterSpec {
  const _FilterSpec(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _FilterSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? spec.color : spec.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          spec.label,
          style: TextStyle(
            color: selected ? Colors.white : spec.color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return Text(
      MedicationUi.historyDate(date),
      style: const TextStyle(
        color: VitaMateTheme.primaryDeep,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _HistoryGroupCard extends StatelessWidget {
  const _HistoryGroupCard({required this.group});

  final MedicationHistoryGroup group;

  @override
  Widget build(BuildContext context) {
    return MedicationSurfaceCard(
      padding: EdgeInsets.zero,
      radius: 16,
      child: Column(
        children: [
          for (var i = 0; i < group.items.length; i++) ...[
            _HistoryDoseRow(item: group.items[i]),
            if (i != group.items.length - 1)
              const Divider(
                height: 1,
                indent: 64,
                endIndent: 14,
                color: VitaMateTheme.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _HistoryDoseRow extends StatelessWidget {
  const _HistoryDoseRow({required this.item});

  final MedicationDoseLog item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDoseDetails(context, item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Text(
                item.isPrn ? 'Now' : MedicationUi.timeLabel(item.scheduledFor),
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.doseLabel,
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.takenAt != null) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: VitaMateTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Taken at ${MedicationUi.timeLabel(item.takenAt)}',
                          style: const TextStyle(
                            color: VitaMateTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ] else if (item.snoozedUntil != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Snoozed until ${MedicationUi.timeLabel(item.snoozedUntil)}',
                      style: const TextStyle(
                        color: MedicationUi.snoozed,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MedicationStatusChip(status: item.rawStatus),
                if (item.pointsApplied != 0) ...[
                  const SizedBox(height: 14),
                  Text(
                    '${item.pointsApplied > 0 ? '+' : ''}${item.pointsApplied} pts',
                    style: TextStyle(
                      color: item.pointsApplied > 0
                          ? VitaMateTheme.primary
                          : VitaMateTheme.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDoseDetails(BuildContext context, MedicationDoseLog item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
                item.displayName,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              _SheetLine(
                label: 'Scheduled',
                value: MedicationUi.timeLabel(item.scheduledFor),
              ),
              if (item.takenAt != null)
                _SheetLine(
                  label: 'Taken',
                  value: MedicationUi.timeLabel(item.takenAt),
                ),
              if (item.snoozedUntil != null)
                _SheetLine(
                  label: 'Snoozed until',
                  value: MedicationUi.timeLabel(item.snoozedUntil),
                ),
              _SheetLine(
                label: 'Status',
                value: MedicationUi.statusLabel(item.rawStatus),
              ),
              if (item.notes.trim().isNotEmpty)
                _SheetLine(label: 'Notes', value: item.notes.trim()),
            ],
          ),
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
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

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return const MedicationSurfaceCard(
      padding: EdgeInsets.all(18),
      radius: 18,
      child: Text(
        'No dose history for this filter.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: VitaMateTheme.textMuted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.danger.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: VitaMateTheme.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
