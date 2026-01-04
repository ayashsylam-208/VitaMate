import 'package:flutter/material.dart';

class ProgressHeader extends StatelessWidget {
  final int current;
  final int total;

  const ProgressHeader({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : current / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $current of $total',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: progress, minHeight: 10),
        ),
      ],
    );
  }
}
