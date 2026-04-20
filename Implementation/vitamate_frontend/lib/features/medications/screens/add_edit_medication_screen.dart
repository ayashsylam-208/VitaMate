import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/medication_item.dart';
import '../state/medications_controller.dart';

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
  late final TextEditingController _amount;
  late final TextEditingController _unit;
  late final TextEditingController _form;
  late final TextEditingController _instructions;
  final List<TimeOfDay> _times = [];
  bool _isPrn = false;
  String _mealRelation = 'none';

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    _name = TextEditingController(text: med?.displayName ?? '');
    _amount = TextEditingController(text: med?.doseAmount ?? '');
    _unit = TextEditingController(text: med?.doseUnit ?? 'mg');
    _form = TextEditingController(text: med?.form ?? 'tablet');
    _instructions = TextEditingController(text: med?.instructions ?? '');
    _isPrn = med?.isPrn ?? false;
    _mealRelation = med != null && med.schedules.isNotEmpty
        ? med.schedules.first.mealRelation
        : 'none';
    for (final schedule in med?.schedules ?? const []) {
      final parts = schedule.time.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          _times.add(TimeOfDay(hour: hour, minute: minute));
        }
      }
    }
    if (_times.isEmpty) {
      _times.add(const TimeOfDay(hour: 8, minute: 0));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _unit.dispose();
    _form.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );
    if (picked != null) {
      setState(() => _times.add(picked));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isPrn && _times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one reminder time.')),
      );
      return;
    }
    final sourceType = widget.medication?.sourceType ?? widget.sourceType;
    final payload = {
      'display_name': _name.text.trim(),
      'source_type': sourceType,
      if (sourceType == 'condition')
        'user_condition_id':
            widget.medication?.linkedConditionId ?? widget.linkedConditionId,
      'dose_amount': _amount.text.trim(),
      'dose_unit': _unit.text.trim(),
      'form': _form.text.trim(),
      'instructions': _instructions.text.trim(),
      'start_date': DateTime.now().toIso8601String().substring(0, 10),
      'timezone': DateTime.now().timeZoneName,
      'is_prn': _isPrn,
      'schedules': _isPrn
          ? []
          : _times
                .map(
                  (time) => {
                    'schedule_type': 'daily',
                    'time':
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    'meal_relation': _mealRelation,
                    'grace_period_minutes': 60,
                    'snooze_default_minutes': 15,
                  },
                )
                .toList(),
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

  @override
  Widget build(BuildContext context) {
    final linkedName =
        widget.medication?.linkedConditionName ?? widget.linkedConditionName;
    return Scaffold(
      backgroundColor: VitaMateTheme.background,
      appBar: AppBar(
        title: Text(
          widget.medication == null ? 'Add medication' : 'Edit medication',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (linkedName != null) ...[
                _LinkedConditionBanner(name: linkedName),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Medication name'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amount,
                      decoration: const InputDecoration(labelText: 'Dose'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _form,
                decoration: const InputDecoration(labelText: 'Form'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructions,
                decoration: const InputDecoration(labelText: 'Instructions'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isPrn,
                onChanged: (value) => setState(() => _isPrn = value),
                title: const Text('As needed medication'),
                subtitle: const Text(
                  'No fixed pending doses will be generated.',
                ),
              ),
              if (!_isPrn) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _mealRelation,
                  decoration: const InputDecoration(labelText: 'Meal relation'),
                  items: const [
                    DropdownMenuItem(
                      value: 'none',
                      child: Text('No meal relation'),
                    ),
                    DropdownMenuItem(
                      value: 'before_meal',
                      child: Text('Before meal'),
                    ),
                    DropdownMenuItem(
                      value: 'after_meal',
                      child: Text('After meal'),
                    ),
                    DropdownMenuItem(
                      value: 'with_food',
                      child: Text('With food'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _mealRelation = value ?? 'none'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Reminder times',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addTime,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add time'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final time in _times)
                      InputChip(
                        label: Text(time.format(context)),
                        onDeleted: _times.length == 1
                            ? null
                            : () => setState(() => _times.remove(time)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: widget.controller.state.isSaving ? null : _save,
                child: Text(
                  widget.controller.state.isSaving
                      ? 'Saving...'
                      : 'Save medication',
                ),
              ),
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(8),
      ),
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
