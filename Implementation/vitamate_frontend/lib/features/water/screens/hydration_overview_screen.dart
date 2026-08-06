import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/routing/routes.dart';
import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/chronic_guide_card.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../models/hydration_summary.dart';
import '../models/water_log.dart';
import '../state/water_controller.dart';
import 'hydration_logs_screen.dart';
import 'hydration_settings_screen.dart';
import 'log_drink_screen.dart';

class HydrationOverviewScreen extends StatefulWidget {
  const HydrationOverviewScreen({
    super.key,
    this.controller,
    this.autoLoad = true,
  });

  final WaterController? controller;
  final bool autoLoad;

  @override
  State<HydrationOverviewScreen> createState() =>
      _HydrationOverviewScreenState();
}

class _HydrationOverviewScreenState extends State<HydrationOverviewScreen> {
  late final WaterController controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? WaterController();
    _ownsController = widget.controller == null;
    if (widget.autoLoad) {
      unawaited(controller.load());
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: -1),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.loading && controller.summary.activeTargetMl == 0) {
              return const _HydrationSkeleton();
            }
            if (controller.error != null &&
                controller.summary.activeTargetMl == 0 &&
                controller.logs.isEmpty) {
              return _HydrationErrorState(
                message: controller.error!,
                onRetry: controller.load,
              );
            }
            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                key: const ValueKey(AppTestKeys.waterScreen),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 118),
                children: [
                  _HydrationTopBar(
                    onBack: _goBack,
                    onViewLog: _openLogs,
                    onSettings: _openSettings,
                  ),
                  const SizedBox(height: 18),
                  HydrationProgressCard(summary: controller.summary),
                  const SizedBox(height: 14),
                  QuickAddRow(saving: controller.saving, onAdd: _quickAdd),
                  const SizedBox(height: 14),
                  _ActionCard(
                    title: 'Log any drink',
                    subtitle:
                        'Water, coffee, tea, juice, milk, soda, or a custom drink.',
                    icon: Icons.add_circle_outline_rounded,
                    onTap: () => _openLogDrink(),
                  ),
                  const SizedBox(height: 14),
                  _DrinkShortcutGrid(onOpenType: _openLogDrink),
                  if (controller.lastDrinkAt != null) ...[
                    const SizedBox(height: 14),
                    LastDrinkStatus(lastDrinkAt: controller.lastDrinkAt!),
                  ],
                  if (controller.chronicHydrationGuides.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ChronicGuideCard(
                      item: controller.chronicHydrationGuides.first,
                      compact: true,
                    ),
                  ],
                  const SizedBox(height: 18),
                  _RecentLogsCard(
                    logs: controller.logs.take(3).toList(growable: false),
                    onViewAll: _openLogs,
                    onEdit: (log) => _openLogDrink(existingLog: log),
                  ),
                  if (controller.error != null) ...[
                    const SizedBox(height: 12),
                    _InlineError(message: controller.error!),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, Routes.home);
  }

  Future<void> _quickAdd(int amountMl) async {
    final saved = await controller.drink(amountMl);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Added $amountMl ml.'
              : controller.error ?? 'Could not add water.',
        ),
      ),
    );
  }

  Future<void> _openLogDrink({
    String preselectedType = 'water',
    WaterLog? existingLog,
  }) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LogDrinkScreen(
          controller: controller,
          preselectedType: preselectedType,
          existingLog: existingLog,
        ),
      ),
    );
    if (changed == true) {
      await controller.load();
    }
  }

  Future<void> _openLogs() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HydrationLogsScreen(controller: controller),
      ),
    );
    if (changed == true) {
      await controller.load();
    }
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HydrationSettingsScreen(controller: controller),
      ),
    );
    if (changed == true) {
      await controller.load();
    }
  }
}

class _HydrationTopBar extends StatelessWidget {
  const _HydrationTopBar({
    required this.onBack,
    required this.onViewLog,
    required this.onSettings,
  });

  final VoidCallback onBack;
  final VoidCallback onViewLog;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          label: 'Back',
          button: true,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE9FAFF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.water_drop_rounded, color: Color(0xFF13A7C7)),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Hydration',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(onPressed: onViewLog, child: const Text('View log')),
        Semantics(
          label: 'Hydration settings',
          button: true,
          child: IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
        ),
      ],
    );
  }
}

class HydrationProgressCard extends StatelessWidget {
  const HydrationProgressCard({super.key, required this.summary});

  final HydrationSummary summary;

