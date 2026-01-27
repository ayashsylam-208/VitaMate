import 'package:flutter/material.dart';

import '../../../core/notifications/notifications_service.dart';
import '../state/activity_controller.dart';
import '../models/exercise.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late final ActivityController controller;

  Exercise? _selectedExercise;
  final _durationCtrl = TextEditingController(text: '30');
  bool remindersEnabled = false;
  TimeOfDay reminderTime = const TimeOfDay(hour: 10, minute: 0);

  @override
  void initState() {
    super.initState();
    controller = ActivityController()..load();
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.error != null) {
              return Center(child: Text(controller.error!));
            }

            final exercises = controller.exercises;
            if (_selectedExercise != null) {
              final match = exercises.where((e) => e.id == _selectedExercise!.id).toList();
              _selectedExercise = match.isNotEmpty ? match.first : null;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryCard(cs),
                  const SizedBox(height: 14),
                  _reminderCard(cs),
                  const SizedBox(height: 14),
                  _logCard(cs, exercises),
                  const SizedBox(height: 18),
                  const Text(
                    'Today logs',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  _logsList(cs),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _summaryCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's activity",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${controller.caloriesBurnedToday} kcal burned',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars, color: cs.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${controller.activityPointsToday} pts (activity)',
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reminderCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: cs.outlineVariant.withOpacity(0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Activity reminders'),
              subtitle: Text(
                'Daily at ${reminderTime.format(context)}',
                style: TextStyle(color: cs.outline),
              ),
              value: remindersEnabled,
              onChanged: (v) async {
                setState(() => remindersEnabled = v);
                if (v) {
                  await NotificationsService.scheduleDailyActivityReminder(
                    time: DateTime(2000, 1, 1, reminderTime.hour, reminderTime.minute),
                  );
                  _showSnack('Activity reminder scheduled');
                } else {
                  await NotificationsService.cancelActivity();
                  _showSnack('Activity reminders disabled');
                }
              },
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: const Text('Reminder time'),
              subtitle: Text(reminderTime.format(context)),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: reminderTime,
                );
                if (picked != null) {
                  setState(() => reminderTime = picked);
                  if (remindersEnabled) {
                    await NotificationsService.scheduleDailyActivityReminder(
                      time: DateTime(2000, 1, 1, picked.hour, picked.minute),
                    );
                    _showSnack('Activity reminder updated');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _logCard(ColorScheme cs, List<Exercise> exercises) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Log activity', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            DropdownButtonFormField<Exercise>(
              isExpanded: true,
              value: _selectedExercise,
              items: exercises
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text('${e.name} (MET ${e.metValue})'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedExercise = v),
              decoration: const InputDecoration(
                labelText: 'Select exercise',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                border: OutlineInputBorder(),
                suffixText: 'min',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedExercise == null
                    ? null
                    : () async {
                        final minutes = int.tryParse(_durationCtrl.text) ?? 0;
                        if (minutes <= 0) {
                          _showSnack('Enter a valid duration');
                          return;
                        }
                        await controller.addActivity(
                          exerciseId: _selectedExercise!.id,
                          durationMinutes: minutes,
                        );
                        _showSnack('Activity logged');
                      },
                child: const Text('Save activity'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logsList(ColorScheme cs) {
    if (controller.logs.isEmpty) {
      return Text(
        'No activities yet.',
        style: TextStyle(color: cs.outline),
      );
    }
    return Column(
      children: controller.logs.map((log) {
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
          ),
          child: ListTile(
            leading: Icon(Icons.fitness_center, color: cs.primary),
            title: Text(log.exerciseName, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${log.durationMinutes} min • ${log.caloriesBurned} kcal'),
            trailing: Text(log.date.toIso8601String().split('T').first),
          ),
        );
      }).toList(),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
