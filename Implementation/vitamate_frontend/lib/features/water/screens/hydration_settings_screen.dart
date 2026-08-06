import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/notification_hub/notification_hub.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../state/water_controller.dart';

class HydrationSettingsScreen extends StatefulWidget {
  const HydrationSettingsScreen({super.key, this.controller});

  final WaterController? controller;

  @override
  State<HydrationSettingsScreen> createState() =>
      _HydrationSettingsScreenState();
}

class _HydrationSettingsScreenState extends State<HydrationSettingsScreen> {
  final NotificationHubController _hub = NotificationHubController.instance;
  late final WaterController controller;
  late final bool _ownsController;
  late final TextEditingController _goalController;
  bool _loading = true;
  bool _saving = false;
  bool _remindersEnabled = true;
  bool _quietHoursEnabled = false;
  int _intervalMinutes = 60;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);
  Map<String, Object?> _baseline = const {};

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? WaterController();
    _ownsController = widget.controller == null;
    _goalController = TextEditingController();
    _goalController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _goalController.dispose();
    if (_ownsController) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
                children: [
                  _TopBar(onReset: _confirmReset),
                  const SizedBox(height: 18),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                          icon: Icons.flag_rounded,
                          title: 'Daily goal',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _goalController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Base target',
                            suffixText: 'ml',
                            helperText:
                                'Active target can increase today from activity or health rules.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Hydration reminders',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: const Text(
                            'Backend plans the reminders; Android delivers them locally.',
                          ),
                          value: _remindersEnabled,
                          onChanged: (value) =>
                              setState(() => _remindersEnabled = value),
                        ),
                        AnimatedOpacity(
                          opacity: _remindersEnabled ? 1 : 0.42,
                          duration: const Duration(milliseconds: 180),
                          child: IgnorePointer(
                            ignoring: !_remindersEnabled,
                            child: Column(
                              children: [
                                DropdownButtonFormField<int>(
                                  key: ValueKey(_intervalMinutes),
                                  initialValue: _intervalMinutes,
                                  decoration: const InputDecoration(
                                    labelText: 'Frequency',
                                  ),
                                  items: const [60, 90, 120, 180]
                                      .map(
                                        (value) => DropdownMenuItem<int>(
                                          value: value,
                                          child: Text('Every $value minutes'),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _intervalMinutes = value);
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _TimeButton(
                                        label: 'Start',
                                        value: _startTime,
                                        onTap: () => _pickTime(
                                          current: _startTime,
                                          onPicked: (value) =>
                                              _startTime = value,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _TimeButton(
                                        label: 'End',
                                        value: _endTime,
                                        onTap: () => _pickTime(
                                          current: _endTime,
                                          onPicked: (value) => _endTime = value,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Quiet hours',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: const Text(
                            'Routine hydration reminders respect this global window.',
                          ),
                          value: _quietHoursEnabled,
                          onChanged: (value) =>
                              setState(() => _quietHoursEnabled = value),
                        ),
                        AnimatedOpacity(
                          opacity: _quietHoursEnabled ? 1 : 0.42,
                          duration: const Duration(milliseconds: 180),
                          child: IgnorePointer(
                            ignoring: !_quietHoursEnabled,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _TimeButton(
                                    label: 'Quiet start',
                                    value: _quietStart,
                                    onTap: () => _pickTime(
                                      current: _quietStart,
                                      onPicked: (value) => _quietStart = value,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _TimeButton(
                                    label: 'Quiet end',
                                    value: _quietEnd,
                                    onTap: () => _pickTime(
                                      current: _quietEnd,
                                      onPicked: (value) => _quietEnd = value,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _Card(
                    child: _InfoRow(
                      icon: Icons.notifications_active_outlined,
                      title: 'Sound and vibration',
                      subtitle:
                          'Handled by Android notification channels. Use system settings to change sound per channel.',
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _isDirty && !_saving && _validGoal
                        ? _save
                        : null,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save settings'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([
      _hub.refreshPreferences(),
      if (controller.summary.activeTargetMl == 0) controller.load(),
    ]);
    if (!mounted) return;
    final prefs = _hub.preferences;
    final targetMl = prefs.dailyWaterTargetMl > 0
        ? prefs.dailyWaterTargetMl
        : controller.summary.baseTargetMl;
    setState(() {
      _goalController.text = targetMl.toString();
      _remindersEnabled = prefs.enableWaterReminders;
      _intervalMinutes = _validInterval(prefs.waterReminderIntervalMinutes);
      _startTime = TimeOfDay.fromDateTime(prefs.waterReminderStartTime);
      _endTime = TimeOfDay.fromDateTime(prefs.waterReminderEndTime);
      _quietHoursEnabled = prefs.quietHoursEnabled;
      _quietStart = TimeOfDay.fromDateTime(
        prefs.quietStart ?? DateTime(2000, 1, 1, 22),
      );
      _quietEnd = TimeOfDay.fromDateTime(
        prefs.quietEnd ?? DateTime(2000, 1, 1, 7),
      );
      _baseline = _snapshot();
      _loading = false;
    });
  }

  bool get _validGoal {
    final goal = int.tryParse(_goalController.text.trim()) ?? 0;
    return goal >= 500 && goal <= 8000;
  }

  bool get _isDirty {
    if (_loading) return false;
    return !_mapsEqual(_baseline, _snapshot());
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _hub.updatePreferences({
        'daily_water_target_ml': int.parse(_goalController.text.trim()),
        'enable_water_reminders': _remindersEnabled,
        'water_reminder_interval_minutes': _intervalMinutes,
        'water_reminder_start_time': _clock(_startTime),
        'water_reminder_end_time': _clock(_endTime),
        'quiet_hours_enabled': _quietHoursEnabled,
        'quiet_start': _clock(_quietStart),
        'quiet_end': _clock(_quietEnd),
      });
      await controller.load();
      if (!mounted) return;
      setState(() {
        _baseline = _snapshot();
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hydration settings saved.')),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save hydration settings.')),
      );
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reset hydration settings?',
                  style: TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This restores the reminder window and frequency. Your profile-based water goal remains editable.',
                  style: TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;
    setState(() {
      _remindersEnabled = true;
      _intervalMinutes = 60;
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 21, minute: 0);
      _quietHoursEnabled = false;
      _quietStart = const TimeOfDay(hour: 22, minute: 0);
      _quietEnd = const TimeOfDay(hour: 7, minute: 0);
    });
  }

  Future<void> _pickTime({
    required TimeOfDay current,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    setState(() => onPicked(picked));
  }

  Map<String, Object?> _snapshot() {
    return {
      'goal': int.tryParse(_goalController.text.trim()) ?? 0,
      'enabled': _remindersEnabled,
      'interval': _intervalMinutes,
      'start': _clock(_startTime),
      'end': _clock(_endTime),
      'quiet_enabled': _quietHoursEnabled,
      'quiet_start': _clock(_quietStart),
      'quiet_end': _clock(_quietEnd),
    };
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        const Expanded(
          child: Text(
            'Hydration Settings',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(onPressed: onReset, child: const Text('Reset')),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: VitaMateTheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
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
  final TimeOfDay value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(height: 2),
          Text(
            value.format(context),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: VitaMateTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

int _validInterval(int value) {
  return const [60, 90, 120, 180].contains(value) ? value : 60;
}

String _clock(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:00';
}

bool _mapsEqual(Map<String, Object?> left, Map<String, Object?> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}
