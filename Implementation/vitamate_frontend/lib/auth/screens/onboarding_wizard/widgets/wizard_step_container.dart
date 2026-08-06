import 'package:flutter/material.dart';

import '../../../../core/theme/vitamate_theme.dart';

const wizardPageBackground = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    VitaMateTheme.background,
    VitaMateTheme.surface,
    VitaMateTheme.softSurface,
  ],
);

const wizardShellBackground = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [VitaMateTheme.softSurface, VitaMateTheme.surface],
);

const wizardButtonGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [VitaMateTheme.primaryGlow, VitaMateTheme.primary],
);

const wizardDeepPurple = VitaMateTheme.primaryDeep;
const wizardMidPurple = VitaMateTheme.primary;
const wizardHintPurple = VitaMateTheme.textMuted;
const wizardStrokePurple = VitaMateTheme.border;

InputDecoration wizardInputDecoration({
  required String hintText,
  IconData? prefixIcon,
  String? suffixText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: wizardHintPurple,
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, color: wizardHintPurple, size: 20),
    suffixText: suffixText,
    suffixStyle: const TextStyle(
      color: wizardHintPurple,
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
    ),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: wizardStrokePurple),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: wizardMidPurple, width: 1.3),
    ),
  );
}

class WizardStepContainer extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool compact;

  const WizardStepContainer({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, compact ? 6 : 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: compact ? 54 : 58,
            decoration: BoxDecoration(
              gradient: wizardShellBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1457369A),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: wizardMidPurple,
                size: compact ? 24 : 28,
              ),
            ),
          ),
          SizedBox(height: compact ? 16 : 18),
          Text(
            title,
            style: TextStyle(
              color: wizardDeepPurple,
              fontSize: compact ? 22 : 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: wizardMidPurple.withValues(alpha: 0.82),
              fontSize: compact ? 13.5 : 14.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          SizedBox(height: compact ? 22 : 28),
          child,
        ],
      ),
    );
  }
}
