import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';

class EmptyMedicationsState extends StatelessWidget {
  const EmptyMedicationsState({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: VitaMateTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: VitaMateTheme.softSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: VitaMateTheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No medications added yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first medication to track doses, reminders, and adherence.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAdd, child: const Text('Add medication')),
        ],
      ),
    );
  }
}
