import 'package:flutter/material.dart';

import '../../../../core/theme/vitamate_theme.dart';
import '../mappers/habit_ui_mapper.dart';

class HabitOverviewCard extends StatelessWidget {
  const HabitOverviewCard({
    super.key,
    required this.model,
    required this.expanded,
    required this.busy,
    required this.onToggleExpanded,
    required this.onPrimaryAction,
    required this.onEditPlan,
    required this.onPauseOrResume,
  });

  final HabitCardViewModel model;
  final bool expanded;
  final bool busy;
  final VoidCallback onToggleExpanded;
  final VoidCallback onPrimaryAction;
  final VoidCallback onEditPlan;
  final VoidCallback onPauseOrResume;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${model.title}. ${model.statusLabel}. ${model.supportingText}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: model.canExpand ? onToggleExpanded : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: expanded
                    ? model.statusColor.withValues(alpha: 0.42)
                    : VitaMateTheme.border,
              ),
              boxShadow: const [
                BoxShadow(
                  color: VitaMateTheme.shadow,
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(model: model),
                const SizedBox(height: 12),
                if (model.primaryMetric != null)
                  _PrimaryMetric(metric: model.primaryMetric!)
                else
                  Text(
                    model.supportingText,
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                if (model.primaryMetric != null &&
                    model.supportingText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    model.supportingText,
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
                if (model.inlineMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InlineUpdate(message: model.inlineMessage),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : onPrimaryAction,
                        child: Text(model.primaryActionLabel),
                      ),
                    ),
                    if (model.canExpand) ...[
                      const SizedBox(width: 10),
                      _ExpandButton(
                        expanded: expanded,
                        onPressed: onToggleExpanded,
                      ),
                    ],
                  ],
                ),
                if (expanded)
                  _ExpandedDetails(
                    model: model,
                    busy: busy,
                    onEditPlan: onEditPlan,
                    onPauseOrResume: onPauseOrResume,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.model});

  final HabitCardViewModel model;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: model.statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(model.icon, color: model.statusColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.title,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              _StatusBadge(label: model.statusLabel, color: model.statusColor),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Today status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PrimaryMetric extends StatelessWidget {
  const _PrimaryMetric({required this.metric});

  final HabitPrimaryMetric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.value,
          style: const TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (metric.helper.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            metric.helper,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineUpdate extends StatelessWidget {
  const _InlineUpdate({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: VitaMateTheme.textMuted,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
    );
  }
}

class _ExpandButton extends StatelessWidget {
  const _ExpandButton({required this.expanded, required this.onPressed});

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: expanded ? 'Hide habit details' : 'Show habit details',
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          onPressed: onPressed,
          icon: AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ),
      ),
    );
  }
}

class _ExpandedDetails extends StatelessWidget {
  const _ExpandedDetails({
    required this.model,
    required this.busy,
    required this.onEditPlan,
    required this.onPauseOrResume,
  });

  final HabitCardViewModel model;
  final bool busy;
  final VoidCallback onEditPlan;
  final VoidCallback onPauseOrResume;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: VitaMateTheme.border),
          const SizedBox(height: 10),
          for (final detail in model.details) ...[
            _DetailRow(detail: detail),
            const SizedBox(height: 10),
          ],
          if (model.canEditPlan || model.canPauseOrResume) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                if (model.canEditPlan)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onEditPlan,
                      child: const Text('Edit plan'),
                    ),
                  ),
                if (model.canEditPlan && model.canPauseOrResume)
                  const SizedBox(width: 10),
                if (model.canPauseOrResume)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onPauseOrResume,
                      child: Text(
                        model.isPaused ? 'Continue plan' : 'Pause this plan',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.detail});

  final HabitDetailItem detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            detail.label,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            detail.value,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
