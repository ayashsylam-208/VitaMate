import 'package:flutter/material.dart';

import '../../core/theme/vitamate_theme.dart';

class VitaMateAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VitaMateAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: VitaMateTheme.surface,
      elevation: 0,
      centerTitle: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Image.asset(
            'assets/images/finallogo.png',
            height: 30,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          const Text(
            'VitaMate',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: VitaMateTheme.primaryDeep,
            ),
          ),
        ],
      ),
    );
  }
}
