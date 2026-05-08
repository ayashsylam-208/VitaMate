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
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: VitaMateTheme.softSurface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: VitaMateTheme.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No medications added yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start with your first medication to unlock reminders, today plans, and adherence tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add medication'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
