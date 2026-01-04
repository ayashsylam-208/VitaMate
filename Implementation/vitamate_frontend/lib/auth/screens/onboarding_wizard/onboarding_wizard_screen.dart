import 'package:flutter/material.dart';
import '../../../shared/widgets/vitamate_app_bar.dart';
import 'onboarding_state.dart';

import 'steps/step_01_basic_info.dart';
import 'steps/step_02_activity_level.dart';
import 'steps/step_03_goal.dart';
import 'steps/step_04_summary.dart';

class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  final PageController _controller = PageController();
  final OnboardingState state = OnboardingState();

  int step = 0;
  static const int totalSteps = 4;

  void _go(int newStep) {
    setState(() => step = newStep);
    _controller.animateToPage(
      newStep,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void next() {
    if (step < totalSteps - 1) _go(step + 1);
  }

  void back() {
    if (step > 0) _go(step - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const VitaMateAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
            child: Row(
              children: [
                Text(
                  'Step ${step + 1} / $totalSteps',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (step + 1) / totalSteps,
                      minHeight: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Step02BasicInfo(state: state, onNext: next),
                Step03ActivityLevel(state: state, onNext: next, onBack: back),
                Step04Goal(state: state, onNext: next, onBack: back),
                Step05Summary(state: state, onBack: back),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
