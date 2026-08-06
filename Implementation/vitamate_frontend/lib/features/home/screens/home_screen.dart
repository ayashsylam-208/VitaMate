import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../core/config/api_endpoints.dart';
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
import '../../motivation/models/motivation_models.dart';
import '../../motivation/state/motivation_experience_controller.dart';
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
  late final AuthRepository? _authRepository;
  late final bool _ownsHomeController;
  late final bool _ownsChronicController;

  String _displayName = 'there';
  PageRoute<dynamic>? _subscribedRoute;
  bool _routeVisible = true;
  bool _refreshWhenVisible = false;
  String _avatarUrl = '';
  String _userInitials = 'V';

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? HomeController();
    chronicController =
        widget.chronicController ?? ChronicConditionsController();
    _authRepository = widget.authRepository;
    _ownsHomeController = widget.controller == null;
    _ownsChronicController = widget.chronicController == null;
    HealthSyncBus.instance.addListener(_handleTrackerRefresh);
    if (widget.autoLoad) {
      MotivationExperienceController.instance.activatePresentation();
      unawaited(controller.load());
      unawaited(_loadHomeIdentity());
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
    unawaited(_loadHomeIdentity());
    if (!_refreshWhenVisible) {
      return;
    }
    _refreshWhenVisible = false;
    unawaited(controller.load());
  }

  Future<void> _loadHomeIdentity() async {
    try {
      final user = await (_authRepository ?? AuthRepository(AuthApi())).getMe();
      if (!mounted) {
        return;
      }
      final preferred = user.fullName.trim();
      setState(() {
        _displayName = preferred.isEmpty ? 'there' : preferred;
        _avatarUrl = user.profile.avatarUrl;
        _userInitials = _initialsFor(
          firstName: user.firstName,
          lastName: user.lastName,
          username: user.username,
        );
      });
    } catch (_) {
      // Keep the fallback greeting.
    }
  }

  static String _initialsFor({
    required String firstName,
    required String lastName,
    required String username,
  }) {
    final first = firstName.trim();
    final last = lastName.trim();
    final value =
        '${first.isEmpty ? '' : first[0]}${last.isEmpty ? '' : last[0]}';
    if (value.isNotEmpty) {
      return value.toUpperCase();
    }
    final fallback = username.trim();
    return fallback.isEmpty ? 'V' : fallback[0].toUpperCase();
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>([
      controller.load(),
      MotivationExperienceController.instance.load(),
    ]);
    unawaited(_loadHomeIdentity());
  }

  Future<void> _openNotificationSettings() async {
    await Navigator.of(context).pushNamed(Routes.managerNotifications);
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
            colors: [
              VitaMateTheme.background,
              VitaMateTheme.surface,
              VitaMateTheme.softSurface,
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              controller,
              MotivationExperienceController.instance,
            ]),
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
              final motivationFeed =
                  MotivationExperienceController.instance.feed;
              return RefreshIndicator(
                onRefresh: _refreshAll,
                child: ListView(
                  key: const ValueKey(AppTestKeys.homeScreen),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 116),
                  children: [
                    _HomeTopBar(
                      displayName: _displayName,
                      avatarUrl: _avatarUrl,
                      initials: _userInitials,
                      onNotificationTap: () =>
                          unawaited(_openNotificationSettings()),
                    ),
                    const SizedBox(height: 20),
                    _TodayBriefPanel(data: data, feed: motivationFeed),
                    const SizedBox(height: 18),
                    const _SectionTitle('Core Tracking'),
                    const SizedBox(height: 12),
                    _TrackingGrid(data: data),
                    const SizedBox(height: 20),
                    _TodayPlanCard(data: data),
                    const SizedBox(height: 14),
                    _ConditionsHomeSection(
                      conditions: controller.conditionsCenter,
                      error: controller.error,
                      loading: controller.loading,
                      insight: _insightMessage(data),
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
    final hydration = data.component('hydration', 'water');
    final hydrationProgress = hydration != null && hydration.target > 0
        ? (hydration.current / hydration.target).clamp(0.0, 1.4)
        : 1.0;
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
        data.dailyHealth.hasData ||
        controller.conditionsCenter.isNotEmpty ||
        data.chronicSummary.hasAny;
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.displayName,
    required this.avatarUrl,
    required this.initials,
    required this.onNotificationTap,
  });

  final String displayName;
  final String avatarUrl;
  final String initials;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeAvatar(avatarUrl: avatarUrl, initials: initials),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
            child: Semantics(
              button: true,
              label: 'Open notification settings',
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
        ),
      ],
    );
  }
}

