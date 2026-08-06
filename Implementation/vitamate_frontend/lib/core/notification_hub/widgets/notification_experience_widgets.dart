import 'package:flutter/material.dart';

import '../../theme/vitamate_theme.dart';

class VitaHealthAlertDialog extends StatelessWidget {
  const VitaHealthAlertDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onReview,
    this.sourceLabel,
    this.allowAcknowledge = false,
    this.onAcknowledge,
  });

  final String title;
  final String message;
  final String? sourceLabel;
  final bool allowAcknowledge;
  final VoidCallback onReview;
  final VoidCallback? onAcknowledge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      namesRoute: true,
      label: 'Health alert. $title. $message',
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: Color(0xFFF2C8CE)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
        contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
        actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF0),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.health_and_safety_outlined,
                color: VitaMateTheme.danger,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Health alert',
                style: TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: VitaMateTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if ((sourceLabel ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              VitaNotificationStatusChip(
                label: sourceLabel!,
                icon: Icons.monitor_heart_outlined,
                color: VitaMateTheme.danger,
              ),
            ],
          ],
        ),
        actions: [
          if (allowAcknowledge)
            TextButton(
              onPressed: onAcknowledge,
              child: const Text('Acknowledge'),
            ),
          FilledButton(
            onPressed: onReview,
            style: FilledButton.styleFrom(
              minimumSize: const Size(132, 48),
              backgroundColor: VitaMateTheme.primary,
            ),
            child: const Text('Review now'),
          ),
        ],
      ),
    );
  }
}

class VitaRoutineReminderBanner extends StatelessWidget {
  const VitaRoutineReminderBanner({
    super.key,
    required this.title,
    required this.message,
    this.onOpen,
  });

  final String title;
  final String message;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => _NotificationCard(
    icon: Icons.schedule_rounded,
    accent: const Color(0xFF258B7B),
    title: title,
    message: message,
    actionLabel: onOpen == null ? null : 'Open',
    onAction: onOpen,
  );
}

class VitaMotivationNudgeCard extends StatelessWidget {
  const VitaMotivationNudgeCard({
    super.key,
    required this.title,
    required this.message,
    this.points,
    this.onOpen,
  });

  final String title;
  final String message;
  final int? points;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => _NotificationCard(
    icon: Icons.bolt_rounded,
    accent: VitaMateTheme.primary,
    title: title,
    message: message,
    secondary: points == null || points == 0 ? null : '+$points points',
    actionLabel: onOpen == null ? null : 'Open',
    onAction: onOpen,
  );
}

class VitaAchievementCelebration extends StatelessWidget {
  const VitaAchievementCelebration({
    super.key,
    required this.title,
    required this.message,
    this.points,
  });

  final String title;
  final String message;
  final int? points;

  @override
  Widget build(BuildContext context) => _NotificationCard(
    icon: Icons.emoji_events_outlined,
    accent: VitaMateTheme.success,
    title: title,
    message: message,
    secondary: points == null || points == 0 ? null : '+$points points',
  );
}

class VitaNotificationPermissionCard extends StatelessWidget {
  const VitaNotificationPermissionCard({
    super.key,
    required this.enabled,
    required this.statusLabel,
    this.onAction,
    this.actionLabel = 'Open settings',
  });

  final bool enabled;
  final String statusLabel;
  final VoidCallback? onAction;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(),
      child: Row(
        children: [
          Icon(
            enabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            color: enabled ? VitaMateTheme.success : VitaMateTheme.warning,
            size: 27,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'Notifications enabled' : 'Notifications are off',
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusLabel,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!enabled && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class VitaNotificationStatusChip extends StatelessWidget {
  const VitaNotificationStatusChip({
    super.key,
    required this.label,
    required this.icon,
    this.color = VitaMateTheme.primary,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class VitaNotificationSettingsSection extends StatelessWidget {
  const VitaNotificationSettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: VitaMateTheme.primaryDeep,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(
          subtitle!,
          style: const TextStyle(color: VitaMateTheme.textMuted, fontSize: 12),
        ),
      ],
      const SizedBox(height: 10),
      Container(
        decoration: _surfaceDecoration(),
        child: Column(children: children),
      ),
    ],
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    this.secondary,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String message;
  final String? secondary;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (message.isNotEmpty)
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                if (secondary != null)
                  Text(
                    secondary!,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    ),
  );
}

BoxDecoration _surfaceDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: VitaMateTheme.border),
  boxShadow: const [
    BoxShadow(
      color: VitaMateTheme.shadow,
      blurRadius: 16,
      offset: Offset(0, 7),
    ),
  ],
);
