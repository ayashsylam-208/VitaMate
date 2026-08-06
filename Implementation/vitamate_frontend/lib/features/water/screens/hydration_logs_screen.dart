import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/water_log.dart';
import '../state/water_controller.dart';
import 'log_drink_screen.dart';

class HydrationLogsScreen extends StatefulWidget {
  const HydrationLogsScreen({super.key, this.controller});

  final WaterController? controller;

  @override
  State<HydrationLogsScreen> createState() => _HydrationLogsScreenState();
}

class _HydrationLogsScreenState extends State<HydrationLogsScreen> {
  late final WaterController controller;
  late final bool _ownsController;
  int _tab = 0;
  DateTime _dailyDate = DateTime.now();
  late DateTime _weekStart;
  List<WaterLog> _logs = const [];
  bool _loading = true;
  bool _changed = false;
  String? _error;
  int _allVisibleCount = 30;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? WaterController();
    _ownsController = widget.controller == null;
    _weekStart = _startOfWeek(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    if (_ownsController) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: _tab,
      child: Scaffold(
        backgroundColor: VitaMateTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(changed: _changed),
              TabBar(
                onTap: (index) {
                  setState(() => _tab = index);
                  _load();
                },
                labelColor: VitaMateTheme.primary,
                unselectedLabelColor: VitaMateTheme.textMuted,
                indicatorColor: VitaMateTheme.primary,
                tabs: const [
                  Tab(text: 'Daily'),
                  Tab(text: 'Weekly'),
                  Tab(text: 'All'),
                ],
              ),
              Expanded(
                child: RefreshIndicator(onRefresh: _load, child: _body()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }
    switch (_tab) {
      case 1:
        return _WeeklyLogsView(
          weekStart: _weekStart,
          logs: _logs,
          onPrevious: () {
            setState(
              () => _weekStart = _weekStart.subtract(const Duration(days: 7)),
            );
            _load();
          },
          onNext: () {
            setState(
              () => _weekStart = _weekStart.add(const Duration(days: 7)),
            );
            _load();
          },
          onEdit: _editLog,
        );
      case 2:
        return _AllLogsView(
          logs: _logs.take(_allVisibleCount).toList(growable: false),
          hasMore: _logs.length > _allVisibleCount,
          onLoadMore: () => setState(() => _allVisibleCount += 30),
          onEdit: _editLog,
        );
      default:
        return _DailyLogsView(
          date: _dailyDate,
          logs: _logs,
          onPickDate: _pickDailyDate,
          onEdit: _editLog,
        );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = switch (_tab) {
        1 => await controller.logsFor(
          from: _weekStart,
          to: _weekStart.add(const Duration(days: 7)),
        ),
        2 => await controller.logsFor(),
        _ => await controller.logsFor(date: _dailyDate),
      };
      if (!mounted) return;
      setState(() => _logs = next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load hydration logs.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDailyDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dailyDate,
      firstDate: DateTime.now().subtract(const Duration(days: 366)),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _dailyDate = picked);
    await _load();
  }

  Future<void> _editLog(WaterLog log) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LogDrinkScreen(controller: controller, existingLog: log),
      ),
    );
    if (changed == true) {
      _changed = true;
      await _load();
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.changed});

  final bool changed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context, changed),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          const Expanded(
            child: Text(
              'Hydration Log',
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
      ),
    );
  }
}

class _DailyLogsView extends StatelessWidget {
  const _DailyLogsView({
    required this.date,
    required this.logs,
    required this.onPickDate,
    required this.onEdit,
  });

  final DateTime date;
  final List<WaterLog> logs;
  final VoidCallback onPickDate;
  final ValueChanged<WaterLog> onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _SummaryCard(
          title: _dateLabel(date),
          subtitle: '${logs.length} entries',
          totalHydrationMl: _totalHydration(logs),
          onTap: onPickDate,
          actionLabel: 'Change date',
        ),
        const SizedBox(height: 14),
        if (logs.isEmpty)
          const _EmptyState(text: 'No drinks logged for this day.')
        else
          for (final log in logs) _LogTile(log: log, onTap: () => onEdit(log)),
      ],
    );
  }
}

