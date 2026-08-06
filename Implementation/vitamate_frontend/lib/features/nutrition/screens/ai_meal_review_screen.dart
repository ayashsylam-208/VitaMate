import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/ai_meal_analysis.dart';
import '../models/food_item.dart';
import '../state/ai_meal_controller.dart';
import '../state/nutrition_controller.dart';
import '../widgets/nutrition_reference_ui.dart';
import '../widgets/nutrition_ui.dart' show NutritionErrorView, compactNumber;
import 'meal_saved_screen.dart';

class AiMealReviewScreen extends StatefulWidget {
  const AiMealReviewScreen({
    super.key,
    required this.controller,
    required this.nutritionController,
  });

  final AiMealController controller;
  final NutritionController nutritionController;

  @override
  State<AiMealReviewScreen> createState() => _AiMealReviewScreenState();
}

class _AiMealReviewScreenState extends State<AiMealReviewScreen> {
  late final TextEditingController _dishController;
  String _mealType = 'lunch';
  late DateTime _consumedAt;

  @override
  void initState() {
    super.initState();
    final analysis = widget.controller.analysis!;
    _dishController = TextEditingController(text: analysis.selectedDishLabel);
    _mealType = analysis.mealType == 'unknown' ? 'lunch' : analysis.mealType;
    _consumedAt = DateTime.now();
  }

  @override
  void dispose() {
    _dishController.dispose();
    super.dispose();
  }

  Future<void> _map(AiMealComponent component) async {
    final food = await showDialog<FoodItem>(
      context: context,
      builder: (_) => _FoodMappingDialog(
        controller: widget.nutritionController,
        initialQuery: component.providerLabel,
      ),
    );
    if (food != null) widget.controller.mapComponent(component.id, food);
  }

  Future<void> _addMissingIngredient() async {
    final food = await showDialog<FoodItem>(
      context: context,
      builder: (_) => _FoodMappingDialog(
        controller: widget.nutritionController,
        initialQuery: '',
      ),
    );
    if (food != null) widget.controller.addComponent(food);
  }

