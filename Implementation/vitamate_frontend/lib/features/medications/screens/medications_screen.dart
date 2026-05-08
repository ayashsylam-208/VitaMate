import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/routing/vitamate_route_observer.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../models/medication_item.dart';
import '../state/medications_controller.dart';
import '../widgets/empty_medications_state.dart';
import '../widgets/medication_adherence_card.dart';
import '../widgets/medication_card.dart';
import 'add_edit_medication_screen.dart';
import 'medication_detail_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final activeCount = state.medications.where((item) => item.isActive).length;
    final prnCount = state.medications.where((item) => item.isPrn).length;
    final overall = state.overallAdherence;
    final takenToday = state.todayPlan
        .where((item) {
          final status = item.status.toLowerCase();
          return status == 'taken' ||
              status == 'taken_on_time' ||
              status == 'taken_late';
        })
        .length;
    final pendingToday = state.todayPlan
        .where((item) {
          final status = item.status.toLowerCase();
          return status == 'pending' || status == 'snoozed';
        })
        .length;
    final overdueToday = state.todayPlan
        .where((item) => item.status.toLowerCase() == 'overdue')
        .length;

    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 2),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refreshAll,
          child: ListView(
            key: const ValueKey(AppTestKeys.medicationsScreen),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              const Text(
                'Medication',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: VitaMateTheme.primaryDeep,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Track active plans, today doses, and long-term adherence in one place.',
                style: TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
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
              else ...[
                _MedicationHeroCard(
                  activeCount: activeCount,
                  prnCount: prnCount,
                  plannedToday: state.todayPlan.length,
                  takenToday: takenToday,
                  pendingToday: pendingToday,
                  overdueToday: overdueToday,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _PrimaryGradientButton(
                        key: const ValueKey(
                          AppTestKeys.medicationsTodayPlanButton,
                        ),
                        label: state.todayPlan.isEmpty
                            ? 'Today plan'
                            : 'Today plan (${state.todayPlan.length})',
                        icon: Icons.schedule_rounded,
                        onPressed: _openToday,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey(AppTestKeys.medicationsAddButton),
                        onPressed: _openAdd,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: Colors.white,
                          side: const BorderSide(
                            color: VitaMateTheme.borderStrong,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                MedicationAdherenceCard(
                  summary: overall,
                  plannedToday: state.todayPlan.length,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Active plans',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: VitaMateTheme.primaryDeep,
                        ),
                      ),
                    ),
                    _SectionBadge(
                      label: activeCount == 0
                          ? 'No active meds'
                          : '$activeCount active',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.medications.isEmpty)
                  EmptyMedicationsState(onAdd: _openAdd)
                else
                  for (var i = 0; i < state.medications.length; i++) ...[
                    MedicationCard(
                      medication: state.medications[i],
                      onTap: () => _openMedication(state.medications[i]),
                    ),
                    if (i != state.medications.length - 1)
                      const SizedBox(height: 12),
                  ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicationHeroCard extends StatelessWidget {
  const _MedicationHeroCard({
    required this.activeCount,
    required this.prnCount,
    required this.plannedToday,
    required this.takenToday,
    required this.pendingToday,
    required this.overdueToday,
  });

  final int activeCount;
  final int prnCount;
  final int plannedToday;
  final int takenToday;
  final int pendingToday;
  final int overdueToday;

  @override
  Widget build(BuildContext context) {
    final todayPercent = plannedToday <= 0
        ? 0
        : ((takenToday / plannedToday) * 100).clamp(0, 100).round();
    final progress = plannedToday <= 0
        ? 0.0
        : (takenToday / plannedToday).clamp(0.0, 1.0);
    final headline = activeCount == 0
        ? 'No medication plans yet'
        : '$todayPercent% today adherence';
    final subtitle = overdueToday > 0
        ? '$overdueToday overdue doses need attention.'
        : pendingToday > 0
        ? '$pendingToday doses are still pending today.'
        : plannedToday > 0
        ? 'Today plan is complete so far.'
        : 'Add a plan to unlock dose tracking and reminders.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.medication_liquid_rounded,
                          color: VitaMateTheme.primary,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Medication overview',
                          style: TextStyle(
                            color: VitaMateTheme.primaryDeep,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        color: VitaMateTheme.primary,
                        backgroundColor: VitaMateTheme.softSurface,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$todayPercent%',
                          style: const TextStyle(
                            color: VitaMateTheme.primaryDeep,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const Text(
                          'today',
                          style: TextStyle(
                            color: VitaMateTheme.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            headline,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(
                label: '$activeCount active',
                color: VitaMateTheme.primary,
              ),
              _HeroChip(
                label: '$plannedToday planned today',
                color: VitaMateTheme.accent,
              ),
              _HeroChip(
                label: '$pendingToday pending',
                color: VitaMateTheme.warning,
              ),
              if (overdueToday > 0)
                _HeroChip(
                  label: '$overdueToday overdue',
                  color: VitaMateTheme.danger,
                ),
              if (takenToday > 0)
                _HeroChip(
                  label: '$takenToday taken',
                  color: VitaMateTheme.success,
                ),
              if (prnCount > 0)
                _HeroChip(
                  label: '$prnCount as needed',
                  color: VitaMateTheme.success,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.color});

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
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SectionBadge extends StatelessWidget {
  const _SectionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: VitaMateTheme.textMuted,
          fontWeight: FontWeight.w800,
          fontSize: 12,
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

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7F21F5), Color(0xFF9E2CFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
