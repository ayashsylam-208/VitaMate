import 'package:flutter/material.dart';

import '../models/micronutrient_tracking.dart';
import '../state/nutrition_controller.dart';
import '../widgets/nutrition_reference_ui.dart';
import '../widgets/nutrition_ui.dart';

class MicronutrientsScreen extends StatefulWidget {
  const MicronutrientsScreen({super.key, required this.controller});

  final NutritionController controller;

  @override
  State<MicronutrientsScreen> createState() => _MicronutrientsScreenState();
}

class _MicronutrientsScreenState extends State<MicronutrientsScreen> {
  String filter = 'all';
  bool expanded = false;
  bool loading = false;
  String? error;

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.controller.refreshMicronutrients();
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _chooseFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final entry in const <String, String>{
              'all': 'All',
              'vitamins': 'Vitamins',
              'minerals': 'Minerals',
              'low': 'Low',
              'high': 'High',
            }.entries)
              ListTile(
                leading: Icon(
                  filter == entry.key
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: nutritionPurple,
                ),
                title: Text(entry.value),
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        filter = selected;
        expanded = false;
      });
    }
  }

  List<MicronutrientItem> get _filtered {
    final items = widget.controller.micronutrients.items;
    return switch (filter) {
      'vitamins' => items.where((item) => item.category == 'vitamin').toList(),
      'minerals' => items.where((item) => item.category == 'mineral').toList(),
      'low' =>
        items.where((item) => _statusKind(item.status) == 'low').toList(),
      'high' =>
        items.where((item) => _statusKind(item.status) == 'high').toList(),
      _ => items,
    };
  }

  @override
  Widget build(BuildContext context) {
    final allItems = widget.controller.micronutrients.items;
    final items = _filtered;
    final good = allItems
        .where((item) => _statusKind(item.status) == 'good')
        .length;
    final low = allItems
        .where((item) => _statusKind(item.status) == 'low')
        .length;
    final high = allItems
        .where((item) => _statusKind(item.status) == 'high')
        .length;
    final visible = expanded ? items : items.take(7).toList(growable: false);
    return Scaffold(
      body: SafeArea(
        child: NutritionReferenceBackground(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: nutritionPagePadding,
              children: <Widget>[
                NutritionReferenceHeader(
                  title: 'Micronutrients',
                  compact: true,
                  trailing: NutritionRoundButton(
                    icon: Icons.info_outline_rounded,
                    filled: false,
                    tooltip: 'About micronutrients',
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('About this view'),
                        content: Text(
                          widget.controller.micronutrients.disclaimer.isEmpty
                              ? 'Intake and status are calculated by the VitaMate backend.'
                              : widget.controller.micronutrients.disclaimer,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const _OverviewHero(),
                const SizedBox(height: 14),
                _SummaryCard(good: good, low: low, high: high),
                const SizedBox(height: 14),
                NutritionReferenceCard(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Your Micronutrients',
                              style: TextStyle(
                                color: nutritionInk,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _chooseFilter,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'View by: ${_filterLabel(filter)}',
                                    style: const TextStyle(
                                      color: nutritionPurple,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: nutritionPurple,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      const _TableHeader(),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 34),
                          child: CircularProgressIndicator(),
                        )
                      else if (error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: NutritionErrorView(
                            message: error!,
                            onRetry: _refresh,
                          ),
                        )
                      else if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Text(
                            'No micronutrient data matches this view.',
                          ),
                        )
                      else
                        for (final item in visible)
                          _NutrientRow(
                            item: item,
                            onTap: () => showModalBottomSheet<void>(
                              context: context,
                              useSafeArea: true,
                              builder: (_) => _NutrientDetails(item: item),
                            ),
                          ),
                      if (items.length > 7)
                        TextButton.icon(
                          onPressed: () => setState(() => expanded = !expanded),
                          label: Text(expanded ? 'Show less' : 'View all'),
                          icon: Icon(
                            expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _BalanceTip(lowCount: low),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewHero extends StatelessWidget {
  const _OverviewHero();

  @override
  Widget build(BuildContext context) => NutritionReferenceCard(
    color: const Color(0xFFF4EFFF),
    child: Row(
      children: <Widget>[
        const NutritionIconBubble(
          icon: Icons.nature_outlined,
          color: Color(0xFF7549CF),
          background: Color(0xFFE5DAFF),
          size: 64,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Micronutrients Overview',
                  style: TextStyle(
                    color: Color(0xFF6338BE),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Track vitamins and minerals that support your health and daily wellbeing.',
                style: TextStyle(
                  color: nutritionInk,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.eco_outlined,
          color: const Color(0xFFB8A3ED).withValues(alpha: 0.35),
          size: 66,
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.good,
    required this.low,
    required this.high,
  });

  final int good;
  final int low;
  final int high;

  @override
  Widget build(BuildContext context) => NutritionReferenceCard(
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Summary',
          style: TextStyle(
            color: nutritionInk,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatusSummary(
                label: 'Good',
                detail: 'In target range',
                value: good,
                color: const Color(0xFF2CAD5B),
                icon: Icons.check_rounded,
              ),
            ),
            const SizedBox(
              height: 72,
              child: VerticalDivider(color: nutritionLine),
            ),
            Expanded(
              child: _StatusSummary(
                label: 'Low',
                detail: 'Below target',
                value: low,
                color: const Color(0xFFFF9800),
                icon: Icons.priority_high_rounded,
              ),
            ),
            const SizedBox(
              height: 72,
              child: VerticalDivider(color: nutritionLine),
            ),
            Expanded(
              child: _StatusSummary(
                label: 'High',
                detail: 'Above target',
                value: high,
                color: const Color(0xFFEF4E4E),
                icon: Icons.arrow_upward_rounded,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.label,
    required this.detail,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String detail;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: SizedBox.square(
              dimension: 23,
              child: Icon(icon, color: color, size: 15),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: const TextStyle(
          color: nutritionInk,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(
        detail,
        maxLines: 1,
        style: const TextStyle(color: nutritionMuted, fontSize: 10),
      ),
    ],
  );
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 7),
    child: Row(
      children: <Widget>[
        Expanded(
          flex: 4,
          child: Text(
            'Nutrient',
            style: TextStyle(
              color: nutritionMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'Intake',
            style: TextStyle(
              color: nutritionMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Goal',
            style: TextStyle(
              color: nutritionMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          width: 65,
          child: Text(
            'Status',
            style: TextStyle(
              color: nutritionMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: 14),
      ],
    ),
  );
}

class _NutrientRow extends StatelessWidget {
  const _NutrientRow({required this.item, required this.onTap});

  final MicronutrientItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusKind(item.status);
    final presentation = _nutrientPresentation(
      item.code,
      item.category,
      status,
    );
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: nutritionLine)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 4,
              child: Row(
                children: <Widget>[
                  NutritionIconBubble(
                    icon: presentation.icon,
                    color: Colors.white,
                    background: presentation.color,
                    size: 34,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: nutritionInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _nutrientKind(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: nutritionMuted,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${nutritionNumber(item.totalConsumed)} ${item.unit} (${item.progressPercent.round()}%)',
                    maxLines: 1,
                    style: const TextStyle(
                      color: nutritionInk,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: item.progressFraction,
                      minHeight: 5,
                      color: presentation.color,
                      backgroundColor: const Color(0xFFEAE7F0),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${nutritionNumber(item.targetValue)} ${item.unit}',
                textAlign: TextAlign.center,
                maxLines: 1,
                style: const TextStyle(
                  color: nutritionInk,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 65,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: NutritionStatusBadge(status: status),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFA49CAF),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientPresentation {
  const _NutrientPresentation(this.icon, this.color);
  final IconData icon;
  final Color color;
}

_NutrientPresentation _nutrientPresentation(
  String code,
  String category,
  String status,
) {
  final color = status == 'good'
      ? const Color(0xFF43BE68)
      : status == 'high'
      ? const Color(0xFFEF5D5D)
      : const Color(0xFFFFA046);
  final icon = switch (code.toLowerCase()) {
    'vitamin_d' => Icons.wb_sunny_outlined,
    'vitamin_c' => Icons.shield_outlined,
    'calcium' => Icons.fitness_center_rounded,
    'iron' || 'vitamin_b12' => Icons.water_drop_rounded,
    'magnesium' => Icons.bolt_rounded,
    'zinc' => Icons.view_in_ar_outlined,
    _ =>
      category == 'vitamin'
          ? Icons.local_florist_outlined
          : Icons.hexagon_outlined,
  };
  return _NutrientPresentation(icon, color);
}

class _BalanceTip extends StatelessWidget {
  const _BalanceTip({required this.lowCount});
  final int lowCount;

  @override
  Widget build(BuildContext context) => NutritionReferenceCard(
    color: const Color(0xFFF5F0FF),
    child: Row(
      children: <Widget>[
        const NutritionIconBubble(
          icon: Icons.lightbulb_outline_rounded,
          color: nutritionPurple,
          background: Color(0xFFE8DEFF),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Keep it balanced!',
                style: TextStyle(
                  color: nutritionInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                lowCount > 0
                    ? 'Focus on nutrients that are low to support your overall health.'
                    : 'Keep following your current balanced nutrition pattern.',
                style: const TextStyle(
                  color: nutritionInk,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NutrientDetails extends StatelessWidget {
  const _NutrientDetails({required this.item});
  final MicronutrientItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.name,
          style: const TextStyle(
            color: nutritionInk,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(item.consumedLabel),
        Text(item.foodLabel),
        if (item.supplementConsumed > 0) Text(item.supplementLabel),
        if (item.sourceLabel.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(item.sourceLabel, style: const TextStyle(color: nutritionMuted)),
        ],
        if (item.note.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(item.note),
        ],
      ],
    ),
  );
}

String _statusKind(String status) => switch (status) {
  'over_limit' || 'high' => 'high',
  'met' || 'good' => 'good',
  _ => 'low',
};

String _filterLabel(String value) => switch (value) {
  'vitamins' => 'Vitamins',
  'minerals' => 'Minerals',
  'low' => 'Low',
  'high' => 'High',
  _ => 'All',
};

String _nutrientKind(MicronutrientItem item) {
  if (item.category == 'mineral') return 'Mineral';
  const fatSoluble = <String>{
    'vitamin_a',
    'vitamin_d',
    'vitamin_e',
    'vitamin_k',
  };
  return fatSoluble.contains(item.code.toLowerCase())
      ? 'Fat-soluble vitamin'
      : 'Water-soluble vitamin';
}
