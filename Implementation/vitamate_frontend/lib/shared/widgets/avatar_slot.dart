import 'package:flutter/material.dart';

class AvatarSlot extends StatelessWidget {
  final double size;
  final ImageProvider? image;
  final VoidCallback? onTap;

  const AvatarSlot({super.key, this.size = 110, this.image, this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final widgetBody = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,

        // ✅ بدون خلفية بيضا
        color: Colors.transparent,

        // ✅ إطار بنفس لون الزر
        border: Border.all(color: primary, width: 2.5),

        // ✅ ظل خفيف (أحلى)
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.18),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: image != null
            ? Image(image: image!, fit: BoxFit.cover)
            : Center(
                child: Icon(
                  Icons.person_outline_rounded,
                  size: size * 0.55,
                  color: primary, // ✅ نفس لون الزر
                ),
              ),
      ),
    );

    if (onTap == null) return widgetBody;
    return GestureDetector(onTap: onTap, child: widgetBody);
  }
}
