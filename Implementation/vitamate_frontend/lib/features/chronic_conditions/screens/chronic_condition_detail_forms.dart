part of 'chronic_condition_detail_screen.dart';

class _EditConditionDraft {
  final String severityCode;
  final String status;
  final DateTime? diagnosisDate;
  final String notes;
  final Map<String, dynamic> profileData;
  final List<ConditionTargetOverridePayload> targetOverrides;

  const _EditConditionDraft({
    required this.severityCode,
    required this.status,
    required this.diagnosisDate,
    required this.notes,
    required this.profileData,
    required this.targetOverrides,
  });
}

class _EditConditionSheet extends StatefulWidget {
  const _EditConditionSheet({required this.item});

  final ChronicCondition item;

  @override
  State<_EditConditionSheet> createState() => _EditConditionSheetState();
}

class _EditConditionSheetState extends State<_EditConditionSheet> {
  late String severityCode;
  late String status;
  DateTime? diagnosisDate;
  late final TextEditingController notesController;
  late final TextEditingController glucoseController;
  late final TextEditingController hba1cController;
  late final TextEditingController sodiumController;
  late final TextEditingController systolicController;
  late final TextEditingController diastolicController;
  late final TextEditingController hdlController;
  late final TextEditingController triglyceridesController;
  late final TextEditingController followupController;

  @override
  void initState() {
    super.initState();
    final profile = widget.item.profileData;
    severityCode = widget.item.severityCode;
    status = widget.item.status;
    diagnosisDate = widget.item.diagnosisDate.isEmpty
        ? null
        : DateTime.tryParse(widget.item.diagnosisDate);
    notesController = TextEditingController(text: widget.item.notes);
    glucoseController = TextEditingController(
      text: _valueText(profile['glucose_target']),
    );
    hba1cController = TextEditingController(
      text: _valueText(profile['hba1c_target']),
    );
    sodiumController = TextEditingController(
      text: _valueText(profile['sodium_limit']),
    );
    systolicController = TextEditingController(
      text: _valueText(profile['systolic_target']),
    );
    diastolicController = TextEditingController(
      text: _valueText(profile['diastolic_target']),
    );
    hdlController = TextEditingController(
      text: _valueText(profile['hdl_target']),
    );
    triglyceridesController = TextEditingController(
      text: _valueText(profile['triglyceride_target']),
    );
    followupController = TextEditingController(
      text: _valueText(profile['followup_interval_days']),
    );
  }