class _WeeklyLogsView extends StatelessWidget {
  const _WeeklyLogsView({
    required this.weekStart,
    required this.logs,
    required this.onPrevious,
    required this.onNext,
    required this.onEdit,
  });

  final DateTime weekStart;
  final List<WaterLog> logs;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<WaterLog> onEdit;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay(logs);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _WeekSelector(
          start: weekStart,
          end: weekStart.add(const Duration(days: 6)),
          onPrevious: onPrevious,
          onNext: onNext,
        ),
        const SizedBox(height: 14),
        if (grouped.isEmpty)
          const _EmptyState(text: 'No drinks logged this week.')
        else
          for (final entry in grouped.entries)
            _DayGroupCard(label: entry.key, logs: entry.value, onEdit: onEdit),
      ],
    );
  }
}

class _AllLogsView extends StatelessWidget {
  const _AllLogsView({
    required this.logs,
    required this.hasMore,
    required this.onLoadMore,
    required this.onEdit,
  });

  final List<WaterLog> logs;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final ValueChanged<WaterLog> onEdit;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay(logs);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (logs.isEmpty)
          const _EmptyState(text: 'No hydration history yet.')
        else
          for (final entry in grouped.entries)
            _DayGroupCard(label: entry.key, logs: entry.value, onEdit: onEdit),
        if (hasMore) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onLoadMore, child: const Text('Load more')),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.totalHydrationMl,
    required this.onTap,
    required this.actionLabel,
  });

  final String title;
  final String subtitle;
  final int totalHydrationMl;
  final VoidCallback onTap;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
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
                const SizedBox(height: 4),
                Text(
                  '$subtitle - ${_ml(totalHydrationMl)} hydration',
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({
    required this.start,
    required this.end,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime start;
  final DateTime end;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              '${_dateLabel(start)} - ${_dateLabel(end)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _DayGroupCard extends StatelessWidget {
  const _DayGroupCard({
    required this.label,
    required this.logs,
    required this.onEdit,
  });

  final String label;
  final List<WaterLog> logs;
  final ValueChanged<WaterLog> onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          label,
          style: const TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          '${logs.length} entries - ${_ml(_totalHydration(logs))} hydration',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        children: [
          for (final log in logs) _LogTile(log: log, onTap: () => onEdit(log)),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log, required this.onTap});

  final WaterLog log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = log.nutritionPreview;
    final badges = <String>[
      if (preview != null && preview.caffeine > 0)
        '${preview.caffeine.round()} mg caffeine',
      if (preview != null && preview.calories > 0)
        '${preview.calories.round()} kcal',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE9FAFF),
          child: Icon(
            _drinkIcon(log.beverageType),
            color: const Color(0xFF13A7C7),
          ),
        ),
        title: Text(
          log.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          [
            '${_ml(log.amountMl)} at ${_timeLabel(log.consumedAt)}',
            if (log.hydrationMl != log.amountMl)
              '${_ml(log.hydrationMl)} hydration',
            ...badges,
          ].join(' - '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.edit_rounded, size: 18),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.water_drop_outlined,
            color: VitaMateTheme.primary,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, List<WaterLog>> _groupByDay(List<WaterLog> logs) {
  final grouped = <String, List<WaterLog>>{};
  for (final log in logs) {
    grouped
        .putIfAbsent(_dateLabel(log.consumedAt), () => <WaterLog>[])
        .add(log);
  }
  return grouped;
}

DateTime _startOfWeek(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  return local.subtract(Duration(days: local.weekday - 1));
}

int _totalHydration(List<WaterLog> logs) {
  return logs.fold<int>(0, (sum, log) => sum + log.hydrationMl);
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
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
  );
}

IconData _drinkIcon(String type) {
  switch (type) {
    case 'coffee':
      return Icons.local_cafe_rounded;
    case 'tea':
      return Icons.emoji_food_beverage_rounded;
    case 'juice':
      return Icons.local_bar_rounded;
    case 'milk':
      return Icons.local_drink_rounded;
    case 'soda':
      return Icons.bubble_chart_rounded;
    default:
      return Icons.water_drop_rounded;
  }
}

String _ml(int value) => '$value ml';

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
