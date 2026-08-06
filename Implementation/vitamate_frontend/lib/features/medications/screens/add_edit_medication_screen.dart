import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../../../core/time/local_timezone.dart';
import '../models/medication_item.dart';
import '../state/medications_controller.dart';
import '../widgets/medication_ui.dart';

class AddEditMedicationScreen extends StatefulWidget {
  const AddEditMedicationScreen({
    super.key,
    required this.controller,
    this.medication,
    this.sourceType = 'manual',
    this.linkedConditionId,
    this.linkedConditionName,
  });

  final MedicationsController controller;
  final MedicationItem? medication;
  final String sourceType;
  final int? linkedConditionId;
  final String? linkedConditionName;

  @override
  State<AddEditMedicationScreen> createState() =>
      _AddEditMedicationScreenState();
}

class _AddEditMedicationScreenState extends State<AddEditMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _strength;
  late final TextEditingController _instructions;
  late final TextEditingController _intervalHours;
  late final TextEditingController _timezone;
  late DateTime _startDate;
  final List<TimeOfDay> _times = [];
  final Set<int> _daysOfWeek = <int>{};
  String _form = 'tablet';
  String _mealRelation = 'none';
  String _scheduleType = 'daily';

  bool get _isPrn => _scheduleType == 'as_needed';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    final med = widget.medication;
    _name = TextEditingController(text: med?.displayName ?? '');
    _strength = TextEditingController(text: _strengthLabel(med));
    _instructions = TextEditingController(text: med?.instructions ?? '');
    _intervalHours = TextEditingController(text: '8');
    _timezone = TextEditingController(
      text: med?.timezone.isNotEmpty == true
          ? med!.timezone
          : LocalTimezone.ianaName,
    );
    _startDate = med?.startDate ?? DateTime.now();
    _form = _normalizeForm(med?.form);
    _mealRelation = med != null && med.schedules.isNotEmpty
        ? med.schedules.first.mealRelation
        : 'none';
    _scheduleType = med != null && med.isPrn
        ? 'as_needed'
        : med != null && med.schedules.isNotEmpty
        ? med.schedules.first.scheduleType
        : 'daily';
    if (med != null && med.schedules.isNotEmpty) {
      final first = med.schedules.first;
      _daysOfWeek.addAll(first.daysOfWeek);
      if (first.intervalHours != null) {
        _intervalHours.text = first.intervalHours.toString();
      }
    }
    for (final schedule in med?.schedules ?? const []) {
      final time = _parseTime(schedule.time);
      if (time != null) _times.add(time);
    }
    if (_times.isEmpty) {
      _times.add(const TimeOfDay(hour: 8, minute: 0));
      if (_scheduleType == 'daily') {
        _times.add(const TimeOfDay(hour: 20, minute: 0));
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _name.dispose();
    _strength.dispose();
    _instructions.dispose();
    _intervalHours.dispose();
    _timezone.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times.isEmpty
          ? const TimeOfDay(hour: 8, minute: 0)
          : _times.last,
    );
    if (picked != null && !_times.contains(picked)) {
      setState(() => _times.add(picked));
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isPrn && _times.isEmpty) {
      _showMessage('Add at least one reminder time.');
      return;
    }
    if (_scheduleType == 'specific_days' && _daysOfWeek.isEmpty) {
      _showMessage('Select at least one day.');
      return;
    }
    final intervalHours = int.tryParse(_intervalHours.text.trim());
    if (_scheduleType == 'interval' && intervalHours == null) {
      _showMessage('Enter a valid interval in hours.');
      return;
    }
    final strength = _parseStrength(_strength.text);
    final sourceType = widget.medication?.sourceType ?? widget.sourceType;
    final payload = {
      'display_name': _name.text.trim(),
      'source_type': sourceType,
      if (sourceType == 'condition')
        'user_condition_id':
            widget.medication?.linkedConditionId ?? widget.linkedConditionId,
      'dose_amount': strength.amount,
      'dose_unit': strength.unit,
      'form': _form,
      'instructions': _instructions.text.trim(),
      'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
      'timezone': _timezone.text.trim().isEmpty
          ? LocalTimezone.ianaName
          : _timezone.text.trim(),
      'is_prn': _isPrn,
      'schedules': _isPrn ? [] : _schedulePayloads(intervalHours),
    };
    final ok = widget.medication == null
        ? await widget.controller.createMedication(payload)
        : await widget.controller.updateMedication(
            widget.medication!.id,
            payload,
          );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  List<Map<String, dynamic>> _schedulePayloads(int? intervalHours) {
    final sortedTimes = [..._times]..sort(_compareTimes);
    return sortedTimes
        .map(
          (time) => {
            'schedule_type': _scheduleType,
            'time': _formatTime(time),
            if (_scheduleType == 'specific_days')
              'days_of_week': _daysOfWeek.toList()..sort(),
            if (_scheduleType == 'interval') 'interval_hours': intervalHours,
            'meal_relation': _mealRelation,
            'grace_period_minutes': 60,
            'snooze_default_minutes': 15,
          },
        )
        .toList(growable: false);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final linkedName =
        widget.medication?.linkedConditionName ?? widget.linkedConditionName;
    return Scaffold(
      key: const ValueKey(AppTestKeys.medicationsAddScreen),
      backgroundColor: MedicationUi.background,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.medication == null ? 'Add medication' : 'Edit medication',
        ),
        actions: [
          IconButton(
            key: const ValueKey(AppTestKeys.medicationsSaveButton),
            onPressed: widget.controller.state.isSaving ? null : _save,
            icon: widget.controller.state.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
            children: [
              if (linkedName != null) ...[
                _LinkedConditionBanner(name: linkedName),
                const SizedBox(height: 12),
              ],
              _MedicationInput(
                controller: _name,
                label: 'Medication name *',
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MedicationInput(
                      controller: _strength,
                      label: 'Strength & form *',
                      suffixIcon: Icons.keyboard_arrow_down_rounded,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FormDropdown(
                      value: _form,
                      onChanged: (value) => setState(() => _form = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MedicationInput(
                controller: _instructions,
                label: 'Instructions (optional)',
                minLines: 1,
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              _MealRelationDropdown(
                value: _mealRelation,
                onChanged: (value) => setState(() => _mealRelation = value),
              ),
              const SizedBox(height: 14),
              _SchedulePanel(
                selectedType: _scheduleType,
                onSelected: (value) => setState(() => _scheduleType = value),
                times: _times,
                daysOfWeek: _daysOfWeek,
                intervalHours: _intervalHours,
                onAddTime: _addTime,
                onRemoveTime: (time) => setState(() => _times.remove(time)),
                onToggleDay: (day) {
                  setState(() {
                    if (!_daysOfWeek.add(day)) {
                      _daysOfWeek.remove(day);
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              _DatePickerField(date: _startDate, onTap: _pickStartDate),
              const SizedBox(height: 10),
              _MedicationInput(
                controller: _timezone,
                label: 'Time zone',
                suffixIcon: Icons.keyboard_arrow_down_rounded,
              ),
              if (widget.controller.state.errorMessage != null) ...[
                const SizedBox(height: 14),
                _ErrorCard(text: widget.controller.state.errorMessage!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicationInput extends StatelessWidget {
  const _MedicationInput({
    required this.controller,
    required this.label,
    this.validator,
    this.suffixIcon,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final IconData? suffixIcon;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
        color: VitaMateTheme.primaryDeep,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon == null ? null : Icon(suffixIcon, size: 20),
        filled: true,
        fillColor: MedicationUi.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: VitaMateTheme.border),
        ),
      ),
    );
  }
}

class _FormDropdown extends StatelessWidget {
  const _FormDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = <String>{
      'tablet',
      'capsule',
      'softgel',
      'drops',
      'injection',
    };
    values.add(value);
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: values
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(_capitalize(item)),
            ),
          )
          .toList(),
      onChanged: (value) => onChanged(value ?? 'tablet'),
      decoration: const InputDecoration(labelText: 'Form'),
      style: const TextStyle(
        color: VitaMateTheme.primaryDeep,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MealRelationDropdown extends StatelessWidget {
  const _MealRelationDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = {
      'none': 'With or without food',
      'before_meal': 'Before meal',
      'after_meal': 'After meal',
      'with_food': 'With food',
    };
    return DropdownButtonFormField<String>(
      initialValue: items.containsKey(value) ? value : 'none',
      items: items.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: (value) => onChanged(value ?? 'none'),
      decoration: const InputDecoration(
        labelText: 'Meal relation',
        prefixIcon: Icon(Icons.restaurant_menu_rounded),
      ),
      style: const TextStyle(
        color: VitaMateTheme.primaryDeep,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({
    required this.selectedType,
    required this.onSelected,
    required this.times,
    required this.daysOfWeek,
    required this.intervalHours,
    required this.onAddTime,
    required this.onRemoveTime,
    required this.onToggleDay,
  });

  final String selectedType;
  final ValueChanged<String> onSelected;
  final List<TimeOfDay> times;
  final Set<int> daysOfWeek;
  final TextEditingController intervalHours;
  final VoidCallback onAddTime;
  final ValueChanged<TimeOfDay> onRemoveTime;
  final ValueChanged<int> onToggleDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: MedicationUi.panelTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schedule type',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'How do you take this medication?',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final type in const [
                  'daily',
                  'specific_days',
                  'interval',
                  'as_needed',
                ]) ...[
                  _ScheduleTypeOption(
                    type: type,
                    selected: selectedType == type,
                    onTap: () => onSelected(type),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ScheduleDetails(
            selectedType: selectedType,
            times: times,
            daysOfWeek: daysOfWeek,
            intervalHours: intervalHours,
            onAddTime: onAddTime,
            onRemoveTime: onRemoveTime,
            onToggleDay: onToggleDay,
          ),
        ],
      ),
    );
  }
}

class _ScheduleTypeOption extends StatelessWidget {
  const _ScheduleTypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final String type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = MedicationUi.scheduleTypeColor(type);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? VitaMateTheme.primary : VitaMateTheme.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  MedicationUi.scheduleTypeIcon(type),
                  color: color,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  MedicationUi.scheduleTypeTitle(type),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  MedicationUi.scheduleTypeSubtitle(type),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ],
            ),
            if (selected)
              const Positioned(
                right: -12,
                bottom: -12,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: VitaMateTheme.primary,
                  size: 34,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleDetails extends StatelessWidget {
  const _ScheduleDetails({
    required this.selectedType,
    required this.times,
    required this.daysOfWeek,
    required this.intervalHours,
    required this.onAddTime,
    required this.onRemoveTime,
    required this.onToggleDay,
  });

  final String selectedType;
  final List<TimeOfDay> times;
  final Set<int> daysOfWeek;
  final TextEditingController intervalHours;
  final VoidCallback onAddTime;
  final ValueChanged<TimeOfDay> onRemoveTime;
  final ValueChanged<int> onToggleDay;

  @override
  Widget build(BuildContext context) {
    if (selectedType == 'as_needed') {
      return const MedicationSurfaceCard(
        padding: EdgeInsets.all(14),
        radius: 14,
        child: Text(
          'Log this medication only when you take it. No fixed pending doses are generated.',
          style: TextStyle(
            color: VitaMateTheme.textMuted,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedType == 'specific_days') ...[
          const Text(
            'Days of week',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _WeekdayPicker(selectedDays: daysOfWeek, onToggle: onToggleDay),
          const SizedBox(height: 16),
        ],
        if (selectedType == 'interval') ...[
          _MedicationInput(
            controller: intervalHours,
            label: 'Every N hours',
            suffixIcon: Icons.schedule_rounded,
            validator: (value) =>
                int.tryParse(value?.trim() ?? '') == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                selectedType == 'interval' ? 'Anchor time' : 'Daily times',
                style: const TextStyle(
                  color: VitaMateTheme.primaryDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onAddTime,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add time'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final time in times)
              _TimeChip(
                time: time,
                canRemove: times.length > 1,
                onRemove: () => onRemoveTime(time),
              ),
          ],
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.time,
    required this.canRemove,
    required this.onRemove,
  });

  final TimeOfDay time;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(time),
            style: const TextStyle(
              color: VitaMateTheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (canRemove) ...[
            const SizedBox(width: 9),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(99),
              child: const Icon(
                Icons.close_rounded,
                color: VitaMateTheme.primaryDeep,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selectedDays, required this.onToggle});

  final Set<int> selectedDays;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var day = 0; day < labels.length; day++)
          FilterChip(
            selected: selectedDays.contains(day),
            label: Text(labels[day]),
            onSelected: (_) => onToggle(day),
          ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: MedicationSurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        radius: 10,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start date',
                    style: TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    MedicationUi.compactDate(date),
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.calendar_month_outlined,
              color: VitaMateTheme.primaryDeep,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedConditionBanner extends StatelessWidget {
  const _LinkedConditionBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return MedicationSurfaceCard(
      padding: const EdgeInsets.all(14),
      radius: 14,
      color: MedicationUi.primarySoft,
      child: Text(
        'Linked to $name',
        style: const TextStyle(
          color: VitaMateTheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaMateTheme.danger.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: VitaMateTheme.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _strengthLabel(MedicationItem? medication) {
  if (medication == null) return '';
  final direct = [
    medication.doseAmount,
    medication.doseUnit,
  ].where((item) => item.trim().isNotEmpty).join(' ');
  return direct.isNotEmpty ? direct : medication.dosage;
}

String _normalizeForm(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return normalized.isEmpty ? 'tablet' : normalized;
}

TimeOfDay? _parseTime(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTime(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

int _compareTimes(TimeOfDay a, TimeOfDay b) {
  final aValue = a.hour * 60 + a.minute;
  final bValue = b.hour * 60 + b.minute;
  return aValue.compareTo(bValue);
}

_ParsedStrength _parseStrength(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return const _ParsedStrength('', '');
  if (parts.length == 1) return _ParsedStrength(parts.first, '');
  return _ParsedStrength(parts.first, parts.sublist(1).join(' '));
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

class _ParsedStrength {
  const _ParsedStrength(this.amount, this.unit);

  final String amount;
  final String unit;
}
