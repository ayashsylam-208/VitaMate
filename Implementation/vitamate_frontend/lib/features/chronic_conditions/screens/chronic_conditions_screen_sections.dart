part of 'chronic_conditions_screen.dart';

class _ConditionsHeader extends StatelessWidget {
  const _ConditionsHeader({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey(AppTestKeys.chronicScreenHeader),
      height: 48,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: VitaMateTheme.border),
                    boxShadow: const [
                      BoxShadow(
                        color: VitaMateTheme.shadow,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: VitaMateTheme.primaryDeep,
                  ),
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.center,
            child: Text(
              'Conditions Center',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: VitaMateTheme.primaryDeep,
              ),
            ),
          ),
          if (activeCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: _StateChip(
                label: '$activeCount active',
                color: VitaMateTheme.success,
              ),
            ),
        ],
      ),
    );
  }
}

class _ConditionsIntroCard extends StatelessWidget {
  const _ConditionsIntroCard({required this.onLearnMore});

  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
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
        children: [
          SizedBox(
            width: 82,
            height: 82,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: VitaMateTheme.softSurface,
                    shape: BoxShape.circle,
                  ),
                ),
                const Icon(
                  Icons.shield_outlined,
                  color: VitaMateTheme.primary,
                  size: 36,
                ),
                const Positioned(
                  top: 28,
                  child: Icon(
                    Icons.favorite_outline_rounded,
                    color: VitaMateTheme.primary,
                    size: 14,
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 16,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: VitaMateTheme.border),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: VitaMateTheme.primary,
                      size: 11,
                    ),
                  ),
                ),
                const Positioned(
                  left: 10,
                  top: 12,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: VitaMateTheme.borderStrong,
                    size: 10,
                  ),
                ),
                const Positioned(
                  right: 16,
                  top: 8,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: VitaMateTheme.borderStrong,
                    size: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No chronic conditions added yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Add one of the supported conditions to enable personalized tracking, safer nutrition targets, health alerts, and condition-aware recommendations.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: VitaMateTheme.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onLearnMore,
            icon: const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: VitaMateTheme.primary,
            ),
            label: const Text('Learn how this works'),
          ),
        ],
      ),
    );
  }
}

class _SupportedConditionsRow extends StatelessWidget {
  const _SupportedConditionsRow({
    required this.types,
    required this.controller,
    required this.onAdd,
    required this.onOpen,
  });

  final List<ChronicConditionType> types;
  final ChronicConditionsController controller;
  final Future<void> Function(ChronicConditionType type) onAdd;
  final Future<void> Function(int conditionId) onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < types.length; i++) ...[
          Expanded(
            child: _SupportedConditionCard(
              type: types[i],
              condition: controller.conditionForType(types[i].id),
              onAdd: () => onAdd(types[i]),
              onOpen: () {
                final current = controller.conditionForType(types[i].id);
                if (current != null) {
                  onOpen(current.id);
                }
              },
            ),
          ),
          if (i != types.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _SupportedConditionCard extends StatelessWidget {
  const _SupportedConditionCard({
    required this.type,
    required this.condition,
    required this.onAdd,
    required this.onOpen,
  });

  final ChronicConditionType type;
  final ChronicCondition? condition;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final current = condition;
    final accent = _accentForSlug(type.slug);

    return Container(
      height: 214,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconForSlug(type.slug), color: accent, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            type.slug == 'dyslipidemia' ? 'Cholesterol' : type.uiLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              current == null
                  ? _compactSupportLine(type.slug)
                  : current.summarySubtitle,
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: VitaMateTheme.textMuted,
                height: 1.3,
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: current == null
                ? FilledButton.tonal(
                    key: ValueKey(
                      AppTestKeys.chronicSupportedAddButton(type.slug),
                    ),
                    onPressed: onAdd,
                    style: FilledButton.styleFrom(
                      foregroundColor: VitaMateTheme.primary,
                      backgroundColor: VitaMateTheme.softSurface,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Add'),
                  )
                : FilledButton.tonal(
                    onPressed: onOpen,
                    style: FilledButton.styleFrom(
                      foregroundColor: VitaMateTheme.primaryDeep,
                      backgroundColor: VitaMateTheme.softSurface,
                    ),
                    child: const Text('View'),
                  ),
          ),
        ],
      ),
    );
  }

  String _compactSupportLine(String slug) {
    switch (slug) {
      case 'diabetes':
        return 'Track glucose readings and apply nutrition-aware constraints';
      case 'hypertension':
        return 'Track blood pressure and sodium-sensitive targets';
      case 'dyslipidemia':
        return 'Track lipid-related care and heart-healthy nutrition guidance';
      default:
        return type.description;
    }
  }
}

class _ConditionSummaryCard extends StatelessWidget {
  const _ConditionSummaryCard({required this.condition, required this.onOpen});

  final ChronicCondition condition;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final accent = _statusColor(condition);
    final guideItems = ChronicTargetGuideBuilder.conditionHighlights(condition);

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
                  _iconForSlug(condition.conditionType.slug),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: VitaMateTheme.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      condition.summarySubtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: VitaMateTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _StateChip(label: condition.summaryStatusLabel, color: accent),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            condition.summaryLine,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            condition.secondarySummaryLine,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: VitaMateTheme.textMuted,
              height: 1.4,
            ),
          ),
          if (guideItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Goals and limits',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: VitaMateTheme.primaryDeep,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: guideItems
                  .map((item) => ChronicGuideCard(item: item, compact: true))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (condition.latestReading != null)
                _MetricPill(
                  label: condition.latestReading!.classificationLabel,
                  color: accent,
                ),
              if (condition.latestReading != null) const SizedBox(width: 8),
              _MetricPill(
                label: '${condition.dailyMedicationCount} meds',
                color: VitaMateTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                foregroundColor: VitaMateTheme.primaryDeep,
                backgroundColor: VitaMateTheme.softSurface,
              ),
              child: const Text('View tracking'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: VitaMateTheme.primaryDeep,
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_outline_rounded,
              size: 42,
              color: VitaMateTheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: VitaMateTheme.primaryDeep,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

IconData _iconForSlug(String slug) {
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

Color _accentForSlug(String slug) {
  switch (slug) {
    case 'diabetes':
      return VitaMateTheme.primary;
    case 'hypertension':
      return VitaMateTheme.danger;
    case 'dyslipidemia':
      return VitaMateTheme.accent;
    default:
      return VitaMateTheme.primary;
  }
}

Color _statusColor(ChronicCondition condition) {
  final lower = condition.summaryStatusLabel.toLowerCase();
  if (lower.contains('high') || lower.contains('attention')) {
    return VitaMateTheme.danger;
  }
  if (lower.contains('elevated') || lower.contains('low')) {
    return VitaMateTheme.warning;
  }
  return VitaMateTheme.success;
}
