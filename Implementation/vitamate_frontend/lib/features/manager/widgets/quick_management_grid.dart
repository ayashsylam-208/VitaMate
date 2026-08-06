import 'package:flutter/material.dart';

import '../../../core/theme/vitamate_theme.dart';
import '../models/manager_models.dart';

class QuickManagementGrid extends StatelessWidget {
  const QuickManagementGrid({super.key, required this.actions});

  final List<ManagerQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final items = actions.isEmpty
        ? const [
            ManagerQuickAction(
              key: 'health_profile',
              title: 'Health Profile',
              route: '/my-vitamate/health-profile',
              icon: 'favorite',
            ),
            ManagerQuickAction(
              key: 'goals',
              title: 'Goals',
              route: '/my-vitamate/goals',
              icon: 'flag',
            ),
            ManagerQuickAction(
              key: 'notifications',
              title: 'Notifications',
              route: '/my-vitamate/notifications',
              icon: 'notifications',
            ),
            ManagerQuickAction(
              key: 'privacy',
              title: 'Privacy',
              route: '/my-vitamate/privacy',
              icon: 'shield',
            ),
          ]
        : actions;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.42,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.pushNamed(context, item.route),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: VitaMateTheme.border),
              boxShadow: const [
                BoxShadow(
                  color: VitaMateTheme.shadow,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: VitaMateTheme.softSurface,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    _iconFor(item.icon),
                    color: VitaMateTheme.primary,
                  ),
                ),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: VitaMateTheme.primaryDeep,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static IconData _iconFor(String icon) {
    switch (icon) {
      case 'flag':
        return Icons.flag_rounded;
      case 'notifications':
        return Icons.notifications_active_outlined;
      case 'shield':
        return Icons.shield_outlined;
      case 'favorite':
      default:
        return Icons.favorite_border_rounded;
    }
  }
}
