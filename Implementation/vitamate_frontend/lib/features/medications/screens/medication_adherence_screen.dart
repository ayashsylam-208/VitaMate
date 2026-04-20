import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../state/medications_controller.dart';
import '../widgets/medication_adherence_card.dart';

class MedicationAdherenceScreen extends StatefulWidget {
  const MedicationAdherenceScreen({
    super.key,
    required this.controller,
    required this.medicationId,
  });

  final MedicationsController controller;
  final int medicationId;

  @override
  State<MedicationAdherenceScreen> createState() =>
      _MedicationAdherenceScreenState();
}

class _MedicationAdherenceScreenState extends State<MedicationAdherenceScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.loadMedicationAdherence(widget.medicationId);
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
    final summary = widget.controller.state.selectedMedicationAdherence;
    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      appBar: AppBar(title: const Text('Adherence')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: summary == null
              ? const Center(child: CircularProgressIndicator())
              : MedicationAdherenceCard(summary: summary),
        ),
      ),
    );
  }
}
