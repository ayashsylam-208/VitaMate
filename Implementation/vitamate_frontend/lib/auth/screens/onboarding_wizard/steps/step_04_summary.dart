import 'package:flutter/material.dart';

import '../onboarding_state.dart';
import '../widgets/wizard_step_container.dart';

class Step04Summary extends StatelessWidget {
  final OnboardingState state;
  final bool compact;

  const Step04Summary({super.key, required this.state, required this.compact});

  String _genderLabel(String? value) {
    switch (value) {
      case 'M':
        return 'Male';
      case 'F':
        return 'Female';
      default:
        return '-';
    }
  }

  String _activityLabel(double? value) {
    switch (value) {
      case 1.2:
        return 'Sedentary';
      case 1.375:
        return 'Lightly Active';
      case 1.55:
        return 'Moderately Active';
      case 1.725:
        return 'Very Active';
      case 1.9:
        return 'Extremely Active';
      default:
        return '-';
    }
  }

  String _goalLabel(String? value) {
    switch (value) {
      case 'lose':
        return 'Lose Weight';
      case 'maintain':
        return 'Maintain Weight';
      case 'gain':
        return 'Gain Weight';
      case 'muscle':
        return 'Build Muscle';
      default:
        return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return WizardStepContainer(
      icon: Icons.check_rounded,
      title: 'All Set!',
      subtitle: 'Review your profile details',
      compact: compact,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: wizardStrokePurple),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1257369A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _SummaryRow(label: 'Gender', value: _genderLabel(state.gender)),
            _SummaryRow(
              label: 'Age',
              value: state.age == null ? '-' : '${state.age} years',
            ),
            _SummaryRow(
              label: 'Measurements',
              value: state.heightCm == null || state.weightKg == null
                  ? '-'
                  : '${state.heightCm!.round()} cm, ${state.weightKg!.round()} kg',
            ),
            _SummaryRow(
              label: 'Activity',
              value: _activityLabel(state.activityLevel),
            ),
            _SummaryRow(
              label: 'Goal',
              value: _goalLabel(state.goal),
              last: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF1E5FF))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: wizardDeepPurple.withValues(alpha: 0.58),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: wizardDeepPurple,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
