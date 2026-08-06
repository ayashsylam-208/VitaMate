import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/motivation_models.dart';
import '../state/motivation_controller.dart';
import '../state/motivation_experience_controller.dart';

class MotivationScreen extends StatefulWidget {
  const MotivationScreen({super.key, this.controller});

  final MotivationController? controller;

  @override
  State<MotivationScreen> createState() => _MotivationScreenState();
}

class _MotivationScreenState extends State<MotivationScreen> {
  late final MotivationController _controller;
  late final bool _ownsController;
  final MotivationExperienceController _experienceController =
      MotivationExperienceController.instance;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? MotivationController();
    _ownsController = widget.controller == null;
    _experienceController.start();
    unawaited(_controller.loadDetails());
    unawaited(_experienceController.load(silent: true));
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Motivation progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.loadDetails(),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, _experienceController]),
          builder: (context, _) {
            if (_controller.loading &&
                _controller.missions.isEmpty &&
                _controller.points.days.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_controller.error != null &&
                _controller.missions.isEmpty &&
                _controller.points.days.isEmpty) {
              return _ErrorState(
                message: _controller.error!,
                onRetry: _controller.loadDetails,
              );
            }

            return RefreshIndicator(
              onRefresh: _controller.loadDetails,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _SummaryCard(
                    overview: _controller.overview,
                    feed: _experienceController.feed,
                    unreadCelebrations:
                        _experienceController.unreadCelebrationCount,
                  ),
                  const SizedBox(height: 12),
                  _PointsTrendCard(days: _controller.points.days),
                  const SizedBox(height: 12),
                  _MissionsCard(
                    missions: _controller.missions,
                    onRefreshMission: _controller.refreshMission,
                  ),
                  const SizedBox(height: 12),
                  _BadgesCard(badges: _controller.badges),
                  const SizedBox(height: 12),
                  _TransactionsCard(items: _controller.points.transactions),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.overview,
    required this.feed,
    required this.unreadCelebrations,
  });

  final MotivationOverview overview;
  final MotivationFeed feed;
  final int unreadCelebrations;

  @override
  Widget build(BuildContext context) {
    final summary = feed.summary.hasContent ? feed.summary : overview;
    final focus = feed.focus;
    final previousLevelFloor = ((summary.level - 1) * 1000).clamp(0, 1000000);
    final levelProgress =
        ((summary.totalPoints - previousLevelFloor) /
                (summary.nextLevelThreshold - previousLevelFloor).clamp(
                  1,
                  1000,
                ))
            .clamp(0.0, 1.0);
    return _Card(
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
                      'Journey hub',
                      style: TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.pointsToNextLevel} points to level ${summary.level + 1}',
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _Pill('${summary.levelName} L${summary.level}'),
              if (unreadCelebrations > 0) ...[
                const SizedBox(width: 8),
                _Pill('$unreadCelebrations new'),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill('+${summary.dailyPoints} pts today'),
              _Pill(
                '${summary.missionsCompleted}/${summary.missionsTotal} missions',
              ),
              _Pill('${summary.currentStreak} day streak'),
              _Pill('${summary.totalPoints} total'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: levelProgress,
              minHeight: 8,
              backgroundColor: VitaMateTheme.softSurface,
              valueColor: const AlwaysStoppedAnimation<Color>(
                VitaMateTheme.primary,
              ),
            ),
          ),
          if (focus.hasContent) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VitaMateTheme.softSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.track_changes_rounded,
                    color: VitaMateTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          focus.title,
                          style: const TextStyle(
                            color: VitaMateTheme.primaryDeep,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          focus.subtitle,
                          style: const TextStyle(
                            color: VitaMateTheme.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Pill(
                    focus.rewardPoints > 0 ? '+${focus.rewardPoints}' : 'Goal',
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            summary.insight,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsTrendCard extends StatelessWidget {
  const _PointsTrendCard({required this.days});

  final List<PointTrendDay> days;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly points',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (days.isEmpty)
            const Text(
              'No points recorded yet.',
              style: TextStyle(color: VitaMateTheme.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: days
                  .map(
                    (day) => _Pill(
                      '${DateFormat.E().format(day.date)} +${day.points}',
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _MissionsCard extends StatelessWidget {
  const _MissionsCard({required this.missions, required this.onRefreshMission});

  final List<DailyMission> missions;
  final Future<void> Function(int missionId) onRefreshMission;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily missions',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          if (missions.isEmpty)
            const Text(
              'No missions yet.',
              style: TextStyle(color: VitaMateTheme.textMuted),
            )
          else
            for (final mission in missions) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  mission.title,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  '${mission.currentValue.toStringAsFixed(1)} / ${mission.targetValue.toStringAsFixed(1)}  •  +${mission.pointsReward} pts',
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => onRefreshMission(mission.id),
                ),
              ),
              LinearProgressIndicator(
                value: (mission.progressPercent / 100).clamp(0, 1),
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: VitaMateTheme.softSurface,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({required this.badges});

  final List<BadgeProgress> badges;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Badges',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (badges.isEmpty)
            const Text(
              'Badges will appear as you build streaks.',
              style: TextStyle(color: VitaMateTheme.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badges
                  .map(
                    (badge) => _Pill(
                      badge.earned
                          ? '${badge.name} ✓'
                          : '${badge.name} ${badge.progressPercent}%',
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.items});

  final List<PointTransactionItem> items;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Points history',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text(
              'No transactions yet.',
              style: TextStyle(color: VitaMateTheme.textMuted),
            )
          else
            for (final item in items.take(20))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  item.reason,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  DateFormat('MMM d').format(item.eventDate),
                  style: const TextStyle(color: VitaMateTheme.textMuted),
                ),
                trailing: Text(
                  '${item.points >= 0 ? '+' : ''}${item.points}',
                  style: TextStyle(
                    color: item.points >= 0
                        ? VitaMateTheme.success
                        : VitaMateTheme.danger,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaMateTheme.surface,
        border: Border.all(color: VitaMateTheme.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
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
          fontWeight: FontWeight.w900,
        ),
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
