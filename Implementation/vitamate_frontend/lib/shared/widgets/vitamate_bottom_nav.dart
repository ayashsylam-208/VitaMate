import 'package:flutter/material.dart';

import '../../core/routing/routes.dart';
import '../../core/theme/vitamate_theme.dart';

class VitaMateBottomNav extends StatelessWidget {
  const VitaMateBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const List<_BottomNavItemData> _items = [
    _BottomNavItemData('Home', Icons.home_outlined, Routes.home),
    _BottomNavItemData('Progress', Icons.bar_chart_rounded, Routes.progress),
    _BottomNavItemData('Meds', Icons.link_rounded, Routes.meds),
    _BottomNavItemData('Habits', Icons.sync_alt_rounded, Routes.habits),
    _BottomNavItemData('Profile', Icons.person_outline_rounded, Routes.score),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: VitaMateTheme.border)),
        boxShadow: const [
          BoxShadow(
            color: VitaMateTheme.shadow,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _BottomNavButton(
                    data: _items[i],
                    selected: currentIndex == i,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({required this.data, required this.selected});

  final _BottomNavItemData data;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? VitaMateTheme.primary
        : VitaMateTheme.borderStrong;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        if (selected) {
          return;
        }
        Navigator.pushReplacementNamed(context, data.route);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? VitaMateTheme.softSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, size: selected ? 22 : 21, color: foreground),
            const SizedBox(height: 3),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItemData {
  const _BottomNavItemData(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}
