import 'package:flutter/material.dart';

class VitaMateAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VitaMateAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFDDEEFF),
      elevation: 0,

      // ❌ لا centerTitle
      centerTitle: false,

      title: Row(
        mainAxisAlignment: MainAxisAlignment.start, // 👈 كل المجموعة عاليمين
        mainAxisSize: MainAxisSize.max,
        children: [
          Image.asset(
            'assets/images/IMG_8868.PNG',
            height: 30,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 2), // 👈 تلاصق خفيف
          const Text(
            'VitaMate',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: Color(0xFF0B6FAE),
            ),
          ),
        ],
      ),
    );
  }
}
