import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../../../shared/widgets/chronic_guide_card.dart';
import '../../../core/notifications/notifications_service.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../data/nutrition_api.dart';
import '../models/food_item.dart';
import '../models/meal_log.dart';
import '../models/nutrition_summary.dart';
import '../state/nutrition_controller.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late final NutritionController controller;
  final _quantityCtrl = TextEditingController(text: '200');

  FoodItem? _selectedFood;
  String _mealType = 'breakfast';
  bool _showAllNutritionValues = false;

  bool mealRemindersEnabled = false;
  TimeOfDay breakfast = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay lunch = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay dinner = const TimeOfDay(hour: 19, minute: 0);

  @override
  void initState() {
    super.initState();
    controller = NutritionController(api: NutritionApi())..load();
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _pickTime(
    TimeOfDay current,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.Hm();

    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 1),
      appBar: AppBar(title: const Text('Nutrition')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.error != null) {
              return Center(child: Text(controller.error!));
            }

            final summary = controller.summary;
            final foods = controller.foods;
            if (_selectedFood != null) {
              final match = foods
                  .where((f) => f.id == _selectedFood!.id)
                  .toList();
              _selectedFood = match.isNotEmpty ? match.first : null;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryCard(summary),
                  const SizedBox(height: 14),
                  _reminderCard(dateFmt),
                  const SizedBox(height: 14),
                  _todayLogsCard(dateFmt),
                  const SizedBox(height: 14),
                  _logMealCard(),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateFoodSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add food'),
      ),
    );
  }

  Widget _summaryCard(NutritionSummary summary) {
    final details = controller.detailBreakdown;
    final sugarColor = controller.diabetesActive
        ? VitaMateTheme.danger
        : VitaMateTheme.warning;

    return _NutritionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's nutrition",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Meals and drinks stay connected to the same daily totals.',
            style: TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (controller.diabetesActive) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: VitaMateTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: VitaMateTheme.danger.withValues(alpha: 0.16),
                ),
              ),
              child: Text(
                'Diabetes tracking is active. Sugar values are highlighted in today\'s foods and drinks.',
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if (controller.chronicNutritionGuides.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Condition goals and limits',
              style: TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: controller.chronicNutritionGuides
                  .take(4)
                  .map((item) => ChronicGuideCard(item: item, compact: true))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            '${summary.consumedCalories} / ${summary.targetCalories} kcal',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: summary.targetCalories == 0
                  ? 0.0
                  : (summary.consumedCalories / summary.targetCalories).clamp(
                      0.0,
                      1.0,
                    ),
              minHeight: 8,
              backgroundColor: VitaMateTheme.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                VitaMateTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Remaining ${summary.remainingCalories} kcal',
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MacroPill(
                label: 'Protein ${details.proteinG.round()} g',
                color: VitaMateTheme.primary,
              ),
              _MacroPill(
                label: 'Carbs ${details.carbsG.round()} g',
                color: VitaMateTheme.accent,
              ),
              _MacroPill(
                label: 'Fat ${details.fatG.round()} g',
                color: VitaMateTheme.warning,
              ),
              if (controller.diabetesActive || details.sugarsG > 0)
                _MacroPill(
                  label: 'Sugar ${details.sugarsG.round()} g',
                  color: sugarColor,
                ),
              _MacroPill(
                label: '${controller.mealPointsToday} pts',
                color: VitaMateTheme.primaryDeep,
              ),
              if (details.caffeineMg > 0)
                _MacroPill(
                  label: 'Caffeine ${details.caffeineMg.round()} mg',
                  color: VitaMateTheme.danger,
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => setState(
              () => _showAllNutritionValues = !_showAllNutritionValues,
            ),
            icon: Icon(
              _showAllNutritionValues
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: VitaMateTheme.primary,
            ),
            label: Text(
              _showAllNutritionValues
                  ? 'Hide nutrition values'
                  : 'Show all nutrition values',
            ),
          ),
          if (_showAllNutritionValues) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _NutritionMetricTile(
                  label: 'Calories',
                  value: '${summary.consumedCalories} kcal',
                  color: VitaMateTheme.primaryDeep,
                ),
                _NutritionMetricTile(
                  label: 'Sugar',
                  value: '${details.sugarsG.round()} g',
                  color: sugarColor,
                ),
                _NutritionMetricTile(
                  label: 'Added sugar',
                  value: '${details.addedSugarsG.round()} g',
                  color: sugarColor,
                ),
                _NutritionMetricTile(
                  label: 'Fiber',
                  value: '${details.fiberG.round()} g',
                  color: VitaMateTheme.success,
                ),
                _NutritionMetricTile(
                  label: 'Sodium',
                  value: '${details.sodiumMg.round()} mg',
                  color: VitaMateTheme.warning,
                ),
                _NutritionMetricTile(
                  label: 'Sat. fat',
                  value: '${details.saturatedFatG.round()} g',
                  color: VitaMateTheme.warning,
                ),
                _NutritionMetricTile(
                  label: 'Trans fat',
                  value: '${details.transFatG.round()} g',
                  color: VitaMateTheme.danger,
                ),
                _NutritionMetricTile(
                  label: 'Cholesterol',
                  value: '${details.cholesterolMg.round()} mg',
                  color: VitaMateTheme.accent,
                ),
                _NutritionMetricTile(
                  label: 'Potassium',
                  value: '${details.potassiumMg.round()} mg',
                  color: VitaMateTheme.primary,
                ),
                _NutritionMetricTile(
                  label: 'Caffeine',
                  value: '${details.caffeineMg.round()} mg',
                  color: VitaMateTheme.danger,
                ),
              ],
            ),
          ],
          if (controller.mealPointsDelta != 0) ...[
            const SizedBox(height: 8),
            Text(
              controller.mealPointsDelta > 0
                  ? 'Points +${controller.mealPointsDelta}'
                  : 'Points ${controller.mealPointsDelta}',
              style: TextStyle(
                color: controller.mealPointsDelta > 0
                    ? VitaMateTheme.success
                    : VitaMateTheme.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reminderCard(DateFormat fmt) {
    return _NutritionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meal reminders',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Keep meal reminders on'),
            subtitle: Text(
              '${fmt.format(_toDateTime(breakfast))}, ${fmt.format(_toDateTime(lunch))}, ${fmt.format(_toDateTime(dinner))}',
              style: const TextStyle(color: VitaMateTheme.textMuted),
            ),
            value: mealRemindersEnabled,
            onChanged: (v) async {
              setState(() => mealRemindersEnabled = v);
              if (v) {
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
          const SizedBox(height: 8),
          _timeTile(
            label: 'Breakfast',
            time: breakfast,
            icon: Icons.free_breakfast,
            onPick: () => _pickTime(breakfast, (t) {
              setState(() => breakfast = t);
              if (mealRemindersEnabled) _rescheduleMeals();
            }),
          ),
          _timeTile(
            label: 'Lunch',
            time: lunch,
            icon: Icons.lunch_dining,
            onPick: () => _pickTime(lunch, (t) {
              setState(() => lunch = t);
              if (mealRemindersEnabled) _rescheduleMeals();
            }),
          ),
          _timeTile(
            label: 'Dinner',
            time: dinner,
            icon: Icons.nightlife,
            onPick: () => _pickTime(dinner, (t) {
              setState(() => dinner = t);
              if (mealRemindersEnabled) _rescheduleMeals();
            }),
          ),
        ],
      ),
    );
  }

  Widget _todayLogsCard(DateFormat fmt) {
    final meals = [...controller.meals]
      ..sort(
        (a, b) => (b.consumedAt ?? DateTime(0)).compareTo(
          a.consumedAt ?? DateTime(0),
        ),
      );

    return _NutritionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today logs',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Drinks added from hydration appear here automatically.',
            style: TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (meals.isEmpty)
            const Text(
              'No food or drink logs yet today.',
              style: TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...meals.map(
              (meal) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MealLogTile(
                  meal: meal,
                  timeFormat: fmt,
                  diabetesActive: controller.diabetesActive,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeTile({
    required String label,
    required TimeOfDay time,
    required IconData icon,
    required VoidCallback onPick,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(time.format(context)),
      trailing: const Icon(Icons.edit),
      onTap: onPick,
    );
  }

  Widget _logMealCard() {
    final selectedFood = _selectedFood;
    final unitLabel = selectedFood?.isBeverage == true ? 'ml' : 'g';

    return _NutritionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Log meal',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FoodItem>(
            isExpanded: true,
            initialValue: _selectedFood,
            items: controller.foods
                .map(
                  (f) => DropdownMenuItem(
                    value: f,
                    child: Text(
                      f.isBeverage
                          ? '${f.name} (${f.calories100g} kcal/100 ml)'
                          : '${f.name} (${f.calories100g} kcal/100g)',
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedFood = v),
            decoration: const InputDecoration(labelText: 'Select food'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _quantityCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Quantity',
              suffixText: unitLabel,
            ),
          ),
          if (selectedFood != null) ...[
            const SizedBox(height: 10),
            _selectedFoodPreview(selectedFood),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _mealType,
            items: const [
              DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
              DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
              DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
              DropdownMenuItem(value: 'snack', child: Text('Snack')),
              DropdownMenuItem(value: 'dessert', child: Text('Dessert')),
              DropdownMenuItem(value: 'drink', child: Text('Drink')),
            ],
            onChanged: (v) => setState(() => _mealType = v ?? 'breakfast'),
            decoration: const InputDecoration(labelText: 'Meal type'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedFood == null
                  ? null
                  : () async {
                      final amount = double.tryParse(_quantityCtrl.text) ?? 0;
                      if (amount <= 0) {
                        _showSnack('Enter a valid quantity');
                        return;
                      }
                      if (_selectedFood!.isBeverage) {
                        await controller.logMeal(
                          foodId: _selectedFood!.id,
                          mealType: _mealType,
                          quantity: amount,
                          unit: 'ml',
                        );
                      } else {
                        await controller.logMeal(
                          foodId: _selectedFood!.id,
                          mealType: _mealType,
                          quantityGrams: amount,
                        );
                      }
                      _showSnack(
                        _selectedFood!.isBeverage
                            ? 'Drink logged and synced to hydration'
                            : 'Meal logged',
                      );
                    },
              child: const Text('Save meal'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedFoodPreview(FoodItem food) {
    final amount = double.tryParse(_quantityCtrl.text) ?? 0;
    final factor = amount <= 0 ? 0.0 : amount / 100.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.diabetesActive
                ? 'Nutrition preview for this food'
                : 'Quick nutrition preview',
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MacroPill(
                label: '${(food.calories100g * factor).round()} kcal',
                color: VitaMateTheme.primaryDeep,
              ),
              _MacroPill(
                label: 'Protein ${(food.protein100g * factor).round()} g',
                color: VitaMateTheme.primary,
              ),
              _MacroPill(
                label: 'Carbs ${(food.carbs100g * factor).round()} g',
                color: VitaMateTheme.accent,
              ),
              _MacroPill(
                label: 'Fat ${(food.fat100g * factor).round()} g',
                color: VitaMateTheme.warning,
              ),
              if (controller.diabetesActive || food.sugars100g > 0)
                _MacroPill(
                  label: 'Sugar ${(food.sugars100g * factor).round()} g',
                  color: controller.diabetesActive
                      ? VitaMateTheme.danger
                      : VitaMateTheme.warning,
                ),
              if (food.hydrationContributionMl(amount.round()) != null)
                _MacroPill(
                  label:
                      'Hydration ${food.hydrationContributionMl(amount.round())} ml',
                  color: VitaMateTheme.primary,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openCreateFoodSheet() {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final carbCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    final servingLabelCtrl = TextEditingController(text: 'Serving');
    final servingGramsCtrl = TextEditingController(text: '200');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add new food',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _field(nameCtrl, 'Name'),
              const SizedBox(height: 10),
              _field(
                calCtrl,
                'Calories per 100g',
                suffix: 'kcal',
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _field(
                proteinCtrl,
                'Protein per 100g',
                suffix: 'g',
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _field(
                carbCtrl,
                'Carbs per 100g',
                suffix: 'g',
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _field(
                fatCtrl,
                'Fat per 100g',
                suffix: 'g',
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _field(servingLabelCtrl, 'Serving label (e.g., Plate)'),
              const SizedBox(height: 10),
              _field(
                servingGramsCtrl,
                'Serving grams',
                suffix: 'g',
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final cal = int.tryParse(calCtrl.text) ?? 0;
                    if (nameCtrl.text.isEmpty || cal <= 0) {
                      _showSnack('Enter valid name and calories');
                      return;
                    }
                    await controller.createFood(
                      name: nameCtrl.text.trim(),
                      calories100g: cal,
                      protein100g: double.tryParse(proteinCtrl.text) ?? 0,
                      carbs100g: double.tryParse(carbCtrl.text) ?? 0,
                      fat100g: double.tryParse(fatCtrl.text) ?? 0,
                      servingLabel: servingLabelCtrl.text.trim().isEmpty
                          ? 'Serving'
                          : servingLabelCtrl.text.trim(),
                      servingGrams: int.tryParse(servingGramsCtrl.text) ?? 200,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    _showSnack('Food added to list');
                  },
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? suffix,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixText: suffix,
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.child});

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

class _MacroPill extends StatelessWidget {
  const _MacroPill({required this.label, required this.color});

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
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _NutritionMetricTile extends StatelessWidget {
  const _NutritionMetricTile({
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
      width: 146,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
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

class _MealLogTile extends StatefulWidget {
  const _MealLogTile({
    required this.meal,
    required this.timeFormat,
    required this.diabetesActive,
  });

  final MealLog meal;
  final DateFormat timeFormat;
  final bool diabetesActive;

  @override
  State<_MealLogTile> createState() => _MealLogTileState();
}

class _MealLogTileState extends State<_MealLogTile> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final accent = meal.isDrink ? VitaMateTheme.accent : VitaMateTheme.primary;
    final bits = <String>[
      meal.amountLabel,
      '${meal.caloriesKcal.round()} kcal',
    ];
    if (meal.carbsG > 0) {
      bits.add('${meal.carbsG.round()} g carbs');
    }
    if (widget.diabetesActive && meal.sugarsG > 0) {
      bits.add('${meal.sugarsG.round()} g sugar');
    }
    if (meal.caffeineMg > 0) {
      bits.add('${meal.caffeineMg.round()} mg caffeine');
    }

    final expandedMetrics = <Widget>[
      _NutritionMetricTile(
        label: 'Protein',
        value: '${meal.proteinG.round()} g',
        color: VitaMateTheme.primary,
      ),
      _NutritionMetricTile(
        label: 'Carbs',
        value: '${meal.carbsG.round()} g',
        color: VitaMateTheme.accent,
      ),
      _NutritionMetricTile(
        label: 'Fat',
        value: '${meal.fatG.round()} g',
        color: VitaMateTheme.warning,
      ),
      _NutritionMetricTile(
        label: 'Sugar',
        value: '${meal.sugarsG.round()} g',
        color: widget.diabetesActive
            ? VitaMateTheme.danger
            : VitaMateTheme.warning,
      ),
      _NutritionMetricTile(
        label: 'Added sugar',
        value: '${meal.addedSugarsG.round()} g',
        color: VitaMateTheme.danger,
      ),
      _NutritionMetricTile(
        label: 'Fiber',
        value: '${meal.fiberG.round()} g',
        color: VitaMateTheme.success,
      ),
      _NutritionMetricTile(
        label: 'Sodium',
        value: '${meal.sodiumMg.round()} mg',
        color: VitaMateTheme.warning,
      ),
      _NutritionMetricTile(
        label: 'Sat. fat',
        value: '${meal.saturatedFatG.round()} g',
        color: VitaMateTheme.warning,
      ),
      _NutritionMetricTile(
        label: 'Trans fat',
        value: '${meal.transFatG.round()} g',
        color: VitaMateTheme.danger,
      ),
      _NutritionMetricTile(
        label: 'Cholesterol',
        value: '${meal.cholesterolMg.round()} mg',
        color: VitaMateTheme.accent,
      ),
      _NutritionMetricTile(
        label: 'Potassium',
        value: '${meal.potassiumMg.round()} mg',
        color: VitaMateTheme.primaryDeep,
      ),
      _NutritionMetricTile(
        label: 'Caffeine',
        value: '${meal.caffeineMg.round()} mg',
        color: VitaMateTheme.danger,
      ),
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => expanded = !expanded),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: meal.isDrink
              ? VitaMateTheme.softSurface
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VitaMateTheme.border),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    meal.isDrink
                        ? Icons.local_drink_outlined
                        : _mealTypeIcon(meal),
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.foodName.isEmpty ? 'Food item' : meal.foodName,
                        style: const TextStyle(
                          color: VitaMateTheme.primaryDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bits.join(' - '),
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
                          _MacroPill(label: meal.mealTypeLabel, color: accent),
                          if (meal.consumedAt != null)
                            _MacroPill(
                              label: widget.timeFormat.format(
                                meal.consumedAt!.toLocal(),
                              ),
                              color: VitaMateTheme.primaryDeep,
                            ),
                          if (widget.diabetesActive)
                            _MacroPill(
                              label: 'Sugar ${meal.sugarsG.round()} g',
                              color: meal.sugarsG > 0
                                  ? VitaMateTheme.danger
                                  : VitaMateTheme.primaryDeep,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: VitaMateTheme.primary,
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: expandedMetrics),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _mealTypeIcon(MealLog meal) {
  switch (meal.mealType) {
    case 'breakfast':
      return Icons.free_breakfast;
    case 'lunch':
      return Icons.lunch_dining;
    case 'dinner':
      return Icons.dinner_dining;
    case 'snack':
      return Icons.cookie_outlined;
    case 'dessert':
      return Icons.icecream_outlined;
    default:
      return Icons.local_dining_outlined;
  }
}
