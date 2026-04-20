import 'package:flutter/material.dart';

import '../widgets/wizard_step_container.dart';

class Step03Goal extends StatelessWidget {
  final String? selectedGoal;
  final ValueChanged<String> onSelected;
  final bool compact;

  const Step03Goal({
    super.key,
    required this.selectedGoal,
    required this.onSelected,
    required this.compact,
  });

  static const _goals = [
    (
      'lose',
      'Lose Weight',
      'Focus on fat loss and calorie control',
      Icons.trending_down_rounded,
    ),
    (
      'maintain',
      'Maintain Weight',
      'Stay balanced and consistent',
      Icons.remove_rounded,
    ),
    (
      'gain',
      'Gain Weight',
      'Increase healthy body mass',
      Icons.trending_up_rounded,
    ),
    (
      'muscle',
      'Build Muscle',
      'Strength training and lean gains',
      Icons.fitness_center_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return WizardStepContainer(
      icon: Icons.flag_outlined,
      title: 'Personal Goal',
      subtitle: 'What do you want to achieve?',
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _goals.map((goal) {
          final value = goal.$1;
          final title = goal.$2;
          final description = goal.$3;
          final icon = goal.$4;
          final selected = selectedGoal == value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => onSelected(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFF4EAFF)
                        : Colors.white.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected ? wizardMidPurple : wizardStrokePurple,
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFEEDDFF)
                              : const Color(0xFFF8F1FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          color: selected ? wizardMidPurple : wizardHintPurple,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: selected
                                    ? wizardMidPurple
                                    : wizardDeepPurple,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(
                                color: wizardDeepPurple.withValues(alpha: 0.68),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
