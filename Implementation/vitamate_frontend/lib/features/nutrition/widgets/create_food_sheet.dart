import 'package:flutter/material.dart';

import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../state/nutrition_controller.dart';

class CreateFoodSheet extends StatefulWidget {
  const CreateFoodSheet({super.key, required this.controller});

  final NutritionController controller;

  @override
  State<CreateFoodSheet> createState() => _CreateFoodSheetState();
}

class _CreateFoodSheetState extends State<CreateFoodSheet> {
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _servingLabelController = TextEditingController(text: 'Serving');
  final _servingGramsController = TextEditingController(text: '200');
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _servingLabelController.dispose();
    _servingGramsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final calories = int.tryParse(_caloriesController.text.trim()) ?? 0;
    final servingGrams = int.tryParse(_servingGramsController.text.trim()) ?? 0;
    if (name.isEmpty || calories <= 0 || servingGrams <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid name, calories, and serving size.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.controller.createFood(
        name: name,
        calories100g: calories,
        protein100g: double.tryParse(_proteinController.text.trim()) ?? 0,
        carbs100g: double.tryParse(_carbsController.text.trim()) ?? 0,
        fat100g: double.tryParse(_fatController.text.trim()) ?? 0,
        servingLabel: _servingLabelController.text.trim().isEmpty
            ? 'Serving'
            : _servingLabelController.text.trim(),
        servingGrams: servingGrams,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create food: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      key: const ValueKey(AppTestKeys.nutritionCreateFoodSheet),
      decoration: const BoxDecoration(
        color: VitaMateTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Create custom food',
                        style: TextStyle(
                          color: VitaMateTheme.primaryDeep,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Add a reusable item to your private food library.',
                        style: TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Food name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Calories per 100g',
                suffixText: 'kcal',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _proteinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Protein',
                      suffixText: 'g',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _carbsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Carbs',
                      suffixText: 'g',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fatController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Fat',
                      suffixText: 'g',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _servingLabelController,
                    decoration: const InputDecoration(
                      labelText: 'Serving label',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _servingGramsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Serving size',
                      suffixText: 'g',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey(AppTestKeys.nutritionSaveFoodButton),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.library_add_rounded),
                label: Text(_saving ? 'Saving...' : 'Add to library'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
