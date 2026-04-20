import 'package:flutter/material.dart';

import '../../../core/health/chronic_target_guide.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../shared/widgets/chronic_guide_card.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../data/chronic_conditions_api.dart';
import '../models/chronic_condition.dart';
import '../state/chronic_conditions_controller.dart';
import 'chronic_condition_detail_screen.dart';

part 'chronic_conditions_screen_sheet.dart';
part 'chronic_conditions_screen_sections.dart';

class ChronicConditionsScreen extends StatefulWidget {
  const ChronicConditionsScreen({super.key, this.controller});

  final ChronicConditionsController? controller;

  @override
  State<ChronicConditionsScreen> createState() =>
      _ChronicConditionsScreenState();
}

class _ChronicConditionsScreenState extends State<ChronicConditionsScreen> {
  static const List<String> _supportedSlugs = [
    'diabetes',
    'hypertension',
    'dyslipidemia',
  ];

  late final ChronicConditionsController controller;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? ChronicConditionsController();
    controller.load();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      controller.dispose();
    }
    super.dispose();
  }

  List<ChronicConditionType> get _supportedCatalog {
    final supported = controller.catalog
        .where((type) => _supportedSlugs.contains(type.slug))
        .toList();
    supported.sort(
      (a, b) => _sortWeight(a.slug).compareTo(_sortWeight(b.slug)),
    );
    return supported;
  }

  List<ChronicCondition> get _sortedConditions {
    final conditions = controller.activeConditions
        .where((item) => _supportedSlugs.contains(item.conditionType.slug))
        .toList();
    conditions.sort(
      (a, b) => _sortWeight(
        a.conditionType.slug,
      ).compareTo(_sortWeight(b.conditionType.slug)),
    );
    return conditions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: -1),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.loading && controller.catalog.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.error != null && controller.catalog.isEmpty) {
              return _CenterMessage(
                message: controller.error!,
                actionLabel: 'Try again',
                onAction: controller.load,
              );
            }

            final conditions = _sortedConditions;
            final supported = _supportedCatalog;

            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 112),
                children: [
                  _ConditionsHeader(activeCount: conditions.length),
                  if (controller.error != null) ...[
                    const SizedBox(height: 16),
                    _InlineMessage(
                      message: controller.error!,
                      color: VitaMateTheme.danger,
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (conditions.isEmpty) ...[
                    _ConditionsIntroCard(
                      onLearnMore: () => _showHowItWorks(context),
                    ),
                  ] else ...[
                    const _SectionHeading('Your conditions'),
                    const SizedBox(height: 12),
                    for (final condition in conditions) ...[
                      _ConditionSummaryCard(
                        condition: condition,
                        onOpen: () => _openDetails(condition.id),
                      ),
                      if (condition != conditions.last)
                        const SizedBox(height: 12),
                    ],
                  ],
                  const SizedBox(height: 24),
                  const _SectionHeading('Supported Conditions'),
                  const SizedBox(height: 12),
                  _SupportedConditionsRow(
                    types: supported,
                    controller: controller,
                    onAdd: _openAddConditionSheet,
                    onOpen: _openDetails,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  int _sortWeight(String slug) {
    switch (slug) {
      case 'diabetes':
        return 0;
      case 'hypertension':
        return 1;
      case 'dyslipidemia':
        return 2;
      default:
        return 99;
    }
  }

  Future<void> _openDetails(int conditionId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChronicConditionDetailScreen(
          controller: controller,
          conditionId: conditionId,
        ),
      ),
    );
  }

  Future<void> _openAddConditionSheet(ChronicConditionType type) async {
    final existing = controller.conditionForType(type.id);
    if (existing != null) {
      await _openDetails(existing.id);
      return;
    }
    if (!type.canAdd) {
      await controller.load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This condition is already active for your account.'),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<_ConditionDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConditionDraftSheet(presetType: type),
    );

    if (result == null) {
      return;
    }

    final success = await controller.createCondition(
      conditionTypeId: result.type.id,
      diagnosisDate: null,
      severityCode: result.severityCode,
      status: result.status,
      notes: '',
      profileData: result.profileData,
      targetOverrides: result.targetOverrides,
    );
    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.error ?? 'Failed to save the condition.'),
        ),
      );
      return;
    }

    final created = controller.conditionForType(result.type.id);
    String message = '${result.type.uiLabel} was added.';

    if (created != null && result.initialReadingPayload.isNotEmpty) {
      final readingResult = await controller.logReading(
        conditionId: created.id,
        payload: result.initialReadingPayload,
      );
      if (!mounted) {
        return;
      }
      if (readingResult != null) {
        message = readingResult.recommendations.isNotEmpty
            ? readingResult.recommendations.first.message
            : '${result.type.uiLabel} is ready for tracking.';
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (created != null) {
      await _openDetails(created.id);
    }
  }

  Future<void> _showHowItWorks(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('How condition tracking works'),
          content: const Text(
            'Add one of the supported conditions to unlock condition-aware targets, reminders, readings, and smarter nutrition or hydration guidance across VitaMate.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }
}
