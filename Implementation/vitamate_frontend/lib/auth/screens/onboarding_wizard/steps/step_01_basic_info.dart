import 'package:flutter/material.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../onboarding_state.dart';

class Step02BasicInfo extends StatefulWidget {
  final VoidCallback onNext;
  final OnboardingState state;

  const Step02BasicInfo({super.key, required this.onNext, required this.state});

  @override
  State<Step02BasicInfo> createState() => _Step02BasicInfoState();
}

class _Step02BasicInfoState extends State<Step02BasicInfo> {
  late String gender; // 'F' / 'M'
  late int age;
  late double height;
  late double weight;

  @override
  void initState() {
    super.initState();
    gender = widget.state.gender;
    age = widget.state.age;
    height = widget.state.heightCm;
    weight = widget.state.weightKg;
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
            'Basic Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text('Set your personal details.'),

          const SizedBox(height: 22),

          const Text('Gender', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Female'),
                  selected: gender == 'F',
                  onSelected: (_) => setState(() => gender = 'F'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Male'),
                  selected: gender == 'M',
                  onSelected: (_) => setState(() => gender = 'M'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text('Age: $age'),
          Slider(
            value: age.toDouble(),
            min: 10,
            max: 90,
            divisions: 80,
            onChanged: (v) => setState(() => age = v.round()),
          ),

          const SizedBox(height: 10),

          Text('Height: ${height.round()} cm'),
          Slider(
            value: height,
            min: 120,
            max: 220,
            divisions: 100,
            onChanged: (v) => setState(() => height = v),
          ),

          const SizedBox(height: 10),

          Text('Weight: ${weight.round()} kg'),
          Slider(
            value: weight,
            min: 30,
            max: 180,
            divisions: 150,
            onChanged: (v) => setState(() => weight = v),
          ),

          const Spacer(),

          PrimaryButton(
            text: 'Next',
            onPressed: () {
              widget.state.gender = gender;
              widget.state.age = age;
              widget.state.heightCm = height;
              widget.state.weightKg = weight;
              widget.onNext();
            },
          ),

          const SizedBox(height: 18),
        ],
      ),
    );
  }
}
