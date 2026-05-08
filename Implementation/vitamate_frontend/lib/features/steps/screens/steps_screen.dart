import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/testing/app_test_keys.dart';
import '../../../shared/widgets/vitamate_bottom_nav.dart';
import '../state/steps_controller.dart';

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key, this.controller, this.autoInit = true});

  final StepsController? controller;
  final bool autoInit;

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  late final StepsController controller;
  late final bool _ownsController;
  final TextEditingController _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? StepsController();
    _ownsController = widget.controller == null;
    if (widget.autoInit) {
      unawaited(controller.init());
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
    if (_ownsController) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.decimalPattern();

    return Scaffold(
      bottomNavigationBar: const VitaMateBottomNav(currentIndex: -1),
      appBar: AppBar(
        title: const Text('Steps'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (controller.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!controller.permissionGranted) {
              return _permissionCard(cs);
            }

            if (controller.error != null && controller.stepsToday == 0) {
              return _errorCard(cs, controller.error!);
            }

            final steps = controller.stepsToday;
            final target = controller.targetSteps;
            final progress = target == 0
                ? 0.0
                : (steps / target).clamp(0.0, 1.0);

            return RefreshIndicator(
              onRefresh: controller.refresh,
              child: SingleChildScrollView(
                key: const ValueKey(AppTestKeys.stepsScreen),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryCard(cs, fmt, steps, target, progress),
                    const SizedBox(height: 14),
                    _reminderCard(cs),
                    const SizedBox(height: 14),
                    _manualAddCard(cs),
                    const SizedBox(height: 14),
                    _syncCard(cs, fmt, steps),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _summaryCard(
    ColorScheme cs,
    NumberFormat fmt,
    int steps,
    int target,
    double progress,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's steps",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars, color: cs.primary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '+${controller.pointsToday} pts',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${fmt.format(steps)} / ${fmt.format(target)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress, minHeight: 10),
            ),
            const SizedBox(height: 10),
            Text(
              'Remaining: ${fmt.format(controller.remainingSteps)} steps',
              style: TextStyle(color: cs.outline),
            ),
            if (controller.usingDebugStepSimulation) ...[
              const SizedBox(height: 8),
              Text(
                'Emulator estimate mode is active for step counting.',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _statChip(
                  cs,
                  Icons.directions_walk,
                  '${fmt.format(steps)} steps',
                ),
                _statChip(cs, Icons.flag, 'Goal: ${fmt.format(target)}'),
                _statChip(
                  cs,
                  Icons.map,
                  '${controller.distanceKm.toStringAsFixed(2)} km est.',
                ),
                _statChip(
                  cs,
                  Icons.local_fire_department,
                  '${fmt.format(controller.caloriesBurned)} kcal burned',
                ),
                _statChip(
                  cs,
                  Icons.timer_outlined,
                  '${fmt.format(controller.activeMinutesEstimate)} min active',
                ),
                if (controller.lastSyncedAt != null)
                  _statChip(
                    cs,
                    Icons.cloud_done,
                    'Synced ${DateFormat.Hm().format(controller.lastSyncedAt!)}',
                  ),
              ],
            ),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  controller.error!,
                  style: TextStyle(color: cs.error),
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
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Steps reminder'),
              subtitle: Text(
                'Daily at ${controller.reminderTime.format(context)}',
                style: TextStyle(color: cs.outline),
              ),
              value: controller.reminderEnabled,
              onChanged: (v) async {
                if (v) {
                  await controller.enableReminder(controller.reminderTime);
                  _showSnack('Steps reminder scheduled');
                } else {
                  await controller.disableReminder();
                  _showSnack('Steps reminder disabled');
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Reminder time'),
              subtitle: Text(controller.reminderTime.format(context)),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: controller.reminderTime,
                );
                if (picked != null) {
                  if (controller.reminderEnabled) {
                    await controller.enableReminder(picked);
                    _showSnack('Steps reminder rescheduled');
                  } else {
                    // Just save the preferred time without scheduling.
                    controller.reminderTime = picked;
                    await controller.disableReminder();
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _manualAddCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Log steps manually',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _manualController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Steps to add',
                hintText: 'e.g. 500',
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final raw = _manualController.text.trim();
                  final val = int.tryParse(raw) ?? 0;
                  if (val <= 0) {
                    _showSnack('Enter a positive number of steps');
                    return;
                  }
                  await controller.addManualSteps(val);
                  _manualController.clear();
                  _showSnack('Added $val steps');
                },
                child: const Text('Add steps'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _syncCard(ColorScheme cs, NumberFormat fmt, int steps) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sync steps',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Current: ${fmt.format(steps)}',
              style: TextStyle(color: cs.outline),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await controller.syncSteps();
                  _showSnack('Steps synced');
                },
                child: const Text('Sync now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionCard(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_walk, color: cs.primary, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Activity recognition permission is required',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await controller.init(requestPermission: true);
                  if (!controller.permissionGranted &&
                      controller.permissionPermanentlyDenied) {
                    await openAppSettings();
                  }
                },
                child: Text(
                  controller.permissionPermanentlyDenied
                      ? 'Open settings'
                      : 'Grant permission',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(ColorScheme cs, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => controller.refresh(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(ColorScheme cs, IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18, color: cs.primary),
      label: Text(label),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
