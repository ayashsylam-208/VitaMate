import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/notifications/notifications_service.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/chronic_guide_card.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../../nutrition/models/food_item.dart';
import '../models/water_log.dart';
import '../state/water_controller.dart';

enum _BeverageSheetMode { catalog, custom }

class WaterScreen extends StatefulWidget {
  const WaterScreen({
    super.key,
    required this.targetValueFromBackend,
    this.targetIsLiters = true,
  });

  final double targetValueFromBackend;
  final bool targetIsLiters;

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  late final WaterController controller;
  bool remindersEnabled = false;
  int intervalMinutes = 60;

  int _targetToMl() {
    if (widget.targetIsLiters) {
      return (widget.targetValueFromBackend * 1000).round();
    }
    return widget.targetValueFromBackend.round();
  }

  @override
  void initState() {
    super.initState();
    controller = WaterController()..load(targetMlFromBackend: _targetToMl());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 1),
      appBar: AppBar(
        title: const Text('Hydration'),
        actions: [
          IconButton(
            onPressed: controller.loading
                ? null
                : () => controller.load(targetMlFromBackend: _targetToMl()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.loading && controller.logs.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.error != null && controller.logs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _HydrationInfoCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_drink_outlined,
                          size: 40,
                          color: VitaMateTheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          controller.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: VitaMateTheme.primaryDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () =>
                  controller.load(targetMlFromBackend: _targetToMl()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
                children: [
                  _HydrationHero(controller: controller),
                  if (controller.chronicHydrationGuides.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _HydrationInfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Condition goals and limits',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: VitaMateTheme.primaryDeep,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Hydration guidance updates automatically when chronic-condition targets change.',
                            style: TextStyle(
                              color: VitaMateTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: controller.chronicHydrationGuides
                                .take(3)
                                .map(
                                  (item) => ChronicGuideCard(
                                    item: item,
                                    compact: true,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _HydrationInfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Beverage logging',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: VitaMateTheme.primaryDeep,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Choose from your beverage catalog or create a reusable private drink.',
                          style: TextStyle(
                            color: VitaMateTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: controller.saving
                                ? null
                                : () => _openAddBeverageSheet(),
                            icon: controller.saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add_rounded),
                            label: const Text('Add Beverage'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _QuickDrinkButton(
                              label: 'Water',
                              amountLabel: '250 ml',
                              color: VitaMateTheme.primary,
                              onTap: controller.saving
                                  ? null
                                  : () => _quickLogWater(250),
                            ),
                            _QuickDrinkButton(
                              label: 'Tea',
                              amountLabel: '250 ml',
                              color: VitaMateTheme.accent,
                              onTap: controller.saving
                                  ? null
                                  : () => _openAddBeverageSheet(
                                      initialQuery: 'tea',
                                      initialAmountMl: 250,
                                    ),
                            ),
                            _QuickDrinkButton(
                              label: 'Coffee',
                              amountLabel: '200 ml',
                              color: VitaMateTheme.warning,
                              onTap: controller.saving
                                  ? null
                                  : () => _openAddBeverageSheet(
                                      initialQuery: 'coffee',
                                      initialAmountMl: 200,
                                    ),
                            ),
                            _QuickDrinkButton(
                              label: 'Juice',
                              amountLabel: '200 ml',
                              color: VitaMateTheme.danger,
                              onTap: controller.saving
                                  ? null
                                  : () => _openAddBeverageSheet(
                                      initialQuery: 'juice',
                                      initialAmountMl: 200,
                                    ),
                            ),
                          ],
                        ),
                        if (controller.error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            controller.error!,
                            style: const TextStyle(
                              color: VitaMateTheme.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HydrationInfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hydration reminders',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: VitaMateTheme.primaryDeep,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile.adaptive(
                          value: remindersEnabled,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Keep hydration reminders on'),
                          subtitle: Text(
                            'Every $intervalMinutes minutes',
                            style: const TextStyle(
                              color: VitaMateTheme.textMuted,
                            ),
                          ),
                          onChanged: (value) async {
                            setState(() => remindersEnabled = value);
                            if (value) {
                              await NotificationsService.scheduleWaterInterval(
                                intervalMinutes: intervalMinutes,
                              );
                              await NotificationsService.showWaterEnabled(
                                intervalMinutes,
                              );
                              _showSnack('Hydration reminders enabled');
                            } else {
                              await NotificationsService.cancelWater();
                              _showSnack('Hydration reminders disabled');
                            }
                          },
                        ),
                        Slider(
                          value: intervalMinutes.toDouble(),
                          min: 30,
                          max: 180,
                          divisions: 5,
                          label: '$intervalMinutes min',
                          onChanged: (value) =>
                              setState(() => intervalMinutes = value.round()),
                          onChangeEnd: (value) {
                            if (remindersEnabled) {
                              NotificationsService.scheduleWaterInterval(
                                intervalMinutes: value.round(),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Today logs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: VitaMateTheme.primaryDeep,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (controller.logs.isEmpty)
                    const _HydrationInfoCard(
                      child: Text(
                        'No beverages logged yet today.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: VitaMateTheme.textMuted,
                        ),
                      ),
                    )
                  else
                    ...controller.logs.map(
                      (log) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HydrationLogTile(log: log),
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

  Future<void> _quickLogWater(int amountMl) async {
    final saved = await controller.addNamedBeverage(
      amountMl: amountMl,
      beverageType: 'water',
      beverageName: 'Water',
    );
    if (!mounted) {
      return;
    }
    _showSnack(
      saved
          ? 'Added to hydration and nutrition'
          : (controller.error ?? 'Could not save beverage log.'),
    );
  }

  Future<void> _openAddBeverageSheet({
    String initialQuery = '',
    int initialAmountMl = 250,
    _BeverageSheetMode initialMode = _BeverageSheetMode.catalog,
  }) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBeverageSheet(
        controller: controller,
        initialQuery: initialQuery,
        initialAmountMl: initialAmountMl,
        initialMode: initialMode,
      ),
    );

    if (message == null || !mounted) {
      return;
    }
    _showSnack(message);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HydrationHero extends StatelessWidget {
  const _HydrationHero({required this.controller});

  final WaterController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s hydration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Every beverage here updates hydration and nutrition together.',
            style: TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
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
                        value: controller.progress,
                        strokeWidth: 6,
                        backgroundColor: VitaMateTheme.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          VitaMateTheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      '${(controller.progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 18,
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
                      '${controller.consumedMl} / ${controller.targetMl} ml',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: VitaMateTheme.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Remaining ${controller.remainingMl} ml',
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ScorePill(
                          label: '+${controller.waterPointsToday} pts',
                          color: VitaMateTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        _ScorePill(
                          label: '${controller.logs.length} logs',
                          color: VitaMateTheme.accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: controller.progress,
              minHeight: 8,
              backgroundColor: VitaMateTheme.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                VitaMateTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HydrationInfoCard extends StatelessWidget {
  const _HydrationInfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _QuickDrinkButton extends StatelessWidget {
  const _QuickDrinkButton({
    required this.label,
    required this.amountLabel,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String amountLabel;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              amountLabel,
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HydrationLogTile extends StatelessWidget {
  const _HydrationLogTile({required this.log});

  final WaterLog log;

  @override
  Widget build(BuildContext context) {
    final color = _beverageColor(log.beverageType);
    final preview = log.nutritionPreview;
    final summaryBits = <String>['${log.amountMl} ml'];
    if (log.hydrationMl > 0 && log.hydrationMl != log.amountMl) {
      summaryBits.add('hydrates ${log.hydrationMl} ml');
    }
    if (preview != null && preview.calories > 0) {
      summaryBits.add('${preview.calories.round()} kcal');
    }
    if (preview != null && preview.sugars > 0) {
      summaryBits.add('${_formatMetric(preview.sugars)} g sugars');
    }
    if (preview != null && preview.caffeine > 0) {
      summaryBits.add('${preview.caffeine.round()} mg caffeine');
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_beverageIcon(log.beverageType), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: VitaMateTheme.primaryDeep,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summaryBits.join(' - '),
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (log.linkedMealLogId != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ScorePill(
                        label: log.beverageType == 'water'
                            ? 'Hydration'
                            : 'Drink',
                        color: color,
                      ),
                      const _ScorePill(
                        label: 'Synced to nutrition',
                        color: VitaMateTheme.primary,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
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

class _AddBeverageSheet extends StatefulWidget {
  const _AddBeverageSheet({
    required this.controller,
    required this.initialQuery,
    required this.initialAmountMl,
    required this.initialMode,
  });

  final WaterController controller;
  final String initialQuery;
  final int initialAmountMl;
  final _BeverageSheetMode initialMode;

  @override
  State<_AddBeverageSheet> createState() => _AddBeverageSheetState();
}

class _AddBeverageSheetState extends State<_AddBeverageSheet> {
  final _searchController = TextEditingController();
  final _amountController = TextEditingController();
  final _customNameController = TextEditingController();
  final _caloriesController = TextEditingController(text: '0');
  final _proteinController = TextEditingController(text: '0');
  final _carbsController = TextEditingController(text: '0');
  final _fatController = TextEditingController(text: '0');
  final _sugarsController = TextEditingController(text: '0');
  final _fiberController = TextEditingController(text: '0');
  final _sodiumController = TextEditingController(text: '0');
  final _waterController = TextEditingController(text: '100');
  final _caffeineController = TextEditingController(text: '0');
  Timer? _searchDebounce;
  _BeverageSheetMode _mode = _BeverageSheetMode.catalog;
  FoodItem? _selectedItem;
  String _customType = 'Other';
  bool _saveForReuse = true;

  int get _amountMl => int.tryParse(_amountController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _searchController.text = widget.initialQuery;
    _amountController.text = widget.initialAmountMl.toString();
    _customNameController.text = widget.initialQuery;
    _searchController.addListener(_handleSearchInput);
    for (final controller in [
      _amountController,
      _customNameController,
      _caloriesController,
      _proteinController,
      _carbsController,
      _fatController,
      _sugarsController,
      _fiberController,
      _sodiumController,
      _waterController,
      _caffeineController,
    ]) {
      controller.addListener(_refreshPreview);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchCatalog(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _amountController.dispose();
    _customNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _sugarsController.dispose();
    _fiberController.dispose();
    _sodiumController.dispose();
    _waterController.dispose();
    _caffeineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: const BoxDecoration(
          color: VitaMateTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: VitaMateTheme.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add Beverage',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: VitaMateTheme.primaryDeep,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Log hydration once and keep nutrition in sync.',
                    style: TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SheetModeButton(
                        label: 'Catalog',
                        selected: _mode == _BeverageSheetMode.catalog,
                        onTap: () =>
                            setState(() => _mode = _BeverageSheetMode.catalog),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SheetModeButton(
                        label: 'Custom',
                        selected: _mode == _BeverageSheetMode.custom,
                        onTap: () =>
                            setState(() => _mode = _BeverageSheetMode.custom),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: AnimatedBuilder(
                    animation: widget.controller,
                    builder: (context, _) {
                      return _mode == _BeverageSheetMode.catalog
                          ? _buildCatalogMode()
                          : _buildCustomMode();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogMode() {
    final results = widget.controller.beverageCatalog;
    final groupedResults = _groupCatalogItems(results);
    final previewItem = _selectedItem;
    final factor = _amountMl <= 0 ? 0 : _amountMl / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Search beverages',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount',
            suffixText: 'ml',
          ),
        ),
        if (previewItem != null) ...[
          const SizedBox(height: 12),
          _PreviewBlock(
            title: previewItem.name,
            subtitle: previewItem.supportingLabel,
            metrics: [
              _PreviewMetric(
                'Calories',
                '${(previewItem.calories100g * factor).round()} kcal',
              ),
              _PreviewMetric(
                'Carbs',
                '${_formatMetric(previewItem.carbs100g * factor)} g',
              ),
              _PreviewMetric(
                'Sugars',
                '${_formatMetric(previewItem.sugars100g * factor)} g',
              ),
              if (previewItem.hydrationContributionMl(_amountMl) != null)
                _PreviewMetric(
                  'Hydration',
                  '${previewItem.hydrationContributionMl(_amountMl)} ml',
                ),
              _PreviewMetric(
                'Caffeine',
                '${(previewItem.caffeineMg * factor).round()} mg',
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'Catalog',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: VitaMateTheme.primaryDeep,
              ),
            ),
            const Spacer(),
            if (widget.controller.catalogLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: results.isEmpty
              ? _HydrationInfoCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.controller.catalogError ??
                            'No beverage matched this search.',
                        style: const TextStyle(
                          color: VitaMateTheme.primaryDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a custom beverage to keep hydration and nutrition connected.',
                        style: TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _mode = _BeverageSheetMode.custom;
                            if (_customNameController.text.trim().isEmpty) {
                              _customNameController.text = _searchController
                                  .text
                                  .trim();
                            }
                          });
                        },
                        child: const Text('Create custom beverage'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: groupedResults.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final section = groupedResults[index];
                    return _CatalogGroupSection(
                      section: section,
                      selectedItemId: _selectedItem?.id,
                      onTapItem: (item) => setState(() => _selectedItem = item),
                    );
                  },
                ),
        ),
        if (widget.controller.error != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.controller.error!,
            style: const TextStyle(
              color: VitaMateTheme.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.controller.saving ? null : _saveCatalog,
            child: const Text('Save beverage'),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomMode() {
    final factor = _amountMl <= 0 ? 0 : _amountMl / 100.0;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _customNameController,
            decoration: const InputDecoration(labelText: 'Beverage name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _customType,
            decoration: const InputDecoration(labelText: 'Beverage type'),
            items: const [
              DropdownMenuItem(value: 'Water', child: Text('Water')),
              DropdownMenuItem(value: 'Tea', child: Text('Tea')),
              DropdownMenuItem(value: 'Coffee', child: Text('Coffee')),
              DropdownMenuItem(value: 'Juice', child: Text('Juice')),
              DropdownMenuItem(value: 'Smoothie', child: Text('Smoothie')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) =>
                setState(() => _customType = value ?? 'Other'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              suffixText: 'ml',
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Per 100 ml',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricInput(
                  controller: _caloriesController,
                  label: 'Calories',
                  suffix: 'kcal',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricInput(
                  controller: _proteinController,
                  label: 'Protein',
                  suffix: 'g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricInput(
                  controller: _carbsController,
                  label: 'Carbs',
                  suffix: 'g',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricInput(
                  controller: _fatController,
                  label: 'Fat',
                  suffix: 'g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Advanced nutrition',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: VitaMateTheme.primaryDeep,
                ),
              ),
              subtitle: const Text(
                'Sugars, fiber, sodium, hydration, caffeine',
                style: TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricInput(
                        controller: _sugarsController,
                        label: 'Sugars',
                        suffix: 'g',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricInput(
                        controller: _fiberController,
                        label: 'Fiber',
                        suffix: 'g',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricInput(
                        controller: _sodiumController,
                        label: 'Sodium',
                        suffix: 'mg',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricInput(
                        controller: _waterController,
                        label: 'Hydration',
                        suffix: 'ml',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _HydrationHint(
                        waterValue: _parseMetric(_waterController.text),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricInput(
                        controller: _caffeineController,
                        label: 'Caffeine',
                        suffix: 'mg',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SwitchListTile.adaptive(
            value: _saveForReuse,
            contentPadding: EdgeInsets.zero,
            title: const Text('Save for reuse'),
            subtitle: const Text(
              'Keep this custom beverage private to your account.',
              style: TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: (value) => setState(() => _saveForReuse = value),
          ),
          _PreviewBlock(
            title: _customNameController.text.trim().isEmpty
                ? 'Custom beverage'
                : _customNameController.text.trim(),
            subtitle: _customType,
            metrics: [
              _PreviewMetric(
                'Calories',
                '${(_parseMetric(_caloriesController.text) * factor).round()} kcal',
              ),
              _PreviewMetric(
                'Carbs',
                '${_formatMetric(_parseMetric(_carbsController.text) * factor)} g',
              ),
              _PreviewMetric(
                'Sugars',
                '${_formatMetric(_parseMetric(_sugarsController.text) * factor)} g',
              ),
              _PreviewMetric(
                'Hydration',
                '${(_parseMetric(_waterController.text) * factor).round()} ml',
              ),
              _PreviewMetric(
                'Caffeine',
                '${(_parseMetric(_caffeineController.text) * factor).round()} mg',
              ),
            ],
          ),
          if (widget.controller.error != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.controller.error!,
              style: const TextStyle(
                color: VitaMateTheme.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.controller.saving ? null : _saveCustom,
              child: const Text('Save beverage'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSearchInput() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _searchCatalog(_searchController.text),
    );
  }

  Future<void> _searchCatalog(String query) async {
    await widget.controller.searchBeverages(query);
    if (!mounted) {
      return;
    }
    final results = widget.controller.beverageCatalog;
    FoodItem? next = _selectedItem;
    final nextId = next?.id;
    if (nextId != null && !results.any((item) => item.id == nextId)) {
      next = null;
    }
    next ??= _findExactCatalogItem(results, query);
    next ??= results.isEmpty ? null : results.first;
    setState(() => _selectedItem = next);
  }

  Future<void> _saveCatalog() async {
    if (_selectedItem == null) {
      _showSheetMessage('Choose a beverage first.');
      return;
    }
    if (_amountMl <= 0) {
      _showSheetMessage('Enter a valid amount in ml.');
      return;
    }
    final saved = await widget.controller.addCatalogBeverage(
      foodItemId: _selectedItem!.id,
      amountMl: _amountMl,
    );
    if (!mounted || !saved) {
      return;
    }
    Navigator.of(context).pop('Added to hydration and nutrition');
  }

  Future<void> _saveCustom() async {
    if (_customNameController.text.trim().isEmpty) {
      _showSheetMessage('Enter a beverage name.');
      return;
    }
    if (_amountMl <= 0) {
      _showSheetMessage('Enter a valid amount in ml.');
      return;
    }
    final saved = await widget.controller.addCustomBeverage(
      amountMl: _amountMl,
      name: _customNameController.text.trim(),
      beverageType: _customType,
      caloriesKcal: _parseMetric(_caloriesController.text),
      proteinG: _parseMetric(_proteinController.text),
      carbohydratesG: _parseMetric(_carbsController.text),
      fatG: _parseMetric(_fatController.text),
      sugarsG: _parseMetric(_sugarsController.text),
      fiberG: _parseMetric(_fiberController.text),
      sodiumMg: _parseMetric(_sodiumController.text),
      waterG: _parseMetric(_waterController.text),
      caffeineMg: _parseMetric(_caffeineController.text),
      saveForReuse: _saveForReuse,
    );
    if (!mounted || !saved) {
      return;
    }
    Navigator.of(context).pop('Added to hydration and nutrition');
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showSheetMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SheetModeButton extends StatelessWidget {
  const _SheetModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? VitaMateTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? VitaMateTheme.primary : VitaMateTheme.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : VitaMateTheme.primaryDeep,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CatalogResultTile extends StatelessWidget {
  const _CatalogResultTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FoodItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? VitaMateTheme.softSurface
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? VitaMateTheme.primary : VitaMateTheme.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: VitaMateTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_catalogItemIcon(item), color: VitaMateTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _catalogSubtitle(item),
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (item.isUserOwned)
              const _ScorePill(label: 'Private', color: VitaMateTheme.accent),
          ],
        ),
      ),
    );
  }
}

class _CatalogGroupSection extends StatelessWidget {
  const _CatalogGroupSection({
    required this.section,
    required this.selectedItemId,
    required this.onTapItem,
  });

  final _CatalogSection section;
  final int? selectedItemId;
  final ValueChanged<FoodItem> onTapItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            section.label,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        for (var i = 0; i < section.items.length; i++) ...[
          _CatalogResultTile(
            item: section.items[i],
            selected: section.items[i].id == selectedItemId,
            onTap: () => onTapItem(section.items[i]),
          ),
          if (i != section.items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MetricInput extends StatelessWidget {
  const _MetricInput({
    required this.controller,
    required this.label,
    required this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }
}

class _HydrationHint extends StatelessWidget {
  const _HydrationHint({required this.waterValue});

  final double waterValue;

  @override
  Widget build(BuildContext context) {
    final normalized = waterValue.clamp(0, 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: VitaMateTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Text(
        'Hydration ratio $normalized%',
        style: const TextStyle(
          color: VitaMateTheme.primaryDeep,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock({
    required this.title,
    required this.subtitle,
    required this.metrics,
  });

  final String title;
  final String subtitle;
  final List<_PreviewMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VitaMateTheme.border),
      ),
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
            subtitle,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in metrics)
                _ScorePill(
                  label: '${metric.label}: ${metric.value}',
                  color: VitaMateTheme.primaryDeep,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewMetric {
  const _PreviewMetric(this.label, this.value);

  final String label;
  final String value;
}

class _CatalogSection {
  const _CatalogSection({required this.label, required this.items});

  final String label;
  final List<FoodItem> items;
}

IconData _beverageIcon(String type) {
  switch (type) {
    case 'tea':
      return Icons.emoji_food_beverage_outlined;
    case 'coffee':
      return Icons.coffee_outlined;
    case 'juice':
      return Icons.local_bar_outlined;
    case 'smoothie':
      return Icons.blender_outlined;
    case 'other':
      return Icons.local_drink_outlined;
    default:
      return Icons.water_drop_outlined;
  }
}

Color _beverageColor(String type) {
  switch (type) {
    case 'tea':
      return VitaMateTheme.accent;
    case 'coffee':
      return VitaMateTheme.warning;
    case 'juice':
      return VitaMateTheme.danger;
    case 'smoothie':
      return VitaMateTheme.success;
    case 'other':
      return VitaMateTheme.primaryDeep;
    default:
      return VitaMateTheme.primary;
  }
}

FoodItem? _findExactCatalogItem(List<FoodItem> items, String query) {
  final target = query.trim().toLowerCase();
  if (target.isEmpty) {
    return null;
  }
  for (final item in items) {
    if (item.name.trim().toLowerCase() == target) {
      return item;
    }
  }
  return null;
}

List<_CatalogSection> _groupCatalogItems(List<FoodItem> items) {
  final grouped = <String, List<FoodItem>>{};
  for (final item in items) {
    final label = _catalogGroupLabel(item);
    grouped.putIfAbsent(label, () => <FoodItem>[]).add(item);
  }
  final sections = grouped.entries
      .map((entry) => _CatalogSection(label: entry.key, items: entry.value))
      .toList();
  sections.sort((a, b) {
    final weightDiff =
        _catalogGroupSortWeight(a.label) - _catalogGroupSortWeight(b.label);
    if (weightDiff != 0) {
      return weightDiff;
    }
    return a.label.compareTo(b.label);
  });
  return sections;
}

String _catalogGroupLabel(FoodItem item) {
  final category = item.supportingLabel.trim();
  if (category.isNotEmpty) {
    return category;
  }
  return 'Beverages';
}

int _catalogGroupSortWeight(String label) {
  switch (label.trim().toLowerCase()) {
    case 'water':
      return 0;
    case 'tea':
      return 1;
    case 'coffee':
      return 2;
    case 'juice':
      return 3;
    case 'smoothie':
      return 4;
    default:
      return 99;
  }
}

String _catalogSubtitle(FoodItem item) {
  final parts = <String>[
    item.supportingLabel,
    '${item.calories100g} kcal/100 ml',
  ];
  final hydrationRatio = item.hydrationRatio;
  if (hydrationRatio != null) {
    parts.add('${(hydrationRatio * 100).round()}% hydration');
  }
  return parts.where((part) => part.trim().isNotEmpty).join(' - ');
}

IconData _catalogItemIcon(FoodItem item) {
  final text = '${item.name} ${item.category}'.toLowerCase();
  if (text.contains('water')) return Icons.water_drop_outlined;
  if (text.contains('tea')) return Icons.emoji_food_beverage_outlined;
  if (text.contains('coffee')) return Icons.coffee_outlined;
  if (text.contains('juice')) return Icons.local_bar_outlined;
  if (text.contains('smoothie') || text.contains('shake')) {
    return Icons.blender_outlined;
  }
  return Icons.local_drink_outlined;
}

double _parseMetric(String raw) {
  return double.tryParse(raw.trim()) ?? 0;
}

String _formatMetric(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
