import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';

class NutritionCard extends StatelessWidget {
  const NutritionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = VitaMateTheme.surface,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: VitaMateTheme.border),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: VitaMateTheme.shadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

class NutritionPageHeader extends StatelessWidget {
  const NutritionPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      if (showBack) ...<Widget>[
        IconButton.filledTonal(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                color: VitaMateTheme.primaryDeep,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: VitaMateTheme.textMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) trailing!,
    ],
  );
}

class NutritionSectionTitle extends StatelessWidget {
  const NutritionSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      if (actionLabel != null)
        TextButton(onPressed: onAction, child: Text(actionLabel!)),
    ],
  );
}

class NutritionProgressRing extends StatelessWidget {
  const NutritionProgressRing({
    super.key,
    required this.progress,
    required this.center,
    this.size = 104,
    this.color = VitaMateTheme.primary,
  });

  final double progress;
  final Widget center;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _RingPainter(progress: progress, color: color),
      child: Center(child: center),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(size.width * 0.1, 8.0);
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..color = VitaMateTheme.softSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class NutritionErrorView extends StatelessWidget {
  const NutritionErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.cloud_off_rounded,
            size: 54,
            color: VitaMateTheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );
}

String compactNumber(num value, {int decimals = 0}) {
  final number = value.toDouble();
  if (number == number.roundToDouble()) return number.round().toString();
  return number.toStringAsFixed(decimals == 0 ? 1 : decimals);
}