  @override
  void dispose() {
    notesController.dispose();
    glucoseController.dispose();
    hba1cController.dispose();
    sodiumController.dispose();
    systolicController.dispose();
    diastolicController.dispose();
    hdlController.dispose();
    triglyceridesController.dispose();
    followupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit condition',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: severityCode,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: widget.item.conditionType.severityOptions
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.code,
                      child: Text(item.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => severityCode = value ?? severityCode),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(
                  value: 'controlled',
                  child: Text('Controlled'),
                ),
                DropdownMenuItem(
                  value: 'needs_attention',
                  child: Text('Needs attention'),
                ),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (value) => setState(() => status = value ?? status),
            ),
            const SizedBox(height: 12),
            _DateRow(
              label: 'Diagnosis date',
              value: diagnosisDate,
              onPick: (value) => setState(() => diagnosisDate = value),
            ),
            TextField(
              controller: notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Condition setup'),
              initiallyExpanded: true,
              children: _buildProfileFields(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    _EditConditionDraft(
                      severityCode: severityCode,
                      status: status,
                      diagnosisDate: diagnosisDate,
                      notes: notesController.text.trim(),
                      profileData: _buildProfileData(),
                      targetOverrides: _buildOverrides(),
                    ),
                  );
                },
                child: const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProfileFields() {
    switch (widget.item.conditionType.slug) {
      case 'diabetes':
        return [
          TextField(
            controller: glucoseController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Glucose target'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: hba1cController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'HbA1c target'),
          ),
        ];
      case 'hypertension':
        return [
          TextField(
            controller: systolicController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Systolic target'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: diastolicController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Diastolic target'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: sodiumController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sodium limit'),
          ),
        ];
      case 'dyslipidemia':
        return [
          TextField(
            controller: hdlController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'HDL target'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: triglyceridesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Triglycerides target',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: followupController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Follow-up interval (days)',
            ),
          ),
        ];
      default:
        return const [];
    }
  }

  Map<String, dynamic> _buildProfileData() {
    switch (widget.item.conditionType.slug) {
      case 'diabetes':
        return {
          if (double.tryParse(glucoseController.text.trim()) != null)
            'glucose_target': double.parse(glucoseController.text.trim()),
          if (double.tryParse(hba1cController.text.trim()) != null)
            'hba1c_target': double.parse(hba1cController.text.trim()),
        };
      case 'hypertension':
        return {
          if (double.tryParse(systolicController.text.trim()) != null)
            'systolic_target': double.parse(systolicController.text.trim()),
          if (double.tryParse(diastolicController.text.trim()) != null)
            'diastolic_target': double.parse(diastolicController.text.trim()),
          if (double.tryParse(sodiumController.text.trim()) != null)
            'sodium_limit': double.parse(sodiumController.text.trim()),
        };
      case 'dyslipidemia':
        return {
          if (double.tryParse(hdlController.text.trim()) != null)
            'hdl_target': double.parse(hdlController.text.trim()),
          if (double.tryParse(triglyceridesController.text.trim()) != null)
            'triglyceride_target': double.parse(
              triglyceridesController.text.trim(),
            ),
          if (int.tryParse(followupController.text.trim()) != null)
            'followup_interval_days': int.parse(followupController.text.trim()),
        };
      default:
        return const {};
    }
  }

  List<ConditionTargetOverridePayload> _buildOverrides() {
    final overrides = <ConditionTargetOverridePayload>[];
    final glucose = double.tryParse(glucoseController.text.trim());
    if (glucose != null && widget.item.conditionType.slug == 'diabetes') {
      overrides.add(
        ConditionTargetOverridePayload(
          targetKey: 'fasting_glucose',
          targetName: 'Custom fasting glucose goal',
          category: 'monitoring',
          metricKey: 'fasting_glucose',
          evaluationMode: 'latest_indicator',
          unit: 'mg/dL',
          minValue: null,
          maxValue: glucose,
          sourceType: 'physician_override',
          guidance: 'Clinician-provided fasting glucose goal.',
        ),
      );
    }
    final sodium = double.tryParse(sodiumController.text.trim());
    if (sodium != null && widget.item.conditionType.slug == 'hypertension') {
      overrides.add(
        ConditionTargetOverridePayload(
          targetKey: 'sodium_mg',
          targetName: 'Custom sodium ceiling',
          category: 'nutrition',
          metricKey: 'sodium_mg',
          evaluationMode: 'daily_total',
          unit: 'mg/day',
          minValue: null,
          maxValue: sodium,
          sourceType: 'physician_override',
          guidance: 'Clinician-provided sodium limit.',
        ),
      );
    }
    final systolic = double.tryParse(systolicController.text.trim());
    if (systolic != null && widget.item.conditionType.slug == 'hypertension') {
      overrides.add(
        ConditionTargetOverridePayload(
          targetKey: 'blood_pressure_systolic',
          targetName: 'Custom systolic target',
          category: 'monitoring',
          metricKey: 'blood_pressure_systolic',
          evaluationMode: 'latest_indicator',
          unit: 'mm Hg',
          minValue: null,
          maxValue: systolic,
          sourceType: 'physician_override',
          guidance: 'Clinician-provided blood pressure goal.',
        ),
      );
    }
    final diastolic = double.tryParse(diastolicController.text.trim());
    if (diastolic != null && widget.item.conditionType.slug == 'hypertension') {
      overrides.add(
        ConditionTargetOverridePayload(
          targetKey: 'blood_pressure_diastolic',
          targetName: 'Custom diastolic target',
          category: 'monitoring',
          metricKey: 'blood_pressure_diastolic',
          evaluationMode: 'latest_indicator',
          unit: 'mm Hg',
          minValue: null,
          maxValue: diastolic,
          sourceType: 'physician_override',
          guidance: 'Clinician-provided blood pressure goal.',
        ),
      );
    }
    return overrides;
  }

  String _valueText(dynamic value) => value?.toString() ?? '';
}

class _ConditionReadingSheet extends StatefulWidget {
  const _ConditionReadingSheet({required this.condition});

  final ChronicCondition condition;

  @override
  State<_ConditionReadingSheet> createState() => _ConditionReadingSheetState();
}

class _ConditionReadingSheetState extends State<_ConditionReadingSheet> {
  final valueController = TextEditingController();
  final systolicController = TextEditingController();
  final diastolicController = TextEditingController();
  final pulseController = TextEditingController();
  final hdlController = TextEditingController();
  final triglyceridesController = TextEditingController();
  final ldlController = TextEditingController();
  final totalController = TextEditingController();
  String readingType = 'fasting';
  DateTime recordedAt = DateTime.now();

