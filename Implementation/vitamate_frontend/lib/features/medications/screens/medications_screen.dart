import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/routing/vitamate_route_observer.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../models/medication_dose_log.dart';
import '../models/medication_item.dart';
import '../models/medication_today_plan.dart';
import '../state/medications_controller.dart';
import '../widgets/empty_medications_state.dart';
import '../widgets/medication_adherence_card.dart';
import '../widgets/medication_card.dart';
import '../widgets/medication_ui.dart';
import 'add_edit_medication_screen.dart';
import 'medication_detail_screen.dart';
import 'medication_history_screen.dart';
import 'medication_today_plan_screen.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key, this.controller, this.autoLoad = true});

  final MedicationsController? controller;
  final bool autoLoad;

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> with RouteAware {
  late final MedicationsController controller;
  PageRoute<dynamic>? _subscribedRoute;
  bool _routeVisible = true;
  bool _refreshWhenVisible = false;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? MedicationsController();
    controller.addListener(_onChanged);
    HealthSyncBus.instance.addListener(_handleTrackerRefresh);
    if (widget.autoLoad) {
      unawaited(controller.refreshAll());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    _routeVisible = route?.isCurrent ?? true;
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        vitaMateRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      vitaMateRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    HealthSyncBus.instance.removeListener(_handleTrackerRefresh);
    vitaMateRouteObserver.unsubscribe(this);
    controller.removeListener(_onChanged);
    if (widget.controller == null) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTrackerRefresh() {
    if (!HealthSyncBus.instance.affects(const {HealthSyncScope.medication})) {
      return;
    }
    if (!_isRouteVisible()) {
      _refreshWhenVisible = true;
      return;
    }
    unawaited(controller.refreshAll());
  }

  bool _isRouteVisible() {
    return mounted &&
        (_routeVisible || (ModalRoute.of(context)?.isCurrent ?? false));
  }

  @override
  void didPush() {
    _routeVisible = true;
  }

  @override
  void didPushNext() {
    _routeVisible = false;
  }

  @override
  void didPop() {
    _routeVisible = false;
  }

  @override
  void didPopNext() {
    _routeVisible = true;
    if (!_refreshWhenVisible) {
      return;
    }
    _refreshWhenVisible = false;
    unawaited(controller.refreshAll());
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditMedicationScreen(controller: controller),
      ),
    );
  }

  void _openMedication(MedicationItem medication) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationDetailScreen(
          controller: controller,
          medicationId: medication.id,
        ),
      ),
    );
  }

  void _openToday() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationTodayPlanScreen(controller: controller),
      ),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationHistoryScreen(controller: controller),
      ),
    );
  }

  void _openAllMedications() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AllMedicationsSheet(
        medications: controller.state.medications,
        onOpen: (medication) {
          Navigator.of(sheetContext).pop();
          _openMedication(medication);
        },
      ),
    );
  }

  void _openInsights() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _InsightsSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final today = state.todayAdherence;
    final plannedToday = today.expected == 0
        ? state.todayPlan.length
        : today.expected;
    final canShowMotivation =
        state.motivationStrip != null &&
        today.missed == 0 &&
        today.overdue == 0;

    return Scaffold(
      backgroundColor: MedicationUi.background,
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 2),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refreshAll,
          child: ListView(
            key: const ValueKey(AppTestKeys.medicationsScreen),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
            children: [
              const _MedicationHeader(),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 14),
                _InlineMessage(
                  text: state.errorMessage!,
                  tone: _InlineTone.error,
                ),
              ],
              if (state.successMessage != null) ...[
                const SizedBox(height: 14),
                _InlineMessage(
                  text: state.successMessage!,
                  tone: _InlineTone.success,
                ),
              ],
              const SizedBox(height: 18),
              if (state.isLoading && state.medications.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.medications.isEmpty) ...[
                EmptyMedicationsState(onAdd: _openAdd),
              ] else ...[
                _TodayAdherenceCard(summary: today, plannedToday: plannedToday),
                const SizedBox(height: 14),
                _MedicationShortcutRow(
                  onToday: _openToday,
                  onAllMedications: _openAllMedications,
                  onHistory: _openHistory,
                  onInsights: _openInsights,
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Upcoming next'),
                const SizedBox(height: 10),
                _UpcomingNextCard(dose: state.nextDose, onTap: _openToday),
                if (canShowMotivation) ...[
                  const SizedBox(height: 14),
                  _MedicationMotivationStrip(
                    data: state.motivationStrip!,
                    streak: state.streak,
                  ),
                ],
                const SizedBox(height: 26),
                _AddMedicationCta(onPressed: _openAdd),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicationHeader extends StatelessWidget {
  const _MedicationHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Medication',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: VitaMateTheme.primaryDeep,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Track your meds, stay on track, feel better.',
                style: TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
              color: VitaMateTheme.primaryDeep,
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: VitaMateTheme.danger,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '2',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayAdherenceCard extends StatelessWidget {
  const _TodayAdherenceCard({
    required this.summary,
    required this.plannedToday,
  });

  final MedicationTodaySummary summary;
  final int plannedToday;

  @override
  Widget build(BuildContext context) {
    final completed = summary.taken;
    final expected = plannedToday <= 0 ? summary.expected : plannedToday;
    final percent = summary.percent.clamp(0, 100).toDouble();
    final progress = (percent / 100).clamp(0.0, 1.0);
    return MedicationSurfaceCard(
      padding: const EdgeInsets.all(18),
      radius: 18,
      color: MedicationUi.panelTint,
      shadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today adherence',
                      style: TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      '$completed of $expected doses',
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'completed today',
                      style: TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              _AdherenceRing(progress: progress, percent: percent),
            ],
          ),
          const SizedBox(height: 22),
          _StackedProgressBar(summary: summary, expected: expected),
          const SizedBox(height: 12),
          Row(
            children: [
              _LegendPill(
                color: VitaMateTheme.success,
                label: '${summary.taken} Taken',
              ),
              const Spacer(),
              _LegendPill(
                color: MedicationUi.pending,
                label: '${summary.pending} Pending',
              ),
              const Spacer(),
              _LegendPill(
                color: VitaMateTheme.danger,
                label: '${summary.missed + summary.overdue} Missed',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdherenceRing extends StatelessWidget {
  const _AdherenceRing({required this.progress, required this.percent});

  final double progress;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 94,
      height: 94,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              color: VitaMateTheme.primary,
              backgroundColor: Colors.white,
            ),
          ),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StackedProgressBar extends StatelessWidget {
  const _StackedProgressBar({required this.summary, required this.expected});

  final MedicationTodaySummary summary;
  final int expected;

  @override
  Widget build(BuildContext context) {
    final total = expected <= 0 ? 1 : expected;
    final taken = summary.taken.clamp(0, total).toInt();
    final pending = summary.pending.clamp(0, total).toInt();
    final missed = (summary.missed + summary.overdue).clamp(0, total).toInt();
    final empty = (total - taken - pending - missed).clamp(0, total).toInt();
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 9,
        child: Row(
          children: [
            if (taken > 0)
              Expanded(
                flex: taken,
                child: Container(color: VitaMateTheme.success),
              ),
            if (pending > 0)
              Expanded(
                flex: pending,
                child: Container(color: MedicationUi.pending),
              ),
            if (missed > 0)
              Expanded(
                flex: missed,
                child: Container(color: VitaMateTheme.danger),
              ),
            if (empty > 0)
              Expanded(
                flex: empty,
                child: Container(color: const Color(0xFFE8E5ED)),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: VitaMateTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MedicationShortcutRow extends StatelessWidget {
  const _MedicationShortcutRow({
    required this.onToday,
    required this.onAllMedications,
    required this.onHistory,
    required this.onInsights,
  });

  final VoidCallback onToday;
  final VoidCallback onAllMedications;
  final VoidCallback onHistory;
  final VoidCallback onInsights;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ShortcutTile(
            key: const ValueKey(AppTestKeys.medicationsTodayPlanButton),
            title: 'Today plan',
            icon: Icons.medication_liquid_rounded,
            onTap: onToday,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ShortcutTile(
            title: 'All medications',
            icon: Icons.medical_services_outlined,
            onTap: onAllMedications,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ShortcutTile(
            title: 'History',
            icon: Icons.history_rounded,
            onTap: onHistory,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ShortcutTile(
            title: 'Insights',
            icon: Icons.insights_rounded,
            onTap: onInsights,
          ),
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: MedicationSurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        radius: 11,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: VitaMateTheme.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingNextCard extends StatelessWidget {
  const _UpcomingNextCard({required this.dose, required this.onTap});

  final MedicationDoseLog? dose;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (dose == null) {
      return const MedicationSurfaceCard(
        padding: EdgeInsets.all(16),
        radius: 14,
        child: Text(
          'No upcoming doses right now.',
          style: TextStyle(
            color: VitaMateTheme.textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    final value = dose!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: MedicationSurfaceCard(
        padding: const EdgeInsets.all(16),
        radius: 14,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value.doseLabel,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    MedicationUi.mealRelationLabel(value.mealRelation),
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                const Icon(
                  Icons.alarm_rounded,
                  color: MedicationUi.pending,
                  size: 17,
                ),
                const SizedBox(width: 4),
                Text(
                  MedicationUi.timeLabel(value.scheduledFor),
                  style: const TextStyle(
                    color: MedicationUi.pending,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              color: VitaMateTheme.primaryDeep,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicationMotivationStrip extends StatelessWidget {
  const _MedicationMotivationStrip({required this.data, required this.streak});

  final Map<String, dynamic> data;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return MedicationSurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      radius: 14,
      color: MedicationUi.panelTint,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['title'] ?? "You're doing great!").toString(),
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (data['subtitle'] ?? 'Keep it up to maintain your streak.')
                      .toString(),
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (streak > 0) _StreakCircle(streak: streak),
        ],
      ),
    );
  }
}

class _StreakCircle extends StatelessWidget {
  const _StreakCircle({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(
              value: 0.86,
              strokeWidth: 5,
              color: VitaMateTheme.success,
              backgroundColor: Colors.white,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$streak',
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'day streak',
                style: TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddMedicationCta extends StatelessWidget {
  const _AddMedicationCta({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 240,
        height: 54,
        child: FilledButton.icon(
          key: const ValueKey(AppTestKeys.medicationsAddButton),
          onPressed: onPressed,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add medication'),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
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

class _AllMedicationsSheet extends StatelessWidget {
  const _AllMedicationsSheet({required this.medications, required this.onOpen});

  final List<MedicationItem> medications;
  final ValueChanged<MedicationItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: MedicationUi.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VitaMateTheme.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'All medications',
                style: TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < medications.length; i++) ...[
                MedicationCard(
                  medication: medications[i],
                  onTap: () => onOpen(medications[i]),
                ),
                if (i != medications.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InsightsSheet extends StatelessWidget {
  const _InsightsSheet({required this.controller});

  final MedicationsController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: MedicationUi.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: MedicationAdherenceCard(
          summary: controller.state.overallAdherence,
          plannedToday: controller.state.todayPlan.length,
        ),
      ),
    );
  }
}

enum _InlineTone { error, success }

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text, required this.tone});

  final String text;
  final _InlineTone tone;

  @override
  Widget build(BuildContext context) {
    final color = tone == _InlineTone.error
        ? VitaMateTheme.danger
        : VitaMateTheme.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
