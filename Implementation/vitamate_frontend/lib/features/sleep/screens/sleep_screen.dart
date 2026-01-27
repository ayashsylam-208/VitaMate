import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../core/notifications/notifications_service.dart';
import '../models/sleep_log.dart';
import '../state/sleep_controller.dart';
import '../state/sleep_settings_controller.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  late final SleepController sleepController;
  late final SleepSettingsController settingsController;

  DateTime _wakeTime = DateTime(2000, 1, 1, 7, 0);
  DateTime _bedTime = DateTime(2000, 1, 1, 23, 0);
  double _goalHours = 8.0;

  @override
  void initState() {
    super.initState();

    final repo = AuthRepository(AuthApi());
    sleepController = SleepController(repo);
    settingsController = SleepSettingsController(repo);

    settingsController.load().then((_) {
      final s = settingsController.settings;
      if (s != null) {
        setState(() {
          _wakeTime = s.wakeTime;
          _bedTime = s.bedTime;
          _goalHours = s.goalHours;
        });
      }
    });

    sleepController.loadAll();
  }

  Future<void> _pickTime(DateTime current, ValueChanged<DateTime> onPicked) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked != null) {
      onPicked(DateTime(2000, 1, 1, picked.hour, picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([settingsController, sleepController]),
      builder: (context, _) {
        final summary = sleepController.summary;
        final logs = sleepController.logs;
        final progress = (summary.progressPercent.clamp(0, 100)) / 100;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1325), Color(0xFF1F2A50)],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sleep Routine',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _summaryCard(progress, summary, sleepController.sleepPointsToday),
                    const SizedBox(height: 14),
                    _reminderCard(),
                    const SizedBox(height: 14),
                    _scheduleCard(),
                    const SizedBox(height: 14),
                    _manualLogCard(),
                    const SizedBox(height: 14),
                    _recentLogs(logs),
                    const SizedBox(height: 16),
                    _saveButtonRow(),
                    if (settingsController.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          settingsController.error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summaryCard(double progress, summary, int sleepPointsToday) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s sleep',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.loggedHoursToday.toStringAsFixed(1)}h / ${summary.goalHours.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10),
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7BD6FF)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Progress: ${summary.progressPercent}%',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Sleep points', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text(
                      sleepPointsToday.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reminderCard() {
    return _card(
      child: SwitchListTile(
        title: const Text('Sleep reminders', style: TextStyle(color: Colors.white)),
        subtitle: const Text(
          'Bedtime + Wake-up notifications',
          style: TextStyle(color: Colors.white70),
        ),
        value: settingsController.notificationsEnabled,
        onChanged: (v) async {
          await settingsController.setNotificationsEnabled(v);
        },
      ),
    );
  }

  Widget _scheduleCard() {
    return _card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.nightlight_round, color: Colors.white),
            title: const Text('Bedtime', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              _formatTime(_bedTime),
              style: const TextStyle(color: Colors.white70),
            ),
            onTap: () => _pickTime(_bedTime, (t) => setState(() => _bedTime = t)),
          ),
          const Divider(color: Colors.white12, height: 1),
          ListTile(
            leading: const Icon(Icons.wb_sunny, color: Colors.white),
            title: const Text('Wake-up', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              _formatTime(_wakeTime),
              style: const TextStyle(color: Colors.white70),
            ),
            onTap: () => _pickTime(_wakeTime, (t) => setState(() => _wakeTime = t)),
          ),
          const Divider(color: Colors.white12, height: 1),
          ListTile(
            leading: const Icon(Icons.timelapse, color: Colors.white),
            title: const Text('Daily goal', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              '${_goalHours.toStringAsFixed(1)} hours',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: SizedBox(
              width: 140,
              child: Slider(
                value: _goalHours,
                min: 5,
                max: 10,
                divisions: 10,
                activeColor: Colors.indigoAccent,
                onChanged: (v) => setState(() => _goalHours = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _manualLogCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manual sleep log',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter when you slept and when you woke up.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _openManualSleepSheet,
              child: const Text('Log sleep manually'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentLogs(List<SleepLog> logs) {
    if (sleepController.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (logs.isEmpty) {
      return _card(
        child: const ListTile(
          title: Text('No sleep logs yet', style: TextStyle(color: Colors.white)),
          subtitle: Text('Track your sleep to earn points.', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final dateFmt = DateFormat.MMMd();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent sleep',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...logs.take(3).map((log) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.white12,
                  child: Text(
                    log.durationHours.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(
                  '${_formatTime(log.startTime)} - ${_formatTime(log.endTime)}',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${dateFmt.format(log.date)} • ${log.quality}',
                  style: const TextStyle(color: Colors.white70),
                ),
              )),
        ],
      ),
    );
  }

  Widget _saveButtonRow() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.indigoAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () async {
              await settingsController.update(
                goalHours: _goalHours,
                wakeTime: _wakeTime,
                bedTime: _bedTime,
              );
              await sleepController.loadAll();
            },
            child: const Text('Save routine'),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  String _formatTime(DateTime t) {
    return DateFormat.Hm().format(t);
  }

  Future<void> _openManualSleepSheet() async {
    TimeOfDay start = const TimeOfDay(hour: 23, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 7, minute: 0);
    String quality = 'Deep';

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 18,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Log sleep',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.nightlight, color: Colors.white),
                    title: const Text('Start time', style: TextStyle(color: Colors.white)),
                    subtitle: Text(start.format(ctx), style: const TextStyle(color: Colors.white70)),
                    onTap: () async {
                      final picked = await showTimePicker(context: ctx, initialTime: start);
                      if (picked != null) setState(() => start = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.wb_sunny, color: Colors.white),
                    title: const Text('End time', style: TextStyle(color: Colors.white)),
                    subtitle: Text(end.format(ctx), style: const TextStyle(color: Colors.white70)),
                    onTap: () async {
                      final picked = await showTimePicker(context: ctx, initialTime: end);
                      if (picked != null) setState(() => end = picked);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: quality,
                    dropdownColor: const Color(0xFF1B2340),
                    decoration: const InputDecoration(
                      labelText: 'Quality',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Deep', child: Text('Deep')),
                      DropdownMenuItem(value: 'Light', child: Text('Light')),
                      DropdownMenuItem(value: 'Interrupted', child: Text('Interrupted')),
                    ],
                    onChanged: (v) => setState(() => quality = v ?? 'Deep'),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        var startDt = DateTime(now.year, now.month, now.day, start.hour, start.minute);
                        var endDt = DateTime(now.year, now.month, now.day, end.hour, end.minute);
                        if (endDt.isBefore(startDt)) {
                          endDt = endDt.add(const Duration(days: 1));
                        }
                        await sleepController.add(
                          startTime: startDt,
                          endTime: endDt,
                          quality: quality,
                        );
                        if (!mounted) return;
                        Navigator.of(ctx).pop();
                        if (sleepController.error == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sleep logged successfully')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(sleepController.error!)),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    sleepController.dispose();
    super.dispose();
  }
}
