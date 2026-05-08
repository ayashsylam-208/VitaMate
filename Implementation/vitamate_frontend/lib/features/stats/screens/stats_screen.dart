import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/vitamate_route_observer.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../models/progress_models.dart';
import '../state/stats_controller.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.controller, this.autoLoad = true});

  final StatsController? controller;
  final bool autoLoad;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with RouteAware {
  late final StatsController controller;
  late final bool _ownsController;
  PageRoute<dynamic>? _subscribedRoute;
  bool _routeVisible = true;
  bool _refreshWhenVisible = false;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? StatsController();
    _ownsController = widget.controller == null;
    if (widget.autoLoad) {
      unawaited(controller.load());
    }
    HealthSyncBus.instance.addListener(_handleTrackerRefresh);
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
    if (_ownsController) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleTrackerRefresh() {
    if (!HealthSyncBus.instance.affects(const {
      HealthSyncScope.progressHistory,
    })) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 1),
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => controller.load(),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.loading &&
                controller.overview.trackerCards.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.error != null &&
                controller.overview.trackerCards.isEmpty) {
              return _ErrorState(
                message: controller.error!,
                onRetry: controller.load,
              );
            }
            return RefreshIndicator(
              onRefresh: controller.load,
              child: _ProgressOverviewBody(
                overview: controller.overview,
                historyCount: controller.history.length,
                isStale: controller.isStale,
                onOpenDetail: _openDetail,
              ),
            );
          },
        ),
      ),
    );
  }

  void _openDetail(ProgressTrackerCard card) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ProgressDetailScreen(card: card)));
  }
}

class _ProgressOverviewBody extends StatelessWidget {
  const _ProgressOverviewBody({
    required this.overview,
    required this.historyCount,
    required this.isStale,
    required this.onOpenDetail,
  });

  final ProgressOverview overview;
  final int historyCount;
  final bool isStale;
  final ValueChanged<ProgressTrackerCard> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final cards = overview.trackerCards;
    return SingleChildScrollView(
      key: const ValueKey(AppTestKeys.statsScreen),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TodayProgressCard(
            overview: overview,
            cards: cards.take(5).toList(growable: false),
            onOpenDetail: onOpenDetail,
          ),
          const SizedBox(height: 14),
          _OverallScoreCard(overview: overview, isStale: isStale),
          const SizedBox(height: 14),
          _TrackerRows(cards: cards, onOpenDetail: onOpenDetail),
          const SizedBox(height: 14),
          _FeaturedTrackerSection(
            title: 'Nutrition progress',
            subtitle: 'Track meals and build better eating habits.',
            card: _findCard(cards, 'nutrition'),
            onOpenDetail: onOpenDetail,
          ),
          const SizedBox(height: 14),
          _FeaturedTrackerSection(
            title: 'Habit quitting progress',
            subtitle: 'Build a healthier you, one day at a time.',
            card: _findCard(cards, 'habits'),
            onOpenDetail: onOpenDetail,
          ),
          const SizedBox(height: 14),
          _FeaturedTrackerSection(
            title: 'Medication adherence',
            subtitle: 'Stay consistent with your medications.',
            card: _findCard(cards, 'medications'),
            onOpenDetail: onOpenDetail,
          ),
          const SizedBox(height: 14),
          _TimelineSection(days: overview.timeline),
          const SizedBox(height: 14),
          _FeaturedTrackerSection(
            title: 'Chronic condition adherence',
            subtitle: 'Care plans, limits, and latest history.',
            card: _findCard(cards, 'chronic'),
            onOpenDetail: onOpenDetail,
          ),
          if (historyCount == 0) ...[
            const SizedBox(height: 14),
            _TipCard(
              title: 'Start today',
              message:
                  'Log one meal, drink, activity, or dose to build your first progress timeline.',
            ),
          ],
        ],
      ),
    );
  }

  static ProgressTrackerCard? _findCard(
    List<ProgressTrackerCard> cards,
    String code,
  ) {
    for (final card in cards) {
      if (card.code == code) {
        return card;
      }
    }
    return null;
  }
}

