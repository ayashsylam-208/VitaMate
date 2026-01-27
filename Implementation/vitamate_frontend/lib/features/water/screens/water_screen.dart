import 'package:flutter/material.dart';

import '../../../core/notifications/notifications_service.dart';
import '../state/water_controller.dart';
import '../widgets/drink_icon_tile.dart';

class WaterScreen extends StatefulWidget {
  /// targetLitersFromBackend example: 2.31 (liters)
  /// If you already have targetMl, pass ml directly and set [targetIsLiters] = false.
  final double targetValueFromBackend;
  final bool targetIsLiters;

  const WaterScreen({
    super.key,
    required this.targetValueFromBackend,
    this.targetIsLiters = true,
  });

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  late final WaterController controller;
  bool remindersEnabled = false;
  int intervalMinutes = 60;

  int _targetToMl() {
    if (widget.targetIsLiters) {
      return (widget.targetValueFromBackend * 1000).round();
    }
    return widget.targetValueFromBackend.round();
  }

  @override
  void initState() {
    super.initState();
    controller = WaterController()..load(targetMlFromBackend: _targetToMl());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Water'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.loading
                ? null
                : () => controller.load(targetMlFromBackend: _targetToMl()),
            icon: const Icon(Icons.refresh),
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

            if (controller.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    controller.error!,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () =>
                  controller.load(targetMlFromBackend: _targetToMl()),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryCard(cs),
                    const SizedBox(height: 14),
                    _reminderCard(cs),
                    const SizedBox(height: 14),
                    _quickDrink(cs),
                    const SizedBox(height: 18),
                    const Text(
                      'Today logs',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    if (controller.logs.isEmpty)
                      Text(
                        'No water logs for today yet.',
                        style: TextStyle(color: cs.outline),
                      )
                    else
                      ...controller.logs.map((e) {
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: cs.outlineVariant.withOpacity(0.45),
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.water_drop, color: cs.primary),
                            title: Text(
                              '${e.amountMl} ml',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              'Date: ${e.date.toIso8601String().split("T").first}',
                            ),
                          ),
                        );
                      }),
                  ],
                ),
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
        side: BorderSide(
          color: cs.outlineVariant.withOpacity(0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's water",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${controller.consumedMl} / ${controller.targetMl} ml',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: controller.progress,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Remaining: ${controller.remainingMl} ml',
              style: TextStyle(color: cs.outline),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars, color: cs.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '+${controller.waterPointsToday} pts (water)',
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
              title: const Text('Hydration reminders'),
              subtitle: Text(
                'Every $intervalMinutes minutes',
                style: TextStyle(color: cs.outline),
              ),
              value: remindersEnabled,
              onChanged: (v) async {
                setState(() => remindersEnabled = v);
                if (v) {
                  await NotificationsService.scheduleWaterInterval(
                      intervalMinutes: intervalMinutes);
                  await NotificationsService.showWaterEnabled(intervalMinutes);
                  _showSnack('Water reminders enabled');
                } else {
                  await NotificationsService.cancelWater();
                  _showSnack('Water reminders disabled');
                }
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Interval', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: intervalMinutes.toDouble(),
                    min: 30,
                    max: 180,
                    divisions: 5,
                    label: '$intervalMinutes min',
                    onChanged: (v) => setState(() => intervalMinutes = v.round()),
                    onChangeEnd: (v) {
                      if (remindersEnabled) {
                        NotificationsService.scheduleWaterInterval(
                          intervalMinutes: v.round(),
                        );
                        _showSnack('Updated interval to ${v.round()} minutes');
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickDrink(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick drink',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: 2.1,
          children: [
            DrinkIconTile(
              icon: Icons.local_cafe,
              title: 'Cup',
              subtitle: '250 ml',
              onTap: () => controller.drink(250),
            ),
            DrinkIconTile(
              icon: Icons.emoji_food_beverage,
              title: 'Mug',
              subtitle: '300 ml',
              onTap: () => controller.drink(300),
            ),
            DrinkIconTile(
              icon: Icons.water_drop,
              title: 'Small bottle',
              subtitle: '500 ml',
              onTap: () => controller.drink(500),
            ),
            DrinkIconTile(
              icon: Icons.local_drink,
              title: 'Large bottle',
              subtitle: '1000 ml',
              onTap: () => controller.drink(1000),
            ),
          ],
        ),
      ],
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