  @override
  Widget build(BuildContext context) {
    final complete = summary.goalCompleted;
    final targetLabel = _ml(summary.activeTargetMl);
    final consumedLabel = _ml(summary.hydrationContributionMl);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFEFFBFF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD8EFF8)),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: 'Hydration progress ${summary.progressPercent} percent',
                child: SizedBox(
                  width: 104,
                  height: 104,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 104,
                        height: 104,
                        child: CircularProgressIndicator(
                          value: summary.progressRatio,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          backgroundColor: const Color(0xFFE5F6FB),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            complete
                                ? VitaMateTheme.success
                                : const Color(0xFF13A7C7),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${summary.progressPercent}%',
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              color: VitaMateTheme.primaryDeep,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'today',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              color: VitaMateTheme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complete
                          ? 'Goal completed'
                          : '$consumedLabel / $targetLabel',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      complete
                          ? 'You are covered for today.'
                          : '${_ml(summary.remainingMl)} remaining',
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (summary.adjustmentReasons.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Goal adjusted for today',
                        style: TextStyle(
                          color: Color(0xFF0D7F99),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ContributionTile(
                  label: 'Water',
                  value: _ml(summary.waterContributionMl),
                  icon: Icons.water_drop_rounded,
                  color: const Color(0xFF13A7C7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ContributionTile(
                  label: 'Other drinks',
                  value: _ml(summary.otherDrinksContributionMl),
                  icon: Icons.local_cafe_rounded,
                  color: VitaMateTheme.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContributionTile extends StatelessWidget {
  const _ContributionTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
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

class QuickAddRow extends StatelessWidget {
  const QuickAddRow({super.key, required this.saving, required this.onAdd});

  final bool saving;
  final ValueChanged<int> onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick add water',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final amount in const [150, 250, 500])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilledButton.tonal(
                      onPressed: saving ? null : () => onAdd(amount),
                      child: Text('${amount}ml'),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: VitaMateTheme.softSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: VitaMateTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
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
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class _DrinkShortcutGrid extends StatelessWidget {
  const _DrinkShortcutGrid({required this.onOpenType});

  final void Function({String preselectedType}) onOpenType;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        DrinkTypeShortcut(
          label: 'Coffee',
          icon: Icons.local_cafe_rounded,
          color: VitaMateTheme.warning,
          onTap: () => onOpenType(preselectedType: 'coffee'),
        ),
        DrinkTypeShortcut(
          label: 'Tea',
          icon: Icons.emoji_food_beverage_rounded,
          color: VitaMateTheme.success,
          onTap: () => onOpenType(preselectedType: 'tea'),
        ),
        DrinkTypeShortcut(
          label: 'Juice',
          icon: Icons.local_bar_rounded,
          color: VitaMateTheme.danger,
          onTap: () => onOpenType(preselectedType: 'juice'),
        ),
        DrinkTypeShortcut(
          label: 'Milk',
          icon: Icons.local_drink_rounded,
          color: const Color(0xFF2F8DBF),
          onTap: () => onOpenType(preselectedType: 'milk'),
        ),
        DrinkTypeShortcut(
          label: 'Soda',
          icon: Icons.bubble_chart_rounded,
          color: const Color(0xFF8F62D7),
          onTap: () => onOpenType(preselectedType: 'soda'),
        ),
        DrinkTypeShortcut(
          label: 'Other',
          icon: Icons.edit_note_rounded,
          color: VitaMateTheme.primary,
          onTap: () => onOpenType(preselectedType: 'other'),
        ),
      ],
    );
  }
}

class DrinkTypeShortcut extends StatelessWidget {
  const DrinkTypeShortcut({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Log $label',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: VitaMateTheme.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LastDrinkStatus extends StatelessWidget {
  const LastDrinkStatus({super.key, required this.lastDrinkAt});

  final DateTime lastDrinkAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE9FAFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: Color(0xFF0D7F99),
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Last drink ${_relativeTime(lastDrinkAt)}',
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentLogsCard extends StatelessWidget {
  const _RecentLogsCard({
    required this.logs,
    required this.onViewAll,
    required this.onEdit,
  });

  final List<WaterLog> logs;
  final VoidCallback onViewAll;
  final ValueChanged<WaterLog> onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent drinks',
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(onPressed: onViewAll, child: const Text('All')),
            ],
          ),
          const SizedBox(height: 8),
          if (logs.isEmpty)
            const Text(
              'No drinks logged yet. Add your first one from quick add.',
              style: TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final log in logs)
              _RecentLogTile(log: log, onTap: () => onEdit(log)),
        ],
      ),
    );
  }
}

class _RecentLogTile extends StatelessWidget {
  const _RecentLogTile({required this.log, required this.onTap});

  final WaterLog log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: _drinkColor(log.beverageType).withValues(alpha: 0.12),
        child: Icon(
          _drinkIcon(log.beverageType),
          color: _drinkColor(log.beverageType),
        ),
      ),
      title: Text(
        log.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${_time(log.consumedAt)} - ${_ml(log.hydrationMl)} hydration',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _ml(log.amountMl),
        style: const TextStyle(
          color: VitaMateTheme.primaryDeep,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        color: VitaMateTheme.danger,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _HydrationSkeleton extends StatelessWidget {
  const _HydrationSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 118),
      children: const [
        _SkeletonBox(height: 48),
        SizedBox(height: 18),
        _SkeletonBox(height: 210),
        SizedBox(height: 14),
        _SkeletonBox(height: 116),
        SizedBox(height: 14),
        _SkeletonBox(height: 88),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VitaMateTheme.border),
      ),
    );
  }
}

class _HydrationErrorState extends StatelessWidget {
  const _HydrationErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 118),
      children: [
        const Icon(
          Icons.water_drop_outlined,
          color: VitaMateTheme.primary,
          size: 56,
        ),
        const SizedBox(height: 18),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.96),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: VitaMateTheme.border),
    boxShadow: const [
      BoxShadow(
        color: VitaMateTheme.shadow,
        blurRadius: 16,
        offset: Offset(0, 10),
      ),
    ],
  );
}

String _ml(int value) => '$value ml';

String _time(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _relativeTime(DateTime value) {
  final diff = DateTime.now().difference(value.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

IconData _drinkIcon(String type) {
  switch (type) {
    case 'coffee':
      return Icons.local_cafe_rounded;
    case 'tea':
      return Icons.emoji_food_beverage_rounded;
    case 'juice':
      return Icons.local_bar_rounded;
    case 'milk':
      return Icons.local_drink_rounded;
    case 'soda':
      return Icons.bubble_chart_rounded;
    default:
      return Icons.water_drop_rounded;
  }
}

Color _drinkColor(String type) {
  switch (type) {
    case 'coffee':
      return VitaMateTheme.warning;
    case 'tea':
      return VitaMateTheme.success;
    case 'juice':
      return VitaMateTheme.danger;
    case 'milk':
      return const Color(0xFF2F8DBF);
    case 'soda':
      return const Color(0xFF8F62D7);
    default:
      return const Color(0xFF13A7C7);
  }
}