class _TodayProgressCard extends StatelessWidget {
  const _TodayProgressCard({
    required this.overview,
    required this.cards,
    required this.onOpenDetail,
  });

  final ProgressOverview overview;
  final List<ProgressTrackerCard> cards;
  final ValueChanged<ProgressTrackerCard> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return _ProgressCard(
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
                      'Today',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: VitaMateTheme.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMM d').format(now),
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _PointsBadge(points: overview.points, level: overview.level),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _CompactTrackerTile(
                card: cards[index],
                onTap: () => onOpenDetail(cards[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverallScoreCard extends StatelessWidget {
  const _OverallScoreCard({required this.overview, required this.isStale});

  final ProgressOverview overview;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    return _ProgressCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ProgressRing(
                percent: overview.overallScore,
                color: VitaMateTheme.success,
                label: '${overview.overallScore}%',
                caption: 'Wellness',
                size: 112,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Great progress!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: VitaMateTheme.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      overview.insight.message,
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isStale) ...[
                      const SizedBox(height: 8),
                      const _MiniPill(
                        label: 'Refreshing snapshot',
                        color: VitaMateTheme.warning,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _WeeklyConsistency(consistency: overview.weeklyConsistency),
        ],
      ),
    );
  }
}

class _TrackerRows extends StatelessWidget {
  const _TrackerRows({required this.cards, required this.onOpenDetail});

  final List<ProgressTrackerCard> cards;
  final ValueChanged<ProgressTrackerCard> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const _TipCard(
        title: 'No progress data yet',
        message: 'Your tracker snapshots will appear here after the first log.',
      );
    }
    return _ProgressCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final card in cards)
            _TrackerRow(card: card, onTap: () => onOpenDetail(card)),
        ],
      ),
    );
  }
}

class _FeaturedTrackerSection extends StatelessWidget {
  const _FeaturedTrackerSection({
    required this.title,
    required this.subtitle,
    required this.card,
    required this.onOpenDetail,
  });

  final String title;
  final String subtitle;
  final ProgressTrackerCard? card;
  final ValueChanged<ProgressTrackerCard> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final item = card;
    if (item == null) {
      return const SizedBox.shrink();
    }
    final color = _trackerColor(item.code);
    return _ProgressCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => onOpenDetail(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: VitaMateTheme.primaryDeep,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => onOpenDetail(item),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _ProgressRing(
                  percent: item.percent,
                  color: color,
                  label: '${item.percent}%',
                  caption: item.status,
                  size: 96,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _LabeledValue(
                        label: item.title,
                        value: _formatCardValue(item),
                        color: color,
                      ),
                      const SizedBox(height: 12),
                      _ProgressBar(value: item.percent / 100, color: color),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.summary,
                          style: const TextStyle(
                            color: VitaMateTheme.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.days});

  final List<ProgressTimelineDay> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '7-day timeline',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: VitaMateTheme.primaryDeep,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _TimelineDayTile(day: days[index]),
          ),
        ),
      ],
    );
  }
}

class ProgressDetailScreen extends StatefulWidget {
  const ProgressDetailScreen({super.key, required this.card});

  final ProgressTrackerCard card;

  @override
  State<ProgressDetailScreen> createState() => _ProgressDetailScreenState();
}

class _ProgressDetailScreenState extends State<ProgressDetailScreen> {
  late final ProgressDetailController controller;

