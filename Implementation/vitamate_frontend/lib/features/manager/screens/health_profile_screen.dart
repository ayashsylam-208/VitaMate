import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../auth/models/user.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../state/health_profile_controller.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  late final HealthProfileController _controller;
  final _height = TextEditingController();
  final _weight = TextEditingController();
  DateTime? _birthDate;
  String _gender = 'F';
  double _activityLevel = 1.2;
  String _goal = 'maintain';
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    _controller = HealthProfileController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VitaMateTheme.shellBackground,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final user = _controller.user;
            if (_controller.isLoading && user == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (user == null) {
              return _FailureState(
                message: _controller.error ?? 'Health profile is unavailable.',
                onRetry: _controller.load,
              );
            }
            _fillOnce(user);
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  sliver: SliverList.list(
                    children: [
                      _TopBar(onSave: _save),
                      const SizedBox(height: 18),
                      _PickerCard(
                        title: 'Birth date',
                        value: _birthDate == null
                            ? 'Select date'
                            : DateFormat('MMM d, yyyy').format(_birthDate!),
                        icon: Icons.calendar_month_rounded,
                        onTap: _pickBirthDate,
                      ),
                      const SizedBox(height: 18),
                      const _Label('Gender'),
                      _GenderSegments(
                        value: _gender,
                        onChanged: (value) => setState(() => _gender = value),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _NumberField(
                              label: 'Height',
                              suffix: 'cm',
                              controller: _height,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _NumberField(
                              label: 'Weight',
                              suffix: 'kg',
                              controller: _weight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _ActivityDropdown(
                        value: _activityLevel,
                        onChanged: (value) => setState(() {
                          _activityLevel = value;
                        }),
                      ),
                      const SizedBox(height: 18),
                      _GoalDropdown(
                        value: _goal,
                        onChanged: (value) => setState(() => _goal = value),
                      ),
                      const SizedBox(height: 24),
                      _CalculatedSection(user: user),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _controller.isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(58),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          _controller.isSaving ? 'Saving...' : 'Save changes',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _fillOnce(AuthUser user) {
    if (_filled) return;
    _birthDate = user.profile.birthDate;
    _gender = user.profile.gender.isEmpty ? 'F' : user.profile.gender;
    _height.text = user.profile.height.toStringAsFixed(0);
    _weight.text = user.profile.weight.toStringAsFixed(0);
    _activityLevel = user.profile.activityLevel;
    _goal = user.profile.goal;
    _filled = true;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final payload = <String, dynamic>{
      'gender': _gender,
      'height': double.tryParse(_height.text.trim()) ?? 0,
      'weight': double.tryParse(_weight.text.trim()) ?? 0,
      'activity_level': _activityLevel,
      'goal': _goal,
    };
    if (_birthDate != null) {
      payload['birth_date'] = DateFormat('yyyy-MM-dd').format(_birthDate!);
    }
    final ok = await _controller.save(payload);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Health profile saved.'
              : _controller.error ?? 'Health profile update failed.',
        ),
      ),
    );
    if (ok) Navigator.pop(context);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        const Expanded(
          child: Text(
            'Health profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(onPressed: onSave, child: const Text('Save')),
      ],
    );
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Icon(icon, color: VitaMateTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: VitaMateTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: VitaMateTheme.primaryDeep,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              color: VitaMateTheme.borderStrong,
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderSegments extends StatelessWidget {
  const _GenderSegments({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VitaMateTheme.border),
      ),
      child: Row(
        children: [
          _GenderButton(
            label: 'Female',
            code: 'F',
            selected: value == 'F',
            onChanged: onChanged,
          ),
          _GenderButton(
            label: 'Male',
            code: 'M',
            selected: value == 'M',
            onChanged: onChanged,
          ),
          _GenderButton(
            label: 'Other',
            code: 'O',
            selected: value == 'O',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  const _GenderButton({
    required this.label,
    required this.code,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String code;
  final bool selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? VitaMateTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : VitaMateTheme.textMuted,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.suffix,
    required this.controller,
  });

  final String label;
  final String suffix;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: suffix),
        ),
      ],
    );
  }
}

class _ActivityDropdown extends StatelessWidget {
  const _ActivityDropdown({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final levels = <double, String>{
      1.2: 'Sedentary',
      1.375: 'Lightly active',
      1.55: 'Moderately active',
      1.725: 'Very active',
      1.9: 'Extra active',
    };
    final safeValue = levels.keys.contains(value) ? value : 1.2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Activity level'),
        DropdownButtonFormField<double>(
          initialValue: safeValue,
          items: [
            for (final entry in levels.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}

class _GoalDropdown extends StatelessWidget {
  const _GoalDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const goals = <String, String>{
      'lose': 'Lose weight',
      'maintain': 'Maintain weight',
      'gain': 'Gain weight',
      'muscle': 'Build muscle',
    };
    final safeValue = goals.keys.contains(value) ? value : 'maintain';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Weight goal'),
        DropdownButtonFormField<String>(
          initialValue: safeValue,
          items: [
            for (final entry in goals.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          decoration: const InputDecoration(),
        ),
      ],
    );
  }
}

class _CalculatedSection extends StatelessWidget {
  const _CalculatedSection({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final p = user.profile;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: VitaMateTheme.border),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calculated by VitaMate',
            style: TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CalcPill(
                  label: 'BMI',
                  value: p.bmi.toStringAsFixed(1),
                  icon: Icons.show_chart_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CalcPill(
                  label: 'BMR',
                  value: '${p.bmr}',
                  icon: Icons.local_fire_department_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CalcPill(
                  label: 'Daily calories',
                  value: '${p.dailyCalorieTarget}',
                  icon: Icons.restaurant_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CalcPill(
                  label: 'Step goal',
                  value: '${p.dailyStepGoal}',
                  icon: Icons.directions_walk_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalcPill extends StatelessWidget {
  const _CalcPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: VitaMateTheme.softSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: VitaMateTheme.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: VitaMateTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: VitaMateTheme.primaryDeep,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: VitaMateTheme.border),
  );
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
