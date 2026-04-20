import 'package:flutter/material.dart';

import '../../core/health/chronic_target_guide.dart';
import '../../core/theme/vitamate_theme.dart';

class ChronicGuideCard extends StatelessWidget {
  const ChronicGuideCard({super.key, required this.item, this.compact = false});

  final ChronicGuideCardData item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = _accentForBadge(item.badgeLabel);
    return SizedBox(
      width: compact ? 156 : 196,
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (item.sourceLabel.isNotEmpty)
                  Expanded(
                    child: Text(
                      item.sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: VitaMateTheme.textMuted,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                _Badge(label: item.badgeLabel, color: accent),
              ],
            ),
            SizedBox(height: compact ? 8 : 10),
            Text(
              item.title,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w900,
                color: VitaMateTheme.primaryDeep,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.valueLabel,
              style: TextStyle(
                fontSize: compact ? 14 : 15,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
            if (item.supportingText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.supportingText,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: VitaMateTheme.textMuted,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _accentForBadge(String badgeLabel) {
    switch (badgeLabel.toLowerCase()) {
      case 'limit':
        return VitaMateTheme.warning;
      case 'target':
        return VitaMateTheme.success;
      case 'goal':
        return VitaMateTheme.primary;
      default:
        return VitaMateTheme.primaryDeep;
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
