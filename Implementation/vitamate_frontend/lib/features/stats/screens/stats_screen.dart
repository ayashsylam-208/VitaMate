import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../activity/screens/activity_screen.dart';
import '../../nutrition/screens/nutrition_screen.dart';
import '../../sleep/screens/sleep_screen.dart';
import '../../steps/screens/steps_screen.dart';
import '../../water/screens/water_screen.dart';
import '../state/stats_controller.dart';
import '../data/stats_api.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final StatsController controller;
  final StatsApi _statsApi = StatsApi();

  @override
  void initState() {
    super.initState();
    controller = StatsController()..load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.decimalPattern();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.load(),
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        controller.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => controller.load(),
                        child: const Text('Try again'),
                      )
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: controller.load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _todayCard(cs, fmt),
                    const SizedBox(height: 14),
                    _grid(cs, fmt),
                    const SizedBox(height: 18),
                    _progressChart(cs),
                    const SizedBox(height: 18),
                    _trackerCharts(cs),
                    const SizedBox(height: 18),
                    _timeline(cs, fmt),
                    const SizedBox(height: 18),
                    _shortcuts(cs),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _todayCard(ColorScheme cs, NumberFormat fmt) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Today', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.MMMMEEEEd().format(DateTime.now()),
                      style: TextStyle(color: cs.outline),
                    ),
                  ],
                ),
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
                      const SizedBox(width: 6),
                      Text(
                        '${controller.pointsTotal} pts',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Lvl ${controller.level}', style: TextStyle(color: cs.primary)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _chip(cs, Icons.local_fire_department, 'Calories rem.',
                    '${fmt.format(controller.caloriesRemaining)} kcal'),
                _chip(cs, Icons.local_fire_department, 'Burn',
                    '${fmt.format(controller.burnCurrent)} / ${fmt.format(controller.burnTarget)} kcal'),
                _chip(cs, Icons.water_drop, 'Water',
                    '${controller.waterCurrent.toStringAsFixed(2)} / ${controller.waterTarget.toStringAsFixed(2)} L'),
                _chip(cs, Icons.directions_walk, 'Steps',
                    '${fmt.format(controller.stepsCurrent)} / ${fmt.format(controller.stepsTarget)}'),
                _chip(cs, Icons.bedtime, 'Sleep',
                    '${controller.sleepLoggedHours.toStringAsFixed(1)} / ${controller.sleepGoalHours.toStringAsFixed(1)} h'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(ColorScheme cs, NumberFormat fmt) {
    final items = [
      _metricCard(
        cs,
        title: 'Water',
        icon: Icons.water_drop,
        current: controller.waterCurrent,
        target: controller.waterTarget,
        unit: 'L',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WaterScreen(
            targetValueFromBackend: controller.waterTarget,
            targetIsLiters: true,
          ),
        )),
      ),
      _metricCard(
        cs,
        title: 'Sleep',
        icon: Icons.bedtime,
        current: controller.sleepLoggedHours,
        target: controller.sleepGoalHours,
        unit: 'h',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SleepScreen())),
      ),
      _metricCard(
        cs,
        title: 'Calories',
        icon: Icons.restaurant,
        current: controller.caloriesConsumed.toDouble(),
        target: controller.caloriesTarget.toDouble(),
        unit: 'kcal',
        warnIfOver: true,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NutritionScreen())),
      ),
      _metricCard(
        cs,
        title: 'Activity',
        icon: Icons.fitness_center,
        current: controller.burnCurrent.toDouble(),
        target: controller.burnTarget.toDouble(),
        unit: 'kcal',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivityScreen())),
      ),
      _metricCard(
        cs,
        title: 'Steps',
        icon: Icons.directions_walk,
        current: controller.stepsCurrent.toDouble(),
        target: controller.stepsTarget.toDouble(),
        unit: 'steps',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StepsScreen())),
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items,
    );
  }

  Widget _metricCard(
    ColorScheme cs, {
    required String title,
    required IconData icon,
    required double current,
    required double target,
    required String unit,
    bool warnIfOver = false,
    VoidCallback? onTap,
  }) {
    final double pct = target <= 0 ? 0 : (current / target).clamp(0.0, 1.0);
    final over = warnIfOver && target > 0 && current > target;
    final displayCurrent = unit == 'steps'
        ? NumberFormat.decimalPattern().format(current.round())
        : current.toStringAsFixed(unit == 'h' ? 1 : 2);
    final displayTarget = unit == 'steps'
        ? NumberFormat.decimalPattern().format(target.round())
        : target.toStringAsFixed(unit == 'h' ? 1 : 2);

    return SizedBox(
      width: MediaQuery.of(context).size.width / 2 - 22,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$displayCurrent / $displayTarget $unit',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    color: over ? cs.error : cs.primary,
                    backgroundColor: cs.surfaceVariant.withOpacity(0.6),
                  ),
                ),
                if (over)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Over target',
                      style: TextStyle(color: cs.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressChart(ColorScheme cs) {
    if (controller.history.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No history yet to chart.'),
        ),
      );
    }

    final points = controller.history.map((e) => e.pointsEstimate.toDouble()).toList();
    final dates = controller.history.map((e) => DateFormat.E().format(e.date)).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Points trend (7 days)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(
                painter: _LineChartPainter(points: points, color: cs.primary),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Low: ${points.reduce((a, b) => a < b ? a : b)} pts', style: TextStyle(color: cs.outline)),
                Text('High: ${points.reduce((a, b) => a > b ? a : b)} pts', style: TextStyle(color: cs.outline)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: dates.map((d) => Expanded(child: Text(d, textAlign: TextAlign.center, style: TextStyle(color: cs.outline, fontSize: 12)))).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeline(ColorScheme cs, NumberFormat fmt) {
    if (controller.history.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No history yet. Log water, meals, sleep, or steps to start.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '7-day timeline',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
          const SizedBox(height: 8),
          SizedBox(
          height: 360,
            child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: controller.history.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final day = controller.history[index];
              final dateLabel = DateFormat.E().format(day.date);
              final dayNum = day.date.day;
              final kcalLabel = '${fmt.format(day.caloriesIn)} / ${fmt.format(day.caloriesTarget)}';
              return SizedBox(
                width: 220,
                height: double.infinity,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$dateLabel $dayNum',
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('+${day.pointsEstimate} pts',
                                  style: TextStyle(color: cs.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _timelineBar(
                                  cs,
                                  'Water',
                                  Icons.water_drop,
                                  day.waterProgress.clamp(0.0, 1.0).toDouble(),
                                  '${day.waterCurrent.toStringAsFixed(2)} / ${day.waterTarget.toStringAsFixed(2)} L',
                                ),
                                _timelineBar(
                                  cs,
                                  'Calories',
                                  Icons.restaurant,
                                  day.caloriesProgress.clamp(0.0, 1.0).toDouble(),
                                  '$kcalLabel kcal',
                                  warn: day.caloriesTarget > 0 && day.caloriesIn > day.caloriesTarget,
                                ),
                                _timelineBar(
                                  cs,
                                  'Burn',
                                  Icons.local_fire_department,
                                  day.burnProgress.clamp(0.0, 1.0).toDouble(),
                                  '${fmt.format(day.caloriesBurned)} / ${fmt.format(day.burnTarget)} kcal',
                                ),
                                _timelineBar(
                                  cs,
                                  'Steps',
                                  Icons.directions_walk,
                                  day.stepsProgress.clamp(0.0, 1.0).toDouble(),
                                  '${fmt.format(day.steps)} / ${fmt.format(day.stepsTarget)}',
                                ),
                                _timelineBar(
                                  cs,
                                  'Sleep',
                                  Icons.bedtime,
                                  day.sleepProgress.clamp(0.0, 1.0).toDouble(),
                                  '${day.sleepHours.toStringAsFixed(1)} / ${day.sleepTarget.toStringAsFixed(1)} h',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _timelineBar(ColorScheme cs, String title, IconData icon, double value, String subtitle,
      {bool warn = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: warn ? cs.error : cs.primary),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              color: warn ? cs.error : cs.primary,
              backgroundColor: cs.surfaceVariant.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: cs.outline)),
        ],
      ),
    );
  }

  // مخططات فرعية لكل متتبع لعرض التقدم اليومي خلال ٧ أيام
  Widget _trackerCharts(ColorScheme cs) {
    if (controller.history.isEmpty) {
      return const SizedBox.shrink();
    }

    final waterSeries =
        controller.history.map((e) => e.waterProgress.clamp(0.0, 1.5).toDouble()).toList();
    final caloriesSeries =
        controller.history.map((e) => e.caloriesProgress.clamp(0.0, 2.0).toDouble()).toList();
    final stepsSeries =
        controller.history.map((e) => e.stepsProgress.clamp(0.0, 2.0).toDouble()).toList();
    final sleepSeries =
        controller.history.map((e) => e.sleepProgress.clamp(0.0, 1.5).toDouble()).toList();
    final burnSeries =
        controller.history.map((e) => e.burnProgress.clamp(0.0, 2.0).toDouble()).toList();

    List<Widget> cards = [
      _miniChart(cs, 'Water progress', waterSeries, cs.primary),
      _miniChart(cs, 'Calories progress', caloriesSeries, cs.error),
      _miniChart(cs, 'Steps progress', stepsSeries, cs.primary),
      _miniChart(cs, 'Sleep progress', sleepSeries, cs.tertiary),
      _miniChart(cs, 'Burn progress', burnSeries, cs.secondary),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tracker charts', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (w) => SizedBox(
                  width: MediaQuery.of(context).size.width / 2 - 22,
                  child: w,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _miniChart(ColorScheme cs, String title, List<double> series, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: CustomPaint(
                painter: _LineChartPainter(points: series, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// نافذة إدخال نوم يدوي (وقت بداية ونهاية + جودة).
  Future<void> _showSleepLogSheet(ColorScheme cs) async {
    TimeOfDay start = const TimeOfDay(hour: 23, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 7, minute: 0);
    String quality = 'Deep';

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                  const Text('Log sleep', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.nightlight),
                    title: const Text('Start time'),
                    subtitle: Text(start.format(ctx)),
                    onTap: () async {
                      final picked = await showTimePicker(context: ctx, initialTime: start);
                      if (picked != null) setState(() => start = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.wb_sunny),
                    title: const Text('End time'),
                    subtitle: Text(end.format(ctx)),
                    onTap: () async {
                      final picked = await showTimePicker(context: ctx, initialTime: end);
                      if (picked != null) setState(() => end = picked);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: quality,
                    decoration: const InputDecoration(labelText: 'Quality'),
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
                      onPressed: () async {
                        final now = DateTime.now();
                        var startDt = DateTime(now.year, now.month, now.day, start.hour, start.minute);
                        var endDt = DateTime(now.year, now.month, now.day, end.hour, end.minute);
                        if (endDt.isBefore(startDt)) {
                          endDt = endDt.add(const Duration(days: 1));
                        }
                        try {
                          await _statsApi.logSleep(start: startDt, end: endDt, quality: quality);
                          if (mounted) Navigator.of(ctx).pop();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sleep logged successfully')),
                            );
                            controller.load();
                          }
                        } catch (_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to log sleep')),
                            );
                          }
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

  Widget _shortcuts(ColorScheme cs) {
    final shortcuts = [
      _shortcutTile(cs, 'Log water', Icons.water_drop, () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WaterScreen(
            targetValueFromBackend: controller.waterTarget,
            targetIsLiters: true,
          ),
        ));
      }),
      _shortcutTile(cs, 'Log meal', Icons.restaurant, () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NutritionScreen()));
      }),
      _shortcutTile(cs, 'Log activity', Icons.fitness_center, () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivityScreen()));
      }),
      _shortcutTile(cs, 'Log steps', Icons.directions_walk, () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StepsScreen()));
      }),
      _shortcutTile(cs, 'Log sleep (manual)', Icons.hotel, () async {
        await _showSleepLogSheet(cs);
      }),
      _shortcutTile(cs, 'Sleep reminders', Icons.bedtime, () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SleepScreen()));
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick actions',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: shortcuts,
        ),
      ],
    );
  }

  Widget _shortcutTile(ColorScheme cs, String title, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 2 - 22,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(ColorScheme cs, IconData icon, String title, String value) {
    return Chip(
      avatar: Icon(icon, size: 18, color: cs.primary),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: cs.outline)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      backgroundColor: cs.surfaceVariant.withOpacity(0.5),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.points, required this.color});

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paintLine = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final paintFill = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final maxVal = points.reduce((a, b) => a > b ? a : b);
    final minVal = points.reduce((a, b) => a < b ? a : b);
    final span = (maxVal - minVal).abs() < 1 ? 1 : (maxVal - minVal);

    final stepX = points.length == 1 ? 0.0 : size.width / (points.length - 1);
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1 ? size.width / 2 : i * stepX;
      final norm = (points[i] - minVal) / span;
      final y = size.height - (norm * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      if (i == points.length - 1) {
        fillPath.lineTo(x, size.height);
        fillPath.close();
      }
    }

    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);

    // Draw points
    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1 ? size.width / 2 : i * stepX;
      final norm = (points[i] - minVal) / span;
      final y = size.height - (norm * size.height);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
  }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
