import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/http_client.dart';
import '../../../core/routing/routes.dart';
import 'onboarding_state.dart';
import 'steps/step_01_basic_info.dart';
import 'steps/step_02_activity_level.dart';
import 'steps/step_03_goal.dart';
import 'steps/step_04_summary.dart';
import 'widgets/wizard_nav_bar.dart';
import 'widgets/wizard_step_container.dart';

class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  static const int _totalSteps = 4;

  final OnboardingState state = OnboardingState();
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;

  int _step = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();

    _ageController.addListener(_syncBasicInfo);
    _heightController.addListener(_syncBasicInfo);
    _weightController.addListener(_syncBasicInfo);
  }

  @override
  void dispose() {
    _ageController.removeListener(_syncBasicInfo);
    _heightController.removeListener(_syncBasicInfo);
    _weightController.removeListener(_syncBasicInfo);
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _syncBasicInfo() {
    setState(() {
      state.age = int.tryParse(_ageController.text.trim());
      state.heightCm = double.tryParse(_heightController.text.trim());
      state.weightKg = double.tryParse(_weightController.text.trim());
    });
  }

  bool get _isCurrentStepValid {
    switch (_step) {
      case 0:
        return state.hasBasicInfo;
      case 1:
        return state.hasActivityLevel;
      case 2:
        return state.hasGoal;
      case 3:
        return true;
      default:
        return false;
    }
  }

  void _setGender(String gender) {
    setState(() => state.gender = gender);
  }

  void _setActivityLevel(double value) {
    setState(() => state.activityLevel = value);
  }

  void _setGoal(String value) {
    setState(() => state.goal = value);
  }

  void _handleBack() {
    if (_saving) return;

    FocusScope.of(context).unfocus();
    if (_step == 0) {
      Navigator.pushReplacementNamed(context, Routes.signup);
      return;
    }

    setState(() => _step -= 1);
  }

  Future<void> _handleNext() async {
    if (_saving || !_isCurrentStepValid) return;

    FocusScope.of(context).unfocus();
    if (_step < _totalSteps - 1) {
      setState(() => _step += 1);
      return;
    }

    await _finish();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);

    try {
      final payload = {
        'gender': state.gender,
        'age': state.age,
        'height': state.heightCm,
        'weight': state.weightKg,
        'activity_level': state.activityLevel,
        'goal': state.goal,
      };

      await HttpClient.dio.patch(ApiEndpoints.me, data: payload);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, Routes.home);
    } on DioException catch (e) {
      String message = 'Failed to save your profile. Please try again.';

      final data = e.response?.data;
      if (data is Map && data.values.isNotEmpty) {
        final firstValue = data.values.first;
        if (firstValue is List && firstValue.isNotEmpty) {
          message = firstValue.first.toString();
        } else if (firstValue != null) {
          message = firstValue.toString();
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error occurred')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildStepContent(bool compact) {
    switch (_step) {
      case 0:
        return Step01BasicInfo(
          key: const ValueKey('step-basic-info'),
          state: state,
          ageController: _ageController,
          heightController: _heightController,
          weightController: _weightController,
          onGenderChanged: _setGender,
          compact: compact,
        );
      case 1:
        return Step02ActivityLevel(
          key: const ValueKey('step-activity-level'),
          selectedLevel: state.activityLevel,
          onSelected: _setActivityLevel,
          compact: compact,
        );
      case 2:
        return Step03Goal(
          key: const ValueKey('step-goal'),
          selectedGoal: state.goal,
          onSelected: _setGoal,
          compact: compact,
        );
      default:
        return Step04Summary(
          key: const ValueKey('step-summary'),
          state: state,
          compact: compact,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(gradient: wizardPageBackground),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 760;
              final shellHeight = constraints.maxHeight > 12
                  ? constraints.maxHeight - 8
                  : constraints.maxHeight;

              return Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      height: shellHeight,
                      decoration: BoxDecoration(
                        gradient: wizardShellBackground,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.88),
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A57369A),
                            blurRadius: 32,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          WizardNavBar(
                            step: _step + 1,
                            totalSteps: _totalSteps,
                            onBack: _handleBack,
                          ),
                          Expanded(
                            child: ClipRect(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeOutCubic,
                                transitionBuilder: (child, animation) {
                                  final slide = Tween<Offset>(
                                    begin: const Offset(0.06, 0),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: slide,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildStepContent(isCompact),
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              12,
                              20,
                              isCompact ? 18 : 22,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.84),
                                  Colors.white.withValues(alpha: 0.98),
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(36),
                                bottomRight: Radius.circular(36),
                              ),
                            ),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: _isCurrentStepValid ? 1 : 0.45,
                              child: SizedBox(
                                height: isCompact ? 48 : 52,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: wizardButtonGradient,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33962CF8),
                                        blurRadius: 18,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _saving || !_isCurrentStepValid
                                        ? null
                                        : _handleNext,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      disabledBackgroundColor:
                                          Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      disabledForegroundColor: Colors.white70,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _saving
                                              ? 'Saving...'
                                              : _step == _totalSteps - 1
                                              ? 'Create Account'
                                              : 'Continue',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (!_saving &&
                                            _step < _totalSteps - 1) ...[
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
