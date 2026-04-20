import 'package:flutter/material.dart';

class MedicationDoseActionSheet extends StatelessWidget {
  const MedicationDoseActionSheet({
    super.key,
    required this.onTaken,
    required this.onMissed,
    required this.onSkipped,
    required this.onSnooze,
  });

  final VoidCallback onTaken;
  final VoidCallback onMissed;
  final VoidCallback onSkipped;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_rounded),
              title: const Text('Taken'),
              onTap: onTaken,
            ),
            ListTile(
              leading: const Icon(Icons.snooze_rounded),
              title: const Text('Snooze 15 minutes'),
              onTap: onSnooze,
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Missed'),
              onTap: onMissed,
            ),
            ListTile(
              leading: const Icon(Icons.pause_rounded),
              title: const Text('Skip'),
              onTap: onSkipped,
            ),
          ],
        ),
      ),
    );
  }
}