  void _selectDish(AiMealCandidate candidate) {
    widget.controller.selectDish(candidate);
    _dishController.text = candidate.label;
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_consumedAt),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _consumedAt = DateTime(
        _consumedAt.year,
        _consumedAt.month,
        _consumedAt.day,
        selected.hour,
        selected.minute,
      );
    });
  }

  Future<void> _save() async {
    final analysis = widget.controller.analysis!;
    if (!analysis.canConfirm ||
        !widget.controller.dishChoiceConfirmed ||
        _dishController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            analysis.needsManualWeights
                ? 'Enter the total meal weight or each included ingredient weight before saving.'
                : 'Choose the dish when confidence is low, then map every included ingredient and confirm its weight.',
          ),
        ),
      );
      return;
    }
    final confirmed = await widget.controller.confirm(
      dishLabel: _dishController.text.trim(),
      dishId: analysis.selectedDishId,
      mealType: _mealType,
      consumedAt: _consumedAt,
    );
    if (!confirmed || !mounted) return;
    final finalized = await widget.controller.finalize();
    if (!finalized || !mounted) return;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MealSavedScreen(
          result: widget.controller.result!,
          controller: widget.nutritionController,
          imageUrl: analysis.imageUrl,
        ),
      ),
    );
    if (done == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NutritionReferenceBackground(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final analysis = widget.controller.analysis!;
            if (widget.controller.state == AiMealFlowStatus.expired ||
                analysis.status == 'expired') {
              return NutritionErrorView(
                message: 'This analysis expired. Analyze the meal photo again.',
                onRetry: () => Navigator.pop(context, false),
              );
            }
            final totals = _analysisTotals(analysis.components);
            return Stack(
              children: <Widget>[
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  children: <Widget>[
                    NutritionReferenceHeader(
                      title: 'Scan Result',
                      subtitle: 'Review and save your meal',
                      titleIcon: Icons.auto_awesome_rounded,
                      trailing: NutritionRoundButton(
                        icon: Icons.help_outline_rounded,
                        tooltip: 'About AI meal analysis',
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => const _AiHelpSheet(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _ScanHero(
                      analysis: analysis,
                      totals: totals,
                      dishController: _dishController,
                    ),
                    if (analysis.candidates.any(
                      (item) => item.kind == 'dish',
                    )) ...<Widget>[
                      const SizedBox(height: 14),
                      _DishChoiceCard(
                        analysis: analysis,
                        requiresChoice: widget.controller.requiresDishChoice,
                        onSelect: _selectDish,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _WeightGuidanceCard(analysis: analysis),
                    const SizedBox(height: 22),
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Detected Items',
                            style: TextStyle(
                              color: nutritionInk,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: widget.controller.busy
                              ? null
                              : _addMissingIngredient,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add item'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...analysis.components.map(
                      (component) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ComponentEditor(
                          component: component,
                          onMap: () => _map(component),
                          onGramsChanged: (value) => widget.controller
                              .updateComponentGrams(component.id, value),
                          onIncludedChanged: (value) => widget.controller
                              .toggleComponent(component.id, value),
                          onRemove: () =>
                              widget.controller.removeComponent(component.id),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _MealSettingsCard(
                      analysis: analysis,
                      mealType: _mealType,
                      consumedAt: _consumedAt,
                      onTotalGramsChanged: widget.controller.updateTotalGrams,
                      onMealTypeChanged: (value) =>
                          setState(() => _mealType = value),
                      onPickTime: _pickTime,
                    ),
                    if (widget.controller.error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        widget.controller.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: VitaMateTheme.danger,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: <Widget>[
                        Expanded(
                          flex: 2,
                          child: NutritionOutlineButton(
                            label: 'Retake Photo',
                            icon: Icons.photo_camera_outlined,
                            onTap: widget.controller.busy
                                ? null
                                : () => Navigator.pop(context, false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: NutritionGradientButton(
                            label: 'Save Meal',
                            icon: Icons.check_circle_rounded,
                            enabled: !widget.controller.busy,
                            onTap: _save,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (widget.controller.busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0xAA2F136E),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({
    required this.analysis,
    required this.totals,
    required this.dishController,
  });

  final AiMealAnalysis analysis;
  final _AnalysisTotals totals;
  final TextEditingController dishController;

  @override
  Widget build(BuildContext context) {
    final confidence = analysis.selectedDishCandidate?.confidence;
    return NutritionReferenceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1.55,
              child: analysis.imageUrl.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFF0E8FF),
                      child: Icon(
                        Icons.restaurant_rounded,
                        color: nutritionPurple,
                        size: 58,
                      ),
                    )
                  : Image.network(
                      analysis.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFFF0E8FF),
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: nutritionPurple,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: dishController,
                  maxLines: 2,
                  minLines: 1,
                  style: const TextStyle(
                    color: nutritionInk,
                    fontSize: 22,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: nutritionPurple),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EAFF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: nutritionPurple,
                        size: 16,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'AI Detected',
                        style: TextStyle(
                          color: nutritionPurple,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            confidence == null
                ? 'Confidence unavailable'
                : '${_confidenceLabel(confidence)} confidence  ·  ${(confidence * 100).round()}%',
            style: TextStyle(
              color: confidence != null && confidence >= 0.75
                  ? const Color(0xFF25A853)
                  : const Color(0xFFE58B18),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                _ScanMetric(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Calories',
                  value: compactNumber(totals.calories),
                  unit: 'kcal',
                ),
                _ScanMetric(
                  icon: Icons.eco_outlined,
                  label: 'Protein',
                  value: compactNumber(totals.protein, decimals: 1),
                  unit: 'g',
                ),
                _ScanMetric(
                  icon: Icons.grain_rounded,
                  label: 'Carbs',
                  value: compactNumber(totals.carbs, decimals: 1),
                  unit: 'g',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanMetric extends StatelessWidget {
  const _ScanMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: <Widget>[
          Icon(icon, color: nutritionPurple, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: nutritionMuted, fontSize: 10),
          ),
          const SizedBox(height: 2),
          FittedBox(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: nutritionInk,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(color: nutritionMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DishChoiceCard extends StatelessWidget {
  const _DishChoiceCard({
    required this.analysis,
    required this.requiresChoice,
    required this.onSelect,
  });

  final AiMealAnalysis analysis;
  final bool requiresChoice;
  final ValueChanged<AiMealCandidate> onSelect;

  @override
  Widget build(BuildContext context) => NutritionReferenceCard(
    padding: const EdgeInsets.all(15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          requiresChoice
              ? 'Confidence is low. Choose the closest dish.'
              : 'Confirm the detected dish',
          style: TextStyle(
            color: requiresChoice ? const Color(0xFFE58B18) : nutritionInk,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: analysis.candidates
              .where((item) => item.kind == 'dish')
              .map(
                (candidate) => ChoiceChip(
                  label: Text(candidate.label),
                  selected: candidate.providerId == analysis.selectedDishId,
                  onSelected: (_) => onSelect(candidate),
                ),
              )
              .toList(growable: false),
        ),
      ],
    ),
  );
}

class _WeightGuidanceCard extends StatelessWidget {
  const _WeightGuidanceCard({required this.analysis});

  final AiMealAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final needsManual = analysis.needsManualWeights;
    final hasEstimate = analysis.hasAutomaticWeightEstimate;
    final message = needsManual
        ? (analysis.weightMessage.isNotEmpty
              ? analysis.weightMessage
              : 'Automatic weight estimation was not reliable. Enter a total weight to distribute it by ingredient ratio, or fill each item manually.')
        : hasEstimate
        ? 'AI estimated the total weight and split it by detected ingredient ratio. Adjust anything before saving.'
        : 'Review every ingredient weight before saving.';
    return NutritionReferenceCard(
      color: needsManual ? const Color(0xFFFFF8EA) : const Color(0xFFF4FFF8),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          NutritionIconBubble(
            icon: needsManual
                ? Icons.scale_outlined
                : Icons.check_circle_outline_rounded,
            color: needsManual
                ? const Color(0xFFE58B18)
                : VitaMateTheme.success,
            background: needsManual
                ? const Color(0xFFFFE8C2)
                : const Color(0xFFE4F8EC),
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  needsManual
                      ? 'Manual weight needed'
                      : 'Weight estimate ready',
                  style: TextStyle(
                    color: needsManual ? const Color(0xFFE58B18) : nutritionInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: nutritionMuted,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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

class _MealSettingsCard extends StatelessWidget {
  const _MealSettingsCard({
    required this.analysis,
    required this.mealType,
    required this.consumedAt,
    required this.onTotalGramsChanged,
    required this.onMealTypeChanged,
    required this.onPickTime,
  });

  final AiMealAnalysis analysis;
  final String mealType;
  final DateTime consumedAt;
  final ValueChanged<double> onTotalGramsChanged;
  final ValueChanged<String> onMealTypeChanged;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final totalGrams = analysis.includedTotalGrams;
    return NutritionReferenceCard(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.tune_rounded, color: nutritionPurple),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Total meal weight',
                        style: TextStyle(
                          color: nutritionInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 118,
                      child: _TotalWeightField(
                        grams: totalGrams > 0 ? totalGrams : null,
                        onChanged: onTotalGramsChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  analysis.needsManualWeights
                      ? 'Required when AI cannot estimate weight. It distributes by detected ingredient ratio.'
                      : analysis.hasAutomaticWeightEstimate
                      ? 'AI estimate. Editing it redistributes included items by ratio.'
                      : 'Editing it redistributes included items by ratio.',
                  style: TextStyle(
                    color: analysis.needsManualWeights
                        ? const Color(0xFFE58B18)
                        : nutritionMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: nutritionLine),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                const Icon(Icons.restaurant_rounded, color: nutritionPurple),
                const SizedBox(width: 12),
                const Text(
                  'Meal Type',
                  style: TextStyle(
                    color: nutritionInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          <String>['breakfast', 'lunch', 'dinner', 'snack']
                              .map(
                                (value) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(nutritionMealTypeLabel(value)),
                                    selected: mealType == value,
                                    onSelected: (_) => onMealTypeChanged(value),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: nutritionLine),
          InkWell(
            onTap: onPickTime,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.schedule_rounded, color: nutritionPurple),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Time',
                      style: TextStyle(
                        color: nutritionInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    nutritionTime(consumedAt),
                    style: const TextStyle(
                      color: nutritionPurple,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: nutritionPurple,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalWeightField extends StatefulWidget {
  const _TotalWeightField({required this.grams, required this.onChanged});

  final double? grams;
  final ValueChanged<double> onChanged;

  @override
  State<_TotalWeightField> createState() => _TotalWeightFieldState();
}

class _TotalWeightFieldState extends State<_TotalWeightField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatEditableGrams(widget.grams),
    );
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _TotalWeightField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) return;
    final nextText = _formatEditableGrams(widget.grams);
    if (_controller.text != nextText) _controller.text = nextText;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focusNode,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textAlign: TextAlign.center,
    decoration: const InputDecoration(suffixText: 'g', hintText: 'Required'),
    onChanged: (value) {
      final grams = _parseGrams(value);
      if (grams != null) widget.onChanged(grams);
    },
  );
}

class _AiHelpSheet extends StatelessWidget {
  const _AiHelpSheet();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Review every AI estimate',
          style: TextStyle(
            color: nutritionInk,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Confirm the dish, map every included ingredient to the food library, and correct each estimated weight before saving.',
          style: TextStyle(color: nutritionMuted, height: 1.4),
        ),
      ],
    ),
  );
}

class _ComponentEditor extends StatelessWidget {
  const _ComponentEditor({
    required this.component,
    required this.onMap,
    required this.onGramsChanged,
    required this.onIncludedChanged,
    required this.onRemove,
  });

  final AiMealComponent component;
  final VoidCallback onMap;
  final ValueChanged<double> onGramsChanged;
  final ValueChanged<bool> onIncludedChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final grams = component.confirmedGrams ?? component.suggestedGrams;
    return NutritionReferenceCard(
      color: component.isIncluded ? Colors.white : const Color(0xFFF1EEF6),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Checkbox(
                value: component.isIncluded,
                onChanged: (value) => onIncludedChanged(value ?? false),
              ),
              const NutritionIconBubble(
                icon: Icons.restaurant_menu_rounded,
                color: nutritionPurple,
                background: Color(0xFFF1EAFF),
                size: 42,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      component.providerLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: nutritionInk,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${compactNumber(_nutritionValue(component, 'calories_kcal'))} kcal',
                      style: const TextStyle(
                        color: nutritionMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove ingredient',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, color: nutritionMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  onTap: component.isIncluded ? onMap : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      component.mappedFoodName.isEmpty
                          ? 'Tap to map to food library'
                          : 'Mapped to ${component.mappedFoodName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: component.mappedFoodName.isEmpty
                            ? VitaMateTheme.danger
                            : VitaMateTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 104,
                child: TextFormField(
                  key: ValueKey<String>('ai-component-${component.id}-$grams'),
                  initialValue: grams == null ? '' : compactNumber(grams),
                  enabled: component.isIncluded,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    suffixText: 'g',
                    hintText: 'Required',
                  ),
                  onChanged: (value) {
                    final parsed = _parseGrams(value);
                    if (parsed != null) onGramsChanged(parsed);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalysisTotals {
  const _AnalysisTotals({
    required this.calories,
    required this.protein,
    required this.carbs,
  });

  final double calories;
  final double protein;
  final double carbs;
}

_AnalysisTotals _analysisTotals(List<AiMealComponent> components) {
  var calories = 0.0;
  var protein = 0.0;
  var carbs = 0.0;
  for (final component in components.where((item) => item.isIncluded)) {
    calories += _nutritionValue(component, 'calories_kcal');
    protein += _nutritionValue(component, 'protein_g');
    carbs += _nutritionValue(component, 'carbs_g');
  }
  return _AnalysisTotals(calories: calories, protein: protein, carbs: carbs);
}

String _confidenceLabel(double value) => value >= 0.75
    ? 'High'
    : value >= 0.5
    ? 'Medium'
    : 'Low';

double _nutritionValue(AiMealComponent component, String key) {
  final value = component.estimatedNutrition[key];
  return value is num ? value.toDouble() : 0;
}

double? _parseGrams(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final grams = double.tryParse(normalized);
  return grams != null && grams > 0 ? grams : null;
}

String _formatEditableGrams(double? grams) =>
    grams == null || grams <= 0 ? '' : compactNumber(grams);

class _FoodMappingDialog extends StatefulWidget {
  const _FoodMappingDialog({
    required this.controller,
    required this.initialQuery,
  });
  final NutritionController controller;
  final String initialQuery;

  @override
  State<_FoodMappingDialog> createState() => _FoodMappingDialogState();
}

class _FoodMappingDialogState extends State<_FoodMappingDialog> {
  late final TextEditingController _query;
  List<FoodItem> _foods = const <FoodItem>[];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.initialQuery);
    unawaited(_search());
  }

  Future<void> _search() async {
    final values = await widget.controller.searchFoods(
      mealType: 'lunch',
      query: _query.text,
      includeMealSlot: false,
      limit: 20,
    );
    if (mounted) setState(() => _foods = values);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Map ingredient'),
    content: SizedBox(
      width: 420,
      height: 420,
      child: Column(
        children: <Widget>[
          TextField(
            controller: _query,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), _search);
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _foods.length,
              itemBuilder: (_, index) {
                final food = _foods[index];
                return ListTile(
                  title: Text(food.name),
                  subtitle: Text(food.supportingLabel),
                  trailing: Text('${food.calories100g} kcal'),
                  onTap: () => Navigator.pop(context, food),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