  @override
  void initState() {
    super.initState();
    controller = ProgressDetailController(tracker: widget.card.code);
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => controller.load(),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.loading && controller.data.title.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.error != null && controller.data.title.isEmpty) {
              return _ErrorState(
                message: controller.error!,
                onRetry: controller.load,
              );
            }
            return RefreshIndicator(
              onRefresh: controller.load,
              child: _ProgressDetailBody(
                card: widget.card,
                detail: controller.data,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProgressDetailBody extends StatelessWidget {
  const _ProgressDetailBody({required this.card, required this.detail});

  final ProgressTrackerCard card;
  final ProgressDetailPayload detail;

  @override
  Widget build(BuildContext context) {
    final color = _trackerColor(card.code);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressCard(
            child: Row(
              children: [
                _ProgressRing(
                  percent: detail.score,
                  color: color,
                  label: '${detail.score}%',
                  caption: detail.status,
                  size: 116,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    detail.insight.isEmpty ? card.summary : detail.insight,
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SummaryCardGrid(cards: detail.summaryCards, color: color),
          const SizedBox(height: 14),
          _TrendCard(points: detail.trend, color: color),
          const SizedBox(height: 14),
          _MetricList(metrics: detail.metrics, color: color),
          for (final section in detail.sections) ...[
            const SizedBox(height: 14),
            _GenericSection(section: section, color: color),
          ],
        ],
      ),
    );
  }
}

class _SummaryCardGrid extends StatelessWidget {
  const _SummaryCardGrid({required this.cards, required this.color});

  final List<ProgressSummaryCard> cards;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards
          .map(
            (card) => SizedBox(
              width: MediaQuery.of(context).size.width / 2 - 21,
              child: _ProgressCard(
                padding: const EdgeInsets.all(14),
                child: _LabeledValue(
                  label: card.label,
                  value: _formatValue(card.current, card.target, card.unit),
                  color: color,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points, required this.color});

  final List<ProgressTrendPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }
    return _ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly trend',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendPainter(
                values: points
                    .map((point) => point.percent / 100)
                    .toList(growable: false),
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: points
                .map(
                  (point) => Expanded(
                    child: Text(
                      DateFormat.E().format(point.date),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _MetricList extends StatelessWidget {
  const _MetricList({required this.metrics, required this.color});

  final List<ProgressMetric> metrics;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const SizedBox.shrink();
    }
    return _ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed progress',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 12),
          for (final metric in metrics) ...[
            _MetricRow(
              metric: metric,
              color: metric.limit ? _limitColor(metric) : color,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _GenericSection extends StatelessWidget {
  const _GenericSection({required this.section, required this.color});

  final ProgressDetailSection section;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (section.items.isEmpty) {
      return const SizedBox.shrink();
    }
    return _ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: section.items
                .take(8)
                .map((item) {
                  final label =
                      item['label']?.toString() ??
                      item['title']?.toString() ??
                      item['habit_type']?.toString() ??
                      'Item';
                  final progress = item['progress'];
                  final percent = progress is Map
                      ? (progress['adherence_percent'] as num?)?.round()
                      : null;
                  return _MiniPill(
                    label: percent == null ? label : '$label $percent%',
                    color: color,
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: VitaMateTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CompactTrackerTile extends StatelessWidget {
  const _CompactTrackerTile({required this.card, required this.onTap});

  final ProgressTrackerCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _trackerColor(card.code);
    return SizedBox(
      width: 132,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: VitaMateTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_trackerIcon(card.code), color: color),
                const SizedBox(height: 8),
                Text(
                  card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  '${card.percent}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                _ProgressBar(value: card.percent / 100, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackerRow extends StatelessWidget {
  const _TrackerRow({required this.card, required this.onTap});

  final ProgressTrackerCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _trackerColor(card.code);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(_trackerIcon(card.code), color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    card.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 96,
              child: _ProgressBar(value: card.percent / 100, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              '${card.percent}%',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: VitaMateTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyConsistency extends StatelessWidget {
  const _WeeklyConsistency({required this.consistency});

  final ProgressWeeklyConsistency consistency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'You completed ${consistency.daysMet} of ${consistency.totalDays} days',
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _MiniPill(
            label: '${consistency.percent}% consistent',
            color: VitaMateTheme.success,
          ),
        ],
      ),
    );
  }
}

class _TimelineDayTile extends StatelessWidget {
  const _TimelineDayTile({required this.day});

  final ProgressTimelineDay day;

  @override
  Widget build(BuildContext context) {
    final color = day.complete ? VitaMateTheme.success : VitaMateTheme.primary;
    return Container(
      width: 88,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: day.complete ? color : VitaMateTheme.border,
          width: day.complete ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            DateFormat.E().format(day.date),
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            DateFormat.MMMd().format(day.date),
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _ProgressRing(
            percent: day.score,
            color: color,
            label: day.complete ? 'OK' : '${day.score}%',
            caption: '',
            size: 44,
            strokeWidth: 4,
          ),
          const Spacer(),
          Text(
            '+${day.points} pts',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.percent,
    required this.color,
    required this.label,
    required this.caption,
    required this.size,
    this.strokeWidth = 9,
  });

  final int percent;
  final Color color;
  final String label;
  final String caption;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: percent.clamp(0, 100) / 100,
          color: color,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: size > 60 ? 22 : 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (caption.isNotEmpty)
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 8,
        color: color,
        backgroundColor: color.withValues(alpha: 0.16),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric, required this.color});

  final ProgressMetric metric;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                metric.label,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              _formatValue(metric.current, metric.target, metric.unit),
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _ProgressBar(value: metric.percent / 100, color: color),
      ],
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: VitaMateTheme.textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}

class _PointsBadge extends StatelessWidget {
  const _PointsBadge({required this.points, required this.level});

  final int points;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, color: VitaMateTheme.primary),
          const SizedBox(width: 6),
          Text(
            '$points pts',
            style: const TextStyle(
              color: VitaMateTheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          _MiniPill(label: 'Lvl $level', color: VitaMateTheme.primary),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _ProgressCard(
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: VitaMateTheme.primary),
          const SizedBox(width: 12),
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
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final base = Paint()
      ..color = color.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value.clamp(0, 1),
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }
    final grid = Paint()
      ..color = VitaMateTheme.border
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    final fill = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = size.height - (values[i].clamp(0, 1) * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..color = color.withValues(alpha: 0.09)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = size.height - (values[i].clamp(0, 1) * size.height);
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

IconData _trackerIcon(String code) {
  switch (code) {
    case 'nutrition':
      return Icons.restaurant_rounded;
    case 'hydration':
      return Icons.water_drop_rounded;
    case 'activity':
      return Icons.local_fire_department_rounded;
    case 'steps':
      return Icons.directions_walk_rounded;
    case 'sleep':
      return Icons.nightlight_round;
    case 'medications':
      return Icons.medication_rounded;
    case 'chronic':
      return Icons.health_and_safety_rounded;
    case 'habits':
      return Icons.flag_rounded;
  }
  return Icons.insights_rounded;
}

Color _trackerColor(String code) {
  switch (code) {
    case 'nutrition':
      return VitaMateTheme.success;
    case 'hydration':
      return const Color(0xFF258BEF);
    case 'activity':
      return VitaMateTheme.danger;
    case 'steps':
      return const Color(0xFF34A853);
    case 'sleep':
      return VitaMateTheme.primary;
    case 'medications':
      return VitaMateTheme.primary;
    case 'chronic':
      return const Color(0xFF5B4BE8);
    case 'habits':
      return VitaMateTheme.warning;
  }
  return VitaMateTheme.primary;
}

Color _limitColor(ProgressMetric metric) {
  if (metric.target != null && metric.current > metric.target!) {
    return VitaMateTheme.danger;
  }
  return VitaMateTheme.warning;
}

String _formatCardValue(ProgressTrackerCard card) {
  return _formatValue(card.current, card.target, card.unit);
}

String _formatValue(double current, double? target, String unit) {
  final currentText = _formatNumber(current, unit);
  if (target == null || target <= 0) {
    return '$currentText $unit'.trim();
  }
  return '$currentText / ${_formatNumber(target, unit)} $unit'.trim();
}

String _formatNumber(double value, String unit) {
  if (unit == 'steps' || unit == 'kcal' || unit == 'doses') {
    return NumberFormat.decimalPattern().format(value.round());
  }
  if (unit == '%') {
    return '${value.round()}';
  }
  return value.toStringAsFixed(value >= 10 ? 0 : 2);
}
