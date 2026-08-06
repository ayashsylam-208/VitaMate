import 'package:flutter/material.dart';

import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../state/nutrition_controller.dart';
import '../widgets/nutrition_reference_ui.dart';
import '../widgets/nutrition_ui.dart' show compactNumber;
import 'ai_meal_capture_screen.dart';
import 'food_library_screen.dart';

class LogMealScreen extends StatefulWidget {
  const LogMealScreen({
    super.key,
    required this.controller,
    this.initialConsumedAt,
  });

  final NutritionController controller;
  final DateTime? initialConsumedAt;

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  static const _mealTypes = <String, String>{
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snack',
    'dessert': 'Dessert',
    'drink': 'Drink',
  };

  String _mealType = 'breakfast';
  late DateTime _consumedAt;
  FoodLibrarySelection? _selection;
  bool _saving = false;

  bool get _hasDraftChanges =>
      _selection != null ||
      _mealType != 'breakfast' ||
      DateTime.now().difference(_consumedAt).abs() > const Duration(minutes: 2);

  bool get _canReview =>
      _selection != null &&
      _selection!.quantity > 0 &&
      _mealTypes.containsKey(_mealType) &&
      !_consumedAt.isAfter(DateTime.now().add(const Duration(minutes: 1)));

  @override
  void initState() {
    super.initState();
    _consumedAt = widget.initialConsumedAt ?? DateTime.now();
  }

