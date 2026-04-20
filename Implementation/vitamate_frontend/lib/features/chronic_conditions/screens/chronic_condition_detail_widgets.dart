part of 'chronic_condition_detail_screen.dart';

class _ConditionOverviewCard extends StatelessWidget {
  const _ConditionOverviewCard({required this.condition});

  final ChronicCondition condition;

  @override
  Widget build(BuildContext context) {
    final accent = _detailAccent(condition);
    final chips = <Widget>[
      _StateTag(label: condition.summaryStatusLabel, color: accent),
      _InfoTag(label: '${condition.dailyMedicationCount} medications'),
      _InfoTag(label: '${condition.dailyPendingDoses} doses pending'),
      if (condition.openAlertsCount > 0)
        _StateTag(
          label: '${condition.openAlertsCount} alerts',
          color: VitaMateTheme.danger,
        ),
      if ((condition.summary?.latestRecordedAt ?? '').isNotEmpty)
        _InfoTag(
          label:
              'Latest ${_dateTimeLabel(context, condition.summary!.latestRecordedAt)}',
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 14,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _detailIconForSlug(condition.conditionType.slug),
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      condition.uiLabel,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      condition.summarySubtitle,
                      style: const TextStyle(color: VitaMateTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            condition.summaryLine,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            condition.secondarySummaryLine,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }
}

class _ConditionSummaryCard extends StatelessWidget {
  const _ConditionSummaryCard({required this.condition});

  final ChronicCondition condition;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = condition.summary;
    final evaluation = condition.evaluation;
    final riskFlags = summary?.riskFlags ?? evaluation.riskFlags;
    final recommendations =
        summary?.recommendations ?? evaluation.recommendations;
    final trackerImpacts = summary?.trackerImpacts ?? evaluation.trackerImpacts;
    final latestReading =
        summary?.latestReading ??
        (condition.indicatorRecords.isNotEmpty
            ? condition.indicatorRecords.first
            : null);
    final statusLabel = _statusLabel(summary?.status ?? evaluation.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StateTag(
                  label: statusLabel,
                  color: _statusColor(
                    colorScheme,
                    summary?.status ?? evaluation.status,
                  ),
                ),
                _InfoTag(
                  label:
                      '${evaluation.medicationAdherencePercent.toStringAsFixed(0)}% meds',
                ),
                _InfoTag(
                  label:
                      '${evaluation.restrictionAdherencePercent.toStringAsFixed(0)}% restrictions',
                ),
                _InfoTag(
                  label:
                      '${evaluation.pointsDelta + evaluation.streakBonus} pts',
                ),
              ],
            ),
            if (latestReading != null) ...[
              const SizedBox(height: 12),
              Text(
                latestReading.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(latestReading.primaryValueLabel),
              if (latestReading.classification.isNotEmpty ||
                  latestReading.riskLevel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (latestReading.classification.isNotEmpty)
                      latestReading.classification.replaceAll('_', ' '),
                    if (latestReading.riskLevel.isNotEmpty)
                      'risk ${latestReading.riskLevel}',
                  ].join(' | '),
                  style: TextStyle(color: colorScheme.outline),
                ),
              ],
            ],
            if (riskFlags.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Risk flags',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: riskFlags
                    .map(
                      (item) => _StateTag(
                        label: item.replaceAll('_', ' '),
                        color: colorScheme.error,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (recommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Recommendations',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...recommendations
                  .take(3)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MessageCard(message: item.message),
                    ),
                  ),
            ],
            if (trackerImpacts.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Tracker impacts',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: trackerImpacts
                    .map((impact) => _InfoTag(label: _impactLabel(impact)))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _impactLabel(Map<String, dynamic> impact) {
    final tracker = (impact['tracker'] ?? '').toString().replaceAll('_', ' ');
    final key = (impact['key'] ?? '').toString().replaceAll('_', ' ');
    final value = impact['value'];
    if (value == null || value.toString().isEmpty) {
      return [tracker, key].where((item) => item.isNotEmpty).join(' | ');
    }
    return [
      tracker,
      key,
      value.toString(),
    ].where((item) => item.isNotEmpty).join(' | ');
  }

  Color _statusColor(ColorScheme colorScheme, String status) {
    switch (status) {
      case 'critical':
        return colorScheme.error;
      case 'attention_needed':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'attention_needed':
        return 'Attention needed';
      case 'critical':
        return 'Critical';
      case 'stable':
        return 'Stable';
      default:
        return status.replaceAll('_', ' ');
    }
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.record});

  final ConditionIndicatorRecord record;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  _dateTimeLabel(context, record.recordedAt),
                  style: TextStyle(color: colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              record.primaryValueLabel,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (record.readingContext.isNotEmpty)
                  _InfoTag(label: record.readingContext.replaceAll('_', ' ')),
                if (record.classification.isNotEmpty)
                  _StateTag(
                    label: record.classification.replaceAll('_', ' '),
                    color: _classificationColor(
                      colorScheme,
                      record.classification,
                    ),
                  ),
                if (record.riskLevel.isNotEmpty)
                  _InfoTag(label: 'Risk ${record.riskLevel}'),
                ..._payloadTags(record),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _classificationColor(ColorScheme colorScheme, String classification) {
    switch (classification) {
      case 'high':
      case 'critical':
        return colorScheme.error;
      case 'low':
      case 'elevated':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  List<Widget> _payloadTags(ConditionIndicatorRecord record) {
    if (record.indicatorType != 'lipid_panel') {
      return const [];
    }
    final payload = record.payload;
    return [
      if (payload['hdl'] != null) _InfoTag(label: 'HDL ${payload['hdl']}'),
      if (payload['triglycerides'] != null)
        _InfoTag(label: 'Triglycerides ${payload['triglycerides']}'),
      if (payload['total_cholesterol'] != null)
        _InfoTag(label: 'Total ${payload['total_cholesterol']}'),
    ];
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final ConditionAlertItem alert;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final levelColor = switch (alert.level) {
      'critical' => colorScheme.error,
      'high' => colorScheme.error,
      'warning' => Colors.orange,
      'medium' => Colors.orange,
      _ => colorScheme.primary,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: levelColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StateTag(
                  label: alert.level.isEmpty ? 'Open' : alert.level,
                  color: levelColor,
                ),
                if (alert.code.isNotEmpty)
                  _InfoTag(label: alert.code.replaceAll('_', ' ')),
              ],
            ),
            if (alert.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(alert.message),
            ],
            const SizedBox(height: 6),
            Text(
              _dateTimeLabel(context, alert.createdAt),
              style: TextStyle(color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.medication,
    required this.controller,
    required this.onEdit,
    required this.onDeactivate,
  });

  final ChronicMedication medication;
  final ChronicConditionsController controller;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    medication.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDeactivate,
                  icon: const Icon(Icons.visibility_off_outlined),
                ),
              ],
            ),
            if (medication.dosageLabel.isNotEmpty)
              Text(
                medication.dosageLabel,
                style: TextStyle(color: colorScheme.outline),
              ),
            if (medication.instructions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(medication.instructions),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoTag(label: medication.relationToMeal.replaceAll('_', ' ')),
                if (medication.scientificName.isNotEmpty)
                  _InfoTag(label: medication.scientificName),
              ],
            ),
            if (medication.schedules.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...medication.schedules.map(
                (schedule) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MedicationScheduleRow(
                    schedule: schedule,
                    controller: controller,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MedicationScheduleRow extends StatelessWidget {
  const _MedicationScheduleRow({
    required this.schedule,
    required this.controller,
  });

  final MedicationSchedule schedule;
  final ChronicConditionsController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoTag(label: schedule.timeOfDay),
              _StateTag(
                label: schedule.todayStatus.replaceAll('_', ' '),
                color: _scheduleColor(colorScheme, schedule.todayStatus),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => _showResult(
                  context,
                  controller.markMedicationTaken(schedule.id),
                  'Dose marked as taken.',
                ),
                child: const Text('Taken'),
              ),
              OutlinedButton(
                onPressed: () => _showResult(
                  context,
                  controller.snoozeMedicationDose(
                    schedule.id,
                    snoozeMinutes: 15,
                  ),
                  'Dose snoozed for 15 minutes.',
                ),
                child: const Text('Snooze'),
              ),
              TextButton(
                onPressed: () => _showResult(
                  context,
                  controller.markMedicationMissed(schedule.id),
                  'Dose marked as missed.',
                ),
                child: const Text('Missed'),
              ),
              TextButton(
                onPressed: () => _skipDose(context, schedule.id),
                child: const Text('Skip'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _scheduleColor(ColorScheme colorScheme, String status) {
    switch (status) {
      case 'taken_on_time':
      case 'taken_late':
        return Colors.green;
      case 'missed':
      case 'skipped':
        return colorScheme.error;
      case 'snoozed':
        return Colors.orange;
      default:
        return colorScheme.primary;
    }
  }

  Future<void> _showResult(
    BuildContext context,
    Future<DoseActionResult?> future,
    String successMessage,
  ) async {
    final result = await future;
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? controller.error ?? 'Action failed.'
              : successMessage,
        ),
      ),
    );
  }

  Future<void> _skipDose(BuildContext context, int scheduleId) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Skip dose'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Example: clinician asked to hold dose',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(reasonController.text.trim()),
              child: const Text('Skip'),
            ),
          ],
        );
      },
    );
    reasonController.dispose();

    if (reason == null || !context.mounted) {
      return;
    }

    await _showResult(
      context,
      controller.skipMedicationDose(scheduleId, reason: reason),
      'Dose skipped.',
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.target});

  final ChronicTargetResult target;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (target.status) {
      'out_of_range' => colorScheme.error,
      'pending' => Colors.orange,
      _ => Colors.green,
    };
    final badgeLabel = ChronicTargetGuideBuilder.badgeLabelForTarget(target);
    final valueLabel = ChronicTargetGuideBuilder.valueLabelForTarget(target);
    final currentLabel = ChronicTargetGuideBuilder.currentLabelForTarget(
      target,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  target.targetName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  _InfoTag(label: badgeLabel),
                  _StateTag(label: _targetStatus(target.status), color: color),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valueLabel,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          if (currentLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              currentLabel,
              style: const TextStyle(
                color: VitaMateTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (target.guidance.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(target.guidance),
          ],
        ],
      ),
    );
  }

  String _targetStatus(String status) {
    switch (status) {
      case 'within_target':
        return 'Within target';
      case 'out_of_range':
        return 'Out of range';
      default:
        return status.replaceAll('_', ' ');
    }
  }
}

class _Title extends StatelessWidget {
  const _Title(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
    );
  }
}

class _StateTag extends StatelessWidget {
  const _StateTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message),
    );
  }
}

String _dateTimeLabel(BuildContext context, String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }
  final local = parsed.toLocal();
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatMediumDate(local);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$date, $time';
}

Color _detailAccent(ChronicCondition condition) {
  final lower = condition.summaryStatusLabel.toLowerCase();
  if (lower.contains('high') || lower.contains('attention')) {
    return VitaMateTheme.danger;
  }
  if (lower.contains('elevated') || lower.contains('low')) {
    return VitaMateTheme.warning;
  }
  return VitaMateTheme.success;
}

IconData _detailIconForSlug(String slug) {
  switch (slug) {
    case 'diabetes':
      return Icons.bloodtype_outlined;
    case 'hypertension':
      return Icons.favorite_outline_rounded;
    case 'dyslipidemia':
      return Icons.monitor_heart_outlined;
    default:
      return Icons.health_and_safety_outlined;
  }
}
