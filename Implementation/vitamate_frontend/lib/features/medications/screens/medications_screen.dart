import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../models/medication_item.dart';
import '../state/medications_controller.dart';
import '../widgets/empty_medications_state.dart';
import '../widgets/medication_adherence_card.dart';
import '../widgets/medication_card.dart';
import 'add_edit_medication_screen.dart';
import 'medication_detail_screen.dart';
import 'medication_today_plan_screen.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key, this.controller});

  final MedicationsController? controller;

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  late final MedicationsController controller;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? MedicationsController();
    controller.addListener(_onChanged);
    controller.refreshAll();
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    if (widget.controller == null) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openAdd() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditMedicationScreen(controller: controller),
      ),
    );
    if (saved == true) {
      await controller.refreshAll();
    }
  }

  void _openMedication(MedicationItem medication) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationDetailScreen(
          controller: controller,
          medicationId: medication.id,
        ),
      ),
    );
  }

  void _openToday() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationTodayPlanScreen(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: 2),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medications',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Doses, reminders, and adherence.',
                          style: TextStyle(
                            color: VitaMateTheme.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _openAdd,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (state.errorMessage != null)
                _Message(text: state.errorMessage!),
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                MedicationAdherenceCard(summary: state.overallAdherence),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _openToday,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: VitaMateTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: VitaMateTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.today_outlined,
                          color: VitaMateTheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${state.todayPlan.length} doses planned today',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Active medications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                if (state.medications.isEmpty)
                  EmptyMedicationsState(onAdd: _openAdd)
                else
                  for (final medication in state.medications) ...[
                    MedicationCard(
                      medication: medication,
                      onTap: () => _openMedication(medication),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: VitaMateTheme.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
