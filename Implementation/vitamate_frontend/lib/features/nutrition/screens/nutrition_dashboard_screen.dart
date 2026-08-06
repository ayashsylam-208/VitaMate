import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/routing/routes.dart';
import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../data/nutrition_repository.dart';
import '../models/meal_log.dart';
import '../models/nutrition_summary.dart';
import '../state/nutrition_controller.dart';
import '../widgets/nutrition_ui.dart';
import 'food_library_screen.dart';
import 'log_meal_screen.dart';
import 'micronutrients_screen.dart';
import 'nutrition_details_screen.dart';
import 'today_meals_screen.dart';

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

  @override
  void initState() {
    super.initState();
    controller =
        widget.controller ??
        NutritionController(repository: NutritionRepository());
    _ownsController = widget.controller == null;
    if (widget.autoLoad) unawaited(controller.load());
  }

  @override
  void dispose() {
    if (_ownsController) controller.dispose();
    super.dispose();
  }

  Future<void> _openLogMeal() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => LogMealScreen(controller: controller),
      ),
    );
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _openNotificationSettings() {
    Navigator.of(context).pushNamed(Routes.managerNotifications);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VitaMateTheme.shellBackground,
    bottomNavigationBar: const _NutritionBottomNav(),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.loading && controller.summary.targetCalories == 0) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.error != null && controller.meals.isEmpty) {
            return NutritionErrorView(
              message: controller.error!,
              onRetry: controller.load,
            );
          }

          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFFF5F0FF),
                  Color(0xFFFBF9FF),
                  Color(0xFFF7F2FF),
                ],
                stops: <double>[0, 0.48, 1],
              ),
            ),
            child: RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                key: const ValueKey(AppTestKeys.nutritionScreen),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                children: <Widget>[
                  _NutritionHeader(
                    onLibraryTap: () =>
                        _push(FoodLibraryScreen(controller: controller)),
                    onNotificationsTap: _openNotificationSettings,
                  ),
                  const SizedBox(height: 24),
                  _DailySummaryCard(summary: controller.summary),
                  const SizedBox(height: 14),
                  _MacroCard(
                    summary: controller.summary,
                    onViewDetails: () =>
                        _push(NutritionDetailsScreen(controller: controller)),
                  ),
                  const SizedBox(height: 14),
                  _LogMealButton(onPressed: _openLogMeal),
                  const SizedBox(height: 16),
                  _TodayMealsCard(
                    meals: controller.meals,
                    onViewAll: () =>
                        _push(TodayMealsScreen(controller: controller)),
                    onOpenGroup: (hasMeals) {
                      if (hasMeals) {
                        _push(TodayMealsScreen(controller: controller));
                      } else {
                        unawaited(_openLogMeal());
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _MicronutrientsCard(
                    trackedCount:
                        controller.micronutrients.deficiencyTracked.length,
                    hasData: controller.micronutrients.items.isNotEmpty,
                    onTap: () =>
                        _push(MicronutrientsScreen(controller: controller)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _NutritionHeader extends StatelessWidget {
  const _NutritionHeader({
    required this.onLibraryTap,
    required this.onNotificationsTap,
  });

  final VoidCallback onLibraryTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _RoundHeaderButton(
        tooltip: 'Food library',
        icon: Icons.eco_outlined,
        onTap: onLibraryTap,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          children: <Widget>[
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Nutrition',
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF241065),
                  fontSize: 34,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                ),
              ),
            ),
            const SizedBox(height: 7),
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Track meals, drinks, and daily',
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF665B7C),
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'nutrition in one place.',
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF665B7C),
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      _RoundHeaderButton(
        tooltip: 'Notification settings',
        icon: Icons.notifications_none_rounded,
        showDot: true,
        onTap: onNotificationsTap,
      ),
    ],
  );
}

