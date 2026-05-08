import 'package:flutter/material.dart';

import '../../../../core/testing/app_test_keys.dart';
import 'wizard_step_container.dart';

class WizardNavBar extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onBack;

  const WizardNavBar({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  key: const ValueKey(AppTestKeys.onboardingBackButton),
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: wizardDeepPurple,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Step $step of $totalSteps',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: wizardDeepPurple,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(totalSteps, (index) {
              final active = index < step;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(
                    right: index == totalSteps - 1 ? 0 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFE3FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    decoration: BoxDecoration(
                      gradient: active ? wizardButtonGradient : null,
                      color: active ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
