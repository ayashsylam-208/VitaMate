import 'package:flutter/material.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../onboarding_state.dart';

class Step03ActivityLevel extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final OnboardingState state;

  const Step03ActivityLevel({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.state,
  });

  @override
  State<Step03ActivityLevel> createState() => _Step03ActivityLevelState();
}

class _Step03ActivityLevelState extends State<Step03ActivityLevel> {
  late double level;

  final levels = const [
    (1.2, 'Sedentary', 'Desk job, little to no exercise'),
    (1.375, 'Lightly active', 'Light exercise 1–3 days/week'),
    (1.55, 'Moderately active', 'Moderate exercise 3–5 days/week'),
    (1.725, 'Very active', 'Hard exercise 6–7 days/week'),
    (1.9, 'Extremely active', 'Physical job or intense training'),
  ];

  @override
  void initState() {
    super.initState();
    level = widget.state.activityLevel;
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
            'Activity Level',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text('Choose what best describes your daily activity.'),

          const SizedBox(height: 18),

          ...levels.map((x) {
            final value = x.$1;
            final name = x.$2;
            final desc = x.$3;
            final selected = level == value;

            return Card(
              child: ListTile(
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(desc),
                trailing: selected ? const Icon(Icons.check_circle) : null,
                onTap: () => setState(() => level = value),
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
                    widget.state.activityLevel = level; // ✅ sends double like backend
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
