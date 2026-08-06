import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/medication_dose_log.dart';
import '../models/medication_today_plan.dart';
import '../widgets/medication_ui.dart';

class MedicationDoseLoggedSuccessScreen extends StatelessWidget {
  const MedicationDoseLoggedSuccessScreen({
    super.key,
    required this.dose,
    this.daySummary,
    this.nextDose,
    this.streak = 0,
  });

  final MedicationDoseLog dose;
  final MedicationTodaySummary? daySummary;
  final MedicationDoseLog? nextDose;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final points = dose.pointsApplied;
    final hasProgressDetails = daySummary != null || nextDose != null;
    return Scaffold(
      backgroundColor: MedicationUi.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: MedicationSurfaceCard(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  radius: 22,
                  color: const Color(0xFFEFFAF4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const _ConfettiField(),
                      Column(
                        children: [
                          const SizedBox(height: 8),
                          const _SuccessMark(),
                          const SizedBox(height: 24),
                          const Text(
                            'Dose logged!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: VitaMateTheme.primaryDeep,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dose.displayName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: VitaMateTheme.primaryDeep,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            dose.doseLabel,
                            style: const TextStyle(
                              color: VitaMateTheme.primaryDeep,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                color: Color(0xFF16765E),
                                size: 18,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                MedicationUi.timeLabel(
                                  dose.takenAt ?? dose.scheduledFor,
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF16765E),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 42),
                          _SupportCard(points: points, streak: streak),
                          if (hasProgressDetails) ...[
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                if (daySummary != null)
                                  Expanded(
                                    child: _ProgressFactCard(
                                      icon: Icons.medication_liquid_outlined,
                                      title: 'Remaining today',
                                      value:
                                          '${daySummary!.unresolved} ${daySummary!.unresolved == 1 ? 'dose' : 'doses'}',
                                    ),
                                  ),
                                if (daySummary != null && nextDose != null)
                                  const SizedBox(width: 12),
                                if (nextDose != null)
                                  Expanded(
                                    child: _ProgressFactCard(
                                      icon: Icons.schedule_rounded,
                                      title: 'Next dose',
                                      value: MedicationUi.timeLabel(
                                        nextDose!.scheduledFor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              child: const Text('Done'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF63D896), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x552EC98D),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 72),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.points, required this.streak});

  final int points;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return MedicationSurfaceCard(
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Row(
        children: [
          if (points != 0) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: VitaMateTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: VitaMateTheme.primary,
                    size: 16,
                  ),
                  Text(
                    '${points > 0 ? '+' : ''}$points',
                    style: const TextStyle(
                      color: VitaMateTheme.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          const Expanded(
            child: Text(
              "Great job! You're taking care of your health.",
              style: TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
          if (streak > 0) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(
                      value: 0.86,
                      strokeWidth: 4,
                      color: VitaMateTheme.success,
                      backgroundColor: MedicationUi.successSoft,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$streak',
                        style: const TextStyle(
                          color: VitaMateTheme.primaryDeep,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'day streak',
                        style: TextStyle(
                          color: VitaMateTheme.textMuted,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressFactCard extends StatelessWidget {
  const _ProgressFactCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MedicationSurfaceCard(
      padding: const EdgeInsets.all(14),
      radius: 15,
      child: Row(
        children: [
          Icon(icon, color: VitaMateTheme.primaryDeep, size: 24),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: VitaMateTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiField extends StatelessWidget {
  const _ConfettiField();

  @override
  Widget build(BuildContext context) {
    const pieces = [
      _ConfettiPiece(20, 16, Color(0xFFF17B65)),
      _ConfettiPiece(74, 54, Color(0xFFB595FF)),
      _ConfettiPiece(38, 118, Color(0xFFE3C65F)),
      _ConfettiPiece(214, 34, Color(0xFF5F7EE6)),
      _ConfettiPiece(252, 86, Color(0xFF4EC7A4)),
      _ConfettiPiece(284, 152, Color(0xFF7E52FF)),
      _ConfettiPiece(92, 152, Color(0xFF7ED0A0)),
    ];
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            for (final piece in pieces)
              Positioned(
                left: piece.left,
                top: piece.top,
                child: Transform.rotate(
                  angle: 0.7,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: piece.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  const _ConfettiPiece(this.left, this.top, this.color);

  final double left;
  final double top;
  final Color color;
}
