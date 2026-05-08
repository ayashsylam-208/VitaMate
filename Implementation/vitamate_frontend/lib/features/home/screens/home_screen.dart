import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../core/routing/routes.dart';
import '../../../core/routing/vitamate_route_observer.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../../chronic_conditions/models/chronic_condition.dart';
import '../../chronic_conditions/screens/chronic_condition_detail_screen.dart';
import '../../chronic_conditions/screens/chronic_conditions_screen.dart';
import '../../chronic_conditions/state/chronic_conditions_controller.dart';
import '../models/dashboard_data.dart';
import '../state/home_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.controller,
    this.chronicController,
    this.authRepository,
    this.autoLoad = true,
  });

  final HomeController? controller;
  final ChronicConditionsController? chronicController;
  final AuthRepository? authRepository;
  final bool autoLoad;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  late final HomeController controller;
  late final ChronicConditionsController chronicController;
  late final AuthRepository _authRepository;
  late final bool _ownsHomeController;
  late final bool _ownsChronicController;

  String _displayName = 'there';
  PageRoute<dynamic>? _subscribedRoute;
  bool _routeVisible = true;
  bool _refreshWhenVisible = false;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? HomeController();
    chronicController =
        widget.chronicController ?? ChronicConditionsController();
    _authRepository = widget.authRepository ?? AuthRepository(AuthApi());
    _ownsHomeController = widget.controller == null;
    _ownsChronicController = widget.chronicController == null;
    HealthSyncBus.instance.addListener(_handleTrackerRefresh);
    if (widget.autoLoad) {
      unawaited(controller.load());
      unawaited(_loadDisplayName());
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
    if (_ownsHomeController) {
      controller.dispose();
    }
    if (_ownsChronicController) {
      chronicController.dispose();
    }
    super.dispose();
  }

  void _handleTrackerRefresh() {
    if (!HealthSyncBus.instance.affects(const {HealthSyncScope.homeOverview})) {
      return;
    }
    if (!_isRouteVisible()) {
      _refreshWhenVisible = true;
      return;
    }
    unawaited(controller.load());
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
    unawaited(controller.load());
  }

  Future<void> _loadDisplayName() async {
    try {
      final user = await _authRepository.getMe();
      if (!mounted) {
        return;
      }
      final preferred = user.firstName.trim().isNotEmpty
          ? user.firstName.trim()
          : user.username.trim();
      setState(() => _displayName = preferred.isEmpty ? 'there' : preferred);
    } catch (_) {
      // Keep the fallback greeting.
    }
  }

  Future<void> _refreshAll() async {
    await controller.load();
    unawaited(_loadDisplayName());
  }

  Future<void> _openConditionsCenter() async {
    if (chronicController.catalog.isEmpty && !chronicController.loading) {
      unawaited(chronicController.loadCenter());
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChronicConditionsScreen(controller: chronicController),
      ),
    );
  }

  Future<void> _openCondition(int conditionId) async {
    if (chronicController.conditionById(conditionId) == null) {
      await chronicController.loadCenter(includeCatalog: false);
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChronicConditionDetailScreen(
          controller: chronicController,
          conditionId: conditionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9F5FF), Color(0xFFF3ECFF), Color(0xFFF7F2FF)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              if (_isInitialDashboardLoad()) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.error != null && !_hasDashboardData()) {
                return _HomeErrorState(
                  message: controller.error!,
                  onRetry: _refreshAll,
                );
              }

              final data = controller.data;
              return RefreshIndicator(
                onRefresh: _refreshAll,
                child: ListView(
                  key: const ValueKey(AppTestKeys.homeScreen),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 116),
                  children: [
                    _HomeTopBar(
                      displayName: _displayName,
                      onNotificationTap: () {},
                    ),
                    const SizedBox(height: 20),
                    _DailyScoreCard(data: data),
                    const SizedBox(height: 20),
                    _InsightCard(message: _insightMessage(data)),
                    const SizedBox(height: 20),
                    const _SectionTitle('Core Tracking'),
                    const SizedBox(height: 12),
                    _TrackingGrid(data: data),
                    const SizedBox(height: 22),
                    const _SectionTitle('Conditions Center'),
                    const SizedBox(height: 12),
                    _ConditionsHomeSection(
                      conditions: controller.conditionsCenter,
                      error: controller.error,
                      loading: controller.loading,
                      onAddCondition: _openConditionsCenter,
                      onOpenCenter: _openConditionsCenter,
                      onOpenCondition: _openCondition,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _insightMessage(DashboardData data) {
    final hydrationProgress = (data.waterMl / 2500).clamp(0.0, 1.4);
    if (controller.conditionsCenter.isNotEmpty &&
        controller.conditionsCenter.first.needsAttention) {
      return controller.conditionsCenter.first.secondarySummaryLine;
    }
    if (hydrationProgress < 0.85) {
      return 'Your hydration is lower than usual. Drinking a glass of water now will help you reach your daily goal.';
    }
    return 'You are maintaining a steady rhythm today. Keep logging your health essentials to preserve it.';
  }

  bool _isInitialDashboardLoad() {
    return controller.loading && !_hasDashboardData();
  }

  bool _hasDashboardData() {
    final data = controller.data;
    return data.points != 0 ||
        data.todaySteps != 0 ||
        data.waterMl != 0 ||
        data.sleepMinutes != 0 ||
        data.calories != 0 ||
        controller.conditionsCenter.isNotEmpty ||
        data.chronicSummary.hasAny;
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.displayName,
    required this.onNotificationTap,
  });

  final String displayName;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $displayName \u{1F44B}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: VitaMateTheme.primaryDeep,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ready for a healthy day?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: VitaMateTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onNotificationTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: VitaMateTheme.border),
                boxShadow: const [
                  BoxShadow(
                    color: VitaMateTheme.shadow,
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 22,
                      color: VitaMateTheme.primary,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: VitaMateTheme.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyScoreCard extends StatelessWidget {
  const _DailyScoreCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final metrics = _TrackerMetrics.fromDashboard(data);
    final score = (metrics.healthScore + data.dailyPoints)
        .clamp(0, 100)
        .toInt();
    final level = data.level > 0 ? data.level : metrics.level;

    return _SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Daily Health Score',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: VitaMateTheme.primaryDeep,
                  ),
                ),
              ),
              _PillLabel(label: 'Level $level'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 78,
                      height: 78,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 6,
                        backgroundColor: const Color(0xFFF0E7FF),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          VitaMateTheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: VitaMateTheme.primaryDeep,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _headlineForScore(score),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: VitaMateTheme.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _supportForScore(score),
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ScoreChip(label: '+${data.dailyPoints} pts today'),
                        _ScoreChip(label: '${data.points} pts total'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _headlineForScore(int score) {
    if (score >= 80) {
      return 'Great job today! \u{1F389}';
    }
    if (score >= 60) {
      return 'Good progress today';
    }
    return 'Keep building today';
  }

  String _supportForScore(int score) {
    if (score >= 80) {
      return 'You\'re maintaining a strong 5-day streak. Keep it up.';
    }
    if (score >= 60) {
      return 'A couple of small tracker updates will lift your day further.';
    }
    return 'Start with one tracker update and the rest will follow.';
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: VitaMateTheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Smart Insight'),
        const SizedBox(height: 12),
        _SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: VitaMateTheme.softSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: VitaMateTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.38,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackingGrid extends StatelessWidget {
  const _TrackingGrid({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final metrics = _TrackerMetrics.fromDashboard(data);
    final numberFormat = NumberFormat.decimalPattern();
    final activityValue = data.activityBurnedKcal > 0
        ? '${numberFormat.format(data.activityBurnedKcal)} kcal'
        : numberFormat.format(data.todaySteps);
    final activityTarget = data.activityBurnedKcal > 0
        ? (data.burnTargetKcal > 0
              ? '/ ${numberFormat.format(data.burnTargetKcal)} kcal'
              : ' burned')
        : (data.stepTarget > 0
              ? '/ ${_compactSteps(data.stepTarget)}'
              : '/ 10k');

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.02,
      children: [
        _TrackerCard(
          icon: Icons.multiline_chart_rounded,
          title: 'Activity',
          progressPercent: metrics.activityPercent,
          value: activityValue,
          target: activityTarget,
          accent: VitaMateTheme.primary,
          route: Routes.activities,
        ),
        _TrackerCard(
          icon: Icons.water_drop_outlined,
          title: 'Hydration',
          progressPercent: metrics.hydrationPercent,
          value: '${(data.waterMl / 1000).toStringAsFixed(1)}L',
          target: '/ 2.5L',
          accent: VitaMateTheme.accent,
          route: Routes.water,
        ),
        _TrackerCard(
          icon: Icons.apple_outlined,
          title: 'Nutrition',
          progressPercent: metrics.nutritionPercent,
          value: '${numberFormat.format(data.calories)} kcal',
          target: ' · 78g pro',
          accent: const Color(0xFFFF4F9A),
          route: Routes.meals,
        ),
        _TrackerCard(
          icon: Icons.nightlight_round,
          title: 'Sleep',
          progressPercent: metrics.sleepPercent,
          value: _durationLabel(data.sleepMinutes),
          target: ' logged',
          accent: const Color(0xFFB15CFF),
          route: Routes.sleep,
        ),
      ],
    );
  }
}

class _TrackerCard extends StatelessWidget {
  const _TrackerCard({
    required this.icon,
    required this.title,
    required this.progressPercent,
    required this.value,
    required this.target,
    required this.accent,
    required this.route,
  });

  final IconData icon;
  final String title;
  final int progressPercent;
  final String value;
  final String target;
  final Color accent;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.pushNamed(context, route),
        child: _SurfaceCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: accent, size: 25),
                  ),
                  const Spacer(),
                  _PillLabel(label: '$progressPercent%'),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: VitaMateTheme.primaryDeep,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: VitaMateTheme.primaryDeep),
                  children: [
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(
                      text: target,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progressPercent / 100,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF0E7FF),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConditionsHomeSection extends StatelessWidget {
  const _ConditionsHomeSection({
    required this.conditions,
    required this.error,
    required this.loading,
    required this.onAddCondition,
    required this.onOpenCenter,
    required this.onOpenCondition,
  });

  final List<ChronicCondition> conditions;
  final String? error;
  final bool loading;
  final Future<void> Function() onAddCondition;
  final Future<void> Function() onOpenCenter;
  final Future<void> Function(int conditionId) onOpenCondition;

  @override
  Widget build(BuildContext context) {
    if (loading && conditions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null && conditions.isEmpty) {
      return _SurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Text(
          error!,
          style: const TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (conditions.isEmpty) {
      return _SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: VitaMateTheme.softSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_link_rounded,
                color: VitaMateTheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No chronic conditions added yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: VitaMateTheme.primaryDeep,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(
              key: const ValueKey(AppTestKeys.homeConditionsCenterAddButton),
              onPressed: onAddCondition,
              style: FilledButton.styleFrom(
                foregroundColor: VitaMateTheme.primary,
                backgroundColor: VitaMateTheme.softSurface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Add condition'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final condition in conditions) ...[
          _ConditionSummaryCard(
            condition: condition,
            onOpen: () => onOpenCondition(condition.id),
          ),
          if (condition != conditions.last) const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const ValueKey(AppTestKeys.homeConditionsCenterOpenButton),
            onPressed: () {
              onOpenCenter();
            },
            icon: const Icon(Icons.health_and_safety_outlined, size: 18),
            label: const Text('Open conditions center'),
          ),
        ),
      ],
    );
  }
}

class _ConditionSummaryCard extends StatelessWidget {
  const _ConditionSummaryCard({required this.condition, required this.onOpen});

  final ChronicCondition condition;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(condition.summaryStatusLabel);

    return _SurfaceCard(
      key: ValueKey(
        AppTestKeys.homeConditionCard(condition.conditionType.slug),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _conditionIcon(condition.conditionType.slug),
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      condition.uiLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: VitaMateTheme.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      condition.summarySubtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: VitaMateTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                label: condition.summaryStatusLabel,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            condition.summaryLine,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            condition.secondarySummaryLine,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: VitaMateTheme.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonal(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              foregroundColor: VitaMateTheme.primaryDeep,
              backgroundColor: VitaMateTheme.softSurface,
            ),
            child: const Text('View tracking'),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({super.key, required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: VitaMateTheme.primaryDeep,
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: VitaMateTheme.primary,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: VitaMateTheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _TrackerMetrics {
  const _TrackerMetrics({
    required this.activityPercent,
    required this.hydrationPercent,
    required this.nutritionPercent,
    required this.sleepPercent,
    required this.healthScore,
    required this.level,
  });

  final int activityPercent;
  final int hydrationPercent;
  final int nutritionPercent;
  final int sleepPercent;
  final int healthScore;
  final int level;

  factory _TrackerMetrics.fromDashboard(DashboardData data) {
    final stepTarget = data.stepTarget > 0 ? data.stepTarget : 10000;
    final burnTarget = data.burnTargetKcal > 0 ? data.burnTargetKcal : 0;
    final stepsProgress = ((data.todaySteps / stepTarget) * 100)
        .clamp(0, 100)
        .round();
    final burnProgress = burnTarget > 0
        ? ((data.activityBurnedKcal / burnTarget) * 100).clamp(0, 100).round()
        : (data.activityBurnedKcal > 0 ? 12 : 0);
    final activity = stepsProgress > burnProgress
        ? stepsProgress
        : burnProgress;
    final hydration = ((data.waterMl / 2500) * 100).clamp(0, 100).round();
    final nutrition = ((data.calories / 2600) * 100).clamp(0, 100).round();
    final sleep = ((data.sleepMinutes / 480) * 100).clamp(0, 100).round();
    final score = ((activity + hydration + nutrition + sleep) / 4).round();
    final level = score >= 80 ? 2 : 1;
    return _TrackerMetrics(
      activityPercent: activity,
      hydrationPercent: hydration,
      nutritionPercent: nutrition,
      sleepPercent: sleep,
      healthScore: score,
      level: level,
    );
  }
}

String _compactSteps(int steps) {
  if (steps >= 1000 && steps % 1000 == 0) {
    return '${steps ~/ 1000}k';
  }
  if (steps >= 1000) {
    return '${(steps / 1000).toStringAsFixed(1)}k';
  }
  return steps.toString();
}

String _durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours == 0) {
    return '${mins}m';
  }
  return '${hours}h ${mins}m';
}

IconData _conditionIcon(String slug) {
  switch (slug) {
    case 'diabetes':
      return Icons.bloodtype_outlined;
    case 'hypertension':
      return Icons.favorite_outline_rounded;
    case 'dyslipidemia':
      return Icons.monitor_heart_outlined;
    default:
      return Icons.health_and_safety_outlined;
  }
}

Color _statusColor(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('high') || lower.contains('attention')) {
    return VitaMateTheme.danger;
  }
  if (lower.contains('elevated') || lower.contains('low')) {
    return VitaMateTheme.warning;
  }
  return VitaMateTheme.success;
}
