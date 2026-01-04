import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../../../../core/routing/routes.dart';
import '../../../../../core/network/http_client.dart';
import '../../../../../core/config/api_endpoints.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../onboarding_state.dart';

class Step05Summary extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onBack;

  const Step05Summary({super.key, required this.state, required this.onBack});

  @override
  State<Step05Summary> createState() => _Step05SummaryState();
}

class _Step05SummaryState extends State<Step05Summary> {
  bool _loading = false;

  String _genderLabel(String v) => v == 'M' ? 'Male' : 'Female';

  String _activityLabel(double v) {
    if (v == 1.2) return 'Sedentary';
    if (v == 1.375) return 'Lightly active';
    if (v == 1.55) return 'Moderately active';
    if (v == 1.725) return 'Very active';
    if (v == 1.9) return 'Extremely active';
    return v.toString();
  }

  String _goalLabel(String v) {
    switch (v) {
      case 'lose':
        return 'Lose weight';
      case 'maintain':
        return 'Maintain weight';
      case 'gain':
        return 'Gain weight';
      case 'muscle':
        return 'Build muscle';
      default:
        return v;
    }
  }

  Future<void> _finish() async {
    setState(() => _loading = true);

    try {
      final payload = {
        'gender': widget.state.gender, // 'M'/'F'
        'age': widget.state.age,
        'height':
            widget.state.heightCm, // if backend expects height_cm change key
        'weight':
            widget.state.weightKg, // if backend expects weight_kg change key
        'activity_level': widget.state.activityLevel, // double choice
        'goal': widget.state.goal, // lose/maintain/gain/muscle
      };

      await HttpClient.dio.patch(ApiEndpoints.me, data: payload);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, Routes.home);
    } on DioException catch (e) {
      String msg = 'Failed to save your profile. Please try again.';

      final data = e.response?.data;
      if (data is Map && data.values.isNotEmpty) {
        final v = data.values.first;
        if (v is List && v.isNotEmpty)
          msg = v.first.toString();
        else
          msg = v.toString();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error occurred')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          const Text(
            'Summary',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gender: ${_genderLabel(s.gender)}'),
                  Text('Age: ${s.age}'),
                  Text('Height: ${s.heightCm.round()} cm'),
                  Text('Weight: ${s.weightKg.round()} kg'),
                  Text('Activity Level: ${_activityLabel(s.activityLevel)}'),
                  Text('Goal: ${_goalLabel(s.goal)}'),
                ],
              ),
            ),
          ),

          const Spacer(),

          Row(
            children: [
              TextButton(onPressed: widget.onBack, child: const Text('Back')),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  text: _loading ? 'Saving...' : 'Finish',
                  onPressed: _loading ? null : _finish,
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
