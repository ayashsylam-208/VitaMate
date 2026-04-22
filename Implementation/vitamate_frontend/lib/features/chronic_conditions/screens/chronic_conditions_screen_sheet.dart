part of 'chronic_conditions_screen.dart';

class _ConditionDraft {
  const _ConditionDraft({
    required this.type,
    required this.severityCode,
    required this.status,
    required this.profileData,
    required this.targetOverrides,
    required this.initialReadingPayload,
  });

  final ChronicConditionType type;
  final String severityCode;
  final String status;
  final Map<String, dynamic> profileData;
  final List<ConditionTargetOverridePayload> targetOverrides;
  final Map<String, dynamic> initialReadingPayload;
}

class _ConditionDraftSheet extends StatefulWidget {
  const _ConditionDraftSheet({
    required this.presetType,
    this.systolicFieldKey,
    this.diastolicFieldKey,
    this.pulseFieldKey,
    this.saveButtonKey,
  });

  final ChronicConditionType presetType;
  final String? systolicFieldKey;
  final String? diastolicFieldKey;
  final String? pulseFieldKey;
  final String? saveButtonKey;

  @override
  State<_ConditionDraftSheet> createState() => _ConditionDraftSheetState();
}

class _ConditionDraftSheetState extends State<_ConditionDraftSheet> {
  final hba1cController = TextEditingController();
  final dailyAverageGlucoseController = TextEditingController();
  final systolicController = TextEditingController();
  final diastolicController = TextEditingController();
  final pulseController = TextEditingController();
  final ldlController = TextEditingController();
  final hdlController = TextEditingController();
  final triglyceridesController = TextEditingController();
  final totalCholesterolController = TextEditingController();
  final followupDaysController = TextEditingController(text: '90');

  String status = 'active';
  String diabetesType = 'Type 2';
  bool remindersEnabled = true;

  ChronicConditionType get type => widget.presetType;

