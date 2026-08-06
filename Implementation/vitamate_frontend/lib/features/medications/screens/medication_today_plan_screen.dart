import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../models/medication_dose_log.dart';
import '../models/medication_today_plan.dart';
import '../state/medications_controller.dart';
import '../widgets/medication_ui.dart';
import '../widgets/today_dose_tile.dart';
import 'medication_dose_logged_success_screen.dart';

class MedicationTodayPlanScreen extends StatefulWidget {
  const MedicationTodayPlanScreen({super.key, required this.controller});

  final MedicationsController controller;

  @override
  State<MedicationTodayPlanScreen> createState() =>
      _MedicationTodayPlanScreenState();
}

class _MedicationTodayPlanScreenState extends State<MedicationTodayPlanScreen> {
  String _filter = 'all';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.loadTodayPlan(date: _dateQuery);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  String get _dateQuery => DateFormat('yyyy-MM-dd').format(_selectedDate);

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    await widget.controller.loadTodayPlan(date: _dateQuery);
  }

  List<MedicationDoseLog> _visibleDoses(List<MedicationDoseLog> doses) {
    if (_filter == 'all') return doses;
    return doses
        .where((dose) {
          final status = dose.rawStatus.toLowerCase();
          return switch (_filter) {
            'taken' => MedicationUi.isTaken(status),
            'pending' => MedicationUi.isPendingLike(status),
            'missed' => status == 'missed' || status == 'overdue',
            _ => status == _filter,
          };
        })
        .toList(growable: false);
  }

  Future<void> _markTaken(MedicationDoseLog dose) async {
    final ok = await widget.controller.markDoseTaken(dose.logId);
    if (!ok || !mounted) return;
    await widget.controller.refreshAll();
    if (!mounted) return;
    final logged = widget.controller.state.lastDoseAction ?? dose;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationDoseLoggedSuccessScreen(
          dose: logged,
          daySummary: widget.controller.state.todayAdherence,
          nextDose: widget.controller.state.nextDose,
          streak: widget.controller.state.streak,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final summary = state.todayAdherence;
    final doses = _visibleDoses(widget.controller.todayPlan);
    final upcoming = doses
        .where((dose) => MedicationUi.isPendingLike(dose.rawStatus))
        .toList(growable: false);
    final completed = doses
        .where((dose) => MedicationUi.isFinal(dose.rawStatus))
        .toList(growable: false);

    return Scaffold(
      key: const ValueKey(AppTestKeys.medicationsTodayScreen),
      backgroundColor: MedicationUi.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => widget.controller.loadTodayPlan(date: _dateQuery),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _PlanHeader(onCalendar: _pickDate),
              const SizedBox(height: 18),
              _DateAndFilterRow(
                date: _selectedDate,
                onDateTap: _pickDate,
                onFilterTap: () {},
              ),
              const SizedBox(height: 12),
              _FilterChips(
                selected: _filter,
                summary: summary,
                total: summary.expected == 0
                    ? widget.controller.todayPlan.length
                    : summary.expected,
                onSelected: (value) => setState(() => _filter = value),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 14),
                _InlineError(text: state.errorMessage!),
              ],
              const SizedBox(height: 18),
              if (state.isLoading && widget.controller.todayPlan.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (doses.isEmpty)
                const _EmptyDayCard()
              else ...[
                if (upcoming.isNotEmpty) ...[
                  const _SectionTitle('Upcoming'),
                  const SizedBox(height: 10),
                  for (final dose in upcoming) ...[
                    TodayDoseTile(
                      dose: dose,
                      onTaken: () => _markTaken(dose),
                      onSkipped: () => widget.controller.markDoseSkipped(
                        dose.logId,
                        reason: 'Skipped from VitaMate',
                      ),
                      onSnooze: () => widget.controller.snoozeDose(
                        dose.logId,
                        DateTime.now().add(const Duration(minutes: 15)),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
                if (completed.isNotEmpty) ...[
                  const _SectionTitle('Completed'),
                  const SizedBox(height: 10),
                  for (final dose in completed) ...[
                    TodayDoseTile(
                      dose: dose,
                      compact: true,
                      onTaken: () => _markTaken(dose),
                      onSkipped: () => widget.controller.markDoseSkipped(
                        dose.logId,
                        reason: 'Skipped from VitaMate',
                      ),
                      onSnooze: () => widget.controller.snoozeDose(
                        dose.logId,
                        DateTime.now().add(const Duration(minutes: 15)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
              const SizedBox(height: 4),
              _TodaySummaryStrip(summary: summary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.onCalendar});

  final VoidCallback onCalendar;

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
            'Today plan',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: onCalendar,
          icon: const Icon(Icons.calendar_month_outlined),
          color: VitaMateTheme.primaryDeep,
        ),
      ],
    );
  }
}

class _DateAndFilterRow extends StatelessWidget {
  const _DateAndFilterRow({
    required this.date,
    required this.onDateTap,
    required this.onFilterTap,
  });

  final DateTime date;
  final VoidCallback onDateTap;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onDateTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(
                  _dateLabel(date),
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: VitaMateTheme.primaryDeep,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        IconButton.filledTonal(
          onPressed: onFilterTap,
          icon: const Icon(Icons.tune_rounded, size: 18),
          color: VitaMateTheme.primaryDeep,
          style: IconButton.styleFrom(
            backgroundColor: MedicationUi.card,
            minimumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);
    final prefix = selected == today ? 'Today' : DateFormat('EEE').format(date);
    return '$prefix, ${DateFormat('d MMMM').format(date)}';
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.summary,
    required this.total,
    required this.onSelected,
  });

  final String selected;
  final MedicationTodaySummary summary;
  final int total;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _FilterSpec('all', 'All', total, VitaMateTheme.primary),
      _FilterSpec('taken', 'Taken', summary.taken, VitaMateTheme.success),
      _FilterSpec('pending', 'Pending', summary.pending, MedicationUi.pending),
      _FilterSpec(
        'missed',
        'Missed',
        summary.missed + summary.overdue,
        VitaMateTheme.danger,
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final row in rows) ...[
            _FilterChipButton(
              spec: row,
              selected: selected == row.value,
              onTap: () => onSelected(row.value),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterSpec {
  const _FilterSpec(this.value, this.label, this.count, this.color);

  final String value;
  final String label;
  final int count;
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? spec.color : spec.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          '${spec.label} ${spec.count}',
          style: TextStyle(
            color: selected ? Colors.white : spec.color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: VitaMateTheme.primaryDeep,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _TodaySummaryStrip extends StatelessWidget {
  const _TodaySummaryStrip({required this.summary});

  final MedicationTodaySummary summary;

  @override
  Widget build(BuildContext context) {
    return MedicationSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today summary',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryPill(
                  label: '${summary.taken} Taken',
                  color: VitaMateTheme.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryPill(
                  label: '${summary.pending} Pending',
                  color: MedicationUi.pending,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryPill(
                  label: '${summary.missed + summary.overdue} Missed',
                  color: VitaMateTheme.danger,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: VitaMateTheme.textMuted,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard();

  @override
  Widget build(BuildContext context) {
    return const MedicationSurfaceCard(
      padding: EdgeInsets.all(18),
      radius: 18,
      child: Text(
        'No doses match this view.',
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
