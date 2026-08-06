import 'package:flutter/material.dart';

import '../models/nutrition_summary.dart';
import '../state/nutrition_controller.dart';
import '../widgets/nutrition_reference_ui.dart';
import '../widgets/nutrition_ui.dart' show NutritionErrorView;

class NutritionDetailsScreen extends StatelessWidget {
  const NutritionDetailsScreen({super.key, required this.controller});

  final NutritionController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: NutritionReferenceBackground(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final summary = controller.summary;
            final macros = _orderedMetrics(summary, const <String>[
              'protein',
              'carbs',
              'fat',
              'fiber',
            ]);
            final limits = _orderedMetrics(summary, const <String>[
              'sugar',
              'sodium',
              'saturated_fat',
              'cholesterol',
            ]);
            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: nutritionPagePadding,
                children: <Widget>[
                  NutritionReferenceHeader(
                    title: 'Nutrition Details',
                    subtitle: 'See your full nutrient intake for today.',
                    titleIcon: Icons.ramen_dining_rounded,
                    trailing: NutritionRoundButton(
                      tooltip: 'Refresh nutrition details',
                      icon: Icons.refresh_rounded,
                      onTap: controller.loading ? null : controller.load,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _EnergySummary(summary: summary),
                  const SizedBox(height: 18),
                  _SectionHeading(
                    title: 'Macronutrients',
                    icon: Icons.fitness_center_rounded,
                  ),
                  const SizedBox(height: 8),
                  _MetricCard(metrics: macros),
                  const SizedBox(height: 18),
                  _SectionHeading(
                    title: 'Limits to watch',
                    icon: Icons.shield_outlined,
                  ),
                  const SizedBox(height: 8),
                  _MetricCard(metrics: limits),
                  const SizedBox(height: 18),
                  _InsightCard(
                    metrics: <NutritionSummaryMetric>[...macros, ...limits],
                  ),
                  if (controller.error != null) ...<Widget>[
                    const SizedBox(height: 14),
                    NutritionErrorView(
                      message: controller.error!,
                      onRetry: controller.load,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _EnergySummary extends StatelessWidget {
  const _EnergySummary({required this.summary});

  final NutritionSummary summary;

  @override
  Widget build(BuildContext context) {
    final over = summary.status == 'over_target' || summary.status == 'high';
    final progress = summary.progressPercent / 100;
    final color = over ? const Color(0xFFFF5252) : nutritionPurple;
    final status = over
        ? 'Over target today'
        : summary.status == 'good' || summary.status == 'on_track'
        ? 'On track today'
        : 'Building toward your goal';
    return NutritionReferenceCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Today summary',
                  style: TextStyle(
                    color: nutritionPurple,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: '${summary.consumedCalories}',
                          style: const TextStyle(
                            color: Color(0xFF6841C5),
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' / ${summary.targetCalories > 0 ? summary.targetCalories : '--'} kcal',
                          style: const TextStyle(
                            color: Color(0xFF5D5870),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(
                        dimension: 20,
                        child: Icon(
                          over
                              ? Icons.arrow_upward_rounded
                              : Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          NutritionProgressRing(
            progress: progress,
            size: 112,
            color: color,
            track: over ? const Color(0xFFFFDEDE) : const Color(0xFFE8DFFF),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${summary.progressPercent.round()}%',
                  style: const TextStyle(
                    color: nutritionInk,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'of goal',
                  style: TextStyle(
                    color: nutritionMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, color: nutritionPurple, size: 28),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: nutritionInk,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metrics});

  final List<NutritionSummaryMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const NutritionReferenceCard(
        child: Text(
          'No configured backend targets are available for this section.',
          style: TextStyle(color: nutritionMuted),
        ),
      );
    }
    return NutritionReferenceCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < metrics.length; i++) ...<Widget>[
            _MetricRow(metric: metrics[i]),
            if (i != metrics.length - 1)
              const Divider(height: 1, color: nutritionLine),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric});

  final NutritionSummaryMetric metric;

  @override
  Widget build(BuildContext context) {
    final presentation = _metricPresentation(metric.code, metric.status);
    return Semantics(
      label:
          '${metric.label}, ${nutritionNumber(metric.value)} of ${nutritionNumber(metric.target)} ${metric.unit}, ${presentation.status}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: <Widget>[
            NutritionIconBubble(
              icon: presentation.icon,
              color: presentation.color,
              background: presentation.background,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: Text(
                metric.label,
                maxLines: 2,
                style: const TextStyle(
                  color: nutritionInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: nutritionNumber(metric.value),
                          style: const TextStyle(
                            color: Color(0xFF5E35BE),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' / ${nutritionNumber(metric.target)} ${metric.unit}',
                          style: const TextStyle(
                            color: nutritionMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (metric.progressPercent / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      color: presentation.color,
                      backgroundColor: const Color(0xFFECE9F2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            NutritionStatusBadge(status: presentation.status),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.metrics});

  final List<NutritionSummaryMetric> metrics;

  @override
  Widget build(BuildContext context) {
    NutritionSummaryMetric? warning;
    NutritionSummaryMetric? good;
    for (final metric in metrics) {
      if (warning == null &&
          (metric.status == 'high' || metric.status == 'low')) {
        warning = metric;
      }
      if (good == null && metric.status == 'good') good = metric;
    }
    final message = warning == null
        ? 'Your tracked nutrients are moving in a balanced direction today.'
        : good == null
        ? '${warning.label} needs some attention today.'
        : 'You are doing well on ${good.label.toLowerCase()}, but ${warning.label.toLowerCase()} needs attention today.';
    return NutritionReferenceCard(
      color: const Color(0xFFF3EEFF),
      child: Row(
        children: <Widget>[
          const NutritionIconBubble(
            icon: Icons.auto_awesome_rounded,
            color: nutritionPurple,
            background: Colors.white,
            size: 54,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Insight',
                  style: TextStyle(
                    color: nutritionPurple,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  message,
                  style: const TextStyle(
                    color: nutritionInk,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.sentiment_satisfied_alt_rounded,
            color: nutritionPurple,
            size: 33,
          ),
        ],
      ),
    );
  }
}

class _MetricPresentation {
  const _MetricPresentation({
    required this.icon,
    required this.color,
    required this.background,
    required this.status,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String status;
}

_MetricPresentation _metricPresentation(String code, String rawStatus) {
  final status = rawStatus == 'over_target'
      ? 'high'
      : rawStatus == 'good'
      ? 'good'
      : rawStatus == 'high'
      ? 'high'
      : 'low';
  final values = switch (code) {
    'protein' => (
      Icons.egg_alt_outlined,
      const Color(0xFF7141DB),
      const Color(0xFFF0E9FF),
    ),
    'carbs' => (
      Icons.grass_rounded,
      const Color(0xFF25A85A),
      const Color(0xFFE5F7EA),
    ),
    'fat' || 'saturated_fat' => (
      Icons.water_drop_outlined,
      const Color(0xFFFFA51D),
      const Color(0xFFFFF1D8),
    ),
    'fiber' => (
      Icons.eco_outlined,
      const Color(0xFF2E7EEA),
      const Color(0xFFE4F0FF),
    ),
    'sugar' => (
      Icons.view_in_ar_outlined,
      const Color(0xFFEF4E82),
      const Color(0xFFFFE6EF),
    ),
    'sodium' => (
      Icons.science_outlined,
      const Color(0xFFF06B28),
      const Color(0xFFFFEBDD),
    ),
    'cholesterol' => (
      Icons.favorite_border_rounded,
      const Color(0xFF7141DB),
      const Color(0xFFF0E9FF),
    ),
    _ => (Icons.bolt_rounded, nutritionPurple, const Color(0xFFF0E9FF)),
  };
  return _MetricPresentation(
    icon: values.$1,
    color: values.$2,
    background: values.$3,
    status: status,
  );
}

List<NutritionSummaryMetric> _orderedMetrics(
  NutritionSummary summary,
  List<String> codes,
) {
  final byCode = <String, NutritionSummaryMetric>{
    for (final metric in summary.metrics) metric.code: metric,
  };
  return codes
      .map((code) => byCode[code])
      .whereType<NutritionSummaryMetric>()
      .toList(growable: false);
}