  @override
  void dispose() {
    hba1cController.dispose();
    dailyAverageGlucoseController.dispose();
    systolicController.dispose();
    diastolicController.dispose();
    pulseController.dispose();
    ldlController.dispose();
    hdlController.dispose();
    triglyceridesController.dispose();
    totalCholesterolController.dispose();
    followupDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VitaMateTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: VitaMateTheme.borderStrong,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _accentForSlug(type.slug).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _iconForSlug(type.slug),
                        color: _accentForSlug(type.slug),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set up ${type.uiLabel}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: VitaMateTheme.primaryDeep,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _sheetSubtitle(type.slug),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: VitaMateTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SetupCard(
                  title: 'Condition status',
                  subtitle:
                      'Choose the current tracking state for this condition.',
                  child: DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Current status',
                    ),
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
                    ],
                    onChanged: (value) =>
                        setState(() => status = value ?? status),
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildTypeSections(),
                const SizedBox(height: 12),
                _SetupCard(
                  title: 'Health reading reminders',
                  subtitle: type.slug == 'dyslipidemia'
                      ? 'Check-in reminders stay fixed so follow-up logging remains consistent.'
                      : 'Health reading reminders stay fixed so daily tracking remains simple.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: remindersEnabled,
                        title: Text(
                          type.slug == 'dyslipidemia'
                              ? 'Enable follow-up reminders'
                              : 'Enable health reading reminders',
                        ),
                        subtitle: const Text('Morning and evening reminders'),
                        onChanged: (value) =>
                            setState(() => remindersEnabled = value),
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Expanded(child: _PreviewPill(label: 'Morning')),
                          SizedBox(width: 8),
                          Expanded(child: _PreviewPill(label: 'Evening')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SetupCard(
                  title: 'Baseline targets preview',
                  subtitle:
                      'These previews stay coordinated with VitaMate guidance after setup.',
                  child: _TargetPreviewGrid(
                    type: type,
                    followupDays: _followupDays,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: widget.saveButtonKey == null
                        ? null
                        : ValueKey(widget.saveButtonKey!),
                    onPressed: _saveDraft,
                    child: const Text('Save condition'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTypeSections() {
    switch (type.slug) {
      case 'diabetes':
        return [
          _SetupCard(
            title: 'Basic information',
            subtitle: 'Use the same structure as the approved diabetes setup.',
            child: DropdownButtonFormField<String>(
              initialValue: diabetesType,
              decoration: const InputDecoration(labelText: 'Diabetes type'),
              items: const [
                DropdownMenuItem(
                  value: 'Prediabetes',
                  child: Text('Prediabetes'),
                ),
                DropdownMenuItem(value: 'Type 1', child: Text('Type 1')),
                DropdownMenuItem(value: 'Type 2', child: Text('Type 2')),
                DropdownMenuItem(
                  value: 'Gestational',
                  child: Text('Gestational'),
                ),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) =>
                  setState(() => diabetesType = value ?? diabetesType),
            ),
          ),
          const SizedBox(height: 12),
          _SetupCard(
            title: 'Initial readings',
            subtitle: 'Start with the latest values you have available.',
            child: Column(
              children: [
                TextField(
                  controller: hba1cController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'HbA1c average',
                    hintText: 'Example: 6.8',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dailyAverageGlucoseController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Daily average glucose',
                    hintText: 'Example: 118',
                  ),
                ),
              ],
            ),
          ),
        ];
      case 'hypertension':
        return [
          _SetupCard(
            title: 'Initial blood pressure',
            subtitle:
                'Add a recent reading to start classification and tracking.',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: widget.systolicFieldKey == null
                            ? null
                            : ValueKey(widget.systolicFieldKey!),
                        controller: systolicController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Systolic',
                          hintText: '130',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: widget.diastolicFieldKey == null
                            ? null
                            : ValueKey(widget.diastolicFieldKey!),
                        controller: diastolicController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Diastolic',
                          hintText: '80',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: widget.pulseFieldKey == null
                      ? null
                      : ValueKey(widget.pulseFieldKey!),
                  controller: pulseController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pulse (optional)',
                    hintText: '72',
                  ),
                ),
              ],
            ),
          ),
        ];
      case 'dyslipidemia':
        return [
          _SetupCard(
            title: 'Latest lipid follow-up',
            subtitle:
                'Use the latest follow-up or recent average values you have.',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ldlController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'LDL',
                          hintText: '130',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: hdlController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'HDL',
                          hintText: '45',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: triglyceridesController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Triglycerides',
                          hintText: '150',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: totalCholesterolController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Total cholesterol',
                          hintText: '200',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: followupDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up interval (days)',
                    hintText: '90',
                  ),
                ),
              ],
            ),
          ),
        ];
      default:
        return const [];
    }
  }

  void _saveDraft() {
    final initialReadingPayload = _buildInitialReadingPayload();
    if (initialReadingPayload == null) {
      return;
    }
    final severityCode = _resolveSeverityCode();
    if (severityCode.isEmpty) {
      _showValidation(
        'Condition setup data is incomplete. Refresh the page and try again.',
      );
      return;
    }

    Navigator.of(context).pop(
      _ConditionDraft(
        type: type,
        severityCode: severityCode,
        status: status,
        profileData: _buildProfileData(),
        targetOverrides: const [],
        initialReadingPayload: initialReadingPayload,
      ),
    );
  }

  Map<String, dynamic>? _buildInitialReadingPayload() {
    final timestamp = DateTime.now().toUtc().toIso8601String();

    switch (type.slug) {
      case 'diabetes':
        final glucose = _doubleValue(dailyAverageGlucoseController.text);
        if (glucose == null) {
          return const {};
        }
        return {
          'indicator_type': 'glucose',
          'value': glucose,
          'reading_type': 'fasting',
          'recorded_at': timestamp,
        };
      case 'hypertension':
        final systolic = _doubleValue(systolicController.text);
        final diastolic = _doubleValue(diastolicController.text);
        if (systolic == null && diastolic == null) {
          return const {};
        }
        if (systolic == null || diastolic == null) {
          _showValidation(
            'Add both systolic and diastolic values to save the first blood pressure reading.',
          );
          return null;
        }
        return {
          'indicator_type': 'blood_pressure',
          'systolic': systolic,
          'diastolic': diastolic,
          if (_doubleValue(pulseController.text) != null)
            'pulse': _doubleValue(pulseController.text),
          'recorded_at': timestamp,
        };
      case 'dyslipidemia':
        final ldl = _doubleValue(ldlController.text);
        final hdl = _doubleValue(hdlController.text);
        final triglycerides = _doubleValue(triglyceridesController.text);
        final total = _doubleValue(totalCholesterolController.text);
        final hasAnyValue =
            ldl != null ||
            hdl != null ||
            triglycerides != null ||
            total != null;
        if (!hasAnyValue) {
          return const {};
        }
        if (ldl == null ||
            hdl == null ||
            triglycerides == null ||
            total == null) {
          _showValidation(
            'Add LDL, HDL, triglycerides, and total cholesterol to save the first follow-up entry.',
          );
          return null;
        }
        return {
          'indicator_type': 'lipid_panel',
          'ldl': ldl,
          'hdl': hdl,
          'triglycerides': triglycerides,
          'total_cholesterol': total,
          'reading_context': 'followup',
          'recorded_at': timestamp,
        };
      default:
        return const {};
    }
  }

  Map<String, dynamic> _buildProfileData() {
    final data = <String, dynamic>{
      'reading_reminders_enabled': remindersEnabled,
      'reading_reminder_slots': remindersEnabled
          ? const ['morning', 'evening']
          : const <String>[],
    };

    switch (type.slug) {
      case 'diabetes':
        data['diabetes_type'] = diabetesType;
        if (_doubleValue(hba1cController.text) != null) {
          data['hba1c_average'] = _doubleValue(hba1cController.text);
        }
        if (_doubleValue(dailyAverageGlucoseController.text) != null) {
          data['daily_average_glucose'] = _doubleValue(
            dailyAverageGlucoseController.text,
          );
        }
        break;
      case 'hypertension':
        if (_doubleValue(systolicController.text) != null) {
          data['recent_systolic'] = _doubleValue(systolicController.text);
        }
        if (_doubleValue(diastolicController.text) != null) {
          data['recent_diastolic'] = _doubleValue(diastolicController.text);
        }
        if (_doubleValue(pulseController.text) != null) {
          data['recent_pulse'] = _doubleValue(pulseController.text);
        }
        break;
      case 'dyslipidemia':
        if (_doubleValue(ldlController.text) != null) {
          data['latest_ldl'] = _doubleValue(ldlController.text);
        }
        if (_doubleValue(hdlController.text) != null) {
          data['latest_hdl'] = _doubleValue(hdlController.text);
        }
        if (_doubleValue(triglyceridesController.text) != null) {
          data['latest_triglycerides'] = _doubleValue(
            triglyceridesController.text,
          );
        }
        if (_doubleValue(totalCholesterolController.text) != null) {
          data['latest_total_cholesterol'] = _doubleValue(
            totalCholesterolController.text,
          );
        }
        if (_followupDays != null) {
          data['followup_interval_days'] = _followupDays;
        }
        break;
    }
    return data;
  }

  String _resolveSeverityCode() {
    switch (type.slug) {
      case 'diabetes':
        final hba1c = _doubleValue(hba1cController.text);
        final averageGlucose = _doubleValue(dailyAverageGlucoseController.text);
        if (diabetesType == 'Prediabetes' ||
            (hba1c != null && hba1c >= 5.7 && hba1c < 6.5)) {
          return _preferredSeverity(['prediabetes']);
        }
        if (status == 'needs_attention' ||
            (averageGlucose != null && averageGlucose >= 180)) {
          return _preferredSeverity(['diabetes_intensive']);
        }
        return _preferredSeverity(['diabetes_managed']);
      case 'hypertension':
        final systolic = _doubleValue(systolicController.text);
        final diastolic = _doubleValue(diastolicController.text);
        if (status == 'needs_attention' ||
            (systolic != null && systolic >= 140) ||
            (diastolic != null && diastolic >= 90)) {
          return _preferredSeverity(['stage_2', 'stage_1']);
        }
        if ((systolic != null && systolic >= 130) ||
            (diastolic != null && diastolic >= 80) ||
            status == 'active') {
          return _preferredSeverity(['stage_1', 'elevated']);
        }
        return _preferredSeverity(['elevated']);
      case 'dyslipidemia':
        final ldl = _doubleValue(ldlController.text);
        if (ldl != null && ldl >= 190) {
          return _preferredSeverity(['very_high_ldl', 'high_ldl']);
        }
        if (status == 'needs_attention' || (ldl != null && ldl >= 160)) {
          return _preferredSeverity(['high_ldl', 'borderline_high_ldl']);
        }
        return _preferredSeverity(['borderline_high_ldl']);
      default:
        return type.severityOptions.isNotEmpty
            ? type.severityOptions.first.code
            : '';
    }
  }

  String _preferredSeverity(List<String> preferredCodes) {
    final available = type.severityOptions.map((item) => item.code).toList();
    for (final code in preferredCodes) {
      if (available.contains(code)) {
        return code;
      }
    }
    if (available.isNotEmpty) {
      return available.first;
    }
    if (preferredCodes.isNotEmpty) {
      return preferredCodes.first;
    }
    switch (type.slug) {
      case 'diabetes':
        return 'diabetes_managed';
      case 'hypertension':
        return 'elevated';
      case 'dyslipidemia':
        return 'borderline_high_ldl';
      default:
        return '';
    }
  }

  String _sheetSubtitle(String slug) {
    switch (slug) {
      case 'diabetes':
        return 'Basic information, initial readings, reminders, and baseline targets.';
      case 'hypertension':
        return 'Blood-pressure setup with reminders and target preview.';
      case 'dyslipidemia':
        return 'Periodic lipid follow-up with nutrition-linked awareness.';
      default:
        return type.description;
    }
  }

  int? get _followupDays => int.tryParse(followupDaysController.text.trim());

  double? _doubleValue(String value) => double.tryParse(value.trim());

  void _showValidation(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: VitaMateTheme.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TargetPreviewGrid extends StatelessWidget {
  const _TargetPreviewGrid({required this.type, required this.followupDays});

  final ChronicConditionType type;
  final int? followupDays;

  @override
  Widget build(BuildContext context) {
    final items = switch (type.slug) {
      'diabetes' => const [
        ('Pre-meal glucose', '80-130 mg/dL'),
        ('HbA1c goal', 'About 7.0%'),
        ('Reminder rhythm', 'Morning + evening'),
      ],
      'hypertension' => const [
        ('Blood pressure goal', '<130 / 80'),
        ('Sodium ceiling', '1500 mg/day'),
        ('Reminder rhythm', 'Morning + evening'),
      ],
      'dyslipidemia' => [
        const ('LDL focus', 'Goal guided by follow-up'),
        const ('Saturated fat', '<6% kcal'),
        ('Follow-up cadence', '${followupDays ?? 90} days'),
      ],
      _ => const [],
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => SizedBox(
              width: 150,
              child: _PreviewTile(title: item.$1, value: item.$2),
            ),
          )
          .toList(),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: VitaMateTheme.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: VitaMateTheme.primaryDeep,
        ),
      ),
    );
  }
}
