import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/health/chronic_target_guide.dart';
import '../../../core/network/network_error_mapper.dart';
import '../../../core/notifications/notifications_service.dart';
import '../../../core/sync/health_sync_bus.dart';
import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../data/nutrition_repository.dart';
import '../models/food_item.dart';
import '../models/meal_log.dart';
import '../models/micronutrient_tracking.dart';
import '../models/nutrition_summary.dart';
import '../state/nutrition_controller.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key, this.controller, this.autoLoad = true});

  final NutritionController? controller;
  final bool autoLoad;

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late final NutritionController controller;
  late final bool _ownsController;

  bool _mealsExpanded = true;
  bool _remindersExpanded = false;
  bool _constraintsExpanded = false;
  bool _micronutrientGoalsExpanded = true;
  bool mealRemindersEnabled = false;
  TimeOfDay breakfast = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay lunch = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay dinner = const TimeOfDay(hour: 19, minute: 0);

  @override
  void initState() {
    super.initState();
    controller =
        widget.controller ??
        NutritionController(repository: NutritionRepository());
    _ownsController = widget.controller == null;
    HealthSyncBus.instance.addListener(_handleTrackerRefresh);
    if (widget.autoLoad) {
      unawaited(controller.load());
    }
  }

  @override
  void dispose() {
    HealthSyncBus.instance.removeListener(_handleTrackerRefresh);
    if (_ownsController) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleTrackerRefresh() {
    if (!HealthSyncBus.instance.affects(const {
      HealthSyncScope.nutrition,
      HealthSyncScope.medication,
    })) {
      return;
    }
    unawaited(controller.refreshMicronutrients());
  }

  Future<void> _pickTime(
    TimeOfDay current,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) {
      onPicked(picked);
    }
  }

  Future<void> _openLogMealSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogMealSheet(controller: controller),
    );
    if (saved == true && mounted) {
      _showSnack('Meal logged');
    }
  }

  Future<void> _openCreateFoodSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateFoodSheet(controller: controller),
    );
    if (saved == true && mounted) {
      _showSnack('Food added to your library');
    }
  }

  Future<void> _openMicronutrientsSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MicronutrientsSheet(controller: controller),
    );
    if (saved == true && mounted) {
      _showSnack('Micronutrient plan saved');
    }
  }

  Future<void> _openNutritionReviewSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NutritionReviewSheet(
        summary: controller.summary,
        detailBreakdown: controller.detailBreakdown,
        micronutrients: controller.micronutrients,
        mealCount: controller.meals.length,
      ),
    );
  }

  void _rescheduleMeals() {
    NotificationsService.scheduleMeals(
      breakfast: _toDateTime(breakfast),
      lunch: _toDateTime(lunch),
      dinner: _toDateTime(dinner),
    );
  }

  DateTime _toDateTime(TimeOfDay t) => DateTime(2000, 1, 1, t.hour, t.minute);

  void _showSnack(String msg) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('hh:mm a');

    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: -1),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final showInitialLoader =
                controller.loading &&
                controller.foods.isEmpty &&
                controller.meals.isEmpty &&
                controller.summary.targetCalories == 0 &&
                controller.summary.consumedCalories == 0;

            if (showInitialLoader) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.error != null &&
                controller.foods.isEmpty &&
                controller.meals.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    controller.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }

            final meals = [...controller.meals]
              ..sort(
                (a, b) => (b.consumedAt ?? DateTime(0)).compareTo(
                  a.consumedAt ?? DateTime(0),
                ),
              );

            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                key: const ValueKey(AppTestKeys.nutritionScreen),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  const Text(
                    'Nutrition',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: VitaMateTheme.primaryDeep,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Track meals, drinks, and daily nutrition in one place.',
                    style: TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (controller.error != null) ...[
                    const SizedBox(height: 14),
                    _InlineMessage(text: controller.error!),
                  ],
                  const SizedBox(height: 18),
                  _NutritionSummaryHero(
                    summary: controller.summary,
                    detailBreakdown: controller.detailBreakdown,
                    mealCount: meals.length,
                    mealPointsToday: controller.mealPointsToday,
                    diabetesActive: controller.diabetesActive,
                    guideCount: controller.chronicNutritionGuides.length,
                    onReviewPressed: _openNutritionReviewSheet,
                  ),
                  const SizedBox(height: 12),
                  _PrimaryGradientButton(
                    key: const ValueKey(AppTestKeys.nutritionLogMealButton),
                    label: 'Log new meal',
                    icon: Icons.add_rounded,
                    onPressed: _openLogMealSheet,
                  ),
                  const SizedBox(height: 12),
                  _SmallTrackButton(
                    label: 'Add vitamins & minerals tracking',
                    icon: Icons.bubble_chart_outlined,
                    onPressed: _openMicronutrientsSheet,
                  ),
                  if (controller
                      .micronutrients
                      .deficiencyTracked
                      .isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionPanel(
                      icon: Icons.bubble_chart_outlined,
                      title: 'Vitamin & mineral goals',
                      badgeLabel:
                          '${controller.micronutrients.deficiencyTracked.length}',
                      expanded: _micronutrientGoalsExpanded,
                      onToggle: () => setState(
                        () => _micronutrientGoalsExpanded =
                            !_micronutrientGoalsExpanded,
                      ),
                      child: _NutritionPanel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            for (
                              var i = 0;
                              i <
                                  controller
                                      .micronutrients
                                      .deficiencyTracked
                                      .length;
                              i++
                            ) ...[
                              _MicronutrientGoalSummaryRow(
                                item: controller
                                    .micronutrients
                                    .deficiencyTracked[i],
                              ),
                              if (i !=
                                  controller
                                          .micronutrients
                                          .deficiencyTracked
                                          .length -
                                      1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (controller.chronicNutritionGuides.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionPanel(
                      icon: Icons.rule_folder_outlined,
                      title: 'Condition goals and limits',
                      badgeLabel: '${controller.chronicNutritionGuides.length}',
                      expanded: _constraintsExpanded,
                      onToggle: () => setState(
                        () => _constraintsExpanded = !_constraintsExpanded,
                      ),
                      child: _NutritionPanel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            for (
                              var i = 0;
                              i < controller.chronicNutritionGuides.length;
                              i++
                            ) ...[
                              _GuideDropdownRow(
                                guide: controller.chronicNutritionGuides[i],
                              ),
                              if (i !=
                                  controller.chronicNutritionGuides.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _SectionPanel(
                    icon: Icons.restaurant_menu_rounded,
                    title: 'Today meals',
                    badgeLabel: '${meals.length}',
                    expanded: _mealsExpanded,
                    onToggle: () =>
                        setState(() => _mealsExpanded = !_mealsExpanded),
                    child: meals.isEmpty
                        ? const _EmptySectionState(
                            message:
                                'No meals or drinks logged yet today. Start with your first entry.',
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < meals.length; i++) ...[
                                _NutritionMealCard(
                                  meal: meals[i],
                                  timeFormat: timeFormat,
                                  diabetesActive: controller.diabetesActive,
                                ),
                                if (i != meals.length - 1)
                                  const SizedBox(height: 12),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const ValueKey(
                        AppTestKeys.nutritionCreateFoodButton,
                      ),
                      onPressed: _openCreateFoodSheet,
                      icon: const Icon(Icons.library_add_outlined),
                      label: const Text('Create custom food'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionPanel(
                    icon: Icons.notifications_active_outlined,
                    title: 'Meal reminders',
                    badgeLabel: mealRemindersEnabled ? 'ON' : 'OFF',
                    expanded: _remindersExpanded,
                    onToggle: () => setState(
                      () => _remindersExpanded = !_remindersExpanded,
                    ),
                    child: _NutritionPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Keep meal reminders active',
                                      style: TextStyle(
                                        color: VitaMateTheme.primaryDeep,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Breakfast, lunch, and dinner reminders use your local notification settings.',
                                      style: TextStyle(
                                        color: VitaMateTheme.textMuted,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: mealRemindersEnabled,
                                onChanged: (value) async {
                                  setState(() => mealRemindersEnabled = value);
                                  if (value) {
                                    await NotificationsService.scheduleMeals(
                                      breakfast: _toDateTime(breakfast),
                                      lunch: _toDateTime(lunch),
                                      dinner: _toDateTime(dinner),
                                    );
                                    _showSnack('Meal reminders enabled');
                                  } else {
                                    await NotificationsService.cancelMeals();
                                    _showSnack('Meal reminders disabled');
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _ReminderTimeTile(
                            icon: Icons.free_breakfast_rounded,
                            label: 'Breakfast',
                            timeLabel: timeFormat.format(
                              _toDateTime(breakfast),
                            ),
                            onTap: () => _pickTime(breakfast, (picked) {
                              setState(() => breakfast = picked);
                              if (mealRemindersEnabled) {
                                _rescheduleMeals();
                              }
                            }),
                          ),
                          const SizedBox(height: 10),
                          _ReminderTimeTile(
                            icon: Icons.lunch_dining_rounded,
                            label: 'Lunch',
                            timeLabel: timeFormat.format(_toDateTime(lunch)),
                            onTap: () => _pickTime(lunch, (picked) {
                              setState(() => lunch = picked);
                              if (mealRemindersEnabled) {
                                _rescheduleMeals();
                              }
                            }),
                          ),
                          const SizedBox(height: 10),
                          _ReminderTimeTile(
                            icon: Icons.dinner_dining_rounded,
                            label: 'Dinner',
                            timeLabel: timeFormat.format(_toDateTime(dinner)),
                            onTap: () => _pickTime(dinner, (picked) {
                              setState(() => dinner = picked);
                              if (mealRemindersEnabled) {
                                _rescheduleMeals();
                              }
                            }),
                          ),
                        ],
                      ),
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
}

class _NutritionSummaryHero extends StatelessWidget {
  const _NutritionSummaryHero({
    required this.summary,
    required this.detailBreakdown,
    required this.mealCount,
    required this.mealPointsToday,
    required this.diabetesActive,
    required this.guideCount,
    required this.onReviewPressed,
  });

  final NutritionSummary summary;
  final NutritionDetailBreakdown detailBreakdown;
  final int mealCount;
  final int mealPointsToday;
  final bool diabetesActive;
  final int guideCount;
  final VoidCallback onReviewPressed;

  @override
  Widget build(BuildContext context) {
    final consumedCalories = summary.consumedCalories > 0
        ? summary.consumedCalories
        : detailBreakdown.caloriesKcal.round();
    final targetCalories = summary.targetCalories;
    final remainingCalories = targetCalories > 0
        ? (targetCalories - consumedCalories).clamp(0, targetCalories)
        : 0;
    final progress = targetCalories > 0
        ? (consumedCalories / targetCalories).clamp(0.0, 1.0)
        : _loggedCaloriesProgress(consumedCalories);

    return _NutritionPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          color: VitaMateTheme.primary,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Today's Summary",
                          style: TextStyle(
                            color: VitaMateTheme.primaryDeep,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      targetCalories > 0
                          ? '$consumedCalories of $targetCalories kcal'
                          : '$consumedCalories kcal logged',
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      targetCalories > 0
                          ? '$remainingCalories kcal remaining today'
                          : 'Add a target to unlock progress guidance.',
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _NutritionReviewInlineButton(
                      onPressed: onReviewPressed,
                      proteinG: detailBreakdown.proteinG,
                      carbsG: detailBreakdown.carbsG,
                      fatG: detailBreakdown.fatG,
                      sugarG: detailBreakdown.sugarsG,
                      diabetesActive: diabetesActive,
                      guideCount: guideCount,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
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
                        backgroundColor: VitaMateTheme.softSurface,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          VitaMateTheme.primary,
                        ),
                      ),
                    ),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: VitaMateTheme.softSurface,
                        borderRadius: BorderRadius.circular(27),
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: VitaMateTheme.primary,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: VitaMateTheme.softSurface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroMetric(
                    value: mealPointsToday > 0
                        ? '+$mealPointsToday pts'
                        : '$mealPointsToday pts',
                    label: 'today score',
                  ),
                ),
                const _DividerColumn(),
                Expanded(
                  child: _HeroMetric(
                    value: '$mealCount',
                    label: mealCount == 1 ? 'meal logged' : 'entries today',
                    alignEnd: true,
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

class _NutritionReviewInlineButton extends StatelessWidget {
  const _NutritionReviewInlineButton({
    required this.onPressed,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.sugarG,
    required this.diabetesActive,
    required this.guideCount,
  });

  final VoidCallback onPressed;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double sugarG;
  final bool diabetesActive;
  final int guideCount;

  @override
  Widget build(BuildContext context) {
    final sugarColor = diabetesActive
        ? VitaMateTheme.danger
        : VitaMateTheme.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: VitaMateTheme.softSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: VitaMateTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7F21F5), Color(0xFFB42CFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review consumed nutrients',
                      style: TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'P ${proteinG.round()}g  C ${carbsG.round()}g  F ${fatG.round()}g  S ${sugarG.round()}g',
                      style: TextStyle(
                        color: sugarColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    if (guideCount > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        '$guideCount care guide limits available',
                        style: const TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: VitaMateTheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _loggedCaloriesProgress(int consumedCalories) {
  if (consumedCalories <= 0) {
    return 0;
  }
  return (consumedCalories / 2000).clamp(0.04, 1.0).toDouble();
}

class _GuideDropdownRow extends StatelessWidget {
  const _GuideDropdownRow({required this.guide});

  final ChronicGuideCardData guide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guide.title,
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (guide.sourceLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        guide.sourceLabel,
                        style: const TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _BadgeChip(label: guide.badgeLabel, color: VitaMateTheme.primary),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            guide.valueLabel,
            style: const TextStyle(
              color: VitaMateTheme.primary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          if (guide.supportingText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              guide.supportingText,
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MicronutrientGoalSummaryRow extends StatelessWidget {
  const _MicronutrientGoalSummaryRow({required this.item});

  final MicronutrientItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.status) {
      'met' => VitaMateTheme.success,
      'over_limit' || 'below_min' => VitaMateTheme.danger,
      'low' => VitaMateTheme.warning,
      _ => VitaMateTheme.primary,
    };
    final lab = item.labContext;
    final plan = lab?.improvementPlan;
    final medication = item.linkedMedication;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _BadgeChip(label: _statusLabel(item.status), color: color),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: item.progressFraction,
              minHeight: 8,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${item.consumedLabel} (${item.foodLabel}; ${item.supplementLabel})',
            style: const TextStyle(
              color: VitaMateTheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (lab != null && lab.hasLabResult) ...[
            const SizedBox(height: 6),
            Text(
              lab.referenceLabel.isEmpty
                  ? 'Lab: ${lab.labValueLabel}'
                  : 'Lab: ${lab.labValueLabel} - normal ${lab.referenceLabel}',
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (plan != null && plan.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              plan.message,
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
          if (medication != null) ...[
            const SizedBox(height: 8),
            _BadgeChip(
              label: 'Meds: ${medication.displayName}',
              color: VitaMateTheme.success,
            ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'met' => 'on target',
      'over_limit' => 'above range',
      'below_min' || 'low' => 'needs build-up',
      _ => 'tracking',
    };
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.icon,
    required this.title,
    required this.badgeLabel,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String badgeLabel;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(24),
          child: _NutritionPanel(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            borderRadius: BorderRadius.circular(24),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: VitaMateTheme.softSurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: VitaMateTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (badgeLabel.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: VitaMateTheme.softSurface,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                        color: VitaMateTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: VitaMateTheme.primary,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: child,
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
  }
}

class _NutritionReviewSheet extends StatelessWidget {
  const _NutritionReviewSheet({
    required this.summary,
    required this.detailBreakdown,
    required this.micronutrients,
    required this.mealCount,
  });

  final NutritionSummary summary;
  final NutritionDetailBreakdown detailBreakdown;
  final MicronutrientOverview micronutrients;
  final int mealCount;

  @override
  Widget build(BuildContext context) {
    final calories = summary.consumedCalories > 0
        ? summary.consumedCalories.toDouble()
        : detailBreakdown.caloriesKcal;
    final targetCalories = summary.targetCalories > 0
        ? summary.targetCalories.toDouble()
        : null;
    final lookup = {for (final item in micronutrients.items) item.code: item};
    final macroEntries = <_NutritionReviewEntry>[
      _NutritionReviewEntry(
        label: 'Calories',
        value: calories,
        unit: 'kcal',
        target: targetCalories,
        color: VitaMateTheme.primary,
      ),
      _NutritionReviewEntry(
        label: 'Protein',
        value: detailBreakdown.proteinG,
        unit: 'g',
        color: VitaMateTheme.primary,
      ),
      _NutritionReviewEntry(
        label: 'Carbs',
        value: detailBreakdown.carbsG,
        unit: 'g',
        color: VitaMateTheme.accent,
      ),
      _NutritionReviewEntry(
        label: 'Fat',
        value: detailBreakdown.fatG,
        unit: 'g',
        color: VitaMateTheme.warning,
      ),
    ];
    final detailEntries = <_NutritionReviewEntry>[
      _NutritionReviewEntry(
        label: 'Sugar',
        value: detailBreakdown.sugarsG,
        unit: 'g',
        color: VitaMateTheme.danger,
      ),
      _NutritionReviewEntry(
        label: 'Added sugar',
        value: detailBreakdown.addedSugarsG,
        unit: 'g',
        color: VitaMateTheme.danger,
      ),
      _NutritionReviewEntry(
        label: 'Fiber',
        value: detailBreakdown.fiberG,
        unit: 'g',
        color: VitaMateTheme.success,
      ),
      _NutritionReviewEntry(
        label: 'Saturated fat',
        value: detailBreakdown.saturatedFatG,
        unit: 'g',
        color: VitaMateTheme.warning,
      ),
      _NutritionReviewEntry(
        label: 'Trans fat',
        value: detailBreakdown.transFatG,
        unit: 'g',
        color: VitaMateTheme.danger,
      ),
      _NutritionReviewEntry(
        label: 'Monounsaturated fat',
        value: detailBreakdown.monounsaturatedFatG,
        unit: 'g',
        color: VitaMateTheme.primary,
      ),
      _NutritionReviewEntry(
        label: 'Polyunsaturated fat',
        value: detailBreakdown.polyunsaturatedFatG,
        unit: 'g',
        color: VitaMateTheme.primary,
      ),
      _NutritionReviewEntry(
        label: 'Cholesterol',
        value: detailBreakdown.cholesterolMg,
        unit: 'mg',
        color: VitaMateTheme.warning,
      ),
      _NutritionReviewEntry(
        label: 'Caffeine',
        value: detailBreakdown.caffeineMg,
        unit: 'mg',
        color: VitaMateTheme.primaryDeep,
      ),
    ];
    final mineralEntries = _micronutrientReviewEntries(
      lookup: lookup,
      specs: [
        _NutrientSpec('sodium_mg', 'Sodium', 'mg', detailBreakdown.sodiumMg),
        _NutrientSpec(
          'potassium_mg',
          'Potassium',
          'mg',
          detailBreakdown.potassiumMg,
        ),
        _NutrientSpec('calcium_mg', 'Calcium', 'mg', detailBreakdown.calciumMg),
        _NutrientSpec('iron_mg', 'Iron', 'mg', detailBreakdown.ironMg),
        _NutrientSpec(
          'magnesium_mg',
          'Magnesium',
          'mg',
          detailBreakdown.magnesiumMg,
        ),
        _NutrientSpec('zinc_mg', 'Zinc', 'mg', detailBreakdown.zincMg),
        _NutrientSpec(
          'phosphorus_mg',
          'Phosphorus',
          'mg',
          detailBreakdown.phosphorusMg,
        ),
      ],
      color: VitaMateTheme.warning,
    );
    final vitaminEntries = _micronutrientReviewEntries(
      lookup: lookup,
      specs: [
        _NutrientSpec(
          'vitamin_a_mcg',
          'Vitamin A',
          'mcg',
          detailBreakdown.vitaminAMcg,
        ),
        _NutrientSpec(
          'vitamin_c_mg',
          'Vitamin C',
          'mg',
          detailBreakdown.vitaminCMg,
        ),
        _NutrientSpec(
          'vitamin_d_mcg',
          'Vitamin D',
          'mcg',
          detailBreakdown.vitaminDMcg,
        ),
        _NutrientSpec(
          'vitamin_e_mg',
          'Vitamin E',
          'mg',
          detailBreakdown.vitaminEMg,
        ),
        _NutrientSpec(
          'vitamin_k_mcg',
          'Vitamin K',
          'mcg',
          detailBreakdown.vitaminKMcg,
        ),
        _NutrientSpec(
          'vitamin_b1_mg',
          'Vitamin B1',
          'mg',
          detailBreakdown.vitaminB1Mg,
        ),
        _NutrientSpec(
          'vitamin_b2_mg',
          'Vitamin B2',
          'mg',
          detailBreakdown.vitaminB2Mg,
        ),
        _NutrientSpec(
          'vitamin_b3_mg',
          'Vitamin B3',
          'mg',
          detailBreakdown.vitaminB3Mg,
        ),
        _NutrientSpec(
          'vitamin_b6_mg',
          'Vitamin B6',
          'mg',
          detailBreakdown.vitaminB6Mg,
        ),
        _NutrientSpec(
          'vitamin_b12_mcg',
          'Vitamin B12',
          'mcg',
          detailBreakdown.vitaminB12Mcg,
        ),
        _NutrientSpec('folate_mcg', 'Folate', 'mcg', detailBreakdown.folateMcg),
      ],
      color: VitaMateTheme.primary,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: VitaMateTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            children: [
              Center(
                child: Container(
                  width: 58,
                  height: 6,
                  decoration: BoxDecoration(
                    color: VitaMateTheme.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Nutrition review',
                style: TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A full review of nutrients logged from today meals and drinks. Supplements are shown separately when they exist.',
                style: TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ReviewSummaryTile(
                    label: 'Entries',
                    value: '$mealCount',
                    icon: Icons.restaurant_menu_rounded,
                  ),
                  _ReviewSummaryTile(
                    label: 'Calories',
                    value: '${_formatSheetNumber(calories)} kcal',
                    icon: Icons.local_fire_department_rounded,
                  ),
                  _ReviewSummaryTile(
                    label: 'Protein',
                    value: '${_formatSheetNumber(detailBreakdown.proteinG)} g',
                    icon: Icons.fitness_center_rounded,
                  ),
                  _ReviewSummaryTile(
                    label: 'Sugar',
                    value: '${_formatSheetNumber(detailBreakdown.sugarsG)} g',
                    icon: Icons.cookie_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _NutritionReviewSection(
                title: 'Calories & macros',
                subtitle: 'Main energy and macronutrient totals from food.',
                entries: macroEntries,
              ),
              const SizedBox(height: 16),
              _NutritionReviewSection(
                title: 'Sugar, fiber & fats',
                subtitle: 'Detailed values that usually matter for limits.',
                entries: detailEntries,
              ),
              const SizedBox(height: 16),
              _NutritionReviewSection(
                title: 'Minerals from food',
                subtitle:
                    'Food-only minerals. Supplement doses remain separated.',
                entries: mineralEntries,
              ),
              const SizedBox(height: 16),
              _NutritionReviewSection(
                title: 'Vitamins from food',
                subtitle:
                    'Food-only vitamins compared with daily targets when available.',
                entries: vitaminEntries,
              ),
            ],
          ),
        );
      },
    );
  }

  List<_NutritionReviewEntry> _micronutrientReviewEntries({
    required Map<String, MicronutrientItem> lookup,
    required List<_NutrientSpec> specs,
    required Color color,
  }) {
    return specs
        .map((spec) {
          final item = lookup[spec.code];
          if (item == null) {
            return _NutritionReviewEntry(
              label: spec.name,
              value: spec.value,
              unit: spec.unit,
              color: color,
            );
          }
          return _NutritionReviewEntry(
            label: item.name,
            value: item.foodConsumed,
            unit: item.unit,
            target: item.targetValue > 0 ? item.targetValue : null,
            subtitle: item.supplementConsumed > 0
                ? 'Supplements: ${_formatSheetNumber(item.supplementConsumed)} ${item.unit}'
                : null,
            color: color,
          );
        })
        .toList(growable: false);
  }
}

class _ReviewSummaryTile extends StatelessWidget {
  const _ReviewSummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 50) / 2,
      child: _NutritionPanel(
        padding: const EdgeInsets.all(14),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: VitaMateTheme.softSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: VitaMateTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionReviewSection extends StatelessWidget {
  const _NutritionReviewSection({
    required this.title,
    required this.subtitle,
    required this.entries,
  });

  final String title;
  final String subtitle;
  final List<_NutritionReviewEntry> entries;

  @override
  Widget build(BuildContext context) {
    return _NutritionPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < entries.length; i++) ...[
            _NutritionReviewRow(entry: entries[i]),
            if (i != entries.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _NutritionReviewRow extends StatelessWidget {
  const _NutritionReviewRow({required this.entry});

  final _NutritionReviewEntry entry;

  @override
  Widget build(BuildContext context) {
    final target = entry.target;
    final hasTarget = target != null && target > 0;
    final progress = hasTarget
        ? (entry.value / target).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final valueLabel = '${_formatSheetNumber(entry.value)} ${entry.unit}'
        .trim();
    final targetLabel = hasTarget
        ? ' / ${_formatSheetNumber(target)} ${entry.unit}'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.label,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '$valueLabel$targetLabel',
              style: TextStyle(color: entry.color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        if (hasTarget) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: VitaMateTheme.softSurface,
              valueColor: AlwaysStoppedAnimation<Color>(entry.color),
            ),
          ),
        ],
        if (entry.subtitle != null && entry.subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            entry.subtitle!,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _NutritionReviewEntry {
  const _NutritionReviewEntry({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.target,
    this.subtitle,
  });

  final String label;
  final double value;
  final String unit;
  final Color color;
  final double? target;
  final String? subtitle;
}

class _NutrientSpec {
  const _NutrientSpec(this.code, this.name, this.unit, this.value);

  final String code;
  final String name;
  final String unit;
  final double value;
}

class _MicronutrientsSheet extends StatefulWidget {
  const _MicronutrientsSheet({required this.controller});

  final NutritionController controller;

  @override
  State<_MicronutrientsSheet> createState() => _MicronutrientsSheetState();
}

class _MicronutrientsSheetState extends State<_MicronutrientsSheet> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await widget.controller.refreshMicronutrients();
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _openTargetForm() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _MicronutrientTargetFormSheet(controller: widget.controller),
    );
    if (saved == true && mounted) {
      await _refresh();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final overview = widget.controller.micronutrients;
        final vitamins = overview.vitamins;
        final minerals = overview.minerals;
        final tracked = overview.deficiencyTracked;
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: VitaMateTheme.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                children: [
                  Center(
                    child: Container(
                      width: 58,
                      height: 6,
                      decoration: BoxDecoration(
                        color: VitaMateTheme.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Vitamins & minerals',
                          style: TextStyle(
                            color: VitaMateTheme.primaryDeep,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _refreshing ? null : _refresh,
                        icon: _refreshing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        color: VitaMateTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Food intake is tracked separately from supplement doses linked through medications.',
                    style: TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _PrimaryGradientButton(
                    label: 'Add deficiency target',
                    icon: Icons.add_rounded,
                    onPressed: _openTargetForm,
                  ),
                  const SizedBox(height: 16),
                  _MicronutrientInfoStrip(text: overview.disclaimer),
                  const SizedBox(height: 16),
                  _MicronutrientSection(
                    title: 'Deficiency tracking',
                    emptyMessage:
                        'No deficiency targets yet. Add one only when you want extra tracking.',
                    items: tracked,
                    highlightSupplements: true,
                  ),
                  const SizedBox(height: 16),
                  _MicronutrientSection(
                    title: 'Daily minerals',
                    emptyMessage: 'No mineral data yet.',
                    items: minerals,
                  ),
                  const SizedBox(height: 16),
                  _MicronutrientSection(
                    title: 'Daily vitamins',
                    emptyMessage: 'No vitamin data yet.',
                    items: vitamins,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MicronutrientInfoStrip extends StatelessWidget {
  const _MicronutrientInfoStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: VitaMateTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MicronutrientSection extends StatelessWidget {
  const _MicronutrientSection({
    required this.title,
    required this.emptyMessage,
    required this.items,
    this.highlightSupplements = false,
  });

  final String title;
  final String emptyMessage;
  final List<MicronutrientItem> items;
  final bool highlightSupplements;

  @override
  Widget build(BuildContext context) {
    return _NutritionPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              emptyMessage,
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              _MicronutrientProgressRow(
                item: items[i],
                highlightSupplements: highlightSupplements,
              ),
              if (i != items.length - 1) const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _MicronutrientProgressRow extends StatelessWidget {
  const _MicronutrientProgressRow({
    required this.item,
    required this.highlightSupplements,
  });

  final MicronutrientItem item;
  final bool highlightSupplements;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status);
    final medication = item.linkedMedication;
    final lab = item.labContext;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              item.consumedLabel,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: item.progressFraction,
            minHeight: 8,
            backgroundColor: VitaMateTheme.softSurface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _BadgeChip(label: item.foodLabel, color: VitaMateTheme.primary),
            if (item.supplementConsumed > 0 || highlightSupplements)
              _BadgeChip(
                label: item.supplementLabel,
                color: VitaMateTheme.success,
              ),
            if (item.deficiencyTracked)
              _BadgeChip(label: 'deficiency target', color: color),
          ],
        ),
        if (medication != null) ...[
          const SizedBox(height: 8),
          Text(
            'Linked supplement: ${medication.displayName} (${medication.doseLabel})',
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (lab != null) ...[
          const SizedBox(height: 8),
          Text(
            _labContextLabel(lab),
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  String _labContextLabel(MicronutrientLabContext lab) {
    final parts = <String>[];
    if (lab.hasLabResult) {
      final test = lab.testName.isEmpty ? 'Lab result' : lab.testName;
      final reference = lab.referenceLabel;
      parts.add(
        reference.isEmpty
            ? '$test: ${lab.labValueLabel}'
            : '$test: ${lab.labValueLabel} (normal $reference)',
      );
    }
    final plan = lab.improvementPlan;
    if (plan != null && plan.message.isNotEmpty) {
      parts.add(plan.message);
    } else if (lab.suggestedTargetValue != null) {
      parts.add(
        'daily target ${_formatSheetNumber(lab.suggestedTargetValue!)}',
      );
    }
    if (lab.hasMedication) {
      parts.add(
        'current med: ${[lab.currentMedicationName, lab.currentMedicationDose].where((part) => part.trim().isNotEmpty).join(' ')}',
      );
    }
    return parts.join(' - ');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'met':
        return VitaMateTheme.success;
      case 'over_limit':
      case 'below_min':
        return VitaMateTheme.danger;
      case 'low':
        return VitaMateTheme.warning;
      default:
        return VitaMateTheme.primary;
    }
  }
}

class _MicronutrientTargetFormSheet extends StatefulWidget {
  const _MicronutrientTargetFormSheet({required this.controller});

  final NutritionController controller;

  @override
  State<_MicronutrientTargetFormSheet> createState() =>
      _MicronutrientTargetFormSheetState();
}

class _MicronutrientTargetFormSheetState
    extends State<_MicronutrientTargetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _nutrientCode;
  final TextEditingController _minCtrl = TextEditingController();
  final TextEditingController _targetCtrl = TextEditingController();
  final TextEditingController _maxCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _labTestNameCtrl = TextEditingController();
  final TextEditingController _labValueCtrl = TextEditingController();
  final TextEditingController _labUnitCtrl = TextEditingController();
  final TextEditingController _labReferenceMinCtrl = TextEditingController();
  final TextEditingController _labReferenceMaxCtrl = TextEditingController();
  final TextEditingController _labDateCtrl = TextEditingController();
  final TextEditingController _clinicianTargetCtrl = TextEditingController();
  final TextEditingController _currentMedicationNameCtrl =
      TextEditingController();
  final TextEditingController _currentMedicationDoseCtrl =
      TextEditingController();
  final TextEditingController _supplementNameCtrl = TextEditingController();
  final TextEditingController _supplementAmountCtrl = TextEditingController();
  final TextEditingController _supplementUnitCtrl = TextEditingController();
  final TextEditingController _scheduleTimeCtrl = TextEditingController(
    text: '09:00',
  );
  bool _createMedicationPlan = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final items = widget.controller.micronutrients.items;
    final first = items.isNotEmpty ? items.first : null;
    _nutrientCode = first?.code ?? 'vitamin_d_mcg';
    _syncSelectedNutrient(first);
    _labValueCtrl.addListener(_refreshSuggestionPreview);
  }

  @override
  void dispose() {
    _labValueCtrl.removeListener(_refreshSuggestionPreview);
    _minCtrl.dispose();
    _targetCtrl.dispose();
    _maxCtrl.dispose();
    _noteCtrl.dispose();
    _labTestNameCtrl.dispose();
    _labValueCtrl.dispose();
    _labUnitCtrl.dispose();
    _labReferenceMinCtrl.dispose();
    _labReferenceMaxCtrl.dispose();
    _labDateCtrl.dispose();
    _clinicianTargetCtrl.dispose();
    _currentMedicationNameCtrl.dispose();
    _currentMedicationDoseCtrl.dispose();
    _supplementNameCtrl.dispose();
    _supplementAmountCtrl.dispose();
    _supplementUnitCtrl.dispose();
    _scheduleTimeCtrl.dispose();
    super.dispose();
  }

  void _syncSelectedNutrient(MicronutrientItem? item) {
    if (item == null) {
      return;
    }
    _targetCtrl.text = _formatInputNumber(item.targetValue);
    _supplementNameCtrl.text = '${item.name} supplement';
    _supplementUnitCtrl.text = item.unit;
    final lab = item.labContext;
    _labTestNameCtrl.text = lab?.testName ?? '';
    _labValueCtrl.text = lab?.value == null
        ? ''
        : _formatInputNumber(lab!.value!);
    _labUnitCtrl.text = lab?.unit ?? '';
    _labReferenceMinCtrl.text = lab?.referenceMin == null
        ? ''
        : _formatInputNumber(lab!.referenceMin!);
    _labReferenceMaxCtrl.text = lab?.referenceMax == null
        ? ''
        : _formatInputNumber(lab!.referenceMax!);
    _labDateCtrl.text = lab?.testDate ?? '';
    _clinicianTargetCtrl.text = lab?.clinicianRecommendedValue == null
        ? ''
        : _formatInputNumber(lab!.clinicianRecommendedValue!);
    _currentMedicationNameCtrl.text = lab?.currentMedicationName ?? '';
    _currentMedicationDoseCtrl.text = lab?.currentMedicationDose ?? '';
  }

  void _refreshSuggestionPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final currentMedicationName = _currentMedicationNameCtrl.text.trim();
      final currentMedicationDose = _currentMedicationDoseCtrl.text.trim();
      final supplementName = _supplementNameCtrl.text.trim().isNotEmpty
          ? _supplementNameCtrl.text.trim()
          : currentMedicationName;
      final shouldCreateMedication =
          _createMedicationPlan ||
          currentMedicationName.isNotEmpty ||
          currentMedicationDose.isNotEmpty;
      await widget.controller.saveMicronutrientTarget(
        nutrientCode: _nutrientCode,
        minValue: null,
        targetValue: null,
        maxValue: null,
        note: _noteCtrl.text.trim(),
        labTestName: '',
        labValue: _parseOptionalDouble(_labValueCtrl.text),
        labUnit: '',
        labReferenceMin: null,
        labReferenceMax: null,
        labTestDate: '',
        clinicianRecommendedValue: null,
        currentMedicationName: currentMedicationName,
        currentMedicationDose: currentMedicationDose,
        createMedicationPlan: shouldCreateMedication,
        supplementName: supplementName,
        supplementAmount: _parseOptionalDouble(_supplementAmountCtrl.text),
        supplementUnit: _supplementUnitCtrl.text.trim(),
        scheduleTime: _scheduleTimeCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        final message = error is StateError
            ? error.message
            : NetworkErrorMapper.toMessage(
                error,
                fallback: 'Could not save micronutrient plan.',
              );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.controller.micronutrients.items;
    final dropdownItems = items
        .map(
          (item) => DropdownMenuItem<String>(
            value: item.code,
            child: Text(_nutrientDropdownLabel(item)),
          ),
        )
        .toList(growable: false);
    final selectedItem = _selectedMicronutrientItem(items);
    final suggestedTarget = _suggestedTargetFor(selectedItem);
    return Container(
      decoration: const BoxDecoration(
        color: VitaMateTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Deficiency target',
                style: TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue:
                    dropdownItems.any((item) => item.value == _nutrientCode)
                    ? _nutrientCode
                    : null,
                items: dropdownItems,
                selectedItemBuilder: (context) => items
                    .map((item) => Text('${item.name} (${item.unit})'))
                    .toList(growable: false),
                decoration: const InputDecoration(
                  labelText: 'Nutrient',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  final selected = items.firstWhere(
                    (item) => item.code == value,
                    orElse: () => items.first,
                  );
                  setState(() {
                    _nutrientCode = value;
                    _syncSelectedNutrient(selected);
                  });
                },
                validator: (value) =>
                    value == null ? 'Choose a nutrient.' : null,
              ),
              if (selectedItem != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _BadgeChip(
                      label: selectedItem.foodLabel,
                      color: VitaMateTheme.primary,
                    ),
                    _BadgeChip(
                      label: selectedItem.supplementLabel,
                      color: VitaMateTheme.success,
                    ),
                    _BadgeChip(
                      label: 'total ${selectedItem.consumedLabel}',
                      color: VitaMateTheme.primaryDeep,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _MicronutrientFormSection(
                title: 'Current lab result',
                subtitle:
                    'Enter the value from the lab. VitaMate already knows the '
                    'normal range for this nutrient and builds goals or limits '
                    'from that range.',
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _NumberField(
                          controller: _labValueCtrl,
                          label: 'Current value',
                          requiredField: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 54),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: VitaMateTheme.softSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: VitaMateTheme.border),
                          ),
                          child: Text(
                            _labRangeLabel(selectedItem),
                            style: const TextStyle(
                              color: VitaMateTheme.primaryDeep,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _SuggestionBanner(
                    suggestedTarget: suggestedTarget,
                    unit: selectedItem?.unit ?? '',
                    onUse: null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Optional note',
                      hintText: 'Example: follow-up after 8 weeks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MicronutrientFormSection(
                title: 'Medication / supplement plan',
                subtitle:
                    'Enter a supplement name here to add it to Meds and link it '
                    'to this vitamin/mineral goal. Numeric dose is optional.',
                children: [
                  TextFormField(
                    controller: _currentMedicationNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Current medicine / supplement',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _currentMedicationDoseCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dose note',
                      hintText: 'Example: 1000 IU daily',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: _createMedicationPlan,
                onChanged: (value) =>
                    setState(() => _createMedicationPlan = value),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Create supplement reminder',
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: const Text(
                  'Adds a medication plan so taken doses count separately.',
                ),
              ),
              if (_createMedicationPlan) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _supplementNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Supplement name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (!_createMedicationPlan) {
                      return null;
                    }
                    return (value ?? '').trim().isEmpty
                        ? 'Enter supplement name.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        controller: _supplementAmountCtrl,
                        label: 'Dose',
                        requiredField: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _supplementUnitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _scheduleTimeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (!_createMedicationPlan || text.isEmpty) {
                            return null;
                          }
                          return RegExp(r'^\d{2}:\d{2}$').hasMatch(text)
                              ? null
                              : 'HH:mm';
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              _PrimaryGradientButton(
                label: _saving ? 'Saving...' : 'Save target',
                icon: Icons.check_rounded,
                onPressed: _saving ? () {} : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  double? _parseOptionalDouble(String text) {
    final value = text.trim();
    if (value.isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  MicronutrientItem? _selectedMicronutrientItem(List<MicronutrientItem> items) {
    for (final item in items) {
      if (item.code == _nutrientCode) {
        return item;
      }
    }
    return items.isEmpty ? null : items.first;
  }

  String _nutrientDropdownLabel(MicronutrientItem item) {
    final supplement = item.supplementConsumed > 0
        ? ' + ${_formatSheetNumber(item.supplementConsumed)} from supplements'
        : '';
    return '${item.name}: ${_formatSheetNumber(item.foodConsumed)} from food$supplement / ${_formatSheetNumber(item.targetValue)} ${item.unit}';
  }

  double? _suggestedTargetFor(MicronutrientItem? item) {
    if (item == null || item.targetValue <= 0) {
      return null;
    }
    final labValue = _parseOptionalDouble(_labValueCtrl.text);
    if (labValue == null) {
      return item.targetValue;
    }
    final range = item.labRange;
    final minValue = range?.referenceMin;
    final maxValue = range?.referenceMax;
    if (minValue != null && labValue < minValue) {
      return item.targetValue * 1.25;
    }
    if (maxValue != null && labValue > maxValue) {
      return item.targetValue * 0.8;
    }
    return item.targetValue;
  }

  String _labRangeLabel(MicronutrientItem? item) {
    final range = item?.labRange;
    if (range == null || range.referenceLabel.isEmpty) {
      return 'Normal range available';
    }
    final test = range.testName.trim().isEmpty ? 'Normal' : range.testName;
    return '$test\n${range.referenceLabel}';
  }

  String _formatInputNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toString();
  }
}

class _MicronutrientFormSection extends StatelessWidget {
  const _MicronutrientFormSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VitaMateTheme.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SuggestionBanner extends StatelessWidget {
  const _SuggestionBanner({
    required this.suggestedTarget,
    required this.unit,
    required this.onUse,
  });

  final double? suggestedTarget;
  final String unit;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final value = suggestedTarget;
    final label = value == null
        ? 'Enter a lab result or clinician target to calculate a daily target.'
        : 'Suggested daily target: ${_formatSheetNumber(value)} $unit';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.trim(),
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (onUse != null)
            TextButton(
              onPressed: onUse,
              child: const Text(
                'Use',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.requiredField,
  });

  final TextEditingController controller;
  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) {
          return requiredField ? 'Required' : null;
        }
        return double.tryParse(text) == null ? 'Number' : null;
      },
    );
  }
}

String _formatSheetNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(value.abs() < 10 ? 1 : 0);
}

class _ReminderTimeTile extends StatelessWidget {
  const _ReminderTimeTile({
    required this.icon,
    required this.label,
    required this.timeLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: VitaMateTheme.softSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: VitaMateTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: VitaMateTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              timeLabel,
              style: const TextStyle(
                color: VitaMateTheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit_outlined, color: VitaMateTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _NutritionMealCard extends StatefulWidget {
  const _NutritionMealCard({
    required this.meal,
    required this.timeFormat,
    required this.diabetesActive,
  });

  final MealLog meal;
  final DateFormat timeFormat;
  final bool diabetesActive;

  @override
  State<_NutritionMealCard> createState() => _NutritionMealCardState();
}

class _NutritionMealCardState extends State<_NutritionMealCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final accent = meal.isDrink ? VitaMateTheme.accent : VitaMateTheme.primary;
    final subtitleBits = <String>[meal.mealTypeLabel, meal.amountLabel];
    if (widget.diabetesActive && meal.sugarsG > 0) {
      subtitleBits.add('${meal.sugarsG.round()} g sugar');
    }

    return InkWell(
      onTap: () => setState(() => expanded = !expanded),
      borderRadius: BorderRadius.circular(24),
      child: _NutritionPanel(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    meal.isDrink
                        ? Icons.local_drink_outlined
                        : _mealTypeIcon(meal),
                    color: accent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.foodName.isEmpty ? 'Food item' : meal.foodName,
                        style: const TextStyle(
                          color: VitaMateTheme.primaryDeep,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitleBits.join('  -  '),
                        style: const TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _BadgeChip(
                            label: '${meal.caloriesKcal.round()} kcal',
                            color: VitaMateTheme.primaryDeep,
                          ),
                          if (meal.consumedAt != null)
                            _BadgeChip(
                              label: widget.timeFormat.format(
                                meal.consumedAt!.toLocal(),
                              ),
                              color: accent,
                            ),
                          if (meal.caffeineMg > 0)
                            _BadgeChip(
                              label: '${meal.caffeineMg.round()} mg caffeine',
                              color: VitaMateTheme.warning,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: VitaMateTheme.primary,
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricTile(
                      label: 'Protein',
                      value: '${meal.proteinG.round()} g',
                      color: VitaMateTheme.primary,
                    ),
                    _MetricTile(
                      label: 'Carbs',
                      value: '${meal.carbsG.round()} g',
                      color: VitaMateTheme.accent,
                    ),
                    _MetricTile(
                      label: 'Fat',
                      value: '${meal.fatG.round()} g',
                      color: VitaMateTheme.warning,
                    ),
                    _MetricTile(
                      label: 'Sugar',
                      value: '${meal.sugarsG.round()} g',
                      color: widget.diabetesActive
                          ? VitaMateTheme.danger
                          : VitaMateTheme.warning,
                    ),
                    _MetricTile(
                      label: 'Fiber',
                      value: '${meal.fiberG.round()} g',
                      color: VitaMateTheme.success,
                    ),
                    _MetricTile(
                      label: 'Sodium',
                      value: '${meal.sodiumMg.round()} mg',
                      color: VitaMateTheme.primaryDeep,
                    ),
                  ],
                ),
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogMealSheet extends StatefulWidget {
  const _LogMealSheet({required this.controller});

  final NutritionController controller;

  @override
  State<_LogMealSheet> createState() => _LogMealSheetState();
}

class _FoodSearchDisplayItem {
  const _FoodSearchDisplayItem({
    required this.food,
    this.outsideSelectedCategory = false,
  });

  final FoodItem food;
  final bool outsideSelectedCategory;
}

class _FoodHealthBadge {
  const _FoodHealthBadge({required this.label, required this.color});

  final String label;
  final Color color;
}

class _LogMealSheetState extends State<_LogMealSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController(text: '1');

  Timer? _searchDebounce;
  FoodItem? _selectedFood;
  List<_FoodSearchDisplayItem> _searchResults = const [];
  String? _searchError;
  String _mealType = 'breakfast';
  String? _selectedCategory;
  int? _selectedServingOptionId;
  String _unit = 'serving';
  TimeOfDay _consumedTime = TimeOfDay.now();
  bool _searchLoading = false;
  bool _saving = false;
  bool _ignoreMealTypeCategoryPreference = false;
  int _searchRequestId = 0;
  String? _lastSearchKey;

  @override
  void initState() {
    super.initState();
    _searchResults = _localSuggestionsForCurrentFilters(limit: 8);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  _ServingChoice? _selectedServingChoice(FoodItem? food) {
    if (food == null) {
      return null;
    }
    final choices = _servingChoicesForFood(food);
    for (final choice in choices) {
      if (choice.id == _selectedServingOptionId) {
        return choice;
      }
    }
    return choices.isNotEmpty ? choices.first : null;
  }

  bool _matchesMealType(FoodItem food, String mealType) {
    if (mealType == 'drink') {
      return food.isBeverage;
    }
    return !food.isBeverage;
  }

  String? get _activeCategoryPreference {
    final selectedCategory = _selectedCategory?.trim();
    if (selectedCategory != null && selectedCategory.isNotEmpty) {
      return selectedCategory;
    }
    return null;
  }

  String? get _activeMealFilterLabel {
    final category = _activeCategoryPreference;
    if (category != null && category.isNotEmpty) {
      return category;
    }
    if (!_ignoreMealTypeCategoryPreference) {
      return _mealTypeLabels[_mealType];
    }
    return null;
  }

  bool _matchesCategoryLabel(FoodItem food, String category) {
    final expected = category.trim().toLowerCase();
    if (expected.isEmpty) {
      return true;
    }
    final displayCategory = food.supportingLabel.trim().toLowerCase();
    final codeCategory = food.primaryCategoryCode
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ');
    return displayCategory == expected || codeCategory == expected;
  }

  bool _matchesSelectedCategory(FoodItem food) {
    final selectedCategory = _selectedCategory;
    if (selectedCategory == null || selectedCategory.isEmpty) {
      return true;
    }
    return _matchesCategoryLabel(food, selectedCategory);
  }

  bool _matchesMealSlotPreference(FoodItem food) {
    if (_ignoreMealTypeCategoryPreference) {
      return true;
    }
    if (_mealType == 'drink') {
      return food.isBeverage;
    }
    if (food.isBeverage) {
      return false;
    }
    if (food.mealTags.isEmpty) {
      return true;
    }
    return food.mealTags.contains(_mealType);
  }

  Iterable<FoodItem> _catalogFoodsForFilters() sync* {
    final seenIds = <int>{};
    for (final food in [
      ...widget.controller.foods,
      ..._searchResults.map((item) => item.food),
    ]) {
      if (seenIds.add(food.id)) {
        yield food;
      }
    }
  }

  List<_FoodSearchDisplayItem> _localSuggestionsForCurrentFilters({
    required int limit,
  }) {
    final categoryPreference = _activeCategoryPreference;
    final primaryResults = <_FoodSearchDisplayItem>[];
    final fallbackResults = <_FoodSearchDisplayItem>[];
    final seenIds = <int>{};
    for (final food in widget.controller.foods) {
      if (!seenIds.add(food.id)) {
        continue;
      }
      if (!_matchesMealType(food, _mealType)) {
        continue;
      }
      final matchesCategory =
          categoryPreference == null ||
          categoryPreference.isEmpty ||
          _matchesCategoryLabel(food, categoryPreference);
      final matchesMealSlot = _matchesMealSlotPreference(food);
      if (matchesCategory && matchesMealSlot) {
        primaryResults.add(_FoodSearchDisplayItem(food: food));
        if (primaryResults.length >= limit) {
          break;
        }
        continue;
      }
      fallbackResults.add(
        _FoodSearchDisplayItem(food: food, outsideSelectedCategory: true),
      );
    }
    if (primaryResults.isNotEmpty || categoryPreference == null) {
      return primaryResults;
    }
    return fallbackResults.take(limit).toList(growable: false);
  }

  List<FoodItem> _outsideCategoryFoods(
    List<FoodItem> foods,
    String? categoryPreference,
    Set<int> primaryIds,
  ) {
    final results = <FoodItem>[];
    final seenIds = <int>{...primaryIds};
    for (final food in foods) {
      if (!seenIds.add(food.id)) {
        continue;
      }
      if (categoryPreference != null &&
          _matchesCategoryLabel(food, categoryPreference)) {
        continue;
      }
      results.add(food);
    }
    return results;
  }

  List<String> _categoryOptionsForMealType(String mealType) {
    final counts = <String, int>{};
    for (final food in _catalogFoodsForFilters()) {
      if (!_matchesMealType(food, mealType)) {
        continue;
      }
      final category = food.supportingLabel.trim();
      if (category.isEmpty) {
        continue;
      }
      if (_genericCategoryLabels.contains(category.toLowerCase())) {
        continue;
      }
      counts[category] = (counts[category] ?? 0) + 1;
    }
    final categories = counts.keys.toList()
      ..sort((a, b) {
        final countCompare = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    final limited = categories.take(14).toList();
    final selectedCategory = _selectedCategory;
    if (selectedCategory != null &&
        selectedCategory.isNotEmpty &&
        categories.contains(selectedCategory) &&
        !limited.contains(selectedCategory)) {
      limited.add(selectedCategory);
    }
    return limited;
  }

  List<String> _availableUnits(FoodItem? food) {
    if (food == null) {
      return const ['serving', 'g'];
    }
    if (food.isBeverage) {
      return const ['serving', 'ml'];
    }
    return const ['serving', 'g'];
  }

  void _syncCategorySelectionForMealType(String mealType) {
    final options = _categoryOptionsForMealType(mealType);
    if (_selectedCategory != null && !options.contains(_selectedCategory)) {
      _selectedCategory = null;
    }
  }

  bool _searchMatchesSelectedFood() {
    final food = _selectedFood;
    if (food == null) {
      return false;
    }
    return _searchCtrl.text.trim().toLowerCase() ==
        food.name.trim().toLowerCase();
  }

  bool get _hasLockedSelection =>
      _selectedFood != null && _searchMatchesSelectedFood();

  void _scheduleSearch({bool immediate = false}) {
    _searchDebounce?.cancel();
    if (immediate) {
      unawaited(_refreshSearchResults());
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 380),
      () => unawaited(_refreshSearchResults()),
    );
  }

  Future<void> _refreshSearchResults() async {
    final requestId = ++_searchRequestId;
    final rawQuery = _searchCtrl.text.trim();
    final query = rawQuery.length >= 2 ? rawQuery : '';
    final categoryPreference = _activeCategoryPreference;
    final includeMealSlot = !_ignoreMealTypeCategoryPreference;
    final searchScope = _mealType == 'drink' ? 'drink' : 'food';
    final requestKey =
        '$searchScope|$_mealType|${categoryPreference ?? ''}|$includeMealSlot|$query';
    if (requestKey == _lastSearchKey) {
      return;
    }
    _lastSearchKey = requestKey;
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = _localSuggestionsForCurrentFilters(limit: 8);
          _searchLoading = false;
          _searchError = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _searchLoading = true;
        _searchError = null;
      });
    }
    try {
      final primaryResults = await widget.controller.searchFoods(
        mealType: _mealType,
        query: query,
        category: categoryPreference,
        includeMealSlot: includeMealSlot,
        limit: 8,
      );
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      final shouldFetchOutsideCategory =
          ((categoryPreference != null &&
                  categoryPreference.trim().isNotEmpty) ||
              includeMealSlot) &&
          primaryResults.length < _outsideCategoryFallbackThreshold;
      var outsideCategoryResults = const <FoodItem>[];
      if (shouldFetchOutsideCategory) {
        outsideCategoryResults = await widget.controller.searchFoods(
          mealType: _mealType,
          query: query,
          includeMealSlot: false,
          limit: 8,
        );
      }
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      final primaryIds = primaryResults.map((food) => food.id).toSet();
      final outsideFoods = _outsideCategoryFoods(
        outsideCategoryResults,
        categoryPreference,
        primaryIds,
      );
      final displayResults = <_FoodSearchDisplayItem>[
        for (final food in primaryResults) _FoodSearchDisplayItem(food: food),
        for (final food in outsideFoods)
          _FoodSearchDisplayItem(food: food, outsideSelectedCategory: true),
      ];
      setState(() {
        _searchResults = displayResults.take(10).toList(growable: false);
        _searchLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      setState(() {
        _searchResults = const [];
        _searchLoading = false;
        _searchError = NetworkErrorMapper.toMessage(
          error,
          fallback: 'Failed to load food suggestions.',
        );
      });
    }
  }

  void _onMealTypeChanged(String mealType) {
    setState(() {
      _mealType = mealType;
      _ignoreMealTypeCategoryPreference = false;
      _syncCategorySelectionForMealType(mealType);
      if (_selectedFood != null &&
          (!_matchesMealType(_selectedFood!, mealType) ||
              !_matchesMealSlotPreference(_selectedFood!))) {
        _selectedFood = null;
        _selectedServingOptionId = null;
        _searchCtrl.clear();
      }
    });
    if (!_hasLockedSelection) {
      _lastSearchKey = null;
      _scheduleSearch(immediate: true);
    }
  }

  void _selectFood(FoodItem food) {
    _searchDebounce?.cancel();
    final servingChoices = _servingChoicesForFood(food);
    final defaultServing = servingChoices.isNotEmpty
        ? servingChoices.first
        : null;
    final defaultUnit = defaultServing != null
        ? 'serving'
        : _availableUnits(food).first;
    final defaultAmount = defaultUnit == 'serving'
        ? 1.0
        : food.defaultServingSize > 0
        ? food.defaultServingSize
        : food.servingGrams.toDouble();
    setState(() {
      _selectedFood = food;
      _searchCtrl.text = food.name;
      _unit = defaultUnit;
      _selectedServingOptionId = defaultServing?.id;
      _mealType = food.isBeverage
          ? 'drink'
          : _mealType == 'drink'
          ? 'breakfast'
          : _mealType;
      _ignoreMealTypeCategoryPreference = false;
      _syncCategorySelectionForMealType(_mealType);
      _amountCtrl.text = defaultAmount == defaultAmount.roundToDouble()
          ? defaultAmount.round().toString()
          : defaultAmount.toStringAsFixed(1);
      _searchResults = const [];
    });
  }

  double _previewFactor(FoodItem food, double amount, String unit) {
    if (amount <= 0) {
      return 0;
    }
    if (unit == 'serving') {
      final selectedOption = _selectedServingChoice(food);
      final base =
          selectedOption?.gramsEquivalent ??
          (food.defaultServingSize > 0
              ? food.defaultServingSize
              : food.servingGrams.toDouble());
      return (base * amount) / 100.0;
    }
    return amount / 100.0;
  }

  int? _previewHydrationMl(FoodItem food, double amount, String unit) {
    if (!food.isBeverage) {
      return null;
    }
    double milliliters = amount;
    if (unit == 'serving') {
      final selectedOption = _selectedServingChoice(food);
      milliliters =
          selectedOption?.millilitersEquivalent ??
          (food.defaultServingSize > 0
              ? food.defaultServingSize
              : food.servingGrams.toDouble());
      milliliters *= amount;
    }
    return food.hydrationContributionMl(milliliters.round());
  }

  bool get _hasSodiumNutritionGuide => widget.controller.chronicNutritionGuides
      .any((guide) => guide.metricKey.trim() == 'sodium_mg');

  List<_FoodHealthBadge> _healthBadgesForFood(
    FoodItem food, {
    double factor = 1,
  }) {
    final badges = <_FoodHealthBadge>[];
    final sugarG = food.sugars100g * factor;
    final sodiumMg = food.sodiumMg100g * factor;
    final caffeineMg = food.caffeineMg * factor;
    if (widget.controller.diabetesActive && sugarG > 0) {
      badges.add(
        const _FoodHealthBadge(
          label: 'Sugar watch',
          color: VitaMateTheme.danger,
        ),
      );
    }
    if (_hasSodiumNutritionGuide && sodiumMg > 0) {
      badges.add(
        const _FoodHealthBadge(
          label: 'Sodium watch',
          color: VitaMateTheme.warning,
        ),
      );
    }
    if (food.containsCaffeine || caffeineMg > 0) {
      badges.add(
        const _FoodHealthBadge(label: 'Caffeine', color: VitaMateTheme.accent),
      );
    }
    return badges;
  }

  String _amountLabelForSelection(FoodItem food, double amount, String unit) {
    final amountLabel = amount == amount.roundToDouble()
        ? amount.round().toString()
        : amount.toStringAsFixed(1);
    if (unit == 'serving') {
      final selectedOption = _selectedServingChoice(food);
      final servingLabel =
          selectedOption?.label ??
          (food.servingLabel.isNotEmpty ? food.servingLabel : 'serving');
      return '$amountLabel ${servingLabel.toLowerCase()}';
    }
    return '$amountLabel $unit';
  }

  List<_ServingChoice> _servingChoicesForFood(FoodItem? food) {
    if (food == null) {
      return const [];
    }
    final choices = <_ServingChoice>[];
    final seenLabels = <String>{};

    void addChoice(_ServingChoice choice) {
      final normalizedLabel = choice.label.trim().toLowerCase();
      if (normalizedLabel.isEmpty || seenLabels.contains(normalizedLabel)) {
        return;
      }
      seenLabels.add(normalizedLabel);
      choices.add(choice);
    }

    for (final option in food.servingOptions) {
      addChoice(
        _ServingChoice(
          id: option.id,
          label: option.displayLabel,
          summaryLabel: option.summaryLabel,
          gramsEquivalent: option.gramsEquivalent,
          millilitersEquivalent: option.millilitersEquivalent,
          servingOptionId: option.id,
        ),
      );
    }

    if (food.isBeverage) {
      final baseMl = _roundedAmount(
        _coerceServingBase(
          food.defaultServingOption?.millilitersEquivalent ??
              (food.defaultServingUnit.toLowerCase() == 'ml'
                  ? food.defaultServingSize
                  : food.servingGrams.toDouble()),
          minimum: 150,
          maximum: 500,
          fallback: 250,
        ),
      );
      addChoice(
        _ServingChoice(
          id: -201,
          label: 'Small cup',
          summaryLabel: '${_roundedAmount(baseMl * 0.75).round()} ml',
          millilitersEquivalent: _roundedAmount(baseMl * 0.75),
        ),
      );
      addChoice(
        _ServingChoice(
          id: -202,
          label: 'Cup',
          summaryLabel: '${baseMl.round()} ml',
          millilitersEquivalent: baseMl,
        ),
      );
      addChoice(
        _ServingChoice(
          id: -203,
          label: 'Large cup',
          summaryLabel: '${_roundedAmount(baseMl * 1.35).round()} ml',
          millilitersEquivalent: _roundedAmount(baseMl * 1.35),
        ),
      );
      addChoice(
        _ServingChoice(
          id: -204,
          label: 'Glass',
          summaryLabel: '${_roundedAmount(baseMl * 1.1).round()} ml',
          millilitersEquivalent: _roundedAmount(baseMl * 1.1),
        ),
      );
      addChoice(
        _ServingChoice(
          id: -205,
          label: 'Bottle',
          summaryLabel: '${_roundedAmount(baseMl * 2).round()} ml',
          millilitersEquivalent: _roundedAmount(baseMl * 2),
        ),
      );
      return choices;
    }

    final baseGrams = _roundedAmount(
      _coerceServingBase(
        food.defaultServingOption?.gramsEquivalent ??
            (food.defaultServingUnit.toLowerCase() == 'g'
                ? food.defaultServingSize
                : food.servingGrams.toDouble()),
        minimum: 120,
        maximum: 400,
        fallback: 220,
      ),
    );
    addChoice(
      _ServingChoice(
        id: -101,
        label: 'Small plate',
        summaryLabel: '${_roundedAmount(baseGrams * 0.7).round()} g',
        gramsEquivalent: _roundedAmount(baseGrams * 0.7),
      ),
    );
    addChoice(
      _ServingChoice(
        id: -102,
        label: 'Plate',
        summaryLabel: '${baseGrams.round()} g',
        gramsEquivalent: baseGrams,
      ),
    );
    addChoice(
      _ServingChoice(
        id: -103,
        label: 'Large plate',
        summaryLabel: '${_roundedAmount(baseGrams * 1.35).round()} g',
        gramsEquivalent: _roundedAmount(baseGrams * 1.35),
      ),
    );
    addChoice(
      _ServingChoice(
        id: -104,
        label: 'Bowl',
        summaryLabel: '${_roundedAmount(baseGrams * 1.05).round()} g',
        gramsEquivalent: _roundedAmount(baseGrams * 1.05),
      ),
    );
    addChoice(
      _ServingChoice(
        id: -105,
        label: 'Pan',
        summaryLabel: '${_roundedAmount(baseGrams * 1.6).round()} g',
        gramsEquivalent: _roundedAmount(baseGrams * 1.6),
      ),
    );
    return choices;
  }

  double _coerceServingBase(
    double rawValue, {
    required double minimum,
    required double maximum,
    required double fallback,
  }) {
    if (rawValue <= 0) {
      return fallback;
    }
    return rawValue.clamp(minimum, maximum);
  }

  double _roundedAmount(double value) {
    return (value / 10).round() * 10.0;
  }

  DateTime _consumedAt() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      _consumedTime.hour,
      _consumedTime.minute,
    );
  }

  Future<void> _saveMeal() async {
    final food = _selectedFood;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final servingOption = _selectedServingChoice(food);
    if (food == null || amount <= 0 || _saving) {
      return;
    }

    setState(() => _saving = true);
    try {
      if (_unit == 'g') {
        await widget.controller.logMeal(
          foodId: food.id,
          mealType: _mealType,
          quantityGrams: amount,
          consumedAt: _consumedAt(),
        );
      } else if (_unit == 'serving') {
        await widget.controller.logMeal(
          foodId: food.id,
          mealType: _mealType,
          quantity: amount,
          unit: _unit,
          servingOptionId: servingOption?.servingOptionId,
          servingLabelSnapshot: servingOption?.label,
          servingGramsEquivalent: servingOption?.gramsEquivalent,
          servingMillilitersEquivalent: servingOption?.millilitersEquivalent,
          consumedAt: _consumedAt(),
        );
      } else {
        await widget.controller.logMeal(
          foodId: food.id,
          mealType: _mealType,
          quantity: amount,
          unit: _unit,
          consumedAt: _consumedAt(),
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to log meal: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedFood = _selectedFood;
    final servingChoices = _servingChoicesForFood(selectedFood);
    final selectedServingChoice = _selectedServingChoice(selectedFood);
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final previewFactor = selectedFood == null
        ? 0.0
        : _previewFactor(selectedFood, amount, _unit);
    final categoryOptions = _categoryOptionsForMealType(_mealType);
    final activeFilterLabel = _activeMealFilterLabel;
    final results = _searchResults;
    final bestResults = results
        .where((item) => !item.outsideSelectedCategory)
        .toList(growable: false);
    final outsideCategoryResults = results
        .where((item) => item.outsideSelectedCategory)
        .toList(growable: false);
    final shouldShowResults =
        selectedFood == null || !_searchMatchesSelectedFood();

    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey(AppTestKeys.nutritionLogMealSheet),
        decoration: const BoxDecoration(
          color: VitaMateTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Log meal',
                            style: TextStyle(
                              color: VitaMateTheme.primaryDeep,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choose a food, set the amount, and save it to today.',
                            style: TextStyle(
                              color: VitaMateTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SheetLabel('Food or drink'),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey(AppTestKeys.nutritionSearchField),
                  controller: _searchCtrl,
                  onChanged: (_) {
                    setState(() {
                      if (_selectedFood != null &&
                          !_searchMatchesSelectedFood()) {
                        _selectedFood = null;
                        _selectedServingOptionId = null;
                        _selectedCategory = null;
                      }
                    });
                    if (!_hasLockedSelection) {
                      _scheduleSearch();
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search your food library',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                if (_searchCtrl.text.trim().length == 1 &&
                    !_searchMatchesSelectedFood()) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Type at least 2 letters to narrow the food search.',
                    style: TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (shouldShowResults) ...[
                  const SizedBox(height: 10),
                  if (_searchLoading)
                    const _SearchLoadingState()
                  else if (_searchError != null)
                    _InlineMessage(text: _searchError!)
                  else if (results.isEmpty)
                    _SearchEmptyState(
                      selectedCategory: activeFilterLabel,
                      onShowAllCategories: activeFilterLabel == null
                          ? null
                          : () {
                              setState(() {
                                _selectedCategory = null;
                                _ignoreMealTypeCategoryPreference = true;
                                _lastSearchKey = null;
                              });
                              _scheduleSearch(immediate: true);
                            },
                    )
                  else if (outsideCategoryResults.isNotEmpty)
                    Column(
                      children: [
                        if (bestResults.isNotEmpty) ...[
                          _FoodSearchResultGroup(
                            title: 'Best matches',
                            subtitle: activeFilterLabel == null
                                ? ''
                                : 'Inside $activeFilterLabel.',
                            items: bestResults,
                            badgeBuilder: _healthBadgesForFood,
                            onTap: _selectFood,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _FoodSearchResultGroup(
                          title: 'Similar outside selected category',
                          subtitle:
                              'Your category filter is narrow. These foods still match your search.',
                          items: outsideCategoryResults,
                          badgeBuilder: _healthBadgesForFood,
                          onTap: _selectFood,
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0; i < results.length; i++) ...[
                          _FoodLookupTile(
                            food: results[i].food,
                            healthBadges: _healthBadgesForFood(results[i].food),
                            onTap: () => _selectFood(results[i].food),
                          ),
                          if (i != results.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
                ],
                if (selectedFood != null) ...[
                  const SizedBox(height: 16),
                  _SelectedFoodPanel(
                    food: selectedFood,
                    amountLabel: _amountLabelForSelection(
                      selectedFood,
                      amount,
                      _unit,
                    ),
                    factor: previewFactor,
                    hydrationMl: _previewHydrationMl(
                      selectedFood,
                      amount,
                      _unit,
                    ),
                    diabetesActive: widget.controller.diabetesActive,
                    sodiumWatched: _hasSodiumNutritionGuide,
                    healthBadges: _healthBadgesForFood(
                      selectedFood,
                      factor: previewFactor,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const _SheetLabel('Meal type'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final option in _mealTypeOptions)
                      ChoiceChip(
                        label: Text(option.label),
                        selected: _mealType == option.value,
                        onSelected: (_) => _onMealTypeChanged(option.value),
                        labelStyle: TextStyle(
                          color: _mealType == option.value
                              ? Colors.white
                              : VitaMateTheme.primaryDeep,
                          fontWeight: FontWeight.w800,
                        ),
                        selectedColor: VitaMateTheme.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: _mealType == option.value
                              ? VitaMateTheme.primary
                              : VitaMateTheme.borderStrong,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SheetLabel('Category filter'),
                const SizedBox(height: 8),
                IgnorePointer(
                  key: const ValueKey(AppTestKeys.nutritionCategoryField),
                  ignoring: _hasLockedSelection,
                  child: Opacity(
                    opacity: _hasLockedSelection ? 0.72 : 1,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        'category:$_mealType:${_selectedCategory ?? ''}:${categoryOptions.length}',
                      ),
                      isExpanded: true,
                      initialValue: categoryOptions.contains(_selectedCategory)
                          ? _selectedCategory
                          : null,
                      decoration: const InputDecoration(
                        hintText: 'All categories',
                        prefixIcon: Icon(Icons.tune_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            'All categories',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final category in categoryOptions)
                          DropdownMenuItem<String>(
                            value: category,
                            child: Text(
                              category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                          _ignoreMealTypeCategoryPreference = false;
                          if (_selectedFood != null &&
                              !_matchesSelectedCategory(_selectedFood!)) {
                            _selectedFood = null;
                            _selectedServingOptionId = null;
                          }
                        });
                        if (!_hasLockedSelection) {
                          _scheduleSearch(immediate: true);
                        }
                      },
                    ),
                  ),
                ),
                if (_hasLockedSelection) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Category filters apply before choosing a food. Edit the search box to switch items.',
                    style: TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final unit in _availableUnits(selectedFood))
                      ChoiceChip(
                        label: Text(
                          unit == 'serving' ? 'Serving' : unit.toUpperCase(),
                        ),
                        selected: _unit == unit,
                        onSelected: (_) => setState(() {
                          _unit = unit;
                          if (_unit == 'serving' &&
                              _selectedFood != null &&
                              _selectedServingOptionId == null) {
                            final choices = _servingChoicesForFood(
                              _selectedFood,
                            );
                            _selectedServingOptionId = choices.isNotEmpty
                                ? choices.first.id
                                : null;
                            _amountCtrl.text = '1';
                          }
                        }),
                        labelStyle: TextStyle(
                          color: _unit == unit
                              ? Colors.white
                              : VitaMateTheme.primaryDeep,
                          fontWeight: FontWeight.w800,
                        ),
                        selectedColor: VitaMateTheme.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: _unit == unit
                              ? VitaMateTheme.primary
                              : VitaMateTheme.borderStrong,
                        ),
                      ),
                  ],
                ),
                if (_unit == 'serving' &&
                    selectedFood != null &&
                    servingChoices.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const _SheetLabel('Serving type'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'serving:${selectedFood.id}:${selectedServingChoice?.id ?? ''}',
                    ),
                    isExpanded: true,
                    initialValue: selectedServingChoice?.id,
                    decoration: const InputDecoration(
                      hintText: 'Select plate, cup, or bowl',
                      prefixIcon: Icon(Icons.table_restaurant_outlined),
                    ),
                    items: [
                      for (final option in servingChoices)
                        DropdownMenuItem<int>(
                          value: option.id,
                          child: Text(
                            '${option.displayLabel} (${option.summaryLabel})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedServingOptionId = value;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedServingChoice == null
                        ? 'Select the plate, bowl, cup, or pan you used.'
                        : 'Example: ${amount > 0 ? (amount == amount.roundToDouble() ? amount.round().toString() : amount.toStringAsFixed(1)) : '1'} ${selectedServingChoice.displayLabel.toLowerCase()}',
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _SheetLabel(_unit == 'serving' ? 'Serving count' : 'Amount'),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey(AppTestKeys.nutritionAmountField),
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: _unit == 'serving'
                        ? 'e.g. 2 small plates'
                        : 'Enter quantity',
                    suffixText: _unit == 'serving'
                        ? (selectedServingChoice?.displayLabel ??
                              (selectedFood?.defaultServingDisplayLabel
                                          .trim()
                                          .isNotEmpty ==
                                      true
                                  ? selectedFood!.defaultServingDisplayLabel
                                  : 'serving'))
                        : _unit,
                  ),
                ),
                const SizedBox(height: 18),
                const _SheetLabel('Time eaten'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _consumedTime,
                    );
                    if (picked != null) {
                      setState(() => _consumedTime = picked);
                    }
                  },
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(_consumedTime.format(context)),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () {
                                setState(() {
                                  _searchCtrl.clear();
                                  _amountCtrl.text = '1';
                                  _selectedFood = null;
                                  _searchResults = const [];
                                  _searchError = null;
                                  _mealType = 'breakfast';
                                  _selectedCategory = null;
                                  _selectedServingOptionId = null;
                                  _unit = 'serving';
                                  _consumedTime = TimeOfDay.now();
                                });
                                _scheduleSearch(immediate: true);
                              },
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        key: const ValueKey(
                          AppTestKeys.nutritionSaveMealButton,
                        ),
                        onPressed: _selectedFood == null || _saving
                            ? null
                            : _saveMeal,
                        child: Text(_saving ? 'Saving...' : 'Save meal'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateFoodSheet extends StatefulWidget {
  const _CreateFoodSheet({required this.controller});

  final NutritionController controller;

  @override
  State<_CreateFoodSheet> createState() => _CreateFoodSheetState();
}

class _CreateFoodSheetState extends State<_CreateFoodSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _calCtrl = TextEditingController();
  final TextEditingController _proteinCtrl = TextEditingController();
  final TextEditingController _carbCtrl = TextEditingController();
  final TextEditingController _fatCtrl = TextEditingController();
  final TextEditingController _servingLabelCtrl = TextEditingController(
    text: 'Serving',
  );
  final TextEditingController _servingGramsCtrl = TextEditingController(
    text: '200',
  );
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    _servingLabelCtrl.dispose();
    _servingGramsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final calories = int.tryParse(_calCtrl.text.trim()) ?? 0;
    if (_nameCtrl.text.trim().isEmpty || calories <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid name and calories.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.controller.createFood(
        name: _nameCtrl.text.trim(),
        calories100g: calories,
        protein100g: double.tryParse(_proteinCtrl.text.trim()) ?? 0,
        carbs100g: double.tryParse(_carbCtrl.text.trim()) ?? 0,
        fat100g: double.tryParse(_fatCtrl.text.trim()) ?? 0,
        servingLabel: _servingLabelCtrl.text.trim().isEmpty
            ? 'Serving'
            : _servingLabelCtrl.text.trim(),
        servingGrams: int.tryParse(_servingGramsCtrl.text.trim()) ?? 200,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create food: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey(AppTestKeys.nutritionCreateFoodSheet),
        decoration: const BoxDecoration(
          color: VitaMateTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create custom food',
                            style: TextStyle(
                              color: VitaMateTheme.primaryDeep,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Add a reusable item to your nutrition library.',
                            style: TextStyle(
                              color: VitaMateTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SheetLabel('Food name'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Chicken bowl',
                  ),
                ),
                const SizedBox(height: 14),
                const _SheetLabel('Calories per 100g'),
                const SizedBox(height: 8),
                TextField(
                  controller: _calCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(suffixText: 'kcal'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _proteinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Protein',
                          suffixText: 'g',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _carbCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Carbs',
                          suffixText: 'g',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _fatCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Fat',
                          suffixText: 'g',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _SheetLabel('Default serving'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _servingLabelCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Serving label',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _servingGramsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Serving grams',
                          suffixText: 'g',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () {
                                _nameCtrl.clear();
                                _calCtrl.clear();
                                _proteinCtrl.clear();
                                _carbCtrl.clear();
                                _fatCtrl.clear();
                                _servingLabelCtrl.text = 'Serving';
                                _servingGramsCtrl.text = '200';
                                setState(() {});
                              },
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        key: const ValueKey(
                          AppTestKeys.nutritionSaveFoodButton,
                        ),
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving...' : 'Add food'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedFoodPanel extends StatelessWidget {
  const _SelectedFoodPanel({
    required this.food,
    required this.amountLabel,
    required this.factor,
    required this.hydrationMl,
    required this.diabetesActive,
    required this.sodiumWatched,
    required this.healthBadges,
  });

  final FoodItem food;
  final String amountLabel;
  final double factor;
  final int? hydrationMl;
  final bool diabetesActive;
  final bool sodiumWatched;
  final List<_FoodHealthBadge> healthBadges;

  @override
  Widget build(BuildContext context) {
    final calories = (food.calories100g * factor).round();
    final protein = (food.protein100g * factor).round();
    final carbs = (food.carbs100g * factor).round();
    final fat = (food.fat100g * factor).round();
    final sugar = (food.sugars100g * factor).round();
    final sodium = (food.sodiumMg100g * factor).round();
    final caffeine = (food.caffeineMg * factor).round();

    return _NutritionPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      color: VitaMateTheme.softSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: const TextStyle(
                        color: VitaMateTheme.primaryDeep,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      food.supportingLabel,
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _BadgeChip(
                label: amountLabel,
                color: food.isBeverage
                    ? VitaMateTheme.accent
                    : VitaMateTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BadgeChip(
                label: '$calories kcal',
                color: VitaMateTheme.primaryDeep,
              ),
              _BadgeChip(
                label: 'Protein $protein g',
                color: VitaMateTheme.primary,
              ),
              _BadgeChip(label: 'Carbs $carbs g', color: VitaMateTheme.accent),
              _BadgeChip(label: 'Fat $fat g', color: VitaMateTheme.warning),
              if (diabetesActive || sugar > 0)
                _BadgeChip(
                  label: 'Sugar $sugar g',
                  color: diabetesActive
                      ? VitaMateTheme.danger
                      : VitaMateTheme.warning,
                ),
              if (hydrationMl != null)
                _BadgeChip(
                  label: 'Hydration $hydrationMl ml',
                  color: VitaMateTheme.primary,
                ),
              if (sodium > 0)
                _BadgeChip(
                  label: 'Sodium $sodium mg',
                  color: sodiumWatched
                      ? VitaMateTheme.warning
                      : VitaMateTheme.textMuted,
                ),
              if (food.containsCaffeine || caffeine > 0)
                _BadgeChip(
                  label: 'Caffeine $caffeine mg',
                  color: VitaMateTheme.accent,
                ),
              for (final badge in healthBadges.where(
                (badge) => badge.label != 'Caffeine',
              ))
                _BadgeChip(label: badge.label, color: badge.color),
            ],
          ),
        ],
      ),
    );
  }
}

class _FoodLookupTile extends StatelessWidget {
  const _FoodLookupTile({
    required this.food,
    required this.healthBadges,
    required this.onTap,
  });

  final FoodItem food;
  final List<_FoodHealthBadge> healthBadges;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final servingSummary = food.defaultServingOption?.summaryLabel ?? '';
    final subtitleParts = <String>[
      if (food.supportingLabel.trim().isNotEmpty) food.supportingLabel.trim(),
      if (servingSummary.isNotEmpty) servingSummary,
    ];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: VitaMateTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: food.isBeverage
                    ? VitaMateTheme.accent.withValues(alpha: 0.12)
                    : VitaMateTheme.softSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                food.isBeverage
                    ? Icons.local_drink_outlined
                    : Icons.restaurant_menu_rounded,
                color: food.isBeverage
                    ? VitaMateTheme.accent
                    : VitaMateTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (subtitleParts.isNotEmpty)
                    Text(
                      subtitleParts.join(' - '),
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (healthBadges.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final badge in healthBadges)
                          _BadgeChip(label: badge.label, color: badge.color),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Text(
              food.isBeverage
                  ? '${food.calories100g} kcal/100 ml'
                  : '${food.calories100g} kcal/100 g',
              style: const TextStyle(
                color: VitaMateTheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodSearchResultGroup extends StatelessWidget {
  const _FoodSearchResultGroup({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.badgeBuilder,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<_FoodSearchDisplayItem> items;
  final List<_FoodHealthBadge> Function(FoodItem food) badgeBuilder;
  final void Function(FoodItem food) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(22),
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
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            _FoodLookupTile(
              food: items[i].food,
              healthBadges: badgeBuilder(items[i].food),
              onTap: () => onTap(items[i].food),
            ),
            if (i != items.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({
    required this.selectedCategory,
    required this.onShowAllCategories,
  });

  final String? selectedCategory;
  final VoidCallback? onShowAllCategories;

  @override
  Widget build(BuildContext context) {
    final hasCategory =
        selectedCategory != null && selectedCategory!.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasCategory
                ? 'No matching foods found inside $selectedCategory.'
                : 'No matching foods found. Create a custom item if it is missing.',
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (hasCategory && onShowAllCategories != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onShowAllCategories,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Show all categories'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchLoadingState extends StatelessWidget {
  const _SearchLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading food suggestions...',
              style: TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallTrackButton extends StatelessWidget {
  const _SmallTrackButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: VitaMateTheme.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
        backgroundColor: VitaMateTheme.softSurface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
            fontSize: 17,
          ),
        ),
      ),
    );
  }
}

class _NutritionPanel extends StatelessWidget {
  const _NutritionPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.96),
        borderRadius: borderRadius ?? BorderRadius.circular(22),
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

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label, required this.color});

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

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
    this.alignEnd = false,
  });

  final String value;
  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: VitaMateTheme.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _DividerColumn extends StatelessWidget {
  const _DividerColumn();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: VitaMateTheme.borderStrong,
      margin: const EdgeInsets.symmetric(horizontal: 14),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionState extends StatelessWidget {
  const _EmptySectionState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _NutritionPanel(
      padding: const EdgeInsets.all(18),
      child: Text(
        message,
        style: const TextStyle(
          color: VitaMateTheme.textMuted,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaMateTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: VitaMateTheme.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: VitaMateTheme.primaryDeep,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ServingChoice {
  const _ServingChoice({
    required this.id,
    required this.label,
    required this.summaryLabel,
    this.gramsEquivalent,
    this.millilitersEquivalent,
    this.servingOptionId,
  });

  final int id;
  final String label;
  final String summaryLabel;
  final double? gramsEquivalent;
  final double? millilitersEquivalent;
  final int? servingOptionId;

  String get displayLabel => label;
}

const Set<String> _genericCategoryLabels = <String>{
  'food',
  'foods',
  'beverage',
  'beverages',
  'drink',
  'drinks',
  'not included in a food category',
};

const int _outsideCategoryFallbackThreshold = 3;

class _MealTypeOption {
  const _MealTypeOption(this.value, this.label);

  final String value;
  final String label;
}

const List<_MealTypeOption> _mealTypeOptions = <_MealTypeOption>[
  _MealTypeOption('breakfast', 'Breakfast'),
  _MealTypeOption('lunch', 'Lunch'),
  _MealTypeOption('dinner', 'Dinner'),
  _MealTypeOption('snack', 'Snack'),
  _MealTypeOption('dessert', 'Dessert'),
  _MealTypeOption('drink', 'Drink'),
];

const Map<String, String> _mealTypeLabels = <String, String>{
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'dinner': 'Dinner',
  'snack': 'Snack',
  'dessert': 'Dessert',
  'drink': 'Drink',
};

IconData _mealTypeIcon(MealLog meal) {
  switch (meal.mealType) {
    case 'breakfast':
      return Icons.free_breakfast_rounded;
    case 'lunch':
      return Icons.lunch_dining_rounded;
    case 'dinner':
      return Icons.dinner_dining_rounded;
    case 'snack':
      return Icons.cookie_outlined;
    case 'dessert':
      return Icons.icecream_outlined;
    default:
      return Icons.restaurant_rounded;
  }
}
