import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/water_log.dart';
import '../state/water_controller.dart';

class LogDrinkScreen extends StatefulWidget {
  const LogDrinkScreen({
    super.key,
    this.controller,
    this.preselectedType = 'water',
    this.preselectedAmountMl = 250,
    this.existingLog,
  });

  final WaterController? controller;
  final String preselectedType;
  final int preselectedAmountMl;
  final WaterLog? existingLog;

  @override
  State<LogDrinkScreen> createState() => _LogDrinkScreenState();
}

class _LogDrinkScreenState extends State<LogDrinkScreen> {
  late final WaterController controller;
  late final bool _ownsController;
  late final TextEditingController _amountController;
  late final TextEditingController _nameController;
  late final TextEditingController _caffeineController;
  late String _type;
  late DateTime _consumedAt;
  bool _saving = false;

  bool get _isEditing => widget.existingLog != null;
  bool get _needsName => _type == 'other';
  bool get _supportsCaffeine => _type == 'coffee' || _type == 'tea';
  int get _amountMl => int.tryParse(_amountController.text.trim()) ?? 0;
  double? get _caffeineMg {
    if (!_supportsCaffeine) return null;
    final raw = _caffeineController.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? WaterController();
    _ownsController = widget.controller == null;
    final log = widget.existingLog;
    _type = _normalizeType(log?.beverageType ?? widget.preselectedType);
    _consumedAt = log?.consumedAt ?? DateTime.now();
    _amountController = TextEditingController(
      text: (log?.amountMl ?? widget.preselectedAmountMl).toString(),
    );
    _nameController = TextEditingController(
      text: log?.beverageName == 'Water' ? '' : log?.beverageName ?? '',
    );
    _caffeineController = TextEditingController(text: _initialCaffeine(log));
    _amountController.addListener(_refresh);
    _nameController.addListener(_refresh);
    _caffeineController.addListener(_refresh);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _caffeineController.dispose();
    if (_ownsController) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _isValid;
    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            _TopBar(
              title: _isEditing ? 'Edit Drink' : 'Log Drink',
              onDelete: _isEditing ? _delete : null,
            ),
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Drink type'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in _drinkTypes)
                        _TypeChip(
                          selected: _type == type.key,
                          label: type.label,
                          icon: type.icon,
                          onTap: () => setState(() => _type = type.key),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Amount'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final amount in const [150, 250, 330, 500])
                        ChoiceChip(
                          selected: _amountMl == amount,
                          label: Text('$amount ml'),
                          onSelected: (_) => setState(
                            () => _amountController.text = '$amount',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => _changeAmount(-50),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Custom amount',
                            suffixText: 'ml',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () => _changeAmount(50),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Time'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(_dateLabel(_consumedAt)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(_timeLabel(_consumedAt)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_needsName || _supportsCaffeine) ...[
              const SizedBox(height: 14),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Optional details'),
                    if (_needsName) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Custom name',
                          hintText: 'Example: electrolyte drink',
                        ),
                      ),
                    ],
                    if (_supportsCaffeine) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _caffeineController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Caffeine',
                          suffixText: 'mg',
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Hydration contribution is calculated by the backend after save.',
                      style: TextStyle(
                        color: VitaMateTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: valid && !_saving ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEditing ? 'Save changes' : 'Save Drink'),
            ),
            if (controller.error != null) ...[
              const SizedBox(height: 12),
              Text(
                controller.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VitaMateTheme.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _isValid {
    if (_amountMl <= 0 || _amountMl > 5000) return false;
    if (_needsName && _nameController.text.trim().isEmpty) return false;
    if (_supportsCaffeine && _caffeineController.text.trim().isNotEmpty) {
      return _caffeineMg != null && _caffeineMg! >= 0 && _caffeineMg! <= 800;
    }
    return !_consumedAt.isAfter(DateTime.now().add(const Duration(minutes: 5)));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final log = widget.existingLog;
    final name = _displayNameForType(_type, _nameController.text);
    final saved = log == null
        ? await controller.addNamedBeverage(
            amountMl: _amountMl,
            beverageType: _type,
            beverageName: name,
            consumedAt: _consumedAt,
            caffeineMg: _caffeineMg,
          )
        : await controller.updateDrink(
            id: log.id,
            amountMl: _amountMl,
            beverageType: _type,
            beverageName: name,
            consumedAt: _consumedAt,
            caffeineMg: _caffeineMg,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(controller.error ?? 'Could not save drink.')),
    );
  }

  Future<void> _delete() async {
    final log = widget.existingLog;
    if (log == null) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => _DeleteSheet(log: log),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    final deleted = await controller.deleteDrink(log.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (deleted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _consumedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 366)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _consumedAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _consumedAt.hour,
        _consumedAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_consumedAt),
    );
    if (picked == null) return;
    setState(() {
      _consumedAt = DateTime(
        _consumedAt.year,
        _consumedAt.month,
        _consumedAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _changeAmount(int delta) {
    final next = (_amountMl + delta).clamp(0, 5000);
    setState(() => _amountController.text = next.toString());
  }

  void _refresh() => setState(() {});
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.onDelete});

  final String title;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: onDelete,
          icon: Icon(
            Icons.delete_outline_rounded,
            color: onDelete == null
                ? VitaMateTheme.borderStrong
                : VitaMateTheme.danger,
          ),
        ),
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
      width: double.infinity,
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
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: VitaMateTheme.primaryDeep,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      avatar: Icon(
        icon,
        color: selected ? Colors.white : VitaMateTheme.primary,
        size: 18,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.white : VitaMateTheme.primaryDeep,
        fontWeight: FontWeight.w900,
      ),
      selectedColor: VitaMateTheme.primary,
      onSelected: (_) => onTap(),
    );
  }
}

class _DeleteSheet extends StatelessWidget {
  const _DeleteSheet({required this.log});

  final WaterLog log;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delete drink?',
              style: TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${log.displayName} - ${log.amountMl} ml',
              style: const TextStyle(
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
                    style: FilledButton.styleFrom(
                      backgroundColor: VitaMateTheme.danger,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DrinkTypeData {
  const _DrinkTypeData(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

const _drinkTypes = [
  _DrinkTypeData('water', 'Water', Icons.water_drop_rounded),
  _DrinkTypeData('coffee', 'Coffee', Icons.local_cafe_rounded),
  _DrinkTypeData('tea', 'Tea', Icons.emoji_food_beverage_rounded),
  _DrinkTypeData('juice', 'Juice', Icons.local_bar_rounded),
  _DrinkTypeData('milk', 'Milk', Icons.local_drink_rounded),
  _DrinkTypeData('soda', 'Soda', Icons.bubble_chart_rounded),
  _DrinkTypeData('other', 'Other', Icons.edit_note_rounded),
];

String _normalizeType(String value) {
  final type = value.toLowerCase().trim();
  return _drinkTypes.any((item) => item.key == type) ? type : 'other';
}

String _displayNameForType(String type, String custom) {
  final trimmed = custom.trim();
  if (trimmed.isNotEmpty) return trimmed;
  for (final item in _drinkTypes) {
    if (item.key == type) return item.label;
  }
  return 'Drink';
}

String _initialCaffeine(WaterLog? log) {
  final caffeine = log?.nutritionPreview?.caffeine ?? 0;
  if (caffeine <= 0) return '';
  return caffeine.round().toString();
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
