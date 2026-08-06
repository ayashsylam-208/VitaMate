import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/ai_meal_analysis.dart';
import '../state/nutrition_controller.dart';
import '../widgets/nutrition_reference_ui.dart';
import '../widgets/nutrition_ui.dart' show compactNumber;
import 'meal_details_screen.dart';

class MealSavedScreen extends StatelessWidget {
  const MealSavedScreen({
    super.key,
    required this.result,
    required this.controller,
    this.imageUrl = '',
  });

  final AiMealFinalizeResult result;
  final NutritionController controller;
  final String imageUrl;

  Future<void> _openDetails(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            MealDetailsScreen(controller: controller, meal: result.meal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meal = result.meal;
    final time = meal.consumedAt?.toLocal();
    final timeLabel = time == null
        ? 'Just now'
        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      body: NutritionReferenceBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: <Widget>[
              const NutritionReferenceHeader(
                title: 'Meal Saved',
                compact: true,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF9EB),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFC7E9C5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_rounded,
                      color: VitaMateTheme.success,
                    ),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Your meal has been saved!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: VitaMateTheme.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              NutritionReferenceCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: <Widget>[
                    _SavedMealHeader(
                      imageUrl: imageUrl,
                      name: meal.foodName,
                      mealType: meal.mealType,
                    ),
                    const SizedBox(height: 18),
                    _InfoRow(
                      icon: Icons.schedule_rounded,
                      label: 'Time eaten',
                      value: timeLabel,
                    ),
                    _InfoRow(
                      icon: Icons.local_drink_outlined,
                      label: 'Serving size',
                      value: meal.amountLabel,
                    ),
                    const Divider(height: 28, color: nutritionLine),
                    Row(
                      children: <Widget>[
                        _SavedMetric(
                          icon: Icons.local_fire_department_outlined,
                          color: nutritionPurple,
                          background: const Color(0xFFF1EAFF),
                          label: 'Calories',
                          value: meal.caloriesKcal,
                          unit: 'kcal',
                        ),
                        _SavedMetric(
                          icon: Icons.eco_outlined,
                          color: nutritionPurple,
                          background: const Color(0xFFF1EAFF),
                          label: 'Protein',
                          value: meal.proteinG,
                          unit: 'g',
                        ),
                        _SavedMetric(
                          icon: Icons.grain_rounded,
                          color: const Color(0xFF2D70F3),
                          background: const Color(0xFFEAF2FF),
                          label: 'Carbs',
                          value: meal.carbsG,
                          unit: 'g',
                        ),
                        _SavedMetric(
                          icon: Icons.water_drop_outlined,
                          color: const Color(0xFF4B9B20),
                          background: const Color(0xFFEDF7E9),
                          label: 'Fat',
                          value: meal.fatG,
                          unit: 'g',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _NutrientsLink(onTap: () => _openDetails(context)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              NutritionReferenceCard(
                color: const Color(0xFFF8F4FF),
                child: Row(
                  children: <Widget>[
                    const NutritionIconBubble(
                      icon: Icons.auto_awesome_rounded,
                      color: nutritionPurple,
                      background: Color(0xFFE9DCFF),
                      size: 58,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            result.pointsDelta > 0
                                ? 'Meal confirmed · +${result.pointsDelta} points'
                                : 'Meal confirmed',
                            style: const TextStyle(
                              color: nutritionInk,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Your reviewed ingredients and portions now count toward today’s nutrition.',
                            style: TextStyle(
                              color: nutritionMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              NutritionGradientButton(
                label: 'Done',
                icon: Icons.check_circle_rounded,
                onTap: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 12),
              NutritionOutlineButton(
                label: 'Edit Meal',
                icon: Icons.edit_outlined,
                onTap: () => _openDetails(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedMealHeader extends StatelessWidget {
  const _SavedMealHeader({
    required this.imageUrl,
    required this.name,
    required this.mealType,
  });

  final String imageUrl;
  final String name;
  final String mealType;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final image = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 116,
          height: 116,
          child: imageUrl.isEmpty
              ? const ColoredBox(
                  color: Color(0xFFF1EAFF),
                  child: Icon(
                    Icons.ramen_dining_rounded,
                    color: nutritionPurple,
                    size: 52,
                  ),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFFF1EAFF),
                    child: Icon(
                      Icons.ramen_dining_rounded,
                      color: nutritionPurple,
                      size: 52,
                    ),
                  ),
                ),
        ),
      );
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: nutritionInk,
              fontSize: 23,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF1EAFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    nutritionMealTypeIcon(mealType),
                    color: nutritionPurple,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    nutritionMealTypeLabel(mealType),
                    style: const TextStyle(
                      color: nutritionPurple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      if (constraints.maxWidth < 330) {
        return Column(
          children: <Widget>[
            image,
            const SizedBox(height: 15),
            Align(alignment: Alignment.centerLeft, child: details),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          image,
          const SizedBox(width: 16),
          Expanded(child: details),
        ],
      );
    },
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 20, color: nutritionPurple),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(color: nutritionMuted)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _SavedMetric extends StatelessWidget {
  const _SavedMetric({
    required this.icon,
    required this.color,
    required this.background,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String label;
  final double value;
  final String unit;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: <Widget>[
        NutritionIconBubble(
          icon: icon,
          color: color,
          background: background,
          size: 39,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            color: nutritionMuted,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          compactNumber(value),
          style: const TextStyle(
            color: nutritionInk,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(unit, style: const TextStyle(color: nutritionMuted, fontSize: 10)),
      ],
    ),
  );
}

class _NutrientsLink extends StatelessWidget {
  const _NutrientsLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFBF9FF),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3D8F5)),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.show_chart_rounded, color: nutritionPurple),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'View full nutrients',
                style: TextStyle(
                  color: nutritionPurple,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: nutritionPurple),
          ],
        ),
      ),
    ),
  );
}
