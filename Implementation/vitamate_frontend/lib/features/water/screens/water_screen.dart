import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/notifications/notifications_service.dart';
import '../../../core/testing/app_test_keys.dart';
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
    this.controller,
    this.autoLoad = true,
  });

  final double targetValueFromBackend;
  final bool targetIsLiters;
  final WaterController? controller;
  final bool autoLoad;

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  late final WaterController controller;
  late final bool _ownsController;
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
    controller = widget.controller ?? WaterController();
    _ownsController = widget.controller == null;
    if (widget.autoLoad) {
      unawaited(controller.load(targetMlFromBackend: _targetToMl()));
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
                key: const ValueKey(AppTestKeys.waterScreen),
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
                            key: const ValueKey(
                              AppTestKeys.waterAddBeverageButton,
                            ),
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
  final _countController = TextEditingController();
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
  _BeverageServingChoice? _selectedCatalogServing;
  _BeverageServingChoice? _selectedCustomServing;
  String _customType = 'Other';
  bool _saveForReuse = true;

  int get _servingCount => int.tryParse(_countController.text.trim()) ?? 0;
  _BeverageServingChoice? get _activeServingChoice =>
      _mode == _BeverageSheetMode.catalog
      ? _selectedCatalogServing
      : _selectedCustomServing;
  int get _amountMl {
    final serving = _activeServingChoice;
    if (serving == null || _servingCount <= 0) {
      return 0;
    }
    return serving.amountMl * _servingCount;
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _searchController.text = widget.initialQuery;
    _countController.text = '1';
    _customNameController.text = widget.initialQuery;
    _searchController.addListener(_handleSearchInput);
    _selectedCustomServing = _customServingChoices(_customType).first;
    for (final controller in [
      _countController,
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
    _countController.dispose();
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
        key: const ValueKey(AppTestKeys.waterAddBeverageSheet),
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
                        onTap: () => setState(() {
                          _mode = _BeverageSheetMode.catalog;
                          _selectedCatalogServing ??= _firstServingChoice(
                            _catalogServingChoices(_selectedItem),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SheetModeButton(
                        label: 'Custom',
                        selected: _mode == _BeverageSheetMode.custom,
                        onTap: () => setState(() {
                          _mode = _BeverageSheetMode.custom;
                          _selectedCustomServing ??= _firstServingChoice(
                            _customServingChoices(_customType),
                          );
                        }),
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
    final searchQuery = _searchController.text.trim();
    final results = _dedupeFoodItemsById(widget.controller.beverageCatalog);
    final waitingForQuery = searchQuery.isNotEmpty && searchQuery.length < 2;
    final selectedItem = _findFoodItemById(results, _selectedItem?.id);
    final selectedItemId = selectedItem?.id;
    final factor = _amountMl <= 0 ? 0 : _amountMl / 100.0;
    final servingChoices = _catalogServingChoices(selectedItem);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey(AppTestKeys.waterSearchField),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Search beverages',
              prefixIcon: Icon(Icons.search_rounded),
              helperText: 'Browse top drinks or type 2+ letters.',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey(
              'water-beverage:${results.map((item) => item.id).join(',')}:$selectedItemId',
            ),
            isExpanded: true,
            initialValue: selectedItemId,
            decoration: const InputDecoration(
              labelText: 'Beverage',
              prefixIcon: Icon(Icons.local_drink_outlined),
            ),
            hint: Text(
              waitingForQuery ? 'Type 2+ letters first' : 'Choose beverage',
            ),
            items: results
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: item.id,
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: widget.controller.catalogLoading || results.isEmpty
                ? null
                : (foodItemId) {
                    final selected = _findFoodItemById(results, foodItemId);
                    setState(() {
                      _selectedItem = selected;
                      _selectedCatalogServing = _firstServingChoice(
                        _catalogServingChoices(selected),
                      );
                    });
                  },
          ),
          if (widget.controller.catalogLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ],
          const SizedBox(height: 12),
          if (selectedItem == null)
            _HydrationInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waitingForQuery
                        ? 'Type at least 2 letters to narrow the beverage list.'
                        : (widget.controller.catalogError ??
                              'Choose a beverage from the catalog.'),
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'If the catalog is too narrow, switch to Custom and keep only the essentials.',
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
                          _customNameController.text = searchQuery;
                        }
                      });
                    },
                    child: const Text('Create custom beverage'),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              selectedItem.supportingLabel,
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_BeverageServingChoice>(
              isExpanded: true,
              initialValue: _selectedCatalogServing,
              decoration: const InputDecoration(
                labelText: 'Serving type',
                prefixIcon: Icon(Icons.local_cafe_outlined),
              ),
              items: servingChoices
                  .map(
                    (choice) => DropdownMenuItem<_BeverageServingChoice>(
                      value: choice,
                      child: Text(
                        choice.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedCatalogServing = value),
            ),
            if (_selectedCatalogServing != null) ...[
              const SizedBox(height: 8),
              Text(
                'Example: 1 ${_selectedCatalogServing!.shortLabel.toLowerCase()}',
                style: const TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Serving count',
                suffixText: _selectedCatalogServing?.shortLabel ?? 'serving',
              ),
            ),
            if (_amountMl > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Total $_amountMl ml',
                style: const TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _PreviewBlock(
              title: selectedItem.name,
              subtitle: '${selectedItem.supportingLabel} - $_amountMl ml',
              metrics: [
                _PreviewMetric(
                  'Calories',
                  '${(selectedItem.calories100g * factor).round()} kcal',
                ),
                _PreviewMetric(
                  'Carbs',
                  '${_formatMetric(selectedItem.carbs100g * factor)} g',
                ),
                _PreviewMetric(
                  'Sugars',
                  '${_formatMetric(selectedItem.sugars100g * factor)} g',
                ),
                if (selectedItem.hydrationContributionMl(_amountMl) != null)
                  _PreviewMetric(
                    'Hydration',
                    '${selectedItem.hydrationContributionMl(_amountMl)} ml',
                  ),
                _PreviewMetric(
                  'Caffeine',
                  '${(selectedItem.caffeineMg * factor).round()} mg',
                ),
              ],
            ),
          ],
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
              key: const ValueKey(AppTestKeys.waterCatalogSaveButton),
              onPressed: widget.controller.saving || selectedItem == null
                  ? null
                  : _saveCatalog,
              child: const Text('Save beverage'),
            ),
          ),
        ],
      ),
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
            onChanged: (value) {
              final nextType = value ?? 'Other';
              setState(() {
                _customType = nextType;
                _selectedCustomServing = _firstServingChoice(
                  _customServingChoices(nextType),
                );
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<_BeverageServingChoice>(
            isExpanded: true,
            initialValue: _selectedCustomServing,
            decoration: const InputDecoration(
              labelText: 'Serving type',
              prefixIcon: Icon(Icons.local_cafe_outlined),
            ),
            items: _customServingChoices(_customType)
                .map(
                  (choice) => DropdownMenuItem<_BeverageServingChoice>(
                    value: choice,
                    child: Text(
                      choice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _selectedCustomServing = value),
          ),
          if (_selectedCustomServing != null) ...[
            const SizedBox(height: 8),
            Text(
              'Example: 1 ${_selectedCustomServing!.shortLabel.toLowerCase()}',
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _countController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Serving count',
              suffixText: _selectedCustomServing?.shortLabel ?? 'serving',
            ),
          ),
          if (_amountMl > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Total $_amountMl ml',
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _PreviewBlock(
            title: _customNameController.text.trim().isEmpty
                ? 'Custom beverage'
                : _customNameController.text.trim(),
            subtitle: '$_customType - $_amountMl ml',
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
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Nutrition details',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: VitaMateTheme.primaryDeep,
                ),
              ),
              subtitle: const Text(
                'Optional values per 100 ml.',
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
              key: const ValueKey(AppTestKeys.waterCustomSaveButton),
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
      const Duration(milliseconds: 350),
      () => _searchCatalog(_searchController.text),
    );
  }

  Future<void> _searchCatalog(String query) async {
    await widget.controller.searchBeverages(query, limit: 12);
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
    setState(() {
      _selectedItem = next;
      _selectedCatalogServing = _firstServingChoice(
        _catalogServingChoices(next),
      );
    });
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

class _BeverageServingChoice {
  const _BeverageServingChoice({
    required this.label,
    required this.shortLabel,
    required this.amountMl,
  });

  final String label;
  final String shortLabel;
  final int amountMl;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _BeverageServingChoice &&
        other.label == label &&
        other.shortLabel == shortLabel &&
        other.amountMl == amountMl;
  }

  @override
  int get hashCode => Object.hash(label, shortLabel, amountMl);
}

_BeverageServingChoice? _firstServingChoice(
  List<_BeverageServingChoice> choices,
) => choices.isEmpty ? null : choices.first;

List<FoodItem> _dedupeFoodItemsById(Iterable<FoodItem> items) {
  final deduped = <int, FoodItem>{};
  for (final item in items) {
    deduped.putIfAbsent(item.id, () => item);
  }
  return deduped.values.toList(growable: false);
}

FoodItem? _findFoodItemById(Iterable<FoodItem> items, int? id) {
  if (id == null) {
    return null;
  }
  for (final item in items) {
    if (item.id == id) {
      return item;
    }
  }
  return null;
}

List<_BeverageServingChoice> _catalogServingChoices(FoodItem? item) {
  if (item == null) {
    return const [];
  }
  final choices = <_BeverageServingChoice>[
    for (final option in item.servingOptions)
      if (_choiceFromServingOption(option) case final choice?) choice,
    if (item.defaultServingUnit.toLowerCase().contains('ml') &&
        item.defaultServingSize > 0)
      _BeverageServingChoice(
        label:
            '${item.defaultServingDisplayLabel} (${item.defaultServingSize.round()} ml)',
        shortLabel: item.defaultServingDisplayLabel,
        amountMl: item.defaultServingSize.round(),
      ),
    if (item.servingGrams > 0)
      _BeverageServingChoice(
        label: '${item.servingLabel} (${item.servingGrams} ml)',
        shortLabel: item.servingLabel,
        amountMl: item.servingGrams,
      ),
  ];
  if (choices.isEmpty) {
    choices.addAll(_genericServingChoices('${item.name} ${item.category}'));
  }
  return _dedupeServingChoices(choices);
}

List<_BeverageServingChoice> _customServingChoices(String beverageType) {
  return _dedupeServingChoices(_genericServingChoices(beverageType));
}

_BeverageServingChoice? _choiceFromServingOption(
  NutritionServingOption option,
) {
  final amount =
      option.millilitersEquivalent ??
      option.gramsEquivalent ??
      (option.unit.toLowerCase().contains('ml') ? option.amount : null);
  if (amount == null || amount <= 0) {
    return null;
  }
  final ml = amount.round();
  return _BeverageServingChoice(
    label: '${option.displayLabel} ($ml ml)',
    shortLabel: option.displayLabel,
    amountMl: ml,
  );
}

List<_BeverageServingChoice> _genericServingChoices(String hint) {
  final normalized = hint.toLowerCase();
  if (normalized.contains('coffee')) {
    return const [
      _BeverageServingChoice(
        label: 'Small cup (150 ml)',
        shortLabel: 'Small cup',
        amountMl: 150,
      ),
      _BeverageServingChoice(
        label: 'Cup (240 ml)',
        shortLabel: 'Cup',
        amountMl: 240,
      ),
      _BeverageServingChoice(
        label: 'Large cup (350 ml)',
        shortLabel: 'Large cup',
        amountMl: 350,
      ),
    ];
  }
  if (normalized.contains('tea')) {
    return const [
      _BeverageServingChoice(
        label: 'Small cup (180 ml)',
        shortLabel: 'Small cup',
        amountMl: 180,
      ),
      _BeverageServingChoice(
        label: 'Cup (250 ml)',
        shortLabel: 'Cup',
        amountMl: 250,
      ),
      _BeverageServingChoice(
        label: 'Pot (400 ml)',
        shortLabel: 'Pot',
        amountMl: 400,
      ),
    ];
  }
  if (normalized.contains('juice') || normalized.contains('smoothie')) {
    return const [
      _BeverageServingChoice(
        label: 'Small glass (180 ml)',
        shortLabel: 'Small glass',
        amountMl: 180,
      ),
      _BeverageServingChoice(
        label: 'Glass (250 ml)',
        shortLabel: 'Glass',
        amountMl: 250,
      ),
      _BeverageServingChoice(
        label: 'Bottle (450 ml)',
        shortLabel: 'Bottle',
        amountMl: 450,
      ),
    ];
  }
  if (normalized.contains('water')) {
    return const [
      _BeverageServingChoice(
        label: 'Cup (250 ml)',
        shortLabel: 'Cup',
        amountMl: 250,
      ),
      _BeverageServingChoice(
        label: 'Glass (330 ml)',
        shortLabel: 'Glass',
        amountMl: 330,
      ),
      _BeverageServingChoice(
        label: 'Bottle (500 ml)',
        shortLabel: 'Bottle',
        amountMl: 500,
      ),
      _BeverageServingChoice(
        label: 'Large bottle (750 ml)',
        shortLabel: 'Large bottle',
        amountMl: 750,
      ),
    ];
  }
  return const [
    _BeverageServingChoice(
      label: 'Small cup (150 ml)',
      shortLabel: 'Small cup',
      amountMl: 150,
    ),
    _BeverageServingChoice(
      label: 'Cup (250 ml)',
      shortLabel: 'Cup',
      amountMl: 250,
    ),
    _BeverageServingChoice(
      label: 'Glass (330 ml)',
      shortLabel: 'Glass',
      amountMl: 330,
    ),
    _BeverageServingChoice(
      label: 'Bottle (500 ml)',
      shortLabel: 'Bottle',
      amountMl: 500,
    ),
  ];
}

List<_BeverageServingChoice> _dedupeServingChoices(
  Iterable<_BeverageServingChoice> choices,
) {
  final deduped = <String, _BeverageServingChoice>{};
  for (final choice in choices) {
    final key = '${choice.amountMl}:${choice.shortLabel.toLowerCase()}';
    deduped.putIfAbsent(key, () => choice);
  }
  final values = deduped.values.toList()
    ..sort((a, b) => a.amountMl.compareTo(b.amountMl));
  return values;
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

double _parseMetric(String raw) {
  return double.tryParse(raw.trim()) ?? 0;
}

String _formatMetric(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
