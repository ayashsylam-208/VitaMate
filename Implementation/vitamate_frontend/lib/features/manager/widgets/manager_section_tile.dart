import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';

class ManagerSectionTile extends StatelessWidget {
  const ManagerSectionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.isDanger = false,
    this.isDisabled = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDanger;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final color = isDisabled
        ? VitaMateTheme.borderStrong
        : isDanger
        ? VitaMateTheme.danger
        : VitaMateTheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: VitaMateTheme.border),
          boxShadow: const [
            BoxShadow(
              color: VitaMateTheme.shadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDisabled
                          ? VitaMateTheme.textMuted
                          : isDanger
                          ? VitaMateTheme.danger
                          : VitaMateTheme.primaryDeep,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDisabled
                      ? VitaMateTheme.borderStrong
                      : isDanger
                      ? VitaMateTheme.danger
                      : VitaMateTheme.borderStrong,
                ),
          ],
        ),
      ),
    );
  }
}
