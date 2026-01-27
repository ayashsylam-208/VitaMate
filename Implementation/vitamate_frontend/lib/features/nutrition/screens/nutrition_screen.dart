import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/notifications_service.dart';
import '../data/nutrition_api.dart';
import '../models/food_item.dart';
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

  Future<void> _pickTime(TimeOfDay current, ValueChanged<TimeOfDay> onPicked) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat.Hm();

    return Scaffold(
      appBar: AppBar(title: const Text('Calories')),
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
              final match =
                  foods.where((f) => f.id == _selectedFood!.id).toList();
              _selectedFood = match.isNotEmpty ? match.first : null;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryCard(summary, cs),
                  const SizedBox(height: 14),
                  _reminderCard(cs, dateFmt),
                  const SizedBox(height: 14),
                  _logMealCard(cs),
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

  Widget _summaryCard(summary, ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's calories",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.consumedCalories} / ${summary.targetCalories} kcal',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: summary.targetCalories == 0
                  ? 0.0
                  : (summary.consumedCalories / summary.targetCalories).clamp(0.0, 1.0),
              minHeight: 8,
            ),
            const SizedBox(height: 6),
            Text(
              'Remaining: ${summary.remainingCalories} kcal',
              style: TextStyle(color: cs.outline),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars, color: cs.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${controller.mealPointsToday} pts (calories)',
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                  ),
                  if (controller.mealPointsDelta != 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      controller.mealPointsDelta > 0
                          ? '(+${controller.mealPointsDelta})'
                          : '(${controller.mealPointsDelta})',
                      style: TextStyle(
                        color: controller.mealPointsDelta > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reminderCard(ColorScheme cs, DateFormat fmt) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Meal reminders'),
              subtitle: Text(
                '${fmt.format(_toDateTime(breakfast))}, ${fmt.format(_toDateTime(lunch))}, ${fmt.format(_toDateTime(dinner))}',
                style: TextStyle(color: cs.outline),
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

  Widget _logMealCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Log meal',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FoodItem>(
              isExpanded: true,
              value: _selectedFood,
              items: controller.foods
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text('${f.name} (${f.calories100g} kcal/100g)'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedFood = v),
              decoration: const InputDecoration(
                labelText: 'Select food',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _quantityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity (grams)',
                border: OutlineInputBorder(),
                suffixText: 'g',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _mealType,
              items: const [
                DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
                DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                DropdownMenuItem(value: 'snack', child: Text('Snack')),
              ],
              onChanged: (v) => setState(() => _mealType = v ?? 'breakfast'),
              decoration: const InputDecoration(
                labelText: 'Meal type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedFood == null
                    ? null
                    : () async {
                        final grams = double.tryParse(_quantityCtrl.text) ?? 0;
                        if (grams <= 0) {
                          _showSnack('Enter a valid quantity');
                          return;
                        }
                        await controller.logMeal(
                          foodId: _selectedFood!.id,
                          mealType: _mealType,
                          quantityGrams: grams,
                        );
                        _showSnack('Meal logged');
                      },
                child: const Text('Save meal'),
              ),
            ),
          ],
        ),
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
              const Text('Add new food', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              _field(nameCtrl, 'Name'),
              const SizedBox(height: 10),
              _field(calCtrl, 'Calories per 100g', suffix: 'kcal', keyboard: TextInputType.number),
              const SizedBox(height: 10),
              _field(proteinCtrl, 'Protein per 100g', suffix: 'g', keyboard: TextInputType.number),
              const SizedBox(height: 10),
              _field(carbCtrl, 'Carbs per 100g', suffix: 'g', keyboard: TextInputType.number),
              const SizedBox(height: 10),
              _field(fatCtrl, 'Fat per 100g', suffix: 'g', keyboard: TextInputType.number),
              const SizedBox(height: 10),
              _field(servingLabelCtrl, 'Serving label (e.g., Plate)'),
              const SizedBox(height: 10),
              _field(servingGramsCtrl, 'Serving grams', suffix: 'g', keyboard: TextInputType.number),
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
                    if (mounted) Navigator.pop(ctx);
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

  Widget _field(TextEditingController ctrl, String label,
      {String? suffix, TextInputType keyboard = TextInputType.text}) {
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

  DateTime _toDateTime(TimeOfDay t) =>
      DateTime(2000, 1, 1, t.hour, t.minute);

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