  @override
  void dispose() {
    valueController.dispose();
    systolicController.dispose();
    diastolicController.dispose();
    pulseController.dispose();
    hdlController.dispose();
    triglyceridesController.dispose();
    ldlController.dispose();
    totalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.condition.conditionType.slug == 'dyslipidemia'
                  ? 'Log lipid follow-up'
                  : 'Log reading',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _DateRow(
              label: 'Recorded at',
              value: recordedAt,
              onPick: (value) =>
                  setState(() => recordedAt = value ?? recordedAt),
            ),
            const SizedBox(height: 12),
            ..._buildReadingFields(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_buildPayload()),
                child: const Text('Save reading'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReadingFields() {
    switch (widget.condition.conditionType.slug) {
      case 'diabetes':
        return [
          DropdownButtonFormField<String>(
            initialValue: readingType,
            decoration: const InputDecoration(labelText: 'Reading type'),
            items: const [
              DropdownMenuItem(value: 'fasting', child: Text('Fasting')),
              DropdownMenuItem(
                value: 'before_meal',
                child: Text('Before meal'),
              ),
              DropdownMenuItem(value: 'after_meal', child: Text('After meal')),
              DropdownMenuItem(value: 'bedtime', child: Text('Bedtime')),
            ],
            onChanged: (value) =>
                setState(() => readingType = value ?? readingType),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: valueController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Glucose value'),
          ),
        ];
      case 'hypertension':
        return [
          TextField(
            controller: systolicController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Systolic'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: diastolicController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Diastolic'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: pulseController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Pulse (optional)'),
          ),
        ];
      case 'dyslipidemia':
        return [
          TextField(
            controller: hdlController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'HDL'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: triglyceridesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Triglycerides'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ldlController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'LDL'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: totalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Total cholesterol'),
          ),
        ];
      default:
        return const [];
    }
  }

  Map<String, dynamic> _buildPayload() {
    final timestamp = recordedAt.toUtc().toIso8601String();
    switch (widget.condition.conditionType.slug) {
      case 'diabetes':
        return {
          'indicator_type': 'glucose',
          'value': double.tryParse(valueController.text.trim()) ?? 0,
          'reading_type': readingType,
          'recorded_at': timestamp,
        };
      case 'hypertension':
        return {
          'indicator_type': 'blood_pressure',
          'systolic': double.tryParse(systolicController.text.trim()) ?? 0,
          'diastolic': double.tryParse(diastolicController.text.trim()) ?? 0,
          if (double.tryParse(pulseController.text.trim()) != null)
            'pulse': double.parse(pulseController.text.trim()),
          'recorded_at': timestamp,
        };
      case 'dyslipidemia':
        return {
          'indicator_type': 'lipid_panel',
          'hdl': double.tryParse(hdlController.text.trim()) ?? 0,
          'triglycerides':
              double.tryParse(triglyceridesController.text.trim()) ?? 0,
          'ldl': double.tryParse(ldlController.text.trim()) ?? 0,
          'total_cholesterol':
              double.tryParse(totalController.text.trim()) ?? 0,
          'recorded_at': timestamp,
        };
      default:
        return const {};
    }
  }
}

class _MedicationDraft {
  final String name;
  final String scientificName;
  final String dosage;
  final String dosageAmount;
  final String dosageUnit;
  final String instructions;
  final String relationToMeal;
  final List<int> recurrencePattern;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool reminderEnabled;
  final int reminderLeadMinutes;
  final List<ChronicMedicationSchedulePayload> schedules;

  const _MedicationDraft({
    required this.name,
    required this.scientificName,
    required this.dosage,
    required this.dosageAmount,
    required this.dosageUnit,
    required this.instructions,
    required this.relationToMeal,
    required this.recurrencePattern,
    required this.startDate,
    required this.endDate,
    required this.reminderEnabled,
    required this.reminderLeadMinutes,
    required this.schedules,
  });
}

class _MedicationSheet extends StatefulWidget {
  // ignore: unused_element_parameter
  const _MedicationSheet({required this.condition, this.medication});

  final ChronicCondition condition;
  final ChronicMedication? medication;

  @override
  State<_MedicationSheet> createState() => _MedicationSheetState();
}

class _MedicationSheetState extends State<_MedicationSheet> {
  late final TextEditingController nameController;
  late final TextEditingController scientificController;
  late final TextEditingController dosageAmountController;
  late final TextEditingController dosageUnitController;
  late final TextEditingController instructionsController;
  late String relationToMeal;
  late DateTime? startDate;
  late DateTime? endDate;
  late bool reminderEnabled;
  late int reminderLeadMinutes;
  late List<TimeOfDay> times;
  late List<int> recurrenceDays;