class _RoundHeaderButton extends StatelessWidget {
  const _RoundHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      shadowColor: const Color(0x24382189),
      elevation: 6,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 54,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Icon(icon, color: const Color(0xFF28106B), size: 28),
              if (showDot)
                const Positioned(
                  top: 11,
                  right: 11,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF7138F5),
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Colors.white, width: 2),
                      ),
                    ),
                    child: SizedBox.square(dimension: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({required this.summary});

  final NutritionSummary summary;

  @override
  Widget build(BuildContext context) {
    final target = summary.targetCalories;
    final progress = target > 0
        ? summary.consumedCalories / target
        : summary.progressPercent / 100;
    final progressPercent = target > 0
        ? ((summary.consumedCalories / target) * 100).round()
        : summary.progressPercent.round();
    final status = _calorieStatus(summary, progressPercent);

    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 320;
          final ringSize = compact ? 112.0 : 132.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Today's Summary",
                        maxLines: 1,
                        style: TextStyle(
                          color: Color(0xFF1D1256),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: '${summary.consumedCalories}',
                              style: const TextStyle(
                                color: Color(0xFF5C1EF2),
                                fontSize: 31,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            TextSpan(
                              text: target > 0 ? ' / $target' : ' / --',
                              style: const TextStyle(
                                color: Color(0xFF5C5870),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text: ' kcal',
                              style: TextStyle(
                                color: Color(0xFF5C5870),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      target > 0
                          ? '${summary.remainingCalories} kcal left'
                          : 'Set your calorie target',
                      style: const TextStyle(
                        color: Color(0xFF5C1EF2),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _StatusChip(status: status),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _GradientNutritionRing(
                progress: progress,
                size: ringSize,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.ramen_dining_outlined,
                      color: Color(0xFF6726F5),
                      size: 34,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$progressPercent%',
                      style: const TextStyle(
                        color: Color(0xFF28106B),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CalorieStatus {
  const _CalorieStatus(this.label, this.color, this.background, this.icon);

  final String label;
  final Color color;
  final Color background;
  final IconData icon;
}

_CalorieStatus _calorieStatus(NutritionSummary summary, int progressPercent) {
  switch (summary.status) {
    case 'good':
    case 'on_track':
      return const _CalorieStatus(
        'On track',
        Color(0xFF5C1EF2),
        Color(0xFFF0E9FF),
        Icons.local_fire_department_rounded,
      );
    case 'over_target':
    case 'high':
      return const _CalorieStatus(
        'Over target',
        Color(0xFFBF5B16),
        Color(0xFFFFEEDC),
        Icons.trending_up_rounded,
      );
    case 'not_configured':
      return const _CalorieStatus(
        'Set target',
        Color(0xFF655A78),
        Color(0xFFF2EEF8),
        Icons.tune_rounded,
      );
    default:
      return _CalorieStatus(
        '$progressPercent% of goal',
        const Color(0xFF5C1EF2),
        const Color(0xFFF0E9FF),
        Icons.bolt_rounded,
      );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _CalorieStatus status;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: status.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(status.icon, color: status.color, size: 18),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(color: status.color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.summary, required this.onViewDetails});

  final NutritionSummary summary;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final protein = _macro(summary, 'protein', summary.proteinG, 100);
    final carbs = _macro(summary, 'carbs', summary.carbsG, 250);
    final fat = _macro(summary, 'fat', summary.fatG, 70);

    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onViewDetails,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'View details',
                    style: TextStyle(
                      color: Color(0xFF5E22F2),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF5E22F2),
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _MacroItem(
                  label: 'Protein',
                  data: protein,
                  icon: Icons.egg_alt_outlined,
                  color: const Color(0xFFFF5A1F),
                  iconBackground: const Color(0xFFFFEADB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MacroItem(
                  label: 'Carbs',
                  data: carbs,
                  icon: Icons.grass_rounded,
                  color: const Color(0xFF286BFF),
                  iconBackground: const Color(0xFFE7F0FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MacroItem(
                  label: 'Fat',
                  data: fat,
                  icon: Icons.water_drop_outlined,
                  color: const Color(0xFF3D9D13),
                  iconBackground: const Color(0xFFEAF6E5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroData {
  const _MacroData(this.value, this.target, this.progressPercent);

  final double value;
  final double target;
  final double progressPercent;
}

_MacroData _macro(
  NutritionSummary summary,
  String code,
  double fallbackValue,
  double fallbackTarget,
) {
  NutritionSummaryMetric? metric;
  for (final item in summary.metrics) {
    if (item.code == code) {
      metric = item;
      break;
    }
  }
  final value = metric?.value ?? fallbackValue;
  final target = metric?.target ?? fallbackTarget;
  final progress =
      metric?.progressPercent ?? (target > 0 ? (value / target) * 100 : 0);
  return _MacroData(value, target, progress);
}

class _MacroItem extends StatelessWidget {
  const _MacroItem({
    required this.label,
    required this.data,
    required this.icon,
    required this.color,
    required this.iconBackground,
  });

  final String label;
  final _MacroData data;
  final IconData icon;
  final Color color;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    final progress = data.progressPercent.clamp(0, 100) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 38,
                child: Icon(icon, color: color, size: 22),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFF20155C),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: compactNumber(data.value),
                            style: TextStyle(
                              color: color,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(
                            text: ' / ${compactNumber(data.target)} g',
                            style: const TextStyle(
                              color: Color(0xFF625D73),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress.toDouble(),
            minHeight: 5,
            backgroundColor: const Color(0xFFF0ECF8),
            color: color,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${data.progressPercent.round()}%',
          style: const TextStyle(
            color: Color(0xFF6A647B),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LogMealButton extends StatelessWidget {
  const _LogMealButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(
        colors: <Color>[Color(0xFF5420ED), Color(0xFFA447F5)],
      ),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x405C2BE7),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey(AppTestKeys.nutritionLogMealButton),
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: const SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.white,
                size: 29,
              ),
              SizedBox(width: 11),
              Text(
                'Log Meal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TodayMealsCard extends StatelessWidget {
  const _TodayMealsCard({
    required this.meals,
    required this.onViewAll,
    required this.onOpenGroup,
  });

  final List<MealLog> meals;
  final VoidCallback onViewAll;
  final ValueChanged<bool> onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final groups = _MealGroupData.build(meals);
    return _DashboardCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  "Today's Meals",
                  style: TextStyle(
                    color: Color(0xFF21155D),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SmallAction(label: 'View all', onTap: onViewAll),
            ],
          ),
          const SizedBox(height: 8),
          if (meals.isEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onOpenGroup(false),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 22, horizontal: 8),
                child: Row(
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFF0E9FF),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(
                        dimension: 42,
                        child: Icon(
                          Icons.restaurant_menu_rounded,
                          color: Color(0xFF6025ED),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No meals yet. Start with a quick log or scan.',
                        style: TextStyle(
                          color: Color(0xFF675E7C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFF655F75)),
                  ],
                ),
              ),
            )
          else
            for (var i = 0; i < groups.length; i++) ...<Widget>[
              _MealGroupRow(
                data: groups[i],
                onTap: () => onOpenGroup(groups[i].mealCount > 0),
              ),
              if (i != groups.length - 1)
                const Divider(height: 1, color: Color(0xFFEAE5F1)),
            ],
        ],
      ),
    );
  }
}

class _MealGroupData {
  const _MealGroupData({
    required this.label,
    required this.mealCount,
    required this.itemCount,
    required this.calories,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final int mealCount;
  final int itemCount;
  final int calories;
  final IconData icon;
  final Color color;
  final Color background;

  static List<_MealGroupData> build(List<MealLog> meals) {
    return <_MealGroupData>[
      _create(
        meals,
        label: 'Breakfast',
        matches: (meal) => meal.mealType == 'breakfast',
        icon: Icons.wb_twilight_rounded,
        color: const Color(0xFFC87800),
        background: const Color(0xFFFFF0D9),
      ),
      _create(
        meals,
        label: 'Lunch',
        matches: (meal) => meal.mealType == 'lunch',
        icon: Icons.wb_sunny_outlined,
        color: const Color(0xFF1572E8),
        background: const Color(0xFFE5F1FF),
      ),
      _create(
        meals,
        label: 'Dinner',
        matches: (meal) => meal.mealType == 'dinner',
        icon: Icons.nightlight_round,
        color: const Color(0xFF6324F3),
        background: const Color(0xFFF0E8FF),
      ),
      _create(
        meals,
        label: 'Snacks',
        matches: (meal) =>
            meal.mealType == 'snack' || meal.mealType == 'dessert',
        icon: Icons.apple_rounded,
        color: const Color(0xFFE23C2D),
        background: const Color(0xFFFFE9E5),
      ),
      _create(
        meals,
        label: 'Drinks',
        matches: (meal) => meal.mealType == 'drink',
        icon: Icons.local_drink_outlined,
        color: const Color(0xFF0798B9),
        background: const Color(0xFFE1F7FA),
      ),
    ];
  }

  static _MealGroupData _create(
    List<MealLog> meals, {
    required String label,
    required bool Function(MealLog meal) matches,
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    final matching = meals.where(matches).toList(growable: false);
    final itemCount = matching.fold<int>(0, (total, meal) {
      if (meal.isComposite && meal.components.isNotEmpty) {
        return total + meal.components.length;
      }
      return total + 1;
    });
    final calories = matching.fold<double>(
      0,
      (total, meal) => total + meal.caloriesKcal,
    );
    return _MealGroupData(
      label: label,
      mealCount: matching.length,
      itemCount: itemCount,
      calories: calories.round(),
      icon: icon,
      color: color,
      background: background,
    );
  }
}

class _MealGroupRow extends StatelessWidget {
  const _MealGroupRow({required this.data, required this.onTap});

  final _MealGroupData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: data.background,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 38,
              child: Icon(data.icon, color: data.color, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: data.label,
                    style: const TextStyle(
                      color: Color(0xFF21155D),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text:
                        '  •  ${data.itemCount} ${data.itemCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(
                      color: Color(0xFF686277),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '${data.calories}',
                  style: const TextStyle(
                    color: Color(0xFF5F20F3),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const TextSpan(
                  text: ' kcal',
                  style: TextStyle(
                    color: Color(0xFF655F73),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF5F596E),
            size: 23,
          ),
        ],
      ),
    ),
  );
}

class _MicronutrientsCard extends StatelessWidget {
  const _MicronutrientsCard({
    required this.trackedCount,
    required this.hasData,
    required this.onTap,
  });

  final int trackedCount;
  final bool hasData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = !hasData
        ? 'Review'
        : trackedCount == 0
        ? 'Good'
        : '$trackedCount tracked';
    final good = hasData && trackedCount == 0;
    return _DashboardCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFF0E9FF),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 46,
                  child: Icon(
                    Icons.health_and_safety_outlined,
                    color: Color(0xFF6125F2),
                    size: 27,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Flexible(
                          child: Text(
                            'Micronutrients',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF21155D),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: good
                                ? const Color(0xFFEAF6E3)
                                : const Color(0xFFF0E9FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: good
                                    ? const Color(0xFF397E21)
                                    : const Color(0xFF6427E9),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Track vitamins & minerals',
                      style: TextStyle(
                        color: Color(0xFF6C657D),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'View all',
                style: TextStyle(
                  color: Color(0xFF5F20F3),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF5F20F3),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF5F0FF),
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5E20F0),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF5E20F0),
              size: 19,
            ),
          ],
        ),
      ),
    ),
  );
}

class _NutritionBottomNav extends StatelessWidget {
  const _NutritionBottomNav();

  static const _items = <_NutritionNavItem>[
    _NutritionNavItem('Home', Icons.home_outlined, Routes.home),
    _NutritionNavItem(
      'Activity',
      Icons.directions_run_rounded,
      Routes.activities,
    ),
    _NutritionNavItem('Nutrition', Icons.eco_rounded, Routes.meals),
    _NutritionNavItem('Progress', Icons.bar_chart_rounded, Routes.progress),
    _NutritionNavItem(
      'Profile',
      Icons.person_outline_rounded,
      Routes.myVitaMate,
    ),
  ];

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFFFEFDFF),
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      border: Border(top: BorderSide(color: Color(0xFFF0EAFB))),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Color(0x1A382189),
          blurRadius: 22,
          offset: Offset(0, -6),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
        child: Row(
          children: <Widget>[
            for (final item in _items)
              Expanded(
                child: _NutritionNavButton(
                  item: item,
                  selected: item.route == Routes.meals,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _NutritionNavButton extends StatelessWidget {
  const _NutritionNavButton({required this.item, required this.selected});

  final _NutritionNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: selected
        ? null
        : () => Navigator.of(context).pushReplacementNamed(item.route),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 51 : 42,
            height: 34,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF0E8FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Icon(
              item.icon,
              size: selected ? 25 : 24,
              color: selected
                  ? const Color(0xFF5E20F2)
                  : const Color(0xFF6B6980),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.label,
              maxLines: 1,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF5E20F2)
                    : const Color(0xFF858198),
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NutritionNavItem {
  const _NutritionNavItem(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFF0EAFB)),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x173A2386),
          blurRadius: 22,
          offset: Offset(0, 9),
        ),
      ],
    ),
    child: child,
  );
}

class _GradientNutritionRing extends StatelessWidget {
  const _GradientNutritionRing({
    required this.progress,
    required this.size,
    required this.center,
  });

  final double progress;
  final double size;
  final Widget center;

  @override
  Widget build(BuildContext context) {
    final targetProgress = progress.clamp(0.0, 1.0);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: targetProgress),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        child: Center(child: center),
        builder: (context, value, child) => CustomPaint(
          painter: _GradientRingPainter(progress: value),
          child: child,
        ),
      ),
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  const _GradientRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.105;
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final track = Paint()
      ..color = const Color(0xFFE9DEFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);

    final value = progress.clamp(0.0, 1.0);
    if (value <= 0) return;
    final foreground = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 3 / 2,
        colors: <Color>[
          Color(0xFF5217E9),
          Color(0xFFA03DFA),
          Color(0xFF6121EE),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, foreground);
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