class _HomeAvatar extends StatelessWidget {
  const _HomeAvatar({required this.avatarUrl, required this.initials});

  final String avatarUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolveAvatarUrl(avatarUrl);
    return SizedBox(
      width: 48,
      height: 48,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: VitaMateTheme.shadow,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: Container(
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF8D68FF), Color(0xFF5D2DE1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: resolvedUrl == null
                ? _HomeAvatarInitials(initials: initials)
                : Image.network(
                    resolvedUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _HomeAvatarInitials(initials: initials),
                  ),
          ),
        ),
      ),
    );
  }

  static String? _resolveAvatarUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '${ApiEndpoints.baseUrl}$trimmed';
    }
    return trimmed;
  }
}

class _HomeAvatarInitials extends StatelessWidget {
  const _HomeAvatarInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TodayBriefPanel extends StatelessWidget {
  const _TodayBriefPanel({required this.data, required this.feed});

  final DashboardData data;
  final MotivationFeed feed;

  @override
  Widget build(BuildContext context) {
    final summary = _motivationSummary(data: data, feed: feed);
    final focus = _HomeTodayFocus.fromDashboard(
      data: data,
      feed: feed,
      summary: summary,
    );

    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _LevelBadge(level: summary.level),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CircularProgressBadge(
                percent: focus.progressPercent,
                icon: focus.icon,
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      focus.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      focus.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TodayActionButton(focus: focus),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (focus.rewardPoints > 0)
                Text(
                  '+${focus.rewardPoints} pts',
                  style: const TextStyle(
                    color: VitaMateTheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              if (focus.rewardPoints > 0 && summary.currentStreak > 0)
                Container(
                  width: 1,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: VitaMateTheme.borderStrong,
                ),
              if (summary.currentStreak > 0) ...[
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFFF6A1A),
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '${summary.currentStreak}',
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeTodayFocus {
  const _HomeTodayFocus({
    required this.title,
    required this.subtitle,
    required this.progressPercent,
    required this.rewardPoints,
    required this.route,
    required this.icon,
    required this.buttonLabel,
  });

  final String title;
  final String subtitle;
  final int progressPercent;
  final int rewardPoints;
  final String route;
  final IconData icon;
  final String buttonLabel;

  factory _HomeTodayFocus.fromDashboard({
    required DashboardData data,
    required MotivationFeed feed,
    required MotivationOverview summary,
  }) {
    final healthFocus = data.healthFocus;
    if (healthFocus.hasContent) {
      final route = _routeForFocus(
        route: healthFocus.route,
        domain: healthFocus.domain,
      );
      return _HomeTodayFocus(
        title: healthFocus.title,
        subtitle: healthFocus.subtitle.isEmpty
            ? data.dailyHealth.message
            : healthFocus.subtitle,
        progressPercent: healthFocus.progressPercent,
        rewardPoints: _rewardPoints(feed: feed, summary: summary),
        route: route,
        icon: _iconForRoute(route, domain: healthFocus.domain),
        buttonLabel: _buttonLabelForRoute(route, domain: healthFocus.domain),
      );
    }

    if (feed.focus.hasContent) {
      final route = _routeForFocus(route: feed.focus.route);
      return _HomeTodayFocus(
        title: feed.focus.title,
        subtitle: feed.focus.subtitle.isEmpty
            ? 'One focused action keeps your day moving.'
            : feed.focus.subtitle,
        progressPercent: feed.focus.progressPercent,
        rewardPoints: feed.focus.rewardPoints > 0
            ? feed.focus.rewardPoints
            : summary.dailyPoints,
        route: route,
        icon: _iconForRoute(route),
        buttonLabel: _buttonLabelForRoute(route),
      );
    }

    final levelProgress = _levelProgressPercent(summary);
    final nextLevel = summary.level + 1;
    final pointsLeft = summary.pointsToNextLevel > 0
        ? summary.pointsToNextLevel
        : 0;
    return _HomeTodayFocus(
      title: 'Build daily momentum',
      subtitle: pointsLeft > 0
          ? '$pointsLeft pts to L$nextLevel'
          : 'Keep logging your core trackers today.',
      progressPercent: levelProgress,
      rewardPoints: summary.dailyPoints,
      route: Routes.score,
      icon: Icons.auto_graph_rounded,
      buttonLabel: 'View progress',
    );
  }

  static int _rewardPoints({
    required MotivationFeed feed,
    required MotivationOverview summary,
  }) {
    if (feed.focus.rewardPoints > 0) {
      return feed.focus.rewardPoints;
    }
    return summary.dailyPoints;
  }
}

class _CircularProgressBadge extends StatelessWidget {
  const _CircularProgressBadge({required this.percent, required this.icon});

  final int percent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: CircularProgressIndicator(
              value: percent.clamp(0, 100) / 100,
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: VitaMateTheme.softSurface,
              valueColor: const AlwaysStoppedAnimation<Color>(
                VitaMateTheme.primaryGlow,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Icon(icon, size: 18, color: VitaMateTheme.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayActionButton extends StatelessWidget {
  const _TodayActionButton({required this.focus});

  final _HomeTodayFocus focus;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openNamedRoute(context, focus.route),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [VitaMateTheme.primaryGlow, VitaMateTheme.primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: VitaMateTheme.primary.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(focus.icon, color: Colors.white, size: 19),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    focus.buttonLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VitaMateTheme.primaryGlow),
      ),
      child: Text(
        'L$level',
        style: const TextStyle(
          color: VitaMateTheme.primaryDeep,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

MotivationOverview _motivationSummary({
  required DashboardData data,
  required MotivationFeed feed,
}) {
  if (feed.updatedAt != null || feed.summary.hasContent) {
    return feed.summary;
  }
  return MotivationOverview(
    date: '',
    totalPoints: data.points,
    dailyPoints: data.dailyPoints,
    weeklyPoints: 0,
    level: data.level,
    levelName: data.levelName,
    nextLevelThreshold: data.level * 1000,
    pointsToNextLevel: ((data.level * 1000) - data.points).clamp(0, 1000),
    missionsCompleted: data.missionsCompleted,
    missionsTotal: data.missionsTotal,
    currentStreak: data.currentStreak,
    longestStreak: data.currentStreak,
    badgesEarned: 0,
    badgesInProgress: 0,
    insight: '',
  );
}

class _TodayPlanCard extends StatelessWidget {
  const _TodayPlanCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final items = _HomePlanItem.fromDashboard(data).take(2).toList();
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Today's plan",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openNamedRoute(context, Routes.progress),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                label: const Text('View all'),
                style: TextButton.styleFrom(
                  foregroundColor: VitaMateTheme.primary,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _PlanRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.item});

  final _HomePlanItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openNamedRoute(context, item.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: VitaMateTheme.softSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: VitaMateTheme.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.trailing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: VitaMateTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: VitaMateTheme.textMuted,
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomePlanItem {
  const _HomePlanItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final String route;

  static List<_HomePlanItem> fromDashboard(DashboardData data) {
    final metrics = _TrackerMetrics.fromDashboard(data);
    final items = <_HomePlanItem>[];
    final usedRoutes = <String>{};

    void add(_HomePlanItem item) {
      if (usedRoutes.add(item.route)) {
        items.add(item);
      }
    }

    if (data.chronicSummary.pendingDosesToday > 0) {
      add(
        _HomePlanItem(
          icon: Icons.medication_outlined,
          title: 'Medication',
          subtitle: '${data.chronicSummary.pendingDosesToday} dose(s) pending',
          trailing: 'Today',
          route: Routes.medsToday,
        ),
      );
    }

    if (data.healthFocus.hasContent) {
      final route = _routeForFocus(
        route: data.healthFocus.route,
        domain: data.healthFocus.domain,
      );
      add(
        _HomePlanItem(
          icon: _iconForRoute(route, domain: data.healthFocus.domain),
          title: data.healthFocus.title,
          subtitle: data.healthFocus.subtitle,
          trailing: 'Open',
          route: route,
        ),
      );
    }

    if (metrics.hydrationPercent < 100) {
      add(
        _HomePlanItem(
          icon: Icons.water_drop_outlined,
          title: 'Hydration',
          subtitle: _hydrationRemainingLabel(data),
          trailing: 'Open',
          route: Routes.water,
        ),
      );
    }

    if (metrics.activityPercent < 100) {
      add(
        _HomePlanItem(
          icon: Icons.directions_run_rounded,
          title: 'Activity reminder',
          subtitle: _activityRemainingLabel(data),
          trailing: 'Open',
          route: Routes.activities,
        ),
      );
    }

    if (items.isEmpty && metrics.nutritionPercent < 100) {
      add(
        _HomePlanItem(
          icon: Icons.ramen_dining_outlined,
          title: 'Nutrition',
          subtitle: 'Log your next meal today',
          trailing: 'Open',
          route: Routes.meals,
        ),
      );
    }

    return items;
  }
}

class _TrackingGrid extends StatelessWidget {
  const _TrackingGrid({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final metrics = _TrackerMetrics.fromDashboard(data);
    final numberFormat = NumberFormat.decimalPattern();
    final waterComponent = data.component('hydration', 'water');
    final mealsComponent = data.component('nutrition', 'meals');
    final sleepComponent = data.component('sleep', 'sleep');
    final activityComponent = data.component('movement', 'activity_minutes');
    final activityMinutes =
        activityComponent?.current.toInt() ?? data.activityMinutes;
    final activityProgress =
        activityComponent?.progressPercent ?? metrics.activityPercent;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.0,
      children: [
        _TrackerCard(
          icon: Icons.directions_run_rounded,
          title: 'Activity',
          progressPercent: activityProgress,
          value: '${numberFormat.format(activityMinutes)} min',
          target: _targetLabel(activityComponent, fallbackUnit: 'min'),
          accent: VitaMateTheme.primary,
          route: Routes.activities,
        ),
        _TrackerCard(
          icon: Icons.water_drop_outlined,
          title: 'Hydration',
          progressPercent: metrics.hydrationPercent,
          value: '${(data.waterMl / 1000).toStringAsFixed(1)}L',
          target: _targetLabel(waterComponent, fallbackUnit: 'L'),
          accent: VitaMateTheme.accent,
          route: Routes.water,
        ),
        _TrackerCard(
          icon: Icons.ramen_dining_outlined,
          title: 'kcal',
          progressPercent: metrics.nutritionPercent,
          value: mealsComponent != null
              ? '${mealsComponent.current.toInt()} meals'
              : '${numberFormat.format(data.calories)} kcal',
          target: _targetLabel(mealsComponent, fallbackUnit: 'meals'),
          accent: const Color(0xFFFF4F9A),
          route: Routes.meals,
        ),
        _TrackerCard(
          icon: Icons.nightlight_round,
          title: 'Sleep',
          progressPercent: metrics.sleepPercent,
          value: _durationLabel(data.sleepMinutes),
          target: _targetLabel(sleepComponent, fallbackUnit: 'h'),
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(
                              color: VitaMateTheme.primaryDeep,
                            ),
                            children: [
                              TextSpan(
                                text: value,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (target.isNotEmpty)
                                TextSpan(
                                  text: ' $target',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: VitaMateTheme.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: VitaMateTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progressPercent / 100,
                  minHeight: 5,
                  backgroundColor: VitaMateTheme.softSurface,
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
    required this.insight,
    required this.onAddCondition,
    required this.onOpenCenter,
    required this.onOpenCondition,
  });

  final List<ChronicCondition> conditions;
  final String? error;
  final bool loading;
  final String insight;
  final Future<void> Function() onAddCondition;
  final Future<void> Function() onOpenCenter;
  final Future<void> Function(int conditionId) onOpenCondition;

  @override
  Widget build(BuildContext context) {
    if (loading && conditions.isEmpty) {
      return const _SurfaceCard(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null && conditions.isEmpty) {
      return _SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Text(
          error!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    final hasConditions = conditions.isNotEmpty;
    final condition = hasConditions ? conditions.first : null;
    final title = hasConditions
        ? (conditions.length == 1
              ? condition!.uiLabel
              : '${conditions.length} health conditions')
        : 'Add a health condition';
    final subtitle = hasConditions
        ? (condition!.secondarySummaryLine.isEmpty
              ? insight
              : condition.secondarySummaryLine)
        : 'Personalize your goals and guidance';
    final icon = hasConditions
        ? _conditionIcon(condition!.conditionType.slug)
        : Icons.add_link_rounded;
    final color = hasConditions
        ? _statusColor(condition!.summaryStatusLabel)
        : VitaMateTheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(
          hasConditions
              ? AppTestKeys.homeConditionsCenterOpenButton
              : AppTestKeys.homeConditionsCenterAddButton,
        ),
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (!hasConditions) {
            unawaited(onAddCondition());
            return;
          }
          if (conditions.length == 1) {
            unawaited(onOpenCondition(condition!.id));
            return;
          }
          unawaited(onOpenCenter());
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: VitaMateTheme.border),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                VitaMateTheme.softSurface.withValues(alpha: 0.95),
                Colors.white.withValues(alpha: 0.98),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: VitaMateTheme.primaryDeep,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, required this.padding});

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
    final movement = data.domain('movement');
    final hydrationDomain = data.domain('hydration');
    final nutritionDomain = data.domain('nutrition');
    final sleepDomain = data.domain('sleep');
    final stepTarget = data.stepTarget > 0 ? data.stepTarget : 0;
    final burnTarget = data.burnTargetKcal > 0 ? data.burnTargetKcal : 0;
    final stepsProgress = stepTarget > 0
        ? ((data.todaySteps / stepTarget) * 100).clamp(0, 100).round()
        : 0;
    final burnProgress = burnTarget > 0
        ? ((data.activityBurnedKcal / burnTarget) * 100).clamp(0, 100).round()
        : 0;
    final activityFallback = stepsProgress > burnProgress
        ? stepsProgress
        : burnProgress;
    final activity = movement?.score ?? activityFallback;
    final hydration = hydrationDomain?.score ?? 0;
    final nutrition = nutritionDomain?.score ?? 0;
    final sleep = sleepDomain?.score ?? 0;
    final score = ((activity + hydration + nutrition + sleep) / 4).round();
    return _TrackerMetrics(
      activityPercent: activity,
      hydrationPercent: hydration,
      nutritionPercent: nutrition,
      sleepPercent: sleep,
      healthScore: score,
      level: data.level,
    );
  }
}

void _openNamedRoute(BuildContext context, String route) {
  if (route.trim().isEmpty) {
    return;
  }
  Navigator.pushNamed(context, route);
}

String _routeForFocus({String route = '', String domain = ''}) {
  final trimmedRoute = route.trim();
  if (trimmedRoute.isNotEmpty) {
    return trimmedRoute;
  }

  switch (domain) {
    case 'hydration':
      return Routes.water;
    case 'nutrition':
    case 'meal':
    case 'meals':
      return Routes.meals;
    case 'movement':
    case 'activity':
    case 'steps':
      return Routes.activitySteps;
    case 'sleep':
      return Routes.sleep;
    case 'medication':
    case 'medications':
      return Routes.medsToday;
    case 'habit':
    case 'habits':
      return Routes.habits;
    default:
      return Routes.progress;
  }
}

IconData _iconForRoute(String route, {String domain = ''}) {
  final key = '$route $domain'.toLowerCase();
  if (key.contains('water') || key.contains('hydration')) {
    return Icons.water_drop_outlined;
  }
  if (key.contains('meal') || key.contains('nutrition')) {
    return Icons.ramen_dining_outlined;
  }
  if (key.contains('activity') ||
      key.contains('steps') ||
      key.contains('movement')) {
    return Icons.directions_run_rounded;
  }
  if (key.contains('sleep')) {
    return Icons.nightlight_round;
  }
  if (key.contains('med')) {
    return Icons.medication_outlined;
  }
  if (key.contains('habit')) {
    return Icons.sync_alt_rounded;
  }
  return Icons.auto_graph_rounded;
}

String _buttonLabelForRoute(String route, {String domain = ''}) {
  final key = '$route $domain'.toLowerCase();
  if (key.contains('water') || key.contains('hydration')) {
    return 'Log a drink';
  }
  if (key.contains('meal') || key.contains('nutrition')) {
    return 'Log meal';
  }
  if (key.contains('activity') ||
      key.contains('steps') ||
      key.contains('movement')) {
    return 'Start activity';
  }
  if (key.contains('sleep')) {
    return 'Log sleep';
  }
  if (key.contains('med')) {
    return 'Take dose';
  }
  return 'Open';
}

int _levelProgressPercent(MotivationOverview summary) {
  final threshold = summary.nextLevelThreshold > 0
      ? summary.nextLevelThreshold
      : summary.level * 1000;
  if (threshold <= 0) {
    return 0;
  }
  final earnedTowardThreshold = threshold - summary.pointsToNextLevel;
  return ((earnedTowardThreshold / threshold) * 100).clamp(0, 100).round();
}

String _hydrationRemainingLabel(DashboardData data) {
  final water = data.component('hydration', 'water');
  if (water != null && water.target > water.current) {
    final remaining = water.target - water.current;
    final unit = water.unit.isNotEmpty ? water.unit : 'L';
    final value = remaining >= 10
        ? remaining.round().toString()
        : remaining.toStringAsFixed(1);
    return '$value $unit remaining today';
  }
  return 'Log your next drink today';
}

String _activityRemainingLabel(DashboardData data) {
  final activity = data.component('movement', 'activity_minutes');
  if (activity != null && activity.target > activity.current) {
    final remaining = (activity.target - activity.current).ceil();
    return '$remaining active minutes left';
  }
  if (data.burnTargetKcal > data.activityBurnedKcal) {
    return '${data.burnTargetKcal - data.activityBurnedKcal} kcal left';
  }
  return 'Start an activity session';
}

String _targetLabel(
  HealthDomainComponent? component, {
  required String fallbackUnit,
}) {
  if (component == null || component.target <= 0) {
    return '';
  }
  final unit = component.unit.isNotEmpty ? component.unit : fallbackUnit;
  final target = component.target % 1 == 0
      ? component.target.toInt().toString()
      : component.target.toStringAsFixed(1);
  final separator = unit.length <= 1 ? '' : ' ';
  return '/ $target$separator$unit';
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
