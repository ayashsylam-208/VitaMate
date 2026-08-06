import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';

class PermissionStateTile extends StatelessWidget {
  const PermissionStateTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: enabled ? VitaMateTheme.success : VitaMateTheme.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            enabled ? 'Allowed' : 'Off',
            style: TextStyle(
              color: enabled ? VitaMateTheme.success : VitaMateTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
