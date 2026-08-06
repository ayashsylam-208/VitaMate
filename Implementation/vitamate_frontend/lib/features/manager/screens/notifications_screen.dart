import 'package:flutter/material.dart';

import '../../../core/notification_hub/notification_hub.dart';
import '../../../core/theme/vitamate_theme.dart';

class ManagerNotificationsScreen extends StatefulWidget {
  const ManagerNotificationsScreen({super.key});

  @override
  State<ManagerNotificationsScreen> createState() =>
      _ManagerNotificationsScreenState();
}

class _ManagerNotificationsScreenState
    extends State<ManagerNotificationsScreen> {
  final NotificationHubController _hub = NotificationHubController.instance;

  @override
  void initState() {
    super.initState();
    _hub.refreshPreferences();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VitaMateTheme.shellBackground,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _hub,
          builder: (context, _) {
            final prefs = _hub.preferences;
            final permission =
                _hub.permissionState ??
                NotificationChannelRegistry.lastPermissionSnapshot;
            final registration = _hub.registration;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  sliver: SliverList.list(
                    children: [
                      const _TopBar(),
                      const SizedBox(height: 18),
                      if (permission != null) ...[
                        VitaNotificationPermissionCard(
                          enabled: permission.canScheduleLocalNotifications,
                          statusLabel: permission.canScheduleLocalNotifications
                              ? 'VitaMate can schedule reminders on this device.'
                              : permission.permissionStatus == 'not_determined'
                              ? 'Allow notifications to receive health and routine reminders.'
                              : 'Enable notifications in Android settings to restore delivery.',
                          actionLabel:
                              permission.permissionStatus == 'not_determined'
                              ? 'Allow'
                              : 'Open settings',
                          onAction: permission.canScheduleLocalNotifications
                              ? null
                              : () => _handlePermissionAction(
                                  permission.permissionStatus,
                                ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      VitaNotificationSettingsSection(
                        title: 'Device delivery',
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.phone_android_rounded,
                              color: VitaMateTheme.primary,
                            ),
                            title: const Text('Current device'),
                            subtitle: Text(
                              registration?.deliveryEnabled == true
                                  ? 'Local delivery is active'
                                  : registration?.isPrimary == false
                                  ? 'Delivery is disabled on this secondary device'
                                  : 'Waiting for notification permission',
                            ),
                            trailing: VitaNotificationStatusChip(
                              label: registration?.isPrimary == false
                                  ? 'Secondary'
                                  : 'Primary',
                              icon: registration?.isPrimary == false
                                  ? Icons.devices_other_rounded
                                  : Icons.verified_outlined,
                              color: registration?.isPrimary == false
                                  ? VitaMateTheme.warning
                                  : VitaMateTheme.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _QuietHoursCard(
                        enabled: prefs.quietHoursEnabled,
                        start: prefs.quietStart,
                        end: prefs.quietEnd,
                        onToggle: (value) => _patch(<String, dynamic>{
                          'quiet_hours_enabled': value,
                        }),
                        onPickStart: () => _pickTime(
                          key: 'quiet_start',
                          fallback:
                              prefs.quietStart ?? DateTime(2000, 1, 1, 22),
                        ),
                        onPickEnd: () => _pickTime(
                          key: 'quiet_end',
                          fallback: prefs.quietEnd ?? DateTime(2000, 1, 1, 7),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _CategorySwitch(
                        icon: Icons.medication_liquid_rounded,
                        title: 'Medication reminders',
                        subtitle: 'Critical medication plans and dose windows.',
                        value: prefs.enableMedicationReminders,
                        onChanged: (value) => _patch(<String, dynamic>{
                          'enable_medication_reminders': value,
                        }),
                      ),
                      _CategorySwitch(
                        icon: Icons.monitor_heart_outlined,
                        title: 'Health alerts',
                        subtitle: 'Important chronic-care and risk warnings.',
                        value: prefs.enableHealthAlerts,
                        onChanged: (value) => _patch(<String, dynamic>{
                          'enable_health_alerts': value,
                        }),
                      ),
                      _CategorySwitch(
                        icon: Icons.event_repeat_rounded,
                        title: 'Routine reminders',
                        subtitle:
                            'Core reminders that keep daily tracking on time.',
                        value: prefs.enableRoutineReminders,
                        onChanged: (value) => _patch(<String, dynamic>{
                          'enable_routine_reminders': value,
                        }),
                      ),
                      _CategorySwitch(
                        icon: Icons.emoji_events_outlined,
                        title: 'Motivation & achievements',
                        subtitle: 'Points, streaks and achievement nudges.',
                        value: prefs.enableMotivationReminders,
                        onChanged: (value) => _patch(<String, dynamic>{
                          'enable_motivation_reminders': value,
                        }),
                      ),
                      _CategorySwitch(
                        icon: Icons.restaurant_rounded,
                        title: 'Meals',
                        subtitle: 'Breakfast, lunch and dinner reminders.',
                        value: prefs.enableMealReminders,
                        onChanged: (value) => _patch(<String, dynamic>{
                          'enable_meal_reminders': value,
                        }),
                      ),
                      _CategorySwitch(
                        icon: Icons.water_drop_rounded,
                        title: 'Water',
                        subtitle:
                            'Hydration reminders every ${prefs.waterReminderIntervalMinutes} minutes.',
                        value: prefs.enableWaterReminders,
                        onChanged: (value) => _patch(<String, dynamic>{
                          'enable_water_reminders': value,
                        }),
                      ),
                      _CategorySwitch(
                        icon: Icons.directions_run_rounded,
                        title: 'Activity',
                        subtitle:
                            'Movement reminders every ${prefs.activityReminderIntervalHours} hours.',
                        value: prefs.enableActivityReminders,
                        onChanged: (value) => _patch(<String, dynamic>{
                          'enable_activity_reminders': value,
                        }),
                      ),
                      _CategorySwitch(
                        icon: Icons.bedtime_rounded,
                        title: 'Sleep',
                        subtitle: 'Sleep coach reminders and bedtime support.',
                        value: prefs.enableSleepReminders,
                        onChanged: (value) => _patch(<String, dynamic>{
                          'enable_sleep_reminders': value,
                        }),
                      ),
                      _CategorySwitch(
                        icon: Icons.directions_walk_rounded,
                        title: 'Steps',
                        subtitle: 'Daily step nudges tied to activity.',
                        value: prefs.enableStepReminders,
                        onChanged: (value) => _patch(<String, dynamic>{
                          'enable_step_reminders': value,
                        }),
                      ),
                      _CategorySwitch(
                        icon: Icons.self_improvement_rounded,
                        title: 'Habits',
                        subtitle:
                            'Smoking, caffeine and fast-food support reminders.',
                        value: prefs.enableHabitReminders,
                        onChanged: (value) => _patch(<String, dynamic>{
                          'enable_habit_reminders': value,
                        }),
                      ),
                      const SizedBox(height: 16),
                      _AdvancedCard(
                        maxPerDay: prefs.motivationMaxPerDay,
                        cooldown: prefs.motivationTypeCooldownHours,
                        criticalBypass: prefs.criticalBypassQuietHours,
                        onCriticalBypass: (value) => _patch(<String, dynamic>{
                          'critical_bypass_quiet_hours': value,
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _patch(Map<String, dynamic> payload) async {
    try {
      await _hub.updatePreferences(payload);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update notification settings.'),
        ),
      );
    }
  }

  Future<void> _handlePermissionAction(String status) async {
    try {
      if (status == 'not_determined') {
        await _hub.refreshPermissionState(request: true);
      } else {
        await NotificationChannelRegistry.openSystemSettings();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open notification settings.')),
      );
    }
  }

  Future<void> _pickTime({
    required String key,
    required DateTime fallback,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(fallback),
    );
    if (picked == null) return;
    await _patch(<String, dynamic>{
      key:
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00',
    });
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        const Expanded(
          child: Text(
            'Notifications',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _QuietHoursCard extends StatelessWidget {
  const _QuietHoursCard({
    required this.enabled,
    required this.start,
    required this.end,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final bool enabled;
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Quiet hours',
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Switch(value: enabled, onChanged: onToggle),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimeButton(
                  label: 'Start',
                  value: _formatTime(start, '22:00'),
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeButton(
                  label: 'End',
                  value: _formatTime(end, '07:00'),
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Health critical reminders can bypass quiet hours when enabled.',
            style: TextStyle(
              color: VitaMateTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _CategorySwitch extends StatelessWidget {
  const _CategorySwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: VitaMateTheme.softSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: VitaMateTheme.primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
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
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _AdvancedCard extends StatelessWidget {
  const _AdvancedCard({
    required this.maxPerDay,
    required this.cooldown,
    required this.criticalBypass,
    required this.onCriticalBypass,
  });

  final int maxPerDay;
  final int cooldown;
  final bool criticalBypass;
  final ValueChanged<bool> onCriticalBypass;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Advanced settings',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Motivation limit: $maxPerDay per day, $cooldown h cooldown per type.',
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Critical alerts bypass quiet hours'),
            value: criticalBypass,
            onChanged: onCriticalBypass,
          ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime? value, String fallback) {
  if (value == null) return fallback;
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: VitaMateTheme.border),
    boxShadow: const [
      BoxShadow(
        color: VitaMateTheme.shadow,
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
    ],
  );
}
