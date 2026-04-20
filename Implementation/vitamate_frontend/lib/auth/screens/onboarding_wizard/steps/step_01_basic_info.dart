import 'package:flutter/material.dart';

import '../onboarding_state.dart';
import '../widgets/wizard_step_container.dart';

class Step01BasicInfo extends StatelessWidget {
  final OnboardingState state;
  final TextEditingController ageController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final ValueChanged<String> onGenderChanged;
  final bool compact;

  const Step01BasicInfo({
    super.key,
    required this.state,
    required this.ageController,
    required this.heightController,
    required this.weightController,
    required this.onGenderChanged,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return WizardStepContainer(
      icon: Icons.person_outline_rounded,
      title: 'About You',
      subtitle: "Let's get to know you better",
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SelectTile(
                  label: 'Male',
                  selected: state.gender == 'M',
                  onTap: () => onGenderChanged('M'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SelectTile(
                  label: 'Female',
                  selected: state.gender == 'F',
                  onTap: () => onGenderChanged('F'),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 16 : 20),
          const _FieldLabel(text: 'Age'),
          const SizedBox(height: 8),
          TextField(
            controller: ageController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: wizardInputDecoration(hintText: 'Years'),
          ),
          SizedBox(height: compact ? 16 : 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _FieldLabel(text: 'Height'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: heightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: wizardInputDecoration(
                        hintText: 'cm',
                        suffixText: 'cm',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _FieldLabel(text: 'Weight'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      decoration: wizardInputDecoration(
                        hintText: 'kg',
                        suffixText: 'kg',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: wizardDeepPurple,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SelectTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFF4EAFF)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? wizardMidPurple : wizardStrokePurple,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? wizardMidPurple : wizardDeepPurple,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
