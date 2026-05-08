import 'package:flutter/material.dart';

import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../state/medications_controller.dart';
import '../widgets/today_dose_tile.dart';

class MedicationTodayPlanScreen extends StatefulWidget {
  const MedicationTodayPlanScreen({super.key, required this.controller});

  final MedicationsController controller;

  @override
  State<MedicationTodayPlanScreen> createState() =>
      _MedicationTodayPlanScreenState();
}

class _MedicationTodayPlanScreenState extends State<MedicationTodayPlanScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.loadTodayPlan();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final doses = widget.controller.todayPlan;
    return Scaffold(
      key: const ValueKey(AppTestKeys.medicationsTodayScreen),
      backgroundColor: VitaMateTheme.background,
      appBar: AppBar(title: const Text('Today plan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (doses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: Text(
                    'No doses planned today.',
                    style: TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            else
              for (final dose in doses) ...[
                TodayDoseTile(
                  dose: dose,
                  onTaken: () => widget.controller.markDoseTaken(dose.logId),
                  onMissed: () => widget.controller.markDoseMissed(dose.logId),
                  onSkipped: () => widget.controller.markDoseSkipped(
                    dose.logId,
                    reason: 'Skipped from VitaMate',
                  ),
                  onSnooze: () => widget.controller.snoozeDose(
                    dose.logId,
                    DateTime.now().add(const Duration(minutes: 15)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}