  Future<void> _chooseFood() async {
    final result = await Navigator.of(context).push<FoodLibrarySelection>(
      MaterialPageRoute<FoodLibrarySelection>(
        builder: (_) => FoodLibraryScreen(
          controller: widget.controller,
          selectionMode: true,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _selection = result);
  }

  Future<void> _openAiCapture() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            AiMealCaptureScreen(nutritionController: widget.controller),
      ),
    );
    if (saved == true && mounted) {
      await widget.controller.load();
      if (mounted) Navigator.pop(context, 'Meal logged');
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _consumedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _consumedAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _consumedAt.hour,
        _consumedAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_consumedAt),
    );
    if (selected == null || !mounted) return;
    final next = DateTime(
      _consumedAt.year,
      _consumedAt.month,
      _consumedAt.day,
      selected.hour,
      selected.minute,
    );
    if (next.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal time cannot be in the future.')),
      );
      return;
    }
    setState(() => _consumedAt = next);
  }

  Future<void> _clear() async {
    if (!_hasDraftChanges) return;
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
              'Clear meal draft?',
              style: TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text('The selected food, amount, type, and time will reset.'),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear draft'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _selection = null;
        _mealType = 'breakfast';
        _consumedAt = DateTime.now();
      });
    }
  }

  Future<void> _reviewAndSave() async {
    final selection = _selection;
    if (!_canReview || selection == null || _saving) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Review meal',
              style: TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            _ReviewRow(label: 'Food', value: selection.food.name),
            _ReviewRow(label: 'Meal type', value: _mealTypes[_mealType]!),
            _ReviewRow(label: 'Amount', value: _amountLabel(selection)),
            _ReviewRow(label: 'Time', value: _dateTimeLabel(_consumedAt)),
            const SizedBox(height: 12),
            const Text(
              'Nutrition and points will be calculated by VitaMate after saving.',
              style: TextStyle(color: VitaMateTheme.textMuted),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm and save'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continue editing'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save(selection);
  }

  Future<void> _save(FoodLibrarySelection selection) async {
    setState(() => _saving = true);
    try {
      final serving = selection.servingOption;
      await widget.controller.logMeal(
        foodId: selection.food.id,
        mealType: _mealType,
        quantity: selection.quantity,
        unit: selection.unit,
        quantityGrams: selection.unit == 'g' ? selection.quantity : null,
        servingOptionId: serving?.id,
        servingLabelSnapshot: serving?.displayLabel,
        servingGramsEquivalent: serving?.gramsEquivalent,
        servingMillilitersEquivalent: serving?.millilitersEquivalent,
        consumedAt: _consumedAt,
      );
      if (mounted) Navigator.pop(context, 'Meal logged');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this meal.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey(AppTestKeys.nutritionLogMealSheet),
    body: NutritionReferenceBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 170),
          children: <Widget>[
            NutritionReferenceHeader(
              title: 'Log Meal',
              subtitle:
                  'Choose a food or analyze a meal photo, then review and save.',
              trailing: NutritionRoundButton(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                onTap: () => Navigator.maybePop(context),
              ),
            ),
            const SizedBox(height: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _ModeCard(
                    key: const ValueKey('nutrition-open-food-library'),
                    icon: Icons.search_rounded,
                    title: 'Food library',
                    subtitle: 'Search food from our database',
                    selected: _selection != null,
                    onTap: _chooseFood,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeCard(
                    icon: Icons.photo_camera_rounded,
                    title: 'Analyze meal photo',
                    subtitle: 'Snap a photo to estimate nutrition',
                    selected: false,
                    onTap: _openAiCapture,
                    emphasized: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _FieldLabel('Meal type'),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _mealTypes.entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _MealTypeChip(
                          value: entry.key,
                          label: entry.value,
                          selected: _mealType == entry.key,
                          onTap: () => setState(() => _mealType = entry.key),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 22),
            const _FieldLabel('Category'),
            const SizedBox(height: 10),
            _SelectionField(
              icon: Icons.grid_view_rounded,
              title: _selection?.food.category.trim().isNotEmpty == true
                  ? _selection!.food.category
                  : 'Select a category',
              onTap: _chooseFood,
            ),
            const SizedBox(height: 22),
            const _FieldLabel('Quantity mode'),
            const SizedBox(height: 10),
            _QuantityMode(selection: _selection),
            const SizedBox(height: 18),
            _LogDetailsGrid(
              selection: _selection,
              consumedAt: _consumedAt,
              onSelectFood: _chooseFood,
              onPickDate: _pickDate,
              onPickTime: _pickTime,
            ),
            const SizedBox(height: 18),
            if (_selection == null)
              _SelectionField(
                icon: Icons.restaurant_menu_rounded,
                title: 'Choose a food and amount from the library',
                onTap: _chooseFood,
              )
            else
              _SelectedFood(
                selection: _selection!,
                onChange: _chooseFood,
                onRemove: () => setState(() => _selection = null),
              ),
            const SizedBox(height: 18),
            const _InfoStrip(),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: Color(0xFFFBFAFF),
          boxShadow: <BoxShadow>[
            BoxShadow(color: Color(0x183A2386), blurRadius: 20),
          ],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: NutritionOutlineButton(
                label: 'Clear',
                icon: Icons.delete_outline_rounded,
                onTap: _hasDraftChanges ? _clear : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: nutritionGradient,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x355C2BE7),
                      blurRadius: 16,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  key: const ValueKey(AppTestKeys.nutritionSaveMealButton),
                  onPressed: _canReview && !_saving ? _reviewAndSave : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.white.withValues(
                      alpha: 0.58,
                    ),
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: Icon(
                    _saving
                        ? Icons.hourglass_top_rounded
                        : Icons.fact_check_outlined,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_saving ? 'Saving...' : 'Review Meal'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => NutritionReferenceCard(
    onTap: onTap,
    color: selected || emphasized
        ? const Color(0xFFFBF8FF)
        : Colors.white.withValues(alpha: 0.95),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFF0E8FF),
            shape: BoxShape.circle,
            border: emphasized
                ? Border.all(color: const Color(0xFFD7C5FF))
                : null,
          ),
          child: Icon(icon, color: nutritionPurple, size: 38),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: nutritionInk,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: nutritionMuted,
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _SelectedFood extends StatelessWidget {
  const _SelectedFood({
    required this.selection,
    required this.onChange,
    required this.onRemove,
  });

  final FoodLibrarySelection selection;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => NutritionReferenceCard(
    color: const Color(0xFFF4EEFF),
    child: Row(
      children: <Widget>[
        const NutritionIconBubble(
          icon: Icons.restaurant_rounded,
          color: nutritionPurple,
          background: Colors.white,
          size: 48,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                selection.food.name,
                style: const TextStyle(
                  color: nutritionInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                _amountLabel(selection),
                style: const TextStyle(color: nutritionMuted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Change food or amount',
          onPressed: onChange,
          icon: const Icon(Icons.edit_outlined, color: nutritionPurple),
        ),
        IconButton(
          tooltip: 'Remove selected food',
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded, color: nutritionPurple),
        ),
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: nutritionInk,
      fontSize: 17,
      fontWeight: FontWeight.w900,
    ),
  );
}

class _MealTypeChip extends StatelessWidget {
  const _MealTypeChip({
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
    color: selected ? nutritionPurple : Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? nutritionPurple : const Color(0xFFDAD0EA),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              nutritionMealTypeIcon(value),
              size: 18,
              color: selected ? Colors.white : nutritionPurple,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : nutritionInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NutritionReferenceCard(
    onTap: onTap,
    radius: 15,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    child: Row(
      children: <Widget>[
        Icon(icon, color: nutritionPurple),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: nutritionMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Icon(Icons.keyboard_arrow_down_rounded, color: nutritionPurple),
      ],
    ),
  );
}

class _QuantityMode extends StatelessWidget {
  const _QuantityMode({required this.selection});

  final FoodLibrarySelection? selection;

  @override
  Widget build(BuildContext context) {
    final serving = selection?.unit != 'g';
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDAD0EA)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _QuantityModeSegment(
              icon: Icons.ramen_dining_outlined,
              label: 'Serving',
              selected: serving,
            ),
          ),
          Expanded(
            child: _QuantityModeSegment(
              icon: Icons.scale_outlined,
              label: 'g (grams)',
              selected: !serving,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityModeSegment extends StatelessWidget {
  const _QuantityModeSegment({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: selected ? nutritionGradient : null,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, color: selected ? Colors.white : nutritionMuted, size: 19),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : nutritionMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _LogDetailsGrid extends StatelessWidget {
  const _LogDetailsGrid({
    required this.selection,
    required this.consumedAt,
    required this.onSelectFood,
    required this.onPickDate,
    required this.onPickTime,
  });

  final FoodLibrarySelection? selection;
  final DateTime consumedAt;
  final VoidCallback onSelectFood;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 400;
      final fields = <Widget>[
        _CompactField(
          label: selection?.unit == 'g' ? 'Weight' : 'Serving type',
          value: selection == null
              ? 'Select'
              : selection!.servingOption?.displayLabel ?? 'Grams',
          icon: Icons.ramen_dining_outlined,
          onTap: onSelectFood,
        ),
        _CompactField(
          label: selection?.unit == 'g' ? 'Grams' : 'Serving count',
          value: selection == null
              ? '0'
              : compactNumber(selection!.quantity, decimals: 1),
          icon: Icons.add_circle_outline_rounded,
          onTap: onSelectFood,
        ),
        _CompactField(
          label: 'Time eaten',
          value: _timeLabel(consumedAt),
          icon: Icons.schedule_rounded,
          onTap: onPickTime,
        ),
        _CompactField(
          label: 'Date',
          value: _dateLabel(consumedAt),
          icon: Icons.calendar_today_outlined,
          onTap: onPickDate,
        ),
      ];
      if (narrow) {
        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: fields[0]),
                const SizedBox(width: 10),
                Expanded(child: fields[1]),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(child: fields[2]),
                const SizedBox(width: 10),
                Expanded(child: fields[3]),
              ],
            ),
          ],
        );
      }
      return Row(
        children:
            fields
                .expand(
                  (field) => <Widget>[
                    Expanded(child: field),
                    const SizedBox(width: 10),
                  ],
                )
                .toList()
              ..removeLast(),
      );
    },
  );
}

class _CompactField extends StatelessWidget {
  const _CompactField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: nutritionInk,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 7),
      NutritionReferenceCard(
        onTap: onTap,
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(icon, color: nutritionPurple, size: 19),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: nutritionMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF4EFFF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2D7F6)),
    ),
    child: const Row(
      children: <Widget>[
        Icon(Icons.info_outline_rounded, color: nutritionPurple),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'All fields help us provide more accurate nutrition insights.',
            style: TextStyle(color: nutritionMuted, fontSize: 12, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: VitaMateTheme.textMuted),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

String _amountLabel(FoodLibrarySelection selection) {
  if (selection.unit == 'serving') {
    final amount = compactNumber(selection.quantity);
    final label = selection.servingOption?.displayLabel ?? 'serving';
    return '$amount x $label';
  }
  return '${compactNumber(selection.quantity)} g';
}

String _dateLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _timeLabel(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _dateTimeLabel(DateTime value) =>
    '${_dateLabel(value)} ${_timeLabel(value)}';