  @override
  void initState() {
    super.initState();
    final item = widget.medication;
    nameController = TextEditingController(text: item?.name ?? '');
    scientificController = TextEditingController(
      text: item?.scientificName ?? '',
    );
    dosageAmountController = TextEditingController(
      text: item?.dosageAmount ?? '',
    );
    dosageUnitController = TextEditingController(text: item?.dosageUnit ?? '');
    instructionsController = TextEditingController(
      text: item?.instructions ?? '',
    );
    relationToMeal = item?.relationToMeal ?? 'anytime';
    startDate = item?.startDate.isEmpty ?? true
        ? DateTime.now()
        : DateTime.tryParse(item!.startDate);
    endDate = item?.endDate.isEmpty ?? true
        ? null
        : DateTime.tryParse(item!.endDate);
    reminderEnabled = item?.reminderEnabled ?? true;
    reminderLeadMinutes = item?.reminderLeadMinutes ?? 15;
    times = (item?.schedules ?? const []).map((schedule) {
      final parts = schedule.timeOfDay.split(':');
      final hour = int.tryParse(parts.first) ?? 8;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    }).toList();
    if (times.isEmpty) {
      times = [const TimeOfDay(hour: 8, minute: 0)];
    }
    recurrenceDays = item?.recurrencePattern.isNotEmpty == true
        ? List<int>.from(item!.recurrencePattern)
        : [0, 1, 2, 3, 4, 5, 6];
  }

  @override
  void dispose() {
    nameController.dispose();
    scientificController.dispose();
    dosageAmountController.dispose();
    dosageUnitController.dispose();
    instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.medication == null ? 'Add medication' : 'Edit medication',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Medication name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: scientificController,
              decoration: const InputDecoration(
                labelText: 'Scientific or trade name',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: dosageAmountController,
                    decoration: const InputDecoration(labelText: 'Dose amount'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: dosageUnitController,
                    decoration: const InputDecoration(labelText: 'Dose unit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: relationToMeal,
              decoration: const InputDecoration(labelText: 'Relation to meal'),
              items: const [
                DropdownMenuItem(
                  value: 'before_meal',
                  child: Text('Before meal'),
                ),
                DropdownMenuItem(value: 'with_meal', child: Text('With meal')),
                DropdownMenuItem(
                  value: 'after_meal',
                  child: Text('After meal'),
                ),
                DropdownMenuItem(value: 'anytime', child: Text('Anytime')),
              ],
              onChanged: (value) =>
                  setState(() => relationToMeal = value ?? relationToMeal),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: instructionsController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Instructions'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable reminders'),
              value: reminderEnabled,
              onChanged: (value) => setState(() => reminderEnabled = value),
            ),
            DropdownButtonFormField<int>(
              initialValue: reminderLeadMinutes,
              decoration: const InputDecoration(
                labelText: 'Reminder lead time',
              ),
              items: const [0, 5, 10, 15, 30, 60]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        value == 0 ? 'At dose time' : '$value minutes before',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(
                () => reminderLeadMinutes = value ?? reminderLeadMinutes,
              ),
            ),
            const SizedBox(height: 12),
            _DateRow(
              label: 'Start date',
              value: startDate,
              onPick: (value) => setState(() => startDate = value),
            ),
            _DateRow(
              label: 'End date',
              value: endDate,
              onPick: (value) => setState(() => endDate = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Dose times',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 8, minute: 0),
                    );
                    if (picked != null) {
                      setState(() => times = [...times, picked]);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final time in times)
                  Chip(
                    label: Text(time.format(context)),
                    onDeleted: times.length == 1
                        ? null
                        : () => setState(() => times.remove(time)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Repeat on',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final selected = recurrenceDays.contains(index);
                return FilterChip(
                  label: Text(labels[index]),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      if (selected) {
                        recurrenceDays.remove(index);
                      } else {
                        recurrenceDays.add(index);
                        recurrenceDays.sort();
                      }
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final amount = dosageAmountController.text.trim();
                  final unit = dosageUnitController.text.trim();
                  final dosage = [
                    if (amount.isNotEmpty) amount,
                    if (unit.isNotEmpty) unit,
                  ].join(' ').trim();
                  Navigator.of(context).pop(
                    _MedicationDraft(
                      name: nameController.text.trim(),
                      scientificName: scientificController.text.trim(),
                      dosage: dosage,
                      dosageAmount: amount,
                      dosageUnit: unit,
                      instructions: instructionsController.text.trim(),
                      relationToMeal: relationToMeal,
                      recurrencePattern: recurrenceDays,
                      startDate: startDate,
                      endDate: endDate,
                      reminderEnabled: reminderEnabled,
                      reminderLeadMinutes: reminderLeadMinutes,
                      schedules: times
                          .map(
                            (time) => ChronicMedicationSchedulePayload(
                              timeOfDay:
                                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00',
                              recurrenceDays: recurrenceDays,
                            ),
                          )
                          .toList(),
                    ),
                  );
                },
                child: const Text('Save medication'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        value == null
            ? 'Not set'
            : MaterialLocalizations.of(context).formatMediumDate(value!),
      ),
      trailing: const Icon(Icons.event_outlined),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onPick(picked);
        }
      },
    );
  }
}
