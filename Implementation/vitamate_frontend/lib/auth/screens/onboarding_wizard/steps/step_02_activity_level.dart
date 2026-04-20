import 'package:flutter/material.dart';

import '../widgets/wizard_step_container.dart';

class Step02ActivityLevel extends StatelessWidget {
  final double? selectedLevel;
  final ValueChanged<double> onSelected;
  final bool compact;

  const Step02ActivityLevel({
    super.key,
    required this.selectedLevel,
    required this.onSelected,
    required this.compact,
  });

  static const _levels = [
    (1.2, 'Sedentary', 'Little to no regular exercise'),
    (1.375, 'Lightly Active', 'Light exercise 1-3 days/week'),
    (1.55, 'Moderately Active', 'Moderate exercise 3-5 days/week'),
    (1.725, 'Very Active', 'Hard exercise 6-7 days/week'),
    (1.9, 'Extremely Active', 'Physical work or intense training'),
  ];

  @override
  Widget build(BuildContext context) {
    return WizardStepContainer(
      icon: Icons.directions_run_rounded,
      title: 'Activity Level',
      subtitle: 'How active are you daily?',
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _levels.map((level) {
          final value = level.$1;
          final title = level.$2;
          final description = level.$3;
          final selected = selectedLevel == value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OptionTile(
              title: title,
              description: description,
              selected: selected,
              onTap: () => onSelected(value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? wizardMidPurple : wizardDeepPurple,
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
              const SizedBox(width: 12),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? wizardMidPurple : wizardHintPurple,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
