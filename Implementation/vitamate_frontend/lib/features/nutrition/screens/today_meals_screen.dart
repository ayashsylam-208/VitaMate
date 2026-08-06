import 'package:flutter/material.dart';

import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../models/meal_log.dart';
import '../state/nutrition_controller.dart';
import '../widgets/nutrition_reference_ui.dart';
import '../widgets/nutrition_ui.dart';
import 'log_meal_screen.dart';
import 'meal_details_screen.dart';

class TodayMealsScreen extends StatefulWidget {
  const TodayMealsScreen({super.key, required this.controller});

  final NutritionController controller;

  @override
  State<TodayMealsScreen> createState() => _TodayMealsScreenState();
}

class _TodayMealsScreenState extends State<TodayMealsScreen> {
  static const filters = <String, String>{
    'all': 'All',
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snacks',
    'drink': 'Drinks',
  };

  String filter = 'all';
  bool loading = true;
  String? error;
  List<MealLog> meals = const <MealLog>[];
  final Set<String> collapsed = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await widget.controller.getMealsForDate(DateTime.now());
      if (mounted) setState(() => meals = _dedupeLinkedDrinks(values));
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openLog() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => LogMealScreen(controller: widget.controller),
      ),
    );
    if (result != null) await _load();
  }

  Future<void> _openDetails(MealLog meal) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            MealDetailsScreen(controller: widget.controller, meal: meal),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _delete(MealLog meal) async {
    final backup = meals;
    setState(() => meals = meals.where((item) => item.id != meal.id).toList());
    try {
      await widget.controller.deleteMeal(meal.id);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        meals = backup;
        error = exception.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    return Scaffold(
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 1),
      body: SafeArea(
        child: NutritionReferenceBackground(
          child: Column(
            children: <Widget>[
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: <Widget>[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        sliver: SliverToBoxAdapter(
                          child: NutritionReferenceHeader(
                            title: "Today's Meals",
                            subtitle: "Review today's meals and drinks.",
                            trailing: NutritionRoundButton(
                              tooltip: 'Refresh meals',
                              icon: Icons.filter_list_rounded,
                              onTap: loading ? null : _load,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 50,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: filters.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, index) {
                              final entry = filters.entries.elementAt(index);
                              return _FilterChip(
                                value: entry.key,
                                label: entry.value,
                                selected: filter == entry.key,
                                onTap: () => setState(() => filter = entry.key),
                              );
                            },
                          ),
                        ),
                      ),
                      if (loading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (error != null && meals.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: NutritionErrorView(
                            message: error!,
                            onRetry: _load,
                          ),
                        )
                      else if (groups.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyMeals(filterLabel: filters[filter]!),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                          sliver: SliverList.builder(
                            itemCount: groups.length,
                            itemBuilder: (_, index) {
                              final group = groups[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _MealGroupCard(
                                  mealType: group.$1,
                                  meals: group.$2,
                                  collapsed: collapsed.contains(group.$1),
                                  onToggle: () => setState(() {
                                    if (!collapsed.add(group.$1)) {
                                      collapsed.remove(group.$1);
                                    }
                                  }),
                                  onOpen: _openDetails,
                                  onDelete: _delete,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: NutritionGradientButton(
                  label: 'Log Meal',
                  icon: Icons.add_circle_rounded,
                  onTap: _openLog,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<(String, List<MealLog>)> _groups() {
    bool include(MealLog meal, String key) {
      if (key == 'snack') {
        return meal.mealType == 'snack' || meal.mealType == 'dessert';
      }
      return meal.mealType == key;
    }

    final keys = filter == 'all'
        ? const <String>['breakfast', 'lunch', 'dinner', 'snack', 'drink']
        : <String>[filter];
    return keys
        .map((key) {
          final values = meals.where((meal) => include(meal, key)).toList()
            ..sort(
              (a, b) => (a.consumedAt ?? DateTime(0)).compareTo(
                b.consumedAt ?? DateTime(0),
              ),
            );
          return (key, values);
        })
        .where((group) => group.$2.isNotEmpty)
        .toList(growable: false);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.value,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? nutritionPurple : Colors.white.withValues(alpha: 0.78),
    shape: StadiumBorder(
      side: BorderSide(
        color: selected ? nutritionPurple : const Color(0xFFDDD3F2),
      ),
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (value != 'all') ...<Widget>[
              Icon(
                nutritionMealTypeIcon(value),
                size: 18,
                color: selected ? Colors.white : nutritionPurple,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF5D5573),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MealGroupCard extends StatelessWidget {
  const _MealGroupCard({
    required this.mealType,
    required this.meals,
    required this.collapsed,
    required this.onToggle,
    required this.onOpen,
    required this.onDelete,
  });

  final String mealType;
  final List<MealLog> meals;
  final bool collapsed;
  final VoidCallback onToggle;
  final ValueChanged<MealLog> onOpen;
  final Future<void> Function(MealLog) onDelete;

  @override
  Widget build(BuildContext context) {
    final subtotal = meals.fold<double>(
      0,
      (sum, item) => sum + item.caloriesKcal,
    );
    final label = mealType == 'snack'
        ? 'Snacks'
        : nutritionMealTypeLabel(mealType);
    return NutritionReferenceCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0E9FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox.square(
                      dimension: 40,
                      child: Icon(
                        nutritionMealTypeIcon(mealType),
                        color: nutritionPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: nutritionInk,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${subtotal.round()} kcal',
                    style: const TextStyle(
                      color: nutritionPurple,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    collapsed
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                    color: const Color(0xFF625C72),
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed)
            for (final meal in meals) ...<Widget>[
              const Divider(height: 1, color: nutritionLine),
              Dismissible(
                key: ValueKey<String>('meal-${meal.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  await onDelete(meal);
                  return false;
                },
                background: const ColoredBox(
                  color: Color(0xFFF05B63),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: 18),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                child: InkWell(
                  onTap: () => onOpen(meal),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: <Widget>[
                        NutritionIconBubble(
                          icon: meal.isComposite
                              ? Icons.ramen_dining_rounded
                              : nutritionMealTypeIcon(mealType),
                          color: nutritionPurple,
                          background: const Color(0xFFF2ECFF),
                          size: 42,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                meal.foodName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: nutritionInk,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${meal.amountLabel}  •  ${nutritionTime(meal.consumedAt?.toLocal())}',
                                style: const TextStyle(
                                  color: nutritionMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3EDFF),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              '${meal.caloriesKcal.round()} kcal',
                              style: const TextStyle(
                                color: nutritionPurple,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF625C72),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals({required this.filterLabel});

  final String filterLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.restaurant_menu_rounded,
            size: 52,
            color: nutritionPurple,
          ),
          const SizedBox(height: 12),
          Text(
            filterLabel == 'All'
                ? 'No meals logged today.'
                : 'No ${filterLabel.toLowerCase()} logged today.',
            style: const TextStyle(
              color: nutritionInk,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

List<MealLog> _dedupeLinkedDrinks(List<MealLog> values) {
  final seen = <String>{};
  return values
      .where((meal) => seen.add('${meal.source}:${meal.id}'))
      .toList(growable: false);
}
