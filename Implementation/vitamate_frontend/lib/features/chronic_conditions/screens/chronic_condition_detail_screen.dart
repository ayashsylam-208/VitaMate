import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/health/chronic_target_guide.dart';
import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../../medications/models/medication_adherence_summary.dart';
import '../../medications/models/medication_item.dart' as unified;
import '../../medications/models/medication_schedule.dart' as unified;
import '../../medications/screens/add_edit_medication_screen.dart';
import '../../medications/state/medications_controller.dart';
import '../data/chronic_conditions_api.dart';
import '../models/chronic_condition.dart';
import '../state/chronic_conditions_controller.dart';

part 'chronic_condition_detail_forms.dart';
part 'chronic_condition_detail_widgets.dart';

class ChronicConditionDetailScreen extends StatefulWidget {
  const ChronicConditionDetailScreen({
    super.key,
    required this.controller,
    required this.conditionId,
  });

  final ChronicConditionsController controller;
  final int conditionId;

  @override
  State<ChronicConditionDetailScreen> createState() =>
      _ChronicConditionDetailScreenState();
}

class _ChronicConditionDetailScreenState
    extends State<ChronicConditionDetailScreen> {
  ChronicCondition? get condition =>
      widget.controller.conditionById(widget.conditionId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final current = widget.controller.conditionById(widget.conditionId);
      if (current == null || !current.hasDetailPayload) {
        unawaited(widget.controller.loadConditionDetail(widget.conditionId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = condition;
    if (item == null) {
      if (widget.controller.isConditionDetailLoading(widget.conditionId)) {
        return const Scaffold(
          backgroundColor: VitaMateTheme.background,
          bottomNavigationBar: VitaMateBottomNav(currentIndex: -1),
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        backgroundColor: VitaMateTheme.background,
        bottomNavigationBar: const VitaMateBottomNav(currentIndex: -1),
        appBar: AppBar(
          leading: IconButton(
            key: const ValueKey(AppTestKeys.chronicDetailBackButton),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          title: const Text('Condition details'),
        ),
        body: const Center(
          child: Text('This condition is no longer available.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: -1),
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey(AppTestKeys.chronicDetailBackButton),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(item.uiLabel),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _openEditConditionSheet(item);
              } else if (value == 'deactivate') {
                _deactivateCondition(item.id);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit condition')),
              PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final current = condition;
            if (current == null) {
              return const Center(
                child: Text('This condition is no longer available.'),
              );
            }
            final isDetailLoading =
                !current.hasDetailPayload &&
                widget.controller.isConditionDetailLoading(widget.conditionId);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              children: [
                if (isDetailLoading) ...[
                  const _MessageCard(
                    message:
                        'Loading readings, targets, medications, and care details in the background.',
                  ),
                  const SizedBox(height: 16),
                ],
                _ConditionOverviewCard(condition: current),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const ValueKey(
                          AppTestKeys.chronicDetailAddReadingButton,
                        ),
                        onPressed: () => _openReadingSheet(current),
                        icon: Icon(
                          current.conditionType.slug == 'dyslipidemia'
                              ? Icons.update_rounded
                              : Icons.add_chart_rounded,
                        ),
                        label: Text(
                          current.conditionType.slug == 'dyslipidemia'
                              ? 'Update follow-up'
                              : 'Add reading',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => _openMedicationSheet(item: current),
                        style: FilledButton.styleFrom(
                          foregroundColor: VitaMateTheme.primaryDeep,
                          backgroundColor: VitaMateTheme.softSurface,
                        ),
                        child: const Text('Add medication'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailSectionPanel(
                  title: 'Tracking summary',
                  trailing: _InfoTag(label: current.summaryStatusLabel),
                  initiallyExpanded: true,
                  child: _ConditionSummaryCard(condition: current),
                ),
                const SizedBox(height: 16),
                _DetailSectionPanel(
                  title: 'Goals and limits',
                  subtitle: 'Targets and guardrails that matter right now.',
                  child: isDetailLoading && current.targets.isEmpty
                      ? const _MessageCard(
                          message: 'Loading active targets and care limits...',
                        )
                      : current.targets.isEmpty
                      ? const _MessageCard(
                          message: 'No active targets are available yet.',
                        )
                      : Column(
                          children: current.targets
                              .map(
                                (target) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _TargetCard(target: target),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                _DetailSectionPanel(
                  title: 'Recent readings',
                  subtitle: 'Latest measurements for this condition.',
                  initiallyExpanded: true,
                  child: current.indicatorRecords.isEmpty
                      ? (current.latestReading != null
                            ? Column(
                                key: const ValueKey(
                                  AppTestKeys.chronicDetailReadingsList,
                                ),
                                children: [
                                  _ReadingCard(record: current.latestReading!),
                                ],
                              )
                            : isDetailLoading
                            ? const _MessageCard(
                                key: ValueKey(
                                  AppTestKeys.chronicDetailReadingsList,
                                ),
                                message:
                                    'Loading recent readings and classifications...',
                              )
                            : const _MessageCard(
                                key: ValueKey(
                                  AppTestKeys.chronicDetailReadingsList,
                                ),
                                message:
                                    'No reading has been logged for this condition yet.',
                              ))
                      : Column(
                          key: const ValueKey(
                            AppTestKeys.chronicDetailReadingsList,
                          ),
                          children: current.indicatorRecords
                              .take(8)
                              .map(
                                (record) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ReadingCard(record: record),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                _DetailSectionPanel(
                  title: 'Applied care limits',
                  subtitle: 'Condensed restrictions and care guidance.',
                  child: isDetailLoading && current.constraintSummary.isEmpty
                      ? const _MessageCard(
                          message: 'Loading care-limit summary...',
                        )
                      : current.constraintSummary.isEmpty
                      ? const _MessageCard(
                          message:
                              'No care-limit summary is available for this condition yet.',
                        )
                      : Column(
                          children: current.constraintSummary
                              .map(
                                (summary) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _MessageCard(message: summary),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                _DetailSectionPanel(
                  title: 'Medications',
                  trailing: TextButton.icon(
                    onPressed: () => _openMedicationSheet(item: current),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                  child: isDetailLoading && current.medications.isEmpty
                      ? const _MessageCard(
                          message:
                              'Loading linked medications and schedules...',
                        )
                      : current.medications.isEmpty
                      ? const _MessageCard(
                          message:
                              'No medication is linked yet. Add one now to enable reminders and daily adherence tracking.',
                        )
                      : Column(
                          children: current.medications
                              .map(
                                (medication) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _MedicationCard(
                                    medication: medication,
                                    controller: widget.controller,
                                    onEdit: () => _openMedicationSheet(
                                      item: current,
                                      medication: medication,
                                    ),
                                    onDeactivate: () =>
                                        _deactivateMedication(medication.id),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                _DetailSectionPanel(
                  title: 'Recent alerts',
                  child: isDetailLoading && current.alerts.isEmpty
                      ? const _MessageCard(message: 'Loading recent alerts...')
                      : current.alerts.isEmpty
                      ? const _MessageCard(
                          message: 'No alerts are open for this condition.',
                        )
                      : Column(
                          children: current.alerts
                              .map(
                                (alert) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _AlertCard(alert: alert),
                                ),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 16),
                _DetailSectionPanel(
                  title: 'Support note',
                  child: _MessageCard(message: current.disclaimer),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _deactivateCondition(int conditionId) async {
    final success = await widget.controller.deactivateCondition(conditionId);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Condition deactivated.'
              : widget.controller.error ??
                    'Could not deactivate the condition.',
        ),
      ),
    );
    if (success) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deactivateMedication(int medicationId) async {
    final success = await widget.controller.deactivateMedication(medicationId);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Medication deactivated.'
              : widget.controller.error ??
                    'Could not deactivate the medication.',
        ),
      ),
    );
  }

  Future<void> _openEditConditionSheet(ChronicCondition item) async {
    final draft = await showModalBottomSheet<_EditConditionDraft>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => _EditConditionSheet(item: item),
    );
    if (draft == null) {
      return;
    }

    final success = await widget.controller.updateCondition(
      conditionId: item.id,
      conditionTypeId: item.conditionType.id,
      diagnosisDate: draft.diagnosisDate,
      severityCode: draft.severityCode,
      status: draft.status,
      notes: draft.notes,
      profileData: draft.profileData,
      targetOverrides: draft.targetOverrides,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Condition updated.'
              : widget.controller.error ?? 'Could not update the condition.',
        ),
      ),
    );
  }

  Future<void> _openReadingSheet(ChronicCondition item) async {
    final draft = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => _ConditionReadingSheet(
        condition: item,
        systolicFieldKey: item.conditionType.slug == 'hypertension'
            ? AppTestKeys.chronicReadingField(
                slug: 'hypertension',
                field: 'systolicField',
              )
            : null,
        diastolicFieldKey: item.conditionType.slug == 'hypertension'
            ? AppTestKeys.chronicReadingField(
                slug: 'hypertension',
                field: 'diastolicField',
              )
            : null,
        pulseFieldKey: item.conditionType.slug == 'hypertension'
            ? AppTestKeys.chronicReadingField(
                slug: 'hypertension',
                field: 'pulseField',
              )
            : null,
        saveButtonKey: AppTestKeys.chronicReadingSaveButton,
      ),
    );
    if (draft == null) {
      return;
    }

    final result = await widget.controller.logReading(
      conditionId: item.id,
      payload: draft,
    );
    if (!mounted) {
      return;
    }

    final message = result == null
        ? widget.controller.error ?? 'Could not save the reading.'
        : result.recommendations.isNotEmpty
        ? result.recommendations.first.message
        : 'Reading saved.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openMedicationSheet({
    required ChronicCondition item,
    ChronicMedication? medication,
  }) async {
    final medicationsController = MedicationsController();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditMedicationScreen(
          controller: medicationsController,
          medication: medication == null
              ? null
              : _unifiedMedication(item: item, medication: medication),
          sourceType: 'condition',
          linkedConditionId: item.id,
          linkedConditionName: item.conditionType.name,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (saved == true) {
      unawaited(widget.controller.reloadCondition(item.id));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == true
              ? medication == null
                    ? 'Medication saved. This condition is refreshing in the background.'
                    : 'Medication updated. This condition is refreshing in the background.'
              : medicationsController.state.errorMessage ??
                    'Medication was not changed.',
        ),
      ),
    );
    medicationsController.dispose();
  }

  unified.MedicationItem _unifiedMedication({
    required ChronicCondition item,
    required ChronicMedication medication,
  }) {
    return unified.MedicationItem(
      id: medication.id,
      displayName: medication.name,
      sourceType: 'condition',
      linkedConditionId: item.id,
      linkedConditionName: item.conditionType.name,
      doseAmount: medication.dosageAmount,
      doseUnit: medication.dosageUnit,
      dosage: medication.dosage,
      form: '',
      instructions: medication.instructions,
      startDate: DateTime.tryParse(medication.startDate),
      endDate: DateTime.tryParse(medication.endDate),
      isActive: medication.isActive,
      isPrn: false,
      timezone: DateTime.now().timeZoneName,
      supplementNutrientId: null,
      supplementNutrientCode: '',
      supplementNutrientAmount: 0,
      supplementNutrientUnit: '',
      nextDue: null,
      adherenceSummaryShort: MedicationAdherenceSummary.empty(),
      schedules: medication.schedules
          .map(
            (schedule) => unified.MedicationSchedule(
              id: schedule.id,
              scheduleType: 'daily',
              time: schedule.timeOfDay,
              daysOfWeek: schedule.recurrenceDays,
              intervalHours: null,
              mealRelation: medication.relationToMeal == 'with_meal'
                  ? 'with_food'
                  : medication.relationToMeal,
              gracePeriodMinutes: 60,
              snoozeDefaultMinutes: 15,
              isActive: true,
            ),
          )
          .toList(),
    );
  }
}
