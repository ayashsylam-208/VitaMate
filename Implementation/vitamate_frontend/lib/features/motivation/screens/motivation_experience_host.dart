import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../models/motivation_models.dart';
import '../services/motivation_sound_service.dart';
import '../state/motivation_experience_controller.dart';

class MotivationExperienceHost extends StatefulWidget {
  const MotivationExperienceHost({super.key, required this.child});

  final Widget child;

  @override
  State<MotivationExperienceHost> createState() =>
      _MotivationExperienceHostState();
}

class _MotivationExperienceHostState extends State<MotivationExperienceHost> {
  static const String _pillAlignmentXKey =
      'motivation_status_pill_alignment_x_v1';
  static const String _pillAlignmentYKey =
      'motivation_status_pill_alignment_y_v1';
  static const Size _fallbackPillSize = Size(112, 50);

  final MotivationExperienceController _controller =
      MotivationExperienceController.instance;
  final MotivationSoundService _soundService = const MotivationSoundService();
  final GlobalKey _pillKey = GlobalKey();
  Timer? _dismissTimer;
  int? _currentCelebrationId;
  Alignment? _pillAlignment;
  Size _pillSize = _fallbackPillSize;
  bool _userMovedPill = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleCelebrationChange);
    unawaited(_restorePillPosition());
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.removeListener(_handleCelebrationChange);
    super.dispose();
  }

  void _handleCelebrationChange() {
    final current = _controller.activeCelebration;
    if (current == null || current.id == _currentCelebrationId) {
      return;
    }
    _currentCelebrationId = current.id;
    unawaited(_soundService.playFor(current));
    _dismissTimer?.cancel();
    final duration = _isPointsBurst(current)
        ? const Duration(milliseconds: 1200)
        : const Duration(milliseconds: 3200);
    _dismissTimer = Timer(
      duration,
      () => _controller.dismissActiveCelebration(),
    );
  }

  Future<void> _openCelebration(MotivationCelebration celebration) async {
    _dismissTimer?.cancel();
    await _controller.dismissActiveCelebration();
    if (celebration.route.trim().isEmpty) {
      return;
    }
    await pushAppRoute(celebration.route);
  }

  Future<void> _restorePillPosition() async {
    final preferences = await SharedPreferences.getInstance();
    final x = preferences.getDouble(_pillAlignmentXKey);
    final y = preferences.getDouble(_pillAlignmentYKey);
    if (!mounted || _userMovedPill || x == null || y == null) {
      return;
    }
    setState(() {
      _pillAlignment = Alignment(x.clamp(-1.0, 1.0), y.clamp(-1.0, 1.0));
    });
  }

  Future<void> _savePillPosition() async {
    final alignment = _pillAlignment;
    if (alignment == null) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await Future.wait<void>([
      preferences.setDouble(_pillAlignmentXKey, alignment.x),
      preferences.setDouble(_pillAlignmentYKey, alignment.y),
    ]);
  }

  void _measurePill() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final nextSize = _pillKey.currentContext?.size;
      if (nextSize == null || nextSize == _pillSize) {
        return;
      }
      setState(() => _pillSize = nextSize);
    });
  }

  void _movePill({
    required DragUpdateDetails details,
    required _PillDragBounds bounds,
  }) {
    final current = bounds.positionFor(_pillAlignment);
    final next = bounds.clamp(current + details.delta);
    setState(() {
      _userMovedPill = true;
      _pillAlignment = bounds.alignmentFor(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final celebration = _controller.activeCelebration;
        final showStatusPill = _shouldShowStatusPill();
        final isBurst = celebration != null && _isPointsBurst(celebration);
        return LayoutBuilder(
          builder: (context, constraints) {
            final bounds = _PillDragBounds.fromLayout(
              constraints: constraints,
              safePadding: MediaQuery.paddingOf(context),
              pillSize: _pillSize,
            );
            final pillPosition = bounds.positionFor(_pillAlignment);
            if (showStatusPill) {
              _measurePill();
            }
            return Stack(
              children: [
                widget.child,
                if (showStatusPill)
                  Positioned(
                    left: pillPosition.dx,
                    top: pillPosition.dy,
                    child: Semantics(
                      label:
                          'Movable level and daily points summary. Drag to reposition.',
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (details) =>
                            _movePill(details: details, bounds: bounds),
                        onPanEnd: (_) => unawaited(_savePillPosition()),
                        child: KeyedSubtree(
                          key: _pillKey,
                          child: MotivationStatusPill(feed: _controller.feed),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: pillPosition.dx,
                  top: (pillPosition.dy - 54).clamp(bounds.minY, bounds.maxY),
                  child: IgnorePointer(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      child: isBurst
                          ? _PointsBurst(
                              key: ValueKey<int>(celebration.id),
                              celebration: celebration,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 18,
                  child: IgnorePointer(
                    ignoring: celebration == null || isBurst,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutBack,
                      offset: celebration == null || isBurst
                          ? const Offset(0, -1.2)
                          : Offset.zero,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: celebration == null || isBurst ? 0 : 1,
                        child: celebration == null || isBurst
                            ? const SizedBox.shrink()
                            : _CelebrationBanner(
                                celebration: celebration,
                                onTap: () => _openCelebration(celebration),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isPointsBurst(MotivationCelebration celebration) {
    return celebration.type == 'points_awarded';
  }

  bool _shouldShowStatusPill() {
    if (!_controller.presentationEnabled) {
      return false;
    }
    final feed = _controller.feed;
    return feed.updatedAt != null || feed.summary.hasContent;
  }
}

class _PillDragBounds {
  const _PillDragBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.defaultPosition,
  });

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final Offset defaultPosition;

  factory _PillDragBounds.fromLayout({
    required BoxConstraints constraints,
    required EdgeInsets safePadding,
    required Size pillSize,
  }) {
    const margin = 8.0;
    final minX = margin;
    final minY = safePadding.top + margin;
    final maxX = (constraints.maxWidth - pillSize.width - margin).clamp(
      minX,
      double.infinity,
    );
    final maxY =
        (constraints.maxHeight - safePadding.bottom - pillSize.height - margin)
            .clamp(minY, double.infinity);
    final defaultY =
        (constraints.maxHeight - safePadding.bottom - pillSize.height - 92)
            .clamp(minY, maxY);
    return _PillDragBounds(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      defaultPosition: Offset(maxX - 8, defaultY),
    );
  }

  Offset positionFor(Alignment? alignment) {
    if (alignment == null) {
      return clamp(defaultPosition);
    }
    return Offset(
      minX + ((alignment.x + 1) / 2) * (maxX - minX),
      minY + ((alignment.y + 1) / 2) * (maxY - minY),
    );
  }

  Alignment alignmentFor(Offset position) {
    final safe = clamp(position);
    final xRange = maxX - minX;
    final yRange = maxY - minY;
    return Alignment(
      xRange == 0 ? 0 : (((safe.dx - minX) / xRange) * 2) - 1,
      yRange == 0 ? 0 : (((safe.dy - minY) / yRange) * 2) - 1,
    );
  }

  Offset clamp(Offset position) {
    return Offset(position.dx.clamp(minX, maxX), position.dy.clamp(minY, maxY));
  }
}

class MotivationStatusPill extends StatelessWidget {
  const MotivationStatusPill({super.key, required this.feed});

  final MotivationFeed feed;

  @override
  Widget build(BuildContext context) {
    final summary = feed.summary;
    final levelProgress = _levelProgress(summary);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => pushAppRoute(Routes.score),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: VitaMateTheme.border),
            boxShadow: const [
              BoxShadow(
                color: VitaMateTheme.shadow,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: levelProgress,
                      strokeWidth: 3,
                      backgroundColor: VitaMateTheme.softSurface,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        VitaMateTheme.success,
                      ),
                    ),
                    Center(
                      child: Text(
                        'L${summary.level}',
                        style: const TextStyle(
                          color: VitaMateTheme.primaryDeep,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+${summary.dailyPoints}',
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (summary.currentStreak > 0) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: VitaMateTheme.warning,
                  size: 16,
                ),
                Text(
                  '${summary.currentStreak}',
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsBurst extends StatelessWidget {
  const _PointsBurst({super.key, required this.celebration});

  final MotivationCelebration celebration;

  @override
  Widget build(BuildContext context) {
    final value = celebration.pointsDelta > 0
        ? '+${celebration.pointsDelta} XP'
        : celebration.title;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final opacity = t < 0.72
            ? 1.0
            : (1.0 - ((t - 0.72) / 0.28)).clamp(0.0, 1.0);
        final scale =
            0.74 + (0.36 * Curves.easeOutBack.transform(t.clamp(0.0, 1.0)));
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, -18 * t),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: VitaMateTheme.success,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: VitaMateTheme.shadow,
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

double _levelProgress(MotivationOverview summary) {
  final previousLevelFloor = ((summary.level - 1) * 1000).clamp(0, 1000000);
  final denominator = (summary.nextLevelThreshold - previousLevelFloor).clamp(
    1,
    1000,
  );
  return ((summary.totalPoints - previousLevelFloor) / denominator).clamp(
    0.0,
    1.0,
  );
}

class _CelebrationBanner extends StatelessWidget {
  const _CelebrationBanner({required this.celebration, required this.onTap});

  final MotivationCelebration celebration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (celebration.type) {
      'badge_earned' => Icons.workspace_premium_rounded,
      'level_up' => Icons.rocket_launch_rounded,
      'streak_milestone' => Icons.local_fire_department_rounded,
      'mission_completed' => Icons.check_circle_rounded,
      _ => Icons.stars_rounded,
    };
    final accent = switch (celebration.type) {
      'badge_earned' => VitaMateTheme.warning,
      'level_up' => VitaMateTheme.success,
      'streak_milestone' => VitaMateTheme.danger,
      'mission_completed' => VitaMateTheme.primaryGlow,
      _ => VitaMateTheme.accent,
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [VitaMateTheme.primaryDeep, accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: VitaMateTheme.shadow,
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      celebration.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      celebration.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  celebration.pointsDelta > 0
                      ? '+${celebration.pointsDelta}'
                      : 'View',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
