import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';

const nutritionInk = Color(0xFF18104F);
const nutritionPurple = Color(0xFF6024EE);
const nutritionMuted = Color(0xFF6D6684);
const nutritionLine = Color(0xFFE9E3F3);

class NutritionReferenceBackground extends StatelessWidget {
  const NutritionReferenceBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFF6F1FF),
          Color(0xFFFBFAFF),
          Color(0xFFF7F3FF),
        ],
      ),
    ),
    child: child,
  );
}

class NutritionReferenceCard extends StatelessWidget {
  const NutritionReferenceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color ?? Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFF0EAF8)),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x173A2386),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class NutritionReferenceHeader extends StatelessWidget {
  const NutritionReferenceHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.titleIcon,
    this.onBack,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData? titleIcon;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      NutritionRoundButton(
        icon: Icons.arrow_back_rounded,
        onTap: onBack ?? () => Navigator.maybePop(context),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          children: <Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (titleIcon != null) ...<Widget>[
                    Icon(
                      titleIcon,
                      color: nutritionPurple,
                      size: compact ? 24 : 30,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: nutritionInk,
                      fontSize: compact ? 25 : 31,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 7),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: nutritionMuted,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(width: 10),
      trailing ?? const SizedBox.square(dimension: 50),
    ],
  );
}

class NutritionRoundButton extends StatelessWidget {
  const NutritionRoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 50,
    this.filled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: filled ? Colors.white.withValues(alpha: 0.94) : Colors.transparent,
      shape: const CircleBorder(),
      elevation: filled ? 5 : 0,
      shadowColor: const Color(0x24382189),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, color: nutritionPurple, size: size * 0.52),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class NutritionGradientButton extends StatelessWidget {
  const NutritionGradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.height = 56,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final bool enabled;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: enabled ? 1 : 0.48,
    duration: const Duration(milliseconds: 160),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF5420ED), Color(0xFF9744F2)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x355C2BE7),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, color: Colors.white, size: 23),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class NutritionOutlineButton extends StatelessWidget {
  const NutritionOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.danger = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool danger;
  final double height;

  @override
  Widget build(BuildContext context) => NutritionReferenceCard(
    padding: EdgeInsets.zero,
    radius: 15,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                color: danger ? const Color(0xFFF04D3E) : nutritionPurple,
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: danger ? const Color(0xFFF04D3E) : nutritionPurple,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NutritionStatusBadge extends StatelessWidget {
  const NutritionStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = normalized == 'good'
        ? const Color(0xFF168B43)
        : normalized == 'high'
        ? const Color(0xFFE54848)
        : const Color(0xFFE77B0B);
    final background = normalized == 'good'
        ? const Color(0xFFE7F6E9)
        : normalized == 'high'
        ? const Color(0xFFFFE9E9)
        : const Color(0xFFFFF0E2);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          _titleCase(normalized),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class NutritionIconBubble extends StatelessWidget {
  const NutritionIconBubble({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 42,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: SizedBox.square(
      dimension: size,
      child: Icon(icon, color: color, size: size * 0.55),
    ),
  );
}

class NutritionProgressRing extends StatelessWidget {
  const NutritionProgressRing({
    super.key,
    required this.progress,
    required this.center,
    this.size = 104,
    this.color = nutritionPurple,
    this.track = const Color(0xFFE8DFFF),
  });

  final double progress;
  final Widget center;
  final double size;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _ReferenceRingPainter(
        progress: progress,
        color: color,
        track: track,
      ),
      child: Center(child: center),
    ),
  );
}

class _ReferenceRingPainter extends CustomPainter {
  const _ReferenceRingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(size.width * 0.09, 7.0);
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      rect,
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
  bool shouldRepaint(covariant _ReferenceRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

String nutritionNumber(num value, {int decimals = 0}) {
  final number = value.toDouble();
  if (number == number.roundToDouble()) return number.round().toString();
  return number.toStringAsFixed(decimals == 0 ? 1 : decimals);
}

String nutritionTime(DateTime? value) {
  if (value == null) return '--:--';
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String nutritionMealTypeLabel(String value) => switch (value) {
  'breakfast' => 'Breakfast',
  'lunch' => 'Lunch',
  'dinner' => 'Dinner',
  'snack' => 'Snack',
  'dessert' => 'Dessert',
  _ => 'Drink',
};

IconData nutritionMealTypeIcon(String value) => switch (value) {
  'breakfast' => Icons.wb_twilight_rounded,
  'lunch' => Icons.wb_sunny_outlined,
  'dinner' => Icons.nightlight_round,
  'snack' => Icons.apple_rounded,
  'dessert' => Icons.cake_outlined,
  _ => Icons.local_drink_outlined,
};

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

const nutritionPagePadding = EdgeInsets.fromLTRB(20, 18, 20, 28);

const nutritionGradient = LinearGradient(
  colors: <Color>[VitaMateTheme.primary, VitaMateTheme.primaryGlow],
);
