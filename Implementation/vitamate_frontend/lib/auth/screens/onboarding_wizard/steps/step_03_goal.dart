import 'package:flutter/material.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../onboarding_state.dart';

class Step04Goal extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final OnboardingState state;

  const Step04Goal({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.state,
  });

  @override
  State<Step04Goal> createState() => _Step04GoalState();
}

class _Step04GoalState extends State<Step04Goal> {
  late String goal; // lose / maintain / gain / muscle

  final goals = const [
    ('lose', 'Lose weight', 'Focus on fat loss & calorie control'),
    ('maintain', 'Maintain weight', 'Stay balanced and consistent'),
    ('gain', 'Gain weight', 'Increase healthy body mass'),
    ('muscle', 'Build muscle', 'Strength training & muscle gain'),
  ];

  @override
  void initState() {
    super.initState();
    goal = widget.state.goal;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          const Text(
            'Your Goal',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text('Pick the main goal you want VitaMate to focus on.'),

          const SizedBox(height: 18),

          ...goals.map((x) {
            final value = x.$1; // ✅ backend value
            final name = x.$2; // UI label
            final desc = x.$3;
            final selected = goal == value;

            return Card(
              child: ListTile(
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(desc),
                trailing: selected ? const Icon(Icons.check_circle) : null,
                onTap: () => setState(() => goal = value),
              ),
            );
          }),

          const Spacer(),

          Row(
            children: [
              TextButton(onPressed: widget.onBack, child: const Text('Back')),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  text: 'Next',
                  onPressed: () {
                    widget.state.goal =
                        goal; // ✅ sends lose/maintain/gain/muscle
                    widget.onNext();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
        ],
      ),
    );
  }
}
