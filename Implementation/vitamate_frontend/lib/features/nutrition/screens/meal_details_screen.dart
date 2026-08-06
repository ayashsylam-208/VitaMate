import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/meal_log.dart';
import '../state/nutrition_controller.dart';
import '../widgets/nutrition_reference_ui.dart';
import '../widgets/nutrition_ui.dart' show compactNumber;

class MealDetailsScreen extends StatefulWidget {
  const MealDetailsScreen({
    super.key,
    required this.controller,
    required this.meal,
  });

  final NutritionController controller;
  final MealLog meal;

  @override
  State<MealDetailsScreen> createState() => _MealDetailsScreenState();
}

class _MealDetailsScreenState extends State<MealDetailsScreen> {
  late MealLog meal;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    meal = widget.meal;
  }

  Future<void> _edit() async {
    final draft = await showModalBottomSheet<_MealEditDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MealEditSheet(meal: meal),
    );
    if (draft == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final updated = await widget.controller.updateMeal(
        mealId: meal.id,
        mealType: draft.mealType,
        quantityGrams: meal.isComposite ? null : draft.quantityGrams,
        consumedAt: draft.consumedAt,
        notes: draft.notes,
      );
      if (mounted) setState(() => meal = updated);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Delete meal entry?',
              style: TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This removes the saved meal and refreshes its health and points projections.',
              style: TextStyle(color: VitaMateTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: VitaMateTheme.danger,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete entry'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.controller.deleteMeal(meal.id);
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) {
        setState(() {
          busy = false;
          error = exception.toString();
        });
      }
    }
  }

  Future<void> _duplicate() async {
    final foodId = meal.foodId;
    if (foodId == null || meal.isComposite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Composite meals must be reviewed before saving again.',
          ),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await widget.controller.logMeal(
        foodId: foodId,
        mealType: meal.mealType,
        quantityGrams: meal.quantityGrams,
        consumedAt: DateTime.now(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Meal duplicated.')));
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nutrients = <_NutrientValue>[
      _NutrientValue(
        'Protein',
        meal.proteinG,
        'g',
        Icons.fitness_center_rounded,
        const Color(0xFFF36A20),
        const Color(0xFFFFF0E8),
      ),
      _NutrientValue(
        'Carbs',
        meal.carbsG,
        'g',
        Icons.grain_rounded,
        const Color(0xFF2D70F3),
        const Color(0xFFEAF2FF),
      ),
      _NutrientValue(
        'Fat',
        meal.fatG,
        'g',
        Icons.water_drop_outlined,
        const Color(0xFF4B9B20),
        const Color(0xFFEDF7E9),
      ),
      _NutrientValue(
        'Sugar',
        meal.sugarsG,
        'g',
        Icons.catching_pokemon_rounded,
        nutritionPurple,
        const Color(0xFFF1EAFF),
      ),
      _NutrientValue(
        'Fiber',
        meal.fiberG,
        'g',
        Icons.eco_outlined,
        nutritionPurple,
        const Color(0xFFF1EAFF),
      ),
      _NutrientValue(
        'Sodium',
        meal.sodiumMg,
        'mg',
        Icons.local_drink_outlined,
        const Color(0xFF2D70F3),
        const Color(0xFFEAF2FF),
      ),
    ];

    return Scaffold(
      body: NutritionReferenceBackground(
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              ListView(
                padding: nutritionPagePadding,
                children: <Widget>[
                  NutritionReferenceHeader(
                    title: 'Meal Details',
                    subtitle: 'View the details of your logged meal.',
                    trailing: _MealActionsButton(
                      onSelected: (value) {
                        if (value == 'duplicate') _duplicate();
                        if (value == 'edit') _edit();
                        if (value == 'delete') _delete();
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  _MealHero(meal: meal),
                  const SizedBox(height: 22),
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Nutrition Summary',
                          style: TextStyle(
                            color: nutritionInk,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1EAFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Text(
                            'Per entry',
                            style: TextStyle(
                              color: nutritionPurple,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _NutritionSummaryCard(nutrients: nutrients),
                  if (meal.components.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 20),
                    const Text(
                      'Ingredients',
                      style: TextStyle(
                        color: nutritionInk,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _IngredientsCard(components: meal.components),
                  ],
                  const SizedBox(height: 20),
                  _EntryInfoCard(meal: meal),
                  if (error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: VitaMateTheme.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  NutritionGradientButton(
                    label: 'Edit Entry',
                    icon: Icons.edit_outlined,
                    enabled: !busy,
                    onTap: _edit,
                  ),
                  const SizedBox(height: 12),
                  NutritionOutlineButton(
                    label: 'Delete Entry',
                    icon: Icons.delete_outline_rounded,
                    danger: true,
                    onTap: busy ? null : _delete,
                  ),
                  const SizedBox(height: 18),
                ],
              ),
              if (busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x5530205E),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealActionsButton extends StatelessWidget {
  const _MealActionsButton({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.94),
    shape: const CircleBorder(),
    elevation: 5,
    shadowColor: const Color(0x24382189),
    child: PopupMenuButton<String>(
      tooltip: 'Meal actions',
      icon: const Icon(Icons.more_horiz_rounded, color: nutritionPurple),
      onSelected: onSelected,
      itemBuilder: (_) => const <PopupMenuEntry<String>>[
        PopupMenuItem(value: 'duplicate', child: Text('Duplicate meal')),
        PopupMenuItem(value: 'edit', child: Text('Edit entry')),
        PopupMenuItem(value: 'delete', child: Text('Delete entry')),
      ],
    ),
  );
}

class _MealHero extends StatelessWidget {
  const _MealHero({required this.meal});

  final MealLog meal;

  @override
  Widget build(BuildContext context) => NutritionReferenceCard(
    padding: const EdgeInsets.all(20),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        final illustration = Container(
          width: compact ? 82 : 112,
          height: compact ? 82 : 112,
          decoration: const BoxDecoration(
            color: Color(0xFFF3EDFF),
            shape: BoxShape.circle,
          ),
          child: Icon(
            nutritionMealTypeIcon(meal.mealType),
            color: nutritionPurple,
            size: compact ? 42 : 56,
          ),
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              meal.foodName,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: nutritionInk,
                fontSize: 24,
                height: 1.12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _HeroChip(
                  icon: nutritionMealTypeIcon(meal.mealType),
                  label: meal.mealTypeLabel,
                ),
                _HeroChip(
                  icon: Icons.schedule_rounded,
                  label: _timeLabel(meal.consumedAt),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: compactNumber(meal.caloriesKcal),
                    style: const TextStyle(
                      color: nutritionPurple,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const TextSpan(
                    text: ' kcal',
                    style: TextStyle(
                      color: nutritionMuted,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(child: illustration),
              const SizedBox(height: 18),
              details,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            illustration,
            const SizedBox(width: 20),
            Expanded(child: details),
          ],
        );
      },
    ),
  );
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFF1EAFF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: nutritionPurple, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: nutritionPurple,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _NutritionSummaryCard extends StatelessWidget {
  const _NutritionSummaryCard({required this.nutrients});

  final List<_NutrientValue> nutrients;

  @override
  Widget build(BuildContext context) => NutritionReferenceCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 330 ? 2 : 3;
        final width = (constraints.maxWidth - (columns - 1) * 6) / columns;
        return Wrap(
          spacing: 6,
          runSpacing: 18,
          children: nutrients
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _NutrientTile(item: item),
                ),
              )
              .toList(growable: false),
        );
      },
    ),
  );
}

class _NutrientTile extends StatelessWidget {
  const _NutrientTile({required this.item});

  final _NutrientValue item;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      NutritionIconBubble(
        icon: item.icon,
        color: item.color,
        background: item.background,
      ),
      const SizedBox(height: 7),
      Text(
        item.label,
        maxLines: 1,
        style: const TextStyle(
          color: nutritionInk,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: compactNumber(item.value, decimals: 1),
              style: TextStyle(
                color: item.color,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(
              text: ' ${item.unit}',
              style: const TextStyle(
                color: nutritionMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _IngredientsCard extends StatelessWidget {
  const _IngredientsCard({required this.components});

  final List<MealLogComponent> components;

  @override
  Widget build(BuildContext context) => NutritionReferenceCard(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    child: Column(
      children: <Widget>[
        for (var index = 0; index < components.length; index++) ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: <Widget>[
                const NutritionIconBubble(
                  icon: Icons.restaurant_rounded,
                  color: nutritionPurple,
                  background: Color(0xFFF1EAFF),
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    components[index].foodName,
                    style: const TextStyle(
                      color: nutritionInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${compactNumber(components[index].resolvedGrams)} g',
                  style: const TextStyle(
                    color: nutritionMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (index != components.length - 1)
            const Divider(height: 1, color: nutritionLine),
        ],
      ],
    ),
  );
}

class _EntryInfoCard extends StatelessWidget {
  const _EntryInfoCard({required this.meal});

  final MealLog meal;

  @override
  Widget build(BuildContext context) => NutritionReferenceCard(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    child: Column(
      children: <Widget>[
        _InfoRow(
          icon: Icons.info_outline_rounded,
          title: 'Serving Size',
          subtitle: meal.amountLabel,
        ),
        const Divider(height: 1, color: nutritionLine),
        _InfoRow(
          icon: Icons.description_outlined,
          title: 'Source',
          subtitle: meal.source == 'ai'
              ? 'AI-assisted, user confirmed'
              : 'VitaMate food library',
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: <Widget>[
        NutritionIconBubble(
          icon: icon,
          color: nutritionPurple,
          background: const Color(0xFFF1EAFF),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: nutritionInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: nutritionMuted)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: nutritionMuted),
      ],
    ),
  );
}

class _MealEditSheet extends StatefulWidget {
  const _MealEditSheet({required this.meal});
  final MealLog meal;

  @override
  State<_MealEditSheet> createState() => _MealEditSheetState();
}

class _MealEditSheetState extends State<_MealEditSheet> {
  late String mealType;
  late final TextEditingController quantity;
  late final TextEditingController notes;
  late DateTime consumedAt;

  @override
  void initState() {
    super.initState();
    mealType = widget.meal.mealType;
    quantity = TextEditingController(
      text: compactNumber(widget.meal.quantityGrams),
    );
    notes = TextEditingController();
    consumedAt = widget.meal.consumedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    quantity.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          'Edit entry',
          style: TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: mealType,
          decoration: const InputDecoration(labelText: 'Meal type'),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
            DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
            DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
            DropdownMenuItem(value: 'snack', child: Text('Snack')),
            DropdownMenuItem(value: 'dessert', child: Text('Dessert')),
            DropdownMenuItem(value: 'drink', child: Text('Drink')),
          ],
          onChanged: (value) => setState(() => mealType = value ?? mealType),
        ),
        const SizedBox(height: 12),
        if (!widget.meal.isComposite)
          TextField(
            controller: quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              suffixText: 'g',
            ),
          ),
        if (widget.meal.isComposite)
          const Text(
            'Ingredient amounts for composite meals are edited through the review flow.',
            style: TextStyle(color: VitaMateTheme.textMuted),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            final grams = widget.meal.isComposite
                ? null
                : double.tryParse(quantity.text);
            if (!widget.meal.isComposite && (grams == null || grams <= 0)) {
              return;
            }
            Navigator.pop(
              context,
              _MealEditDraft(
                mealType: mealType,
                quantityGrams: grams,
                consumedAt: consumedAt,
                notes: notes.text.trim(),
              ),
            );
          },
          child: const Text('Save changes'),
        ),
      ],
    ),
  );
}

class _MealEditDraft {
  const _MealEditDraft({
    required this.mealType,
    required this.quantityGrams,
    required this.consumedAt,
    required this.notes,
  });

  final String mealType;
  final double? quantityGrams;
  final DateTime consumedAt;
  final String notes;
}

class _NutrientValue {
  const _NutrientValue(
    this.label,
    this.value,
    this.unit,
    this.icon,
    this.color,
    this.background,
  );
  final String label;
  final double value;
  final String unit;
  final IconData icon;
  final Color color;
  final Color background;
}

String _timeLabel(DateTime? value) {
  if (value == null) return 'Time unavailable';
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
}
