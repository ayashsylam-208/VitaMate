import 'dart:async';

import 'package:flutter/material.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/user.dart';
import '../../../core/network/network_error_mapper.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../models/motivation_models.dart';
import '../state/motivation_controller.dart';
import 'motivation_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.motivationController,
    this.authRepository,
  });

  final MotivationController? motivationController;
  final AuthRepository? authRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final MotivationController _motivationController;
  late final AuthRepository _authRepository;
  late final bool _ownsController;

  AuthUser? _user;
  bool _loadingUser = true;
  String? _userError;

  @override
  void initState() {
    super.initState();
    _motivationController =
        widget.motivationController ?? MotivationController();
    _authRepository = widget.authRepository ?? AuthRepository(AuthApi());
    _ownsController = widget.motivationController == null;
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loadingUser = true;
      _userError = null;
    });
    try {
      final userFuture = _authRepository.getMe();
      final motivationFuture = _motivationController.loadDetails();
      final user = await userFuture;
      await motivationFuture;
      if (!mounted) return;
      setState(() {
        _user = user;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userError = NetworkErrorMapper.toMessage(
          e,
          fallback: 'Failed to load profile',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loadingUser = false);
      }
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _motivationController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 4),
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _motivationController,
          builder: (context, _) {
            if (_loadingUser && user == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_userError != null && user == null) {
              return _ProfileError(message: _userError!, onRetry: _load);
            }
            if (user == null) {
              return _ProfileError(
                message: 'No user profile loaded.',
                onRetry: _load,
              );
            }
            final motivation = _motivationController.overview;
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                children: [
                  _Card(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: VitaMateTheme.softSurface,
                          child: Text(
                            user.fullName.isEmpty
                                ? 'U'
                                : user.fullName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: VitaMateTheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullName,
                                style: const TextStyle(
                                  color: VitaMateTheme.primaryDeep,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  color: VitaMateTheme.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _Pill(
                                    '${motivation.levelName} L${motivation.level}',
                                  ),
                                  _Pill('${motivation.totalPoints} pts'),
                                  _Pill(
                                    '${motivation.currentStreak} day streak',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TodayTasksCard(
                    missions: _motivationController.missions,
                    loading: _motivationController.loading,
                    onOpenDetails: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MotivationScreen(
                            controller: _motivationController,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal information',
                          style: TextStyle(
                            color: VitaMateTheme.primaryDeep,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _infoLine('Goal', user.profile.goal),
                        _infoLine(
                          'Weight',
                          '${user.profile.weight.toStringAsFixed(1)} kg',
                        ),
                        _infoLine(
                          'Height',
                          '${user.profile.height.toStringAsFixed(0)} cm',
                        ),
                        _infoLine(
                          'Daily step goal',
                          '${user.profile.dailyStepGoal}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rewards & achievements',
                          style: TextStyle(
                            color: VitaMateTheme.primaryDeep,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _infoLine('Daily points', '+${motivation.dailyPoints}'),
                        _infoLine(
                          'Weekly points',
                          '+${motivation.weeklyPoints}',
                        ),
                        _infoLine(
                          'Missions',
                          '${motivation.missionsCompleted}/${motivation.missionsTotal}',
                        ),
                        _infoLine(
                          'Badges earned',
                          '${motivation.badgesEarned}',
                        ),
                        _infoLine(
                          'Longest streak',
                          '${motivation.longestStreak} days',
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MotivationScreen(
                                  controller: _motivationController,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.insights_rounded),
                          label: const Text('View motivation details'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Settings',
                          style: TextStyle(
                            color: VitaMateTheme.primaryDeep,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _infoLine(
                          'Activity reminders',
                          user.profile.enableActivityReminders ? 'On' : 'Off',
                        ),
                        _infoLine(
                          'Water reminders',
                          user.profile.enableWaterReminders ? 'On' : 'Off',
                        ),
                        _infoLine(
                          'Motivation reminders',
                          user.profile.enableMotivationReminders ? 'On' : 'Off',
                        ),
                        _infoLine(
                          'Sleep improvement',
                          user.profile.enableSleepImprovement ? 'On' : 'Off',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
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

class _TodayTasksCard extends StatelessWidget {
  const _TodayTasksCard({
    required this.missions,
    required this.loading,
    required this.onOpenDetails,
  });

  final List<DailyMission> missions;
  final bool loading;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final visibleMissions = missions.take(3).toList(growable: false);
    final completedCount = missions
        .where((mission) => mission.status == 'completed')
        .length;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: VitaMateTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: VitaMateTheme.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's tasks",
                      style: TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      missions.isEmpty
                          ? 'Your daily health tasks will show here.'
                          : '$completedCount/${missions.length} completed',
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onOpenDetails, child: const Text('View')),
            ],
          ),
          const SizedBox(height: 12),
          if (loading && missions.isEmpty)
            const LinearProgressIndicator(minHeight: 6)
          else if (visibleMissions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VitaMateTheme.softSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'No tasks are available yet. Keep tracking and new tasks will appear.',
                style: TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            )
          else
            for (final mission in visibleMissions) ...[
              _TaskMissionRow(mission: mission),
              if (mission != visibleMissions.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _TaskMissionRow extends StatelessWidget {
  const _TaskMissionRow({required this.mission});

  final DailyMission mission;

  @override
  Widget build(BuildContext context) {
    final completed = mission.status == 'completed';
    final progress = (mission.progressPercent / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: completed
            ? VitaMateTheme.success.withValues(alpha: 0.10)
            : VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed
              ? VitaMateTheme.success.withValues(alpha: 0.24)
              : VitaMateTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: completed ? VitaMateTheme.success : VitaMateTheme.textMuted,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                if (mission.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    mission.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completed ? VitaMateTheme.success : VitaMateTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: VitaMateTheme.border),
            ),
            child: Text(
              '+${mission.pointsReward}',
              style: TextStyle(
                color: completed
                    ? VitaMateTheme.success
                    : VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

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
