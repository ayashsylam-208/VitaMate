import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../state/medications_controller.dart';
import '../widgets/medication_adherence_card.dart';
import 'add_edit_medication_screen.dart';
import 'medication_adherence_screen.dart';

class MedicationDetailScreen extends StatefulWidget {
  const MedicationDetailScreen({
    super.key,
    required this.controller,
    required this.medicationId,
  });

  final MedicationsController controller;
  final int medicationId;

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
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
    final medication = widget.controller.medicationById(widget.medicationId);
    if (medication == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      appBar: AppBar(
        title: Text(medication.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AddEditMedicationScreen(
                    controller: widget.controller,
                    medication: medication,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: VitaMateTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: VitaMateTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.doseLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (medication.instructions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      medication.instructions,
                      style: const TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  for (final schedule in medication.schedules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${schedule.scheduleType} at ${schedule.time}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            MedicationAdherenceCard(summary: medication.adherenceSummaryShort),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MedicationAdherenceScreen(
                      controller: widget.controller,
                      medicationId: medication.id,
                    ),
                  ),
                );
              },
              child: const Text('View adherence'),
            ),
            OutlinedButton(
              onPressed: () async {
                final ok = await widget.controller.deactivateMedication(
                  medication.id,
                );
                if (ok && context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Deactivate medication'),
            ),
          ],
        ),
      ),
    );
  }
}
